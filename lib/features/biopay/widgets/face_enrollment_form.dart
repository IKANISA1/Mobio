import 'package:flutter/material.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/features/biopay/models/biopay_handle.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';
import 'package:mobi_app/shared/widgets/mobi_toggle.dart';

class FaceEnrollmentForm extends StatelessWidget {
  const FaceEnrollmentForm({
    super.key,
    required this.momoValueController,
    required this.handleType,
    required this.onHandleTypeChanged,
    required this.onContinue,
  });

  final TextEditingController momoValueController;
  final BiopayHandleType handleType;
  final ValueChanged<BiopayHandleType> onHandleTypeChanged;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Registration details',
          style: AppTypography.titleMd,
        ),
        const SizedBox(height: 8),
        Text(
          'Enter the MoMo number or agent code you want to use for face identification.',
          style: AppTypography.bodySm.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: MobiToggle(
            labels: const ['Number', 'Code'],
            selectedIndex: handleType == BiopayHandleType.number ? 0 : 1,
            onChanged: (i) => onHandleTypeChanged(
              i == 0 ? BiopayHandleType.number : BiopayHandleType.code,
            ),
          ),
        ),
        const SizedBox(height: 24),
        _buildTextField(
          context: context,
          controller: momoValueController,
          label: handleType == BiopayHandleType.number
              ? 'Phone number'
              : 'Agent code',
          hintText: handleType == BiopayHandleType.number
              ? '0788123456'
              : '123456',
          keyboardType: handleType == BiopayHandleType.number
              ? TextInputType.phone
              : TextInputType.text,
        ),
        const SizedBox(height: 48),
        MobiButton(
          width: double.infinity,
          onPressed: onContinue,
          child: Text(
            'CONTINUE',
            style: AppTypography.labelMd.copyWith(
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required BuildContext context,
    required TextEditingController controller,
    required String label,
    required String hintText,
    required TextInputType keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.labelSm),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: AppTypography.bodyLg,
          decoration: InputDecoration(
            hintText: hintText,
            filled: true,
            fillColor: Theme.of(
              context,
            ).extension<MobiThemeExtension>()!.surfaceContainerLow,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }
}
