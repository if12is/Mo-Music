import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' show Bidi;
import 'package:estrella_music/app_identity.dart';
import 'package:estrella_music/generated/l10n.dart';
import 'package:estrella_music/ui/theme/app_colors.dart';
import 'update_controller.dart';

class UpdateScreen extends StatelessWidget {
  const UpdateScreen({super.key, this.onLater});

  final VoidCallback? onLater;

  static void open({VoidCallback? onLater}) {
    if (Get.isRegistered<UpdateController>()) {
      Get.delete<UpdateController>(force: true);
    }
    Get.to(() => UpdateScreen(onLater: onLater));
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<UpdateController>()
        ? Get.find<UpdateController>()
        : Get.put(UpdateController());
    final theme = Theme.of(context);
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Obx(() {
        if (controller.isLoading.isTrue) {
          return const _UpdateLoading();
        }
        if (controller.error.isNotEmpty) {
          return _UpdateError(
            message: controller.error.value,
            onRetry: controller.fetchUpdateInfo,
            onLater: onLater ?? (canPop ? Get.back : null),
          );
        }

        return SafeArea(
          child: Column(
            children: [
              _TopBar(
                onLater: onLater ?? (canPop ? Get.back : null),
              ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                      children: [
                        const SizedBox(height: 12),
                        _HeroMark(state: controller.downloadState.value),
                        const SizedBox(height: 28),
                        Text(
                          S.of(context).updateNewVersionTitle,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          S.of(context).updateInAppSubtitle,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.brightness == Brightness.dark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _VersionChip(
                          from: controller.currentVersion.value,
                          to: controller.latestVersion,
                        ),
                        if (controller.notes.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          _NotesCard(notes: controller.notes),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              _BottomBar(controller: controller),
            ],
          ),
        );
      }),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({this.onLater});

  final VoidCallback? onLater;

  @override
  Widget build(BuildContext context) {
    if (onLater == null) return const SizedBox(height: 8);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton(
        onPressed: onLater,
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          foregroundColor: AppIdentity.brandBlueSoft,
        ),
        child: Text(S.of(context).updateLater),
      ),
    );
  }
}

class _HeroMark extends StatelessWidget {
  const _HeroMark({required this.state});

  final DownloadState state;

  @override
  Widget build(BuildContext context) {
    final icon = switch (state) {
      DownloadState.done => Icons.check_rounded,
      DownloadState.error => Icons.refresh_rounded,
      DownloadState.installing => Icons.install_mobile_rounded,
      DownloadState.downloading => Icons.downloading_rounded,
      DownloadState.idle => Icons.system_update_alt_rounded,
    };

    return Center(
      child: Container(
        width: 92,
        height: 92,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppColors.primaryGradient,
          boxShadow: [
            BoxShadow(
              color: AppIdentity.brandBlue.withValues(alpha: 0.4),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Icon(icon, size: 40, color: Colors.white),
      ),
    );
  }
}

class _VersionChip extends StatelessWidget {
  const _VersionChip({required this.from, required this.to});

  final String from;
  final String to;

  @override
  Widget build(BuildContext context) {
    if (from.isEmpty && to.isEmpty) return const SizedBox.shrink();
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 10,
        children: [
          if (from.isNotEmpty) _pill(from),
          if (from.isNotEmpty && to.isNotEmpty)
            Icon(
              Icons.arrow_forward_rounded,
              size: 18,
              color: AppIdentity.brandBlueSoft,
              textDirection: Directionality.of(context),
            ),
          if (to.isNotEmpty) _pill(to, filled: true),
        ],
      ),
    );
  }

  Widget _pill(String version, {bool filled = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: filled
            ? AppIdentity.brandBlue
            : AppIdentity.brandBlue.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppIdentity.brandBlueSoft.withValues(alpha: 0.7),
        ),
      ),
      child: Text(
        version,
        textDirection: TextDirection.ltr,
        style: TextStyle(
          color: filled ? Colors.white : AppIdentity.brandBlueSoft,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _NotesCard extends StatelessWidget {
  const _NotesCard({required this.notes});

  final String notes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: AppIdentity.brandBlue.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppIdentity.brandBlueSoft.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(context).updateWhatsNew,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppIdentity.brandBlueSoft,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            notes,
            textDirection: Bidi.detectRtlDirectionality(notes)
                ? TextDirection.rtl
                : TextDirection.ltr,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.5,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.82),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.controller});

  final UpdateController controller;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
        child: Obx(() {
          final state = controller.downloadState.value;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (state == DownloadState.downloading) ...[
                _ProgressBlock(controller: controller),
                const SizedBox(height: 16),
              ],
              if (state == DownloadState.error &&
                  controller.downloadError.isNotEmpty) ...[
                Text(
                  controller.downloadError.value,
                  textAlign: TextAlign.center,
                  textDirection: Bidi.detectRtlDirectionality(
                          controller.downloadError.value)
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppIdentity.brandBlueSoft,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: _onPressed(state),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppIdentity.brandBlue,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        AppIdentity.brandBlue.withValues(alpha: 0.45),
                    disabledForegroundColor: Colors.white70,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  child: _label(context, state),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  VoidCallback? _onPressed(DownloadState state) {
    switch (state) {
      case DownloadState.idle:
        return controller.startUpdate;
      case DownloadState.done:
        return controller.installUpdate;
      case DownloadState.error:
        return () {
          controller.retryDownload();
          controller.startUpdate();
        };
      case DownloadState.downloading:
      case DownloadState.installing:
        return null;
    }
  }

  Widget _label(BuildContext context, DownloadState state) {
    if (state == DownloadState.downloading ||
        state == DownloadState.installing) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            state == DownloadState.installing
                ? S.of(context).updateInstalling
                : S.of(context).updateDownloading,
          ),
        ],
      );
    }

    final text = switch (state) {
      DownloadState.done => controller.canInstallInApp
          ? S.of(context).updateInstallNow
          : S.of(context).updateOpenFile,
      DownloadState.error => S.of(context).retry,
      _ => S.of(context).updateDownloadNow,
    };
    return Text(text);
  }
}

class _ProgressBlock extends StatelessWidget {
  const _ProgressBlock({required this.controller});

  final UpdateController controller;

  @override
  Widget build(BuildContext context) {
    final progress = controller.downloadProgress.value;
    final pct = (progress * 100).clamp(0, 100).toStringAsFixed(0);
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                S.of(context).updateDownloading,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppIdentity.brandBlueSoft,
                    ),
              ),
            ),
            Text(
              '$pct%',
              textDirection: TextDirection.ltr,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppIdentity.brandBlueSoft,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: progress > 0 ? progress : null,
            minHeight: 8,
            backgroundColor: AppIdentity.brandBlue.withValues(alpha: 0.18),
            color: AppIdentity.brandBlueSoft,
          ),
        ),
        if (controller.progressLabel.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            controller.progressLabel,
            textDirection: TextDirection.ltr,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondaryDark,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
          ),
        ],
      ],
    );
  }
}

class _UpdateLoading extends StatelessWidget {
  const _UpdateLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppIdentity.brandBlueSoft),
          SizedBox(height: 16),
          _CheckingLabel(),
        ],
      ),
    );
  }
}

class _CheckingLabel extends StatelessWidget {
  const _CheckingLabel();

  @override
  Widget build(BuildContext context) {
    return Text(
      S.of(context).checkingUpdates,
      style: const TextStyle(color: AppIdentity.brandBlueSoft),
    );
  }
}

class _UpdateError extends StatelessWidget {
  const _UpdateError({
    required this.message,
    required this.onRetry,
    this.onLater,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback? onLater;

  @override
  Widget build(BuildContext context) {
    final friendly = _friendlyCheckError(message);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.primaryGradient,
              ),
              child: const Icon(Icons.refresh_rounded,
                  size: 34, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Text(
              S.of(context).loadInfoUpdate,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              friendly,
              textAlign: TextAlign.center,
              textDirection: Bidi.detectRtlDirectionality(friendly)
                  ? TextDirection.rtl
                  : TextDirection.ltr,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppIdentity.brandBlueSoft,
                    height: 1.45,
                  ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: AppIdentity.brandBlue,
                foregroundColor: Colors.white,
                minimumSize: const Size(160, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Text(S.of(context).retry),
            ),
            if (onLater != null)
              TextButton(
                onPressed: onLater,
                style: TextButton.styleFrom(
                  foregroundColor: AppIdentity.brandBlueSoft,
                ),
                child: Text(S.of(context).updateLater),
              ),
          ],
        ),
      ),
    );
  }

  String _friendlyCheckError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('404') ||
        lower.contains('dioexception') ||
        lower.contains('not found')) {
      return S.current.updateFileNotReady;
    }
    if (lower.contains('socket') ||
        lower.contains('network') ||
        lower.contains('connection')) {
      return S.current.updateDownloadFailed;
    }
    return message;
  }
}
