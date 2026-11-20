import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../core/asr_model_manager.dart';
import '../core/constants.dart';
import '../core/theme_controller.dart';
import 'custom_dialogs.dart';

Future<bool> showVoiceModelDownloadSheet(BuildContext context) async {
  final mgr = AsrModelManager.instance;
  await mgr.fetchModels();
  if (!context.mounted) return false;

  final installed = await CustomDialogs.showModalSheet<bool>(
    context: context,
    builder: (ctx) => ShadSheet(
      title: const Text(
        '首次使用 · 选择离线语音模型',
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
      ),
      description: const Text(
        '模型将从家庭服务器局域网下载至手机本地，后续可随时在「设置 → 语音识别模型」中自由切换。',
        style: TextStyle(fontSize: 13),
      ),
      child: _VoiceModelDownloadBody(),
    ),
  );
  return installed == true;
}

class _VoiceModelDownloadBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = ThemeController.instance.current;
    return ListenableBuilder(
      listenable: AsrModelManager.instance,
      builder: (context, _) {
        final mgr = AsrModelManager.instance;
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...mgr.models.map((m) {
                final downloading = mgr.downloadingModelId == m.id;
                final sizeLabel = m.sizeBytes > 0
                    ? AppConstants.formatFileSize(m.sizeBytes)
                    : '约 ${m.approxSizeMb} MB';
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: m.recommended ? theme.lightBg : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: m.recommended
                          ? theme.lightBorder
                          : const Color(0xFFE2E8F0),
                    ),
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
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${m.badge} · $sizeLabel',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: theme.darkText,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        m.description,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (downloading) ...[
                        LinearProgressIndicator(
                          value: mgr.downloadProgress,
                          color: theme.primary,
                          backgroundColor: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${mgr.downloadStage} ${(mgr.downloadProgress * 100).toInt()}%',
                          style: TextStyle(fontSize: 12, color: theme.primary),
                        ),
                      ] else
                        SizedBox(
                          width: double.infinity,
                          child: ShadButton(
                            enabled: m.availableOnServer && !mgr.isDownloading,
                            onPressed: () async {
                              try {
                                await mgr.downloadAndInstallModel(m);
                                if (context.mounted) {
                                  Navigator.of(context).pop(true);
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  CustomDialogs.showToast(
                                    context,
                                    '下载失败',
                                    description: '$e',
                                    isError: true,
                                  );
                                }
                              }
                            },
                            leading: const Icon(LucideIcons.download, size: 15),
                            child: Text(
                              m.availableOnServer ? '下载并启用' : '服务端未放置模型文件',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }),
              ShadButton.outline(
                enabled: !mgr.isDownloading,
                onPressed: () async {
                  await mgr.selectEngine(AsrModelManager.systemEngineId);
                  if (context.mounted) Navigator.of(context).pop(true);
                },
                child: const Text(
                  '暂不下载，使用系统原生语音',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

