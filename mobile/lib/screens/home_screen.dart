import 'package:flutter/material.dart';
import '../core/api_service.dart';
import '../core/meta_snapshot_store.dart';
import '../core/offline_db.dart';
import '../core/offline_sync_service.dart';
import '../models/models.dart';
import '../widgets/custom_dialogs.dart';
import '../widgets/home_filter_sheets.dart';
import '../widgets/home_item_grid.dart';
import '../widgets/offline_outbox_banner.dart';
import '../widgets/space_anchor_bar.dart';
import '../widgets/voice_search_overlay.dart';
import 'item_detail_screen.dart';
import 'item_edit_screen.dart';

class HomeScreen extends StatefulWidget {
  final House? initialHouse;
  final Room? initialRoom;
  final bool deferInitialRemoteFetch;
  final bool isKeyboardOpen;

  const HomeScreen({
    super.key,
    this.initialHouse,
    this.initialRoom,
    this.deferInitialRemoteFetch = false,
    this.isKeyboardOpen = false,
  });

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  List<House> _houses = [];
  List<Room> _rooms = [];
  List<Category> _categories = [];
  List<Item> _items = [];
  bool _loading = false;
  bool _hasHydratedCache = false;

  House? _activeHouse;
  Room? _activeRoom;
  Category? _selectedCategory;
  bool _showInactiveSpaces = false;

  bool _isAnchorLocked = false;
  House? _anchorHouse;
  Room? _anchorRoom;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  bool _loadMoreError = false;
  int _requestEpoch = 0;
  bool _showVoiceOverlay = false;

  @override
  void initState() {
    super.initState();
    _activeHouse = widget.initialHouse;
    _activeRoom = widget.initialRoom;
    _scrollController.addListener(_onScroll);
    _initWithCacheFirst();
  }

  Future<void> _initWithCacheFirst() async {
    await _hydrateFromLocalCache();
    if (!mounted || widget.deferInitialRemoteFetch) return;
    await loadInitialData(
      keepSelection: _hasHydratedCache,
      silent: _hasHydratedCache,
    );
  }

  Future<void> _hydrateFromLocalCache() async {
    final uid = ApiService.instance.currentUser?.id;
    if (uid == null) return;
    try {
      final snap = await MetaSnapshotStore.loadSnapshot(uid);
      if (!mounted) return;
      if (snap != null) {
        _houses = snap.houses;
        _rooms = snap.rooms;
        _categories = snap.categories;
        _activeHouse ??=
            _houses.where((h) => h.isActive).firstOrNull ?? _houses.firstOrNull;
      }
      final cachedItems = await OfflineDb.instance.getCachedItems(
        uid,
        houseId: _activeHouse?.id,
        roomId: _activeRoom?.id,
        categoryId: _selectedCategory?.id,
        query: _searchController.text.trim(),
      );
      if (!mounted) return;
      if (snap != null || cachedItems.isNotEmpty) {
        setState(() {
          _items = cachedItems;
          _hasMore = false;
          _hasHydratedCache = true;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 300) {
      _loadMoreItems();
    }
  }

  Future<void> applySpaceFilter(House? house, Room? room) async {
    _activeHouse = house;
    _activeRoom = room;
    await loadInitialData(keepSelection: true);
  }

  Future<void> loadInitialData({
    bool keepSelection = false,
    bool silent = false,
  }) async {
    final epoch = ++_requestEpoch;
    if (!silent || (!_hasHydratedCache && _houses.isEmpty && _items.isEmpty)) {
      setState(() => _loading = true);
    }
    try {
      final results = await Future.wait([
        ApiService.instance.getHouses(),
        ApiService.instance.getRooms(),
        ApiService.instance.getCategories(),
      ]);
      if (!mounted || epoch != _requestEpoch) return;
      _houses = results[0] as List<House>;
      _rooms = results[1] as List<Room>;
      _categories = results[2] as List<Category>;

      final uid = ApiService.instance.currentUser?.id;
      if (uid != null) {
        MetaSnapshotStore.saveSnapshot(
          userId: uid,
          houses: _houses,
          rooms: _rooms,
          categories: _categories,
        );
      }
      OfflineSyncService.instance.refreshDrafts();

      if (!keepSelection && _activeHouse == null && _houses.isNotEmpty) {
        _activeHouse = _houses.where((h) => h.isActive).firstOrNull ?? _houses.first;
      } else if (_activeHouse != null) {
        _activeHouse =
            _houses.where((h) => h.id == _activeHouse!.id).firstOrNull;
        if (_activeHouse == null) _activeRoom = null;
      }
      if (_activeRoom != null) {
        _activeRoom = _rooms.where((r) => r.id == _activeRoom!.id).firstOrNull;
      }
      if (_selectedCategory != null) {
        _selectedCategory = _categories
            .where((c) => c.id == _selectedCategory!.id)
            .firstOrNull;
      }

      await _loadItems(expectedEpoch: epoch);
    } catch (e) {
      if (epoch != _requestEpoch) return;
      OfflineSyncService.instance.refreshDrafts();
      final uid = ApiService.instance.currentUser?.id;
      if (uid != null && ApiService.isNetworkError(e)) {
        if (_hasHydratedCache && (_houses.isNotEmpty || _items.isNotEmpty)) {
          if (mounted && !silent) {
            CustomDialogs.showToast(context, '当前离线，已展示本地空间与物品缓存');
          }
          return;
        }
        final snap = await MetaSnapshotStore.loadSnapshot(uid);
        if (snap != null && mounted && epoch == _requestEpoch) {
          _houses = snap.houses;
          _rooms = snap.rooms;
          _categories = snap.categories;
          _activeHouse ??=
              _houses.where((h) => h.isActive).firstOrNull ?? _houses.firstOrNull;
          if (_activeRoom == null && _activeHouse != null) {
            _activeRoom = _rooms
                .where((r) => r.houseId == _activeHouse!.id && r.isActive)
                .firstOrNull;
          }
          await _loadItems(expectedEpoch: epoch);
          if (mounted) {
            CustomDialogs.showToast(context, '当前离线，已加载本地空间与物品快照');
          }
          return;
        }
      }
      if (mounted) {
        CustomDialogs.showToast(
          context,
          '数据加载失败',
          description: ApiService.formatDioError(e),
          isError: true,
        );
      }
    } finally {
      if (mounted && epoch == _requestEpoch) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadItems({int? expectedEpoch}) async {
    final epoch = expectedEpoch ?? ++_requestEpoch;
    _currentPage = 1;
    _hasMore = true;
    _loadMoreError = false;
    _isLoadingMore = false;
    try {
      final q = _searchController.text.trim();
      if (q.isNotEmpty) {
        final all = await ApiService.instance.searchItems(q);
        if (!mounted || epoch != _requestEpoch) return;
        _items = _selectedCategory == null
            ? all
            : all.where((i) => i.categoryId == _selectedCategory!.id).toList();
        _hasMore = false;
      } else {
        final res = await ApiService.instance.getItemsPaginated(
          houseId: _activeHouse?.id,
          roomId: _activeRoom?.id,
          categoryId: _selectedCategory?.id,
          page: 1,
          pageSize: 30,
        );
        if (!mounted || epoch != _requestEpoch) return;
        _items = res['items'] as List<Item>;
        _hasMore = _items.length < (res['total'] as int);
        final uid = ApiService.instance.currentUser?.id;
        if (uid != null && _items.isNotEmpty) {
          OfflineDb.instance.upsertCachedItems(uid, _items);
        }
      }
      if (mounted && epoch == _requestEpoch) setState(() {});
    } catch (e) {
      if (epoch != _requestEpoch) return;
      final uid = ApiService.instance.currentUser?.id;
      if (uid != null && ApiService.isNetworkError(e)) {
        final cached = await OfflineDb.instance.getCachedItems(
          uid,
          houseId: _activeHouse?.id,
          roomId: _activeRoom?.id,
          categoryId: _selectedCategory?.id,
          query: _searchController.text.trim(),
        );
        if (!mounted || epoch != _requestEpoch) return;
        _items = cached;
        _hasMore = false;
        setState(() {});
      }
    }
  }

  Future<void> _loadMoreItems() async {
    if (_isLoadingMore || !_hasMore) return;
    final epoch = _requestEpoch;
    setState(() {
      _isLoadingMore = true;
      _loadMoreError = false;
    });
    try {
      final nextPage = _currentPage + 1;
      final res = await ApiService.instance.getItemsPaginated(
        houseId: _activeHouse?.id,
        roomId: _activeRoom?.id,
        categoryId: _selectedCategory?.id,
        page: nextPage,
        pageSize: 30,
      );
      if (!mounted || epoch != _requestEpoch) return;
      final newItems = res['items'] as List<Item>;
      if (newItems.isEmpty) {
        _hasMore = false;
      } else {
        _currentPage = nextPage;
        _items.addAll(newItems);
        _hasMore = _items.length < (res['total'] as int);
      }
      setState(() => _isLoadingMore = false);
    } catch (_) {
      if (!mounted || epoch != _requestEpoch) return;
      setState(() {
        _isLoadingMore = false;
        _loadMoreError = true;
      });
    }
  }

  void _toggleAnchor() {
    setState(() {
      if (_isAnchorLocked) {
        _isAnchorLocked = false;
        _anchorHouse = null;
        _anchorRoom = null;
      } else if (_activeHouse != null && _activeRoom != null) {
        _isAnchorLocked = true;
        _anchorHouse = _activeHouse;
        _anchorRoom = _activeRoom;
      }
    });
  }

  Future<void> openAddItemScreen() async {
    final res = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ItemEditScreen(
          defaultHouse: _isAnchorLocked ? _anchorHouse : _activeHouse,
          defaultRoom: _isAnchorLocked ? _anchorRoom : _activeRoom,
          houses: _houses,
          rooms: _rooms,
          categories: _categories,
        ),
      ),
    );
    if (res == true) _loadItems();
  }

  @override
  Widget build(BuildContext context) {
    final houseRooms = _activeHouse == null
        ? <Room>[]
        : _rooms
            .where((r) =>
                r.houseId == _activeHouse!.id &&
                (_showInactiveSpaces || (_activeHouse!.isActive && r.isActive)))
            .toList();

    return Stack(
      children: [
        Column(
          children: [
            SpaceAnchorBar(
              activeHouse: _activeHouse,
              activeRoom: _activeRoom,
              selectedCategory: _selectedCategory,
              isAnchorLocked: _isAnchorLocked,
              onOpenHousePicker: () => HomeFilterSheets.showHousePicker(
                context,
                houses: _houses,
                activeHouse: _activeHouse,
                showInactiveSpaces: _showInactiveSpaces,
                onToggleShowInactive: (val) =>
                    setState(() => _showInactiveSpaces = val),
                onSelected: (house) {
                  setState(() {
                    _activeHouse = house;
                    _activeRoom = null;
                  });
                  _loadItems();
                },
              ),
              onOpenRoomPicker: () => HomeFilterSheets.showRoomPicker(
                context,
                rooms: houseRooms,
                activeRoom: _activeRoom,
                onSelected: (room) {
                  setState(() => _activeRoom = room);
                  _loadItems();
                },
              ),
              onOpenCategoryPicker: () => HomeFilterSheets.showCategoryPicker(
                context,
                categories: _categories,
                selectedCategory: _selectedCategory,
                onSelected: (cat) {
                  setState(() => _selectedCategory = cat);
                  _loadItems();
                },
              ),
              onToggleAnchor: _toggleAnchor,
            ),
            HomeSearchBar(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onSearchChanged: (_) => _loadItems(),
              onClear: () {
                _searchController.clear();
                _loadItems();
              },
              onVoiceTap: () => VoiceSearchOverlay.openWithEngineCheck(
                context,
                onReadyOpen: () => setState(() => _showVoiceOverlay = true),
              ),
            ),
            const OfflineOutboxBanner(),
            if (!_loading && _items.isNotEmpty)
              HomeStatusRow(
                itemCount: _items.length,
                isSearching: _searchController.text.isNotEmpty,
                isAnchorLocked: _isAnchorLocked,
              ),
            Expanded(
              child: HomeItemGrid(
                items: _items,
                loading: _loading,
                isLoadingMore: _isLoadingMore,
                hasMore: _hasMore,
                loadMoreError: _loadMoreError,
                isSearchOrFiltered:
                    _searchController.text.isNotEmpty || _selectedCategory != null,
                scrollController: _scrollController,
                onRefresh: () => loadInitialData(keepSelection: true, silent: true),
                onRetryLoadMore: _loadMoreItems,
                onAdd: openAddItemScreen,
                onItemTap: (item) async {
                  final changed = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => ItemDetailScreen(
                        item: item,
                        houses: _houses,
                        rooms: _rooms,
                        categories: _categories,
                      ),
                    ),
                  );
                  if (changed == true) _loadItems();
                },
              ),
            ),
          ],
        ),
        if (!widget.isKeyboardOpen)
          HomeFloatingAddButton(onTap: openAddItemScreen),
        if (_showVoiceOverlay)
          Positioned.fill(
            child: VoiceSearchOverlay(
              domainVocabulary: [
                ..._items.map((e) => e.name),
                ..._items.map((e) => e.brand),
                ..._categories.map((e) => e.name),
                ..._rooms.map((e) => e.name),
              ],
              onRecognized: (text) {
                setState(() {
                  _showVoiceOverlay = false;
                  if (text.isNotEmpty) {
                    _searchController.text = text;
                    _loadItems();
                  }
                });
              },
              onCancel: () => setState(() => _showVoiceOverlay = false),
              onUnavailable: () {
                setState(() => _showVoiceOverlay = false);
                VoiceSearchOverlay.handleUnavailableFallback(
                  context,
                  _searchFocusNode,
                );
              },
            ),
          ),
      ],
    );
  }
}
