import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../core/api_service.dart';
import '../core/app_logger.dart';
import '../core/constants.dart';
import '../core/media_cache_manager.dart';
import '../core/media_draft_uploader.dart';
import '../core/media_pipeline.dart';
import '../core/session_temp_media_tracker.dart';
import '../core/theme_controller.dart';
import '../models/models.dart';
import 'audio_record_sheet.dart';
import 'custom_dialogs.dart';
import 'item_edit_audio_block.dart';
import 'item_edit_image_block.dart';
import 'item_edit_video_block.dart';
import 'shad_sheet_option_tile.dart';

class ItemEditMediaSection extends StatefulWidget {
  final List<Map<String, dynamic>> attachments;
  final VoidCallback onChanged;
  final SessionTempMediaTracker? tempTracker;

  const ItemEditMediaSection({
    super.key,
    required this.attachments,
    required this.onChanged,
    this.tempTracker,
  });

  @override
  State<ItemEditMediaSection> createState() => _ItemEditMediaSectionState();
}

class _ItemEditMediaSectionState extends State<ItemEditMediaSection> {
  final ImagePicker _picker = ImagePicker();
  bool _uploadingImage = false;
  bool _uploadingVideo = false;
  String? _videoStatusText;
  String? _videoButtonLabel;
  double? _videoProgress;
  bool _uploadingAudio = false;
  String? _audioStatusText;
  String? _audioButtonLabel;
  double? _audioProgress;

  List<Map<String, dynamic>> get _images =>
      widget.attachments.where((a) => a['media_type'] == 'image').toList();

  List<Map<String, dynamic>> get _videos =>
      widget.attachments.where((a) => a['media_type'] == 'video').toList();

  List<Map<String, dynamic>> get _audios =>
      widget.attachments.where((a) => a['media_type'] == 'audio').toList();

  Future<void> _cacheBytes(String key, String filename, Uint8List bytes) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$filename');
      await tempFile.writeAsBytes(bytes);
      await MediaCacheManager.instance.putFile(key, tempFile);
    } catch (_) {}
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_images.length >= AppConstants.maxImageAttachments) {
      CustomDialogs.showToast(
        context,
        '已达照片数量上限',
        description: '最多可上传 ${AppConstants.maxImageAttachments} 张实景照片',
      );
      return;
    }
    try {
      final XFile? file = await _picker.pickImage(source: source);
      if (file == null) return;
      setState(() => _uploadingImage = true);

      final result = await MediaPipeline.processXFile(file);
      final rawName = file.name.isNotEmpty
          ? file.name
          : 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filename = rawName.toLowerCase().endsWith('.jpg') ||
              rawName.toLowerCase().endsWith('.jpeg')
          ? rawName
          : '$rawName.jpg';
      AppLogger.instance.media('Image', '开始处理压缩图片: $filename (${result.sizeBytes}B)');
      final uploadRes = await MediaDraftUploader.uploadOrDraftImage(
        bytes: result.mainBytes,
        filename: filename,
        width: result.width,
        height: result.height,
      );
      final att = uploadRes.att;
      widget.attachments.add(att);
      if (!uploadRes.isOffline) {
        widget.tempTracker?.track(att);
        await _cacheBytes(att['file_path'], filename, result.mainBytes);
      } else if (mounted) {
        CustomDialogs.showToast(context, '离线模式：照片已暂存本地草稿');
      }
      widget.onChanged();
    } catch (e, st) {
      AppLogger.instance.e('Image', '图片处理或上传异常: $e\n$st');
      if (mounted) {
        CustomDialogs.showToast(
          context,
          '图片上传失败',
          description: ApiService.formatDioError(e),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  Future<void> _pickVideo(ImageSource source) async {
    if (_videos.length >= AppConstants.maxVideoAttachments) {
      CustomDialogs.showToast(
        context,
        '已达视频数量上限',
        description: '最多可上传 ${AppConstants.maxVideoAttachments} 个寻路短视频',
      );
      return;
    }
    try {
      final XFile? file = await _picker.pickVideo(
        source: source,
        maxDuration: const Duration(
          seconds: AppConstants.videoMaxDurationSeconds,
        ),
      );
      if (file == null) return;
      setState(() {
        _uploadingVideo = true;
        _videoStatusText = '正在压缩转码 · 请勿退出';
        _videoButtonLabel = '压缩进度 0%';
        _videoProgress = 0.0;
      });

      final compressed = await MediaPipeline.compressVideoFile(
        file.path,
        onProgress: (p) {
          if (!mounted) return;
          setState(() {
            _videoProgress = p;
            _videoStatusText = '正在压缩转码 · 请勿退出';
            _videoButtonLabel = '压缩进度 ${(p * 100).round()}%';
          });
        },
      );
      final filename = 'video_${DateTime.now().millisecondsSinceEpoch}.mp4';
      if (mounted) {
        setState(() {
          _videoProgress = 0.0;
          _videoStatusText = '正在上传服务器 · 请勿退出';
          _videoButtonLabel = '上传进度 0%';
        });
      }
      AppLogger.instance.media(
        'Video',
        '开始上传压缩视频: $filename (${compressed.sizeBytes}B, ${compressed.durationSeconds}s)',
      );
      final uploadRes = await MediaDraftUploader.uploadOrDraftVideo(
        filePath: compressed.filePath,
        filename: filename,
        durationSeconds: compressed.durationSeconds,
        posterPath: compressed.posterPath,
        onSendProgress: (sent, total) {
          if (!mounted || total <= 0) return;
          final p = (sent / total).clamp(0.0, 1.0);
          setState(() {
            _videoProgress = p;
            _videoStatusText = '正在上传服务器 · 请勿退出';
            _videoButtonLabel = '上传进度 ${(p * 100).round()}%';
          });
        },
      );
      final att = uploadRes.att;
      widget.attachments.add(att);
      if (!uploadRes.isOffline) {
        widget.tempTracker?.track(att);
      }

      widget.onChanged();
      if (mounted) {
        CustomDialogs.showToast(
          context,
          uploadRes.isOffline ? '离线模式：短视频已暂存本地草稿' : '寻路短视频已压缩上传并缓存',
        );
      }
    } catch (e, st) {
      AppLogger.instance.e('Video', '视频压缩或上传异常: $e\n$st');
      if (mounted) {
        CustomDialogs.showToast(
          context,
          '短视频上传失败',
          description: ApiService.formatDioError(e),
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _uploadingVideo = false;
          _videoStatusText = null;
          _videoButtonLabel = null;
          _videoProgress = null;
        });
      }
    }
  }

  Future<void> _recordAudioMemo() async {
    if (_audios.length >= AppConstants.maxAudioAttachments) {
      CustomDialogs.showToast(
        context,
        '已达语音数量上限',
        description: '最多可附加 ${AppConstants.maxAudioAttachments} 条语音指引备忘',
      );
      return;
    }
    final result = await AudioRecordSheet.show(context);
    if (result == null) return;

    try {
      setState(() {
        _uploadingAudio = true;
        _audioStatusText = '正在上传语音 · 请勿退出';
        _audioButtonLabel = '上传进度 0%';
        _audioProgress = 0.0;
      });
      final filename = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final uploadRes = await MediaDraftUploader.uploadOrDraftAudio(
        bytes: result.bytes,
        filename: filename,
        durationSeconds: result.durationSeconds,
        onSendProgress: (sent, total) {
          if (!mounted || total <= 0) return;
          final p = (sent / total).clamp(0.0, 1.0);
          setState(() {
            _audioProgress = p;
            _audioStatusText = '正在上传语音 · 请勿退出';
            _audioButtonLabel = '上传进度 ${(p * 100).round()}%';
          });
        },
      );
      final att = uploadRes.att;
      widget.attachments.add(att);
      if (!uploadRes.isOffline) {
        widget.tempTracker?.track(att);
        await _cacheBytes(att['file_path'], filename, result.bytes);
      }
      widget.onChanged();
      if (mounted) {
        CustomDialogs.showToast(
          context,
          uploadRes.isOffline ? '离线模式：语音备忘已暂存本地草稿' : '语音备忘已附加并缓存',
        );
      }
    } catch (e) {
      if (mounted) {
        CustomDialogs.showToast(
          context,
          '音频上传失败',
          description: ApiService.formatDioError(e),
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _uploadingAudio = false;
          _audioStatusText = null;
          _audioButtonLabel = null;
          _audioProgress = null;
        });
      }
    }
  }

  void _showMediaPickerSheet({required bool isVideo}) {
    final theme = ThemeController.instance.current;
    CustomDialogs.showModalSheet<void>(
      context: context,
      builder: (ctx) => ShadSheet(
        radius: const BorderRadius.vertical(top: Radius.circular(24)),
        title: Text(
          isVideo ? '选择寻路短视频来源' : '添加现场实景照片',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        description: Text(
          isVideo
              ? '建议拍摄 ${AppConstants.videoMaxDurationSeconds} 秒以内开门/开抽屉路线短视频 (最多 ${AppConstants.maxVideoAttachments} 个)'
              : '支持上传最多 ${AppConstants.maxImageAttachments} 张照片，端侧自动压缩长边 1600px',
          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ShadSheetOptionTile(
                leading: Icon(
                  isVideo ? LucideIcons.video : LucideIcons.camera,
                  size: 20,
                  color: theme.primary,
                ),
                title: isVideo
                    ? '立即拍摄短视频 (≤${AppConstants.videoMaxDurationSeconds}s)'
                    : '拍照现场实景',
                onTap: () {
                  Navigator.of(ctx).pop();
                  isVideo
                      ? _pickVideo(ImageSource.camera)
                      : _pickImage(ImageSource.camera);
                },
              ),
              ShadSheetOptionTile(
                leading: Icon(
                  isVideo ? LucideIcons.film : LucideIcons.image,
                  size: 20,
                  color: const Color(0xFF0EA5E9),
                ),
                title: isVideo ? '从手机相册选择视频' : '从手机相册选取照片',
                margin: EdgeInsets.zero,
                onTap: () {
                  Navigator.of(ctx).pop();
                  isVideo
                      ? _pickVideo(ImageSource.gallery)
                      : _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _removeAttachment(Map<String, dynamic> target) {
    widget.attachments.remove(target);
    widget.tempTracker?.cleanupIfTracked(target['file_path'] as String?);
    widget.onChanged();
  }

  void _reorderByType(String mediaType, int oldIndex, int newIndex, {bool isSwap = false}) {
    final group =
        widget.attachments.where((a) => a['media_type'] == mediaType).toList();
    if (oldIndex < 0 || oldIndex >= group.length) return;

    if (isSwap) {
      if (newIndex < 0 || newIndex >= group.length || oldIndex == newIndex) return;
      final moved = group.removeAt(oldIndex);
      group.insert(newIndex, moved);
    } else {
      var target = newIndex;
      if (oldIndex < target) target -= 1;
      if (target < 0 || target >= group.length || oldIndex == target) return;
      final moved = group.removeAt(oldIndex);
      group.insert(target, moved);
    }

    int cursor = 0;
    for (int i = 0; i < widget.attachments.length; i++) {
      if (widget.attachments[i]['media_type'] == mediaType) {
        widget.attachments[i] = group[cursor++];
      }
    }
    widget.onChanged();
  }

  Future<Attachment?> _rotateImage(
    int imageIndex,
    Attachment current,
    int quarterTurns,
  ) async {
    try {
      final res = await MediaDraftUploader.rotateOrDraftImage(
        filePath: current.filePath,
        url: current.url,
        quarterTurns: quarterTurns,
      );
      if (res == null) return null;
      final att = res.att;

      int seen = 0;
      for (int i = 0; i < widget.attachments.length; i++) {
        if (widget.attachments[i]['media_type'] == 'image') {
          if (seen == imageIndex) {
            final prevPath = widget.attachments[i]['file_path'] as String?;
            widget.attachments[i] = att;
            widget.tempTracker?.cleanupIfTracked(prevPath);
            if (!res.isOffline) widget.tempTracker?.track(att);
            break;
          }
          seen++;
        }
      }

      widget.onChanged();
      if (mounted) CustomDialogs.showToast(context, '图片角度已旋转并更新');
      final fp = (att['local_path'] as String?)?.isNotEmpty == true
          ? att['local_path'] as String
          : (att['file_path'] as String? ?? '');
      return Attachment(
        id: 0,
        itemId: 0,
        mediaType: 'image',
        filePath: fp,
        url: fp,
        thumbnailUrl: att['thumbnail_path'] as String?,
        fileSize: att['file_size'] as int? ?? 0,
        durationSeconds: 0,
        width: att['width'] as int? ?? 0,
        height: att['height'] as int? ?? 0,
      );
    } catch (e) {
      if (mounted) {
        CustomDialogs.showToast(
          context,
          '图片旋转保存失败',
          description: ApiService.formatDioError(e),
          isError: true,
        );
      }
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ItemEditImageBlock(
            images: _images,
            uploading: _uploadingImage,
            onAddTap: () => _showMediaPickerSheet(isVideo: false),
            onRemove: _removeAttachment,
            onReorder: (o, n) => _reorderByType('image', o, n, isSwap: true),
            onRotateImage: _rotateImage,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1, color: Color(0xFFE2E8F0)),
          ),
          ItemEditVideoBlock(
            videos: _videos,
            uploading: _uploadingVideo,
            statusText: _videoStatusText,
            buttonLabel: _videoButtonLabel,
            progress: _videoProgress,
            onAddTap: () => _showMediaPickerSheet(isVideo: true),
            onRemove: _removeAttachment,
            onReorder: (o, n) => _reorderByType('video', o, n, isSwap: true),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1, color: Color(0xFFE2E8F0)),
          ),
          ItemEditAudioBlock(
            audios: _audios,
            uploading: _uploadingAudio,
            statusText: _audioStatusText,
            buttonLabel: _audioButtonLabel,
            progress: _audioProgress,
            onAddTap: _recordAudioMemo,
            onRemove: _removeAttachment,
            onReorder: (o, n) => _reorderByType('audio', o, n, isSwap: true),
          ),
        ],
      ),
    );
  }
}
