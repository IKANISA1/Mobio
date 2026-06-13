import 'package:flutter/material.dart';
import 'package:mobi_app/core/services/admin_service.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/core/utils/phone_number_normalizer.dart';
import 'package:mobi_app/features/admin/widgets/admin_dashboard_utils.dart';
import 'package:mobi_app/features/admin/widgets/admin_ui.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';
import 'package:mobi_app/shared/widgets/whatsapp_input.dart';

class AdminWhatsappSheet extends StatefulWidget {
  const AdminWhatsappSheet({super.key, this.existing, required this.onSave});

  final AdminWhatsappNumberItem? existing;
  final Future<void> Function({
    required String phoneE164,
    required String countryCode,
    String? displayName,
    required bool isActive,
  })
  onSave;

  @override
  State<AdminWhatsappSheet> createState() => _AdminWhatsappSheetState();
}

class _AdminWhatsappSheetState extends State<AdminWhatsappSheet> {
  late final TextEditingController _displayNameController;
  late String _localNumber;
  late String _countryCode;
  late bool _isActive;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController(
      text: widget.existing?.displayName ?? '',
    );
    _localNumber = AdminDashboardUtils.localPhone(
      widget.existing?.phoneE164,
      widget.existing?.countryCode,
    );
    _countryCode = widget.existing?.countryCode ?? '+250';
    _isActive = widget.existing?.isActive ?? true;
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AdminSectionHeader(
              title: widget.existing == null
                  ? 'Add allowlist'
                  : 'Edit allowlist',
              subtitle: 'Approved numbers',
            ),
            const SizedBox(height: AppSpacing.lg),
            WhatsAppInput(
              value: _localNumber,
              onChanged: (value) => setState(() => _localNumber = value),
              countryCode: _countryCode,
              onCountryCodeChanged: (value) =>
                  setState(() => _countryCode = value),
              label: 'WhatsApp',
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _displayNameController,
              style: AppTypography.bodyMd.copyWith(color: cs.onSurface),
              decoration: InputDecoration(
                labelText: 'Label',
                filled: true,
                fillColor: ext.surfaceContainerLow,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(
                    color: cs.outlineVariant.withValues(alpha: 0.55),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(
                    color: cs.primary.withValues(alpha: 0.45),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AdminPanel(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Status',
                          style: AppTypography.titleMd.copyWith(
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          _isActive ? 'Active' : 'Paused',
                          style: AppTypography.bodySm.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: _isActive,
                    onChanged: (value) => setState(() => _isActive = value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: MobiButton(
                    variant: MobiButtonVariant.ghost,
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: MobiButton(
                    isLoading: _isSaving,
                    onPressed: _isSaving ? null : _handleSave,
                    child: Text(widget.existing == null ? 'Save' : 'Update'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSave() async {
    final e164 = PhoneNumberNormalizer.normalizeForCountry(
      phone: _localNumber,
      countryCode: _countryCode,
    );
    if (!PhoneNumberNormalizer.isValidCanonical(e164)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid WhatsApp number.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await widget.onSave(
        phoneE164: e164,
        countryCode: _countryCode,
        displayName: _displayNameController.text.trim().isEmpty
            ? null
            : _displayNameController.text.trim(),
        isActive: _isActive,
      );
      if (mounted) Navigator.of(context).pop();
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
