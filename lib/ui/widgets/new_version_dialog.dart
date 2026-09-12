import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:estrella_music/app_identity.dart';
import 'package:estrella_music/generated/l10n.dart';
import 'package:estrella_music/ui/screens/Home/home_screen_controller.dart';
import 'package:estrella_music/ui/screens/Update/update_screen.dart';
import 'common_dialog_widget.dart';

class NewVersionDialog extends StatelessWidget {
  const NewVersionDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CommonDialog(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppIdentity.brandBlue,
              ),
              child: const Icon(Icons.system_update_alt_rounded,
                  color: Colors.white, size: 30),
            ),
            const SizedBox(height: 16),
            Text(
              S.current.newVersionAvailable,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              S.current.updateInAppSubtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  UpdateScreen.open();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppIdentity.brandBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(S.current.updateDownloadNow),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(S.current.updateLater),
            ),
            GetX<HomeScreenController>(builder: (controller) {
              return CheckboxListTile(
                value: controller.showVersionDialog.isFalse,
                onChanged: (val) {
                  controller.onChangeVersionVisibility(val ?? false);
                },
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  S.current.dontShowInfoAgain,
                  style: theme.textTheme.bodySmall,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
