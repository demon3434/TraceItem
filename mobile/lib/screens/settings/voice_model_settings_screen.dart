import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../core/asr_engine_service.dart';
import '../../core/asr_model_manager.dart';
import '../../core/constants.dart';
import '../../core/theme_controller.dart';
import '../../widgets/custom_dialogs.dart';

class VoiceModelSettingsScreen extends StatefulWidget {
  const VoiceModelSettingsScreen({super.key});

  @override
  State<VoiceModelSettingsScreen> createState() =>
      _VoiceModelSettingsScreenState();
}

class _VoiceModelSettingsScreenState extends State<VoiceModelSettingsScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    await AsrModelManager.instance.fetchModels();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _downloadModel(AsrModelInfo model) async {
    try {
      await AsrModelManager.instance.downloadAndInstallModel(model);
      AsrEngineService.instance.disposeRecognizer();
      if (mounted) {
        CustomDialogs.showToast(context, '${model.name} 下载并启用成功');
      }
    } catch (e) {
      if (mounted) {
        CustomDialogs.showToast(
          context,
          '模型下载失败',
          description: '$e',
          isError: true,
        );
      }
    }
  }

  Future<void> _selectEngine(String id, String name) async {
    HapticFeedback.selectionClick();
    await AsrModelManager.instance.selectEngine(id);
    AsrEngineService.instance.disposeRecognizer();
    if (mounted) {
      CustomDialogs.showToast(context, '已切换语音引擎为：$name');
    }
  }

  Future<void> _deleteModel(AsrModelInfo model) async {
    final ok = await CustomDialogs.showConfirm(
      context: context,
      title: '清理本地模型缓存',
      message: '确定删除 ${model.name}（约 ${AppConstants.formatFileSize(model.localSizeBytes)}）？删除后可随时从家庭服务器重新下载。',
      confirmText: '确认删除',
      isDanger: true,
    );
    if (!ok) return;
    await AsrModelManager.instance.deleteModel(model.id);
    AsrEngineService.instance.disposeRecognizer();
    if (mounted) {
      CustomDialogs.showToast(context, '已清理 ${model.name} 本地缓存');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeController.instance.current;

    return ListenableBuilder(
      listenable: AsrModelManager.instance,
      builder: (context, _) {
        final mgr = AsrModelManager.instance;
        final models = mgr.models;

        return RefreshIndicator(
          color: theme.primary,
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(14),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.lightBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: theme.lightBorder),
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.sparkles, color: theme.primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '模型从家庭服务器局域网下载，全部运算在手机本地完成（断网可用、零服务器压力）。',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.darkText,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (_loading && models.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                ...models.map((m) => _buildModelCard(m, mgr, theme)),
              _buildSystemSttCard(mgr, theme),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModelCard(
    AsrModelInfo m,
    AsrModelManager mgr,
    DopamineThemeConfig theme,
  ) {
    final isSelected = mgr.selectedEngineId == m.id;
    final isThisDownloading = mgr.downloadingModelId == m.id;
    final sizeText = m.localSizeBytes > 0
        ? AppConstants.formatFileSize(m.localSizeBytes)
        : (m.sizeBytes > 0
            ? AppConstants.formatFileSize(m.sizeBytes)
            : '约 ${m.approxSizeMb} MB');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? theme.primary : const Color(0xFFE2E8F0),
          width: isSelected ? 1.8 : 1,
        ),
        boxShadow: theme.ambientShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  m.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.lightBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  m.badge,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.darkText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            m.description,
            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 8),
          Text(
            '体积：$sizeText · ${m.isDownloaded ? '已缓存到本地' : (m.availableOnServer ? '可从家庭服务器下载' : '服务端暂未放置模型归档')}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
          if (isThisDownloading) ...[
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: mgr.downloadProgress,
              color: theme.primary,
              backgroundColor: theme.lightBg,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 4),
            Text(
              '${mgr.downloadStage} ${(mgr.downloadProgress * 100).toInt()}%',
              style: TextStyle(fontSize: 12, color: theme.primary),
            ),
          ] else ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (m.isDownloaded) ...[
                  Expanded(
                    child: ShadButton(
                      enabled: !isSelected,
                      onPressed: () => _selectEngine(m.id, m.name),
                      leading: Icon(
                        isSelected ? LucideIcons.check : LucideIcons.play,
                        size: 15,
                      ),
                      child: Text(
                        isSelected ? '当前正在使用' : '切换启用',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ShadButton.outline(
                    onPressed: () => _deleteModel(m),
                    leading: const Icon(
                      LucideIcons.trash2,
                      size: 15,
                      color: Color(0xFFE11D48),
                    ),
                    child: const Text(
                      '清理',
                      style: TextStyle(fontSize: 13, color: Color(0xFFE11D48)),
                    ),
                  ),
                ] else
                  Expanded(
                    child: ShadButton(
                      enabled: m.availableOnServer && !mgr.isDownloading,
                      onPressed: () => _downloadModel(m),
                      leading: const Icon(LucideIcons.download, size: 15),
                      child: Text(
                        m.availableOnServer ? '下载并启用' : '服务端未就绪',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSystemSttCard(AsrModelManager mgr, DopamineThemeConfig theme) {
    final isSelected = mgr.selectedEngineId == AsrModelManager.systemEngineId;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? theme.primary : const Color(0xFFE2E8F0),
          width: isSelected ? 1.8 : 1,
        ),
        boxShadow: theme.ambientShadows,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  '系统原生语音引擎',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '零存储占用，依赖手机系统内置识别服务（部分国产 ROM 可能不可用）',
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ShadButton(
            enabled: !isSelected,
            onPressed: () =>
                _selectEngine(AsrModelManager.systemEngineId, '系统原生语音引擎'),
            child: Text(
              isSelected ? '当前使用' : '切换',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

