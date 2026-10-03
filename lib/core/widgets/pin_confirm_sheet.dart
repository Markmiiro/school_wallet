// Asks for the PIN before a money control changes (limit, card block).
// Returns the 4 digits typed, or null if dismissed. The server checks
// the PIN; a wrong one comes back as an error message from the call.

import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import '../constants/app_colors.dart';
import '../theme/app_theme.dart';

Future<String?> askForPin(BuildContext context, {required String action}) {
  final pinTheme = PinTheme(
    width: 52,
    height: 52,
    textStyle: AppTheme.labelMono.copyWith(fontSize: 20),
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
      border: Border.all(color: AppColors.outline),
    ),
  );

  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.fromLTRB(
        AppTheme.marginMobile,
        AppTheme.spaceLg,
        AppTheme.marginMobile,
        MediaQuery.of(sheetContext).viewInsets.bottom + AppTheme.spaceXl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Enter your PIN', style: AppTheme.headlineMd),
          const SizedBox(height: AppTheme.spaceXs),
          Text('to $action',
              style: AppTheme.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
          const SizedBox(height: AppTheme.spaceLg),
          Pinput(
            length: 4,
            autofocus: true,
            obscureText: true,
            obscuringCharacter: '●',
            defaultPinTheme: pinTheme,
            focusedPinTheme: pinTheme.copyDecorationWith(
              border: Border.all(color: AppColors.primary, width: 2),
            ),
            onCompleted: (pin) => Navigator.of(sheetContext).pop(pin),
          ),
        ],
      ),
    ),
  );
}
