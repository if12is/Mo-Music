import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:estrella_music/app_identity.dart';
import 'package:estrella_music/generated/l10n.dart';
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
    final colors = theme.colorScheme;
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
                            color: colors.onSurface.withValues(alpha: 0.68),
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
    final colors = Theme.of(context).colorScheme;
    final icon = switch (state) {
      DownloadState.done => Icons.check_rounded,
      DownloadState.error => Icons.refresh_rounded,
      DownloadState.installing => Icons.install_mobile_rounded,
      DownloadState.downloading => Icons.downloading_rounded,
      DownloadState.idle => Icons.system_update_alt_rounded,
    };
    final glow = switch (state) {
      DownloadState.done => const Color(0xFF3DDC97),
      DownloadState.error => colors.error,
      DownloadState.installing => AppIdentity.brandBlueSoft,
      DownloadState.downloading => AppIdentity.brandBlueSoft,
      DownloadState.idle => AppIdentity.brandBlue,
    };

    return Center(
      child: Container(
        width: 92,
        height: 92,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppIdentity.brandBlueSoft,
              AppIdentity.brandBlue,
              AppIdentity.brandBlueDeep,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: glow.withValues(alpha: 0.35),
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
    final colors = Theme.of(context).colorScheme;
    final label = from.isEmpty || to.isEmpty
        ? to
        : S.of(context).updateFromTo(from, to);
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: colors.primaryContainer.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colors.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
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
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(context).updateWhatsNew,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            notes,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                  color: colors.onSurface.withValues(alpha: 0.78),
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
    final colors = Theme.of(context).colorScheme;
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
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.error,
                        height: 1.4,
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
                    backgroundColor: _color(state, colors),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        AppIdentity.brandBlue.withValues(alpha: 0.45),
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

  Color _color(DownloadState state, ColorScheme colors) {
    switch (state) {
      case DownloadState.error:
        return colors.error;
      case DownloadState.done:
        return const Color(0xFF2BB673);
      default:
        return AppIdentity.brandBlue;
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
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            Text(
              '$pct%',
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
            backgroundColor:
                Theme.of(context).colorScheme.surfaceContainerHighest,
            color: AppIdentity.brandBlueSoft,
          ),
        ),
        if (controller.progressLabel.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            controller.progressLabel,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppIdentity.brandBlueSoft),
          const SizedBox(height: 16),
          Text(S.of(context).checkingUpdates),
        ],
      ),
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
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded,
                size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text(
              S.of(context).loadInfoUpdate,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: AppIdentity.brandBlue,
                minimumSize: const Size(160, 48),
              ),
              child: Text(S.of(context).retry),
            ),
            if (onLater != null)
              TextButton(
                onPressed: onLater,
                child: Text(S.of(context).updateLater),
              ),
          ],
        ),
      ),
    );
  }
}
