import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:traceitem_mobile/core/api_service.dart';
import 'package:traceitem_mobile/core/meta_snapshot_store.dart';
import 'package:traceitem_mobile/core/offline_db.dart';
import 'package:traceitem_mobile/core/offline_delta_helper.dart';
import 'package:traceitem_mobile/core/offline_sync_service.dart';
import 'package:traceitem_mobile/models/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Offline entry & multi-user snapshot isolation', () {
    test('MetaSnapshotStore isolates houses/rooms/categories by userId', () async {
      SharedPreferences.setMockInitialValues({});

      await MetaSnapshotStore.saveSnapshot(
        userId: 1,
        houses: [
          House(
            id: 10,
            userId: 1,
            name: '妈妈的家',
            icon: '🏡',
            sortOrder: 0,
            isActive: true,
          ),
        ],
        rooms: [
          Room(
            id: 100,
            houseId: 10,
            userId: 1,
            name: '客厅',
            icon: '🛋️',
            sortOrder: 0,
            isActive: true,
          ),
        ],
        categories: [
          Category(id: 1, name: '玩具', icon: '🧸', isActive: true),
        ],
      );

      await MetaSnapshotStore.saveSnapshot(
        userId: 2,
        houses: [
          House(
            id: 20,
            userId: 2,
            name: '爸爸的书房',
            icon: '📚',
            sortOrder: 0,
            isActive: true,
          ),
        ],
        rooms: [
          Room(
            id: 200,
            houseId: 20,
            userId: 2,
            name: '书桌',
            icon: '🪑',
            sortOrder: 0,
            isActive: true,
          ),
        ],
        categories: [
          Category(id: 2, name: '数码', icon: '💻', isActive: true),
        ],
      );

      final snap1 = await MetaSnapshotStore.loadSnapshot(1);
      final snap2 = await MetaSnapshotStore.loadSnapshot(2);
      final snap3 = await MetaSnapshotStore.loadSnapshot(3);

      expect(snap1, isNotNull);
      expect(snap1!.houses.single.name, '妈妈的家');
      expect(snap1.rooms.single.houseId, 10);
      expect(snap1.categories.single.name, '玩具');

      expect(snap2, isNotNull);
      expect(snap2!.houses.single.name, '爸爸的书房');
      expect(snap2.rooms.single.houseId, 20);
      expect(snap2.categories.single.name, '数码');

      expect(snap3, isNull);
    });

    test('ApiService.isNetworkError detects connection/timeout vs 4xx', () {
      final opts = RequestOptions(path: '/api/items');
      expect(
        ApiService.isNetworkError(
          DioException(requestOptions: opts, type: DioExceptionType.connectionError),
        ),
        isTrue,
      );
      expect(
        ApiService.isNetworkError(
          DioException(requestOptions: opts, type: DioExceptionType.connectionTimeout),
        ),
        isTrue,
      );
      expect(
        ApiService.isNetworkError(const SocketException('No route to host')),
        isTrue,
      );
      expect(
        ApiService.isNetworkError(
          DioException(
            requestOptions: opts,
            type: DioExceptionType.badResponse,
            response: Response(requestOptions: opts, statusCode: 409),
          ),
        ),
        isFalse,
      );
    });

    test('OfflineSyncService.generateClientUuid generates unique UUID v4', () {
      final uuid1 = OfflineSyncService.generateClientUuid();
      final uuid2 = OfflineSyncService.generateClientUuid();
      final v4Regex = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      );
      expect(v4Regex.hasMatch(uuid1), isTrue);
      expect(v4Regex.hasMatch(uuid2), isTrue);
      expect(uuid1, isNot(equals(uuid2)));
    });

    test('OfflineOutboxRecord.fromRow decodes SQLite row payload & attachments', () {
      final record = OfflineOutboxRecord.fromRow({
        'id': 7,
        'user_id': 42,
        'client_uuid': '11111111-1111-4111-8111-111111111111',
        'item_name': '乐高积木盒',
        'payload_json': jsonEncode({'house_id': 1, 'room_id': 2, 'name': '乐高积木盒'}),
        'attachments_json': jsonEncode([
          {'media_type': 'image', 'local_path': '/tmp/a.jpg', 'is_offline_draft': true},
        ]),
        'status': 'failed',
        'error_msg': '房间不存在',
        'created_at': 1700000000000,
      });

      expect(record.id, 7);
      expect(record.userId, 42);
      expect(record.itemName, '乐高积木盒');
      expect(record.payload['house_id'], 1);
      expect(record.attachments.single['is_offline_draft'], isTrue);
      expect(record.status, 'failed');
      expect(record.errorMsg, '房间不存在');
    });

    test('OfflineDeltaHelper computes minimal changed_fields, attachment delta and merges patches', () {
      final baseline = Item(
        id: 5,
        userId: 1,
        houseId: 10,
        roomId: 100,
        categoryId: 2,
        name: '露营灯',
        brand: '牧高笛',
        quantity: 1,
        locationDetail: '阳台柜',
        description: '充电款',
        version: 3,
        tags: [Tag(id: 1, name: '户外')],
        attachments: [
          Attachment(
            id: 9,
            itemId: 5,
            mediaType: 'image',
            filePath: 'images/2026/11/a.jpg',
            url: '/api/media/file/images/2026/11/a.jpg',
            fileSize: 100,
            durationSeconds: 0,
          ),
        ],
      );

      final changed = OfflineDeltaHelper.computeChangedFields(baseline, {
        'house_id': 10,
        'room_id': 100,
        'category_id': 2,
        'name': '露营灯',
        'brand': '牧高笛',
        'quantity': 4,
        'location_detail': '阳台柜',
        'description': '充电款',
        'tag_names': ['户外'],
      });
      expect(changed, {'quantity': 4});

      final attDelta = OfflineDeltaHelper.computeAttachmentDelta(baseline, [
        {'media_type': 'image', 'local_path': '/tmp/b.jpg', 'is_offline_draft': true},
      ]);
      expect(attDelta.removedPaths, ['images/2026/11/a.jpg']);
      expect(attDelta.added.length, 1);

      final merged = OfflineDeltaHelper.mergeUpdatePayloads(
        {
          'changed_fields': {'quantity': 4},
          'removed_attachment_paths': ['images/2026/11/a.jpg'],
        },
        {
          'changed_fields': {'quantity': 6, 'location_detail': '玄关抽屉'},
          'removed_attachment_paths': [],
        },
      );
      expect(merged['changed_fields'], {'quantity': 6, 'location_detail': '玄关抽屉'});
      expect(merged['removed_attachment_paths'], ['images/2026/11/a.jpg']);
    });

    test('ApiService.extractConflictData and isNotFoundError parse responses', () {
      final opts = RequestOptions(path: '/api/items/1');
      final err409 = DioException(
        requestOptions: opts,
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: opts,
          statusCode: 409,
          data: {
            'code': 409,
            'message': '冲突',
            'data': {
              'conflict_fields': ['name'],
              'latest_item': {'id': 1, 'name': '云端名'},
            },
          },
        ),
      );
      final conflict = ApiService.extractConflictData(err409);
      expect(conflict?['conflict_fields'], ['name']);

      final err404 = DioException(
        requestOptions: opts,
        type: DioExceptionType.badResponse,
        response: Response(requestOptions: opts, statusCode: 404),
      );
      expect(ApiService.isNotFoundError(err404), isTrue);
    });
  });
}

