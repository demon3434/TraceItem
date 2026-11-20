import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../core/constants.dart';
import '../../core/media_cache_manager.dart';
import '../../core/theme_controller.dart';
import '../../widgets/custom_dialogs.dart';

class MediaStorageScreen extends StatefulWidget {
  const MediaStorageScreen({super.key});

  @override
  State<MediaStorageScreen> createState() => _MediaStorageScreenState();
}

class _MediaStorageScreenState extends State<MediaStorageScreen> {
  int _cacheSizeBytes = 0;
  int _deviceTotalBytes = 0;
  int _quotaMb = AppConstants.mediaCacheDefaultMaxMb;
  String _selectedVideoProfile = AppConstants.defaultVideoProfile;
  bool _loading = true;

  static const String _kVideoProfilePrefKey = 'traceitem_pref_video_profile';

  @override
  void initState() {
    super.initState();
    _loadStorageData();
  }

  Future<void> _loadStorageData() async {
    setState(() => _loading = true);
    final size = await MediaCacheManager.instance.getCurrentCacheSizeBytes();
    final totalSize =
        await MediaCacheManager.instance.getTotalDeviceCacheSizeBytes();
    final quota = await MediaCacheManager.instance.getCacheQuotaMb();
    final prefs = await SharedPreferences.getInstance();
    final profile = prefs.getString(_kVideoProfilePrefKey) ??
        AppConstants.defaultVideoProfile;

    if (mounted) {
      setState(() {
        _cacheSizeBytes = size;
        _deviceTotalBytes = totalSize;
        _quotaMb = quota;
        _selectedVideoProfile = profile;
        _loading = false;
      });
    }
  }

  Future<void> _setQuota(int mb) async {
    HapticFeedback.selectionClick();
    await MediaCacheManager.instance.setCacheQuotaMb(mb);
    setState(() => _quotaMb = mb);
    if (mounted) {
      CustomDialogs.showToast(context, '缓存上限已更新为 $mb MB');
    }
  }

  Future<void> _setVideoProfile(String key) async {
    HapticFeedback.selectionClick();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kVideoProfilePrefKey, key);
    setState(() => _selectedVideoProfile = key);
    if (mounted) {
      final label = AppConstants.videoProfiles[key]?.label ?? key;
      CustomDialogs.showToast(context, '视频画质偏好已设为 $label ($key)');
    }
  }

  Future<void> _clearCache() async {
    final confirmed = await CustomDialogs.showConfirm(
      context: context,
      title: '清空当前账号媒体缓存？',
      message: '清空后当前登录账号的本地持久化音视频缓存将被移除（不影响其他成员账号），再次查看需通过网络重新拉取。',
      confirmText: '立即清空',
      isDanger: true,
    );
    if (!confirmed) return;

    HapticFeedback.mediumImpact();
    await MediaCacheManager.instance.clearAllCache();
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    await _loadStorageData();
    if (mounted) {
      CustomDialogs.showToast(context, '当前账号多媒体缓存已清空');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final theme = ThemeController.instance.current;
        if (_loading) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: CircularProgressIndicator(
                color: theme.primary,
                strokeWidth: 2.5,
              ),
            ),
          );
        }

        final usedMb = _cacheSizeBytes / (1024 * 1024);
        final deviceMb = _deviceTotalBytes / (1024 * 1024);
        final ratio =
            (_quotaMb > 0 ? (deviceMb / _quotaMb) : 0.0).clamp(0.0, 1.0);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. 缓存使用量统计卡片
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: theme.ambientShadows,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '当前账号媒体缓存',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      '${usedMb.toStringAsFixed(1)} MB (本机共 ${deviceMb.toStringAsFixed(1)} / $_quotaMb MB)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: theme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 8,
                    backgroundColor: const Color(0xFFF1F5F9),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      ratio > 0.85 ? const Color(0xFFE11D48) : theme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  '类 Telegram 机制：看过的音视频与本机刚录制的文件自动保存在本地，达到上限自动 LRU 清理冷数据，绝不无节制占用手机存储。',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 2. 缓存上限配额设置
          const Padding(
            padding: EdgeInsets.only(left: 6, bottom: 8),
            child: Text(
              '缓存上限配额 (自动淘汰阈值)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: theme.ambientShadows,
            ),
            child: Column(
              children: [
                _buildQuotaTile(100, '100 MB', '极致省空间 (适合小容量设备)', theme),
                _buildQuotaTile(200, '200 MB (推荐默认)', '均衡流畅 (约可存 50 个高频视频)', theme),
                _buildQuotaTile(500, '500 MB', '从容充裕 (大量寻物路线离线秒开)', theme),
                _buildQuotaTile(1024, '1 GB', '极速大容量 (近乎全库离线秒开)', theme, isLast: true),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 3. 视频拍摄画质偏好
          const Padding(
            padding: EdgeInsets.only(left: 6, bottom: 8),
            child: Text(
              '视频拍摄与录制画质偏好 (SSOT 规范)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: theme.ambientShadows,
            ),
            child: Column(
              children: AppConstants.videoProfiles.entries.map((entry) {
                final k = entry.key;
                final p = entry.value;
                final isLast = k == AppConstants.videoProfiles.keys.last;
                return _buildProfileTile(k, '${p.label} (${p.width}x${p.height})', p.description, theme, isLast: isLast);
              }).toList(),
            ),
          ),
          const SizedBox(height: 22),

          // 4. 一键清空缓存
          GestureDetector(
            onTap: _clearCache,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFFECDD3)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.trash2, size: 16, color: Color(0xFFE11D48)),
                  SizedBox(width: 8),
                  Text(
                    '立即清空全部多媒体缓存',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE11D48),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
      },
    );
  }

  Widget _buildQuotaTile(int mb, String title, String subtitle, dynamic theme, {bool isLast = false}) {
    final selected = _quotaMb == mb;
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          title: Text(title, style: TextStyle(fontSize: 14, fontWeight: selected ? FontWeight.bold : FontWeight.w500)),
          subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          trailing: selected
              ? Icon(Icons.check_circle_rounded, color: theme.primary, size: 20)
              : const Icon(Icons.radio_button_unchecked_rounded, color: Color(0xFFCBD5E1), size: 20),
          onTap: () => _setQuota(mb),
        ),
        if (!isLast) const Divider(height: 1, color: Color(0xFFF1F5F9)),
      ],
    );
  }

  Widget _buildProfileTile(String key, String title, String subtitle, dynamic theme, {bool isLast = false}) {
    final selected = _selectedVideoProfile == key;
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          title: Text(title, style: TextStyle(fontSize: 14, fontWeight: selected ? FontWeight.bold : FontWeight.w500)),
          subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          trailing: selected
              ? Icon(Icons.check_circle_rounded, color: theme.primary, size: 20)
              : const Icon(Icons.radio_button_unchecked_rounded, color: Color(0xFFCBD5E1), size: 20),
          onTap: () => _setVideoProfile(key),
        ),
        if (!isLast) const Divider(height: 1, color: Color(0xFFF1F5F9)),
      ],
    );
  }
}

