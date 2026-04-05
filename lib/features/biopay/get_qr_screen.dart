import 'dart:ui' as ui;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/platform/platform_io.dart';
import 'package:mobi_app/core/providers/service_providers.dart';
import 'package:mobi_app/core/services/country_service.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/features/biopay/models/biopay_handle.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Get QR Code — generates a MoMo payment QR from the user's handle.
///
/// Two-step flow:
/// 1. **Input** — Number/Code toggle, handle value, optional amount
/// 2. **QR display** — rendered QR with handle below + Download QR button
class GetQrScreen extends ConsumerStatefulWidget {
  final VoidCallback onBack;
  final String countryCode;

  const GetQrScreen({
    super.key,
    required this.onBack,
    this.countryCode = '+250',
  });

  @override
  ConsumerState<GetQrScreen> createState() => _GetQrScreenState();
}

class _GetQrScreenState extends ConsumerState<GetQrScreen> {
  final _amountController = TextEditingController();
  final _handleController = TextEditingController();
  CountryService get _countryService => ref.read(countryServiceProvider);

  final _qrKey = GlobalKey();

  bool _showQr = false;
  BiopayHandleType _selectedType = BiopayHandleType.number;
  String _generatedQrData = '';

  @override
  void dispose() {
    _amountController.dispose();
    _handleController.dispose();
    super.dispose();
  }

  String get _handleValue => _handleController.text.trim();

  Future<String> _buildQrData() async {
    final amount = _amountController.text.replaceAll(',', '').trim();

    // Build the USSD payment string from the handle
    final ussd = await _countryService.buildBiopayUssd(
      dialingCode: widget.countryCode,
      handleType: _selectedType,
      handleValue: _handleValue,
      amount: amount.isEmpty ? null : amount,
    );

    if (ussd == null || ussd.isEmpty) {
      // Fallback: just the handle as plain text
      return _handleValue;
    }

    // Encode as tel: URI so any QR scanner can dial the USSD.
    return 'tel:$ussd';
  }

  Future<void> _generateQr() async {
    if (_handleValue.isEmpty) return;
    final qrData = await _buildQrData();
    setState(() {
      _generatedQrData = qrData;
      _showQr = true;
    });
  }

  void _backToInput() {
    setState(() => _showQr = false);
  }

  Future<void> _downloadQr() async {
    try {
      // Request storage/photos permission before saving
      final hasPermission = await _requestGalleryPermission();
      if (!hasPermission) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gallery access is needed to save the QR code.'),
          ),
        );
        return;
      }

      final boundary =
          _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final pngBytes = byteData.buffer.asUint8List();
      final result = await ImageGallerySaverPlus.saveImage(
        Uint8List.fromList(pngBytes),
        quality: 100,
        name: 'mobi_qr_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (!mounted) return;

      final isSuccess = result is Map && result['isSuccess'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isSuccess ? 'QR saved to gallery.' : 'QR saved.'),
        ),
      );
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save QR: $e')));
    }
  }

  Future<bool> _requestGalleryPermission() async {
    // Android 13+ (API 33): use Permission.photos
    // Older Android: use Permission.storage
    // iOS: Permission.photos
    Permission permission;
    if (Platform.isAndroid) {
      final sdkInt = await _getAndroidSdkVersion();
      permission = sdkInt >= 33 ? Permission.photos : Permission.storage;
    } else {
      permission = Permission.photos;
    }

    var status = await permission.status;
    if (status.isGranted) return true;

    status = await permission.request();
    return status.isGranted;
  }

  Future<int> _getAndroidSdkVersion() async {
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      return info.version.sdkInt;
    } on Object catch (_) {
      return 30; // fallback
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _showQr ? _buildQrView() : _buildInputView()),
          ],
        ),
      ),
    );
  }

  // ─── Header with X close + title ───
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Material(
            color: Theme.of(
              context,
            ).extension<MobiThemeExtension>()!.surfaceContainerHigh,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: _showQr ? _backToInput : widget.onBack,
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Icon(
                  _showQr ? LucideIcons.chevronLeft : LucideIcons.x,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Text(
            'Get QR Code',
            style: AppTypography.headlineMd.copyWith(letterSpacing: -0.5),
          ),
        ],
      ),
    );
  }

  // ─── Input form: Number/Code toggle, handle display, amount ───
  Widget _buildInputView() {
    final currency = _countryService.currencyForCodeSync(widget.countryCode);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      child: Column(
        children: [
          // Identity card
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).extension<MobiThemeExtension>()!.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Number / Code toggle
                _buildHandleTypePill(),
                const SizedBox(height: 20),
                // Handle value (editable)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).extension<MobiThemeExtension>()!.surfaceContainer,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: TextField(
                    controller: _handleController,
                    keyboardType: _selectedType == BiopayHandleType.number
                        ? TextInputType.phone
                        : TextInputType.text,
                    style: AppTypography.headlineMd.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      letterSpacing: -0.5,
                    ),
                    decoration: InputDecoration(
                      hintText: _selectedType == BiopayHandleType.number
                          ? '0781234567'
                          : '123456',
                      hintStyle: AppTypography.headlineMd.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.3),
                        letterSpacing: -0.5,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Divider
                Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
                const SizedBox(height: 20),
                // Amount to receive
                Text(
                  'AMOUNT TO RECEIVE',
                  style: AppTypography.labelSm.copyWith(
                    letterSpacing: 2,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).extension<MobiThemeExtension>()!.surfaceContainer,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Text(
                        currency,
                        style: AppTypography.headlineMd.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _amountController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [_ThousandSeparatorFormatter()],
                          style: AppTypography.headlineMd.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          decoration: InputDecoration(
                            hintText: '12,345',
                            hintStyle: AppTypography.headlineMd.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.4),
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          // Generate button
          _buildPrimaryButton(label: 'GENERATE QR', onPressed: _generateQr),
        ],
      ),
    );
  }

  // ─── QR display: rendered QR + branding + Download QR ───
  Widget _buildQrView() {
    final currency = _countryService.currencyForCodeSync(widget.countryCode);
    final brand = _countryService.momoBrandForCodeSync(widget.countryCode);
    final amount = _amountController.text.replaceAll(',', '').trim();
    final handle = _handleValue;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      child: Column(
        children: [
          // QR card
          RepaintBoundary(
            key: _qrKey,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                children: [
                  // Brand header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        LucideIcons.shieldCheck,
                        size: 18,
                        color: Color(0xFF1A1A2E),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        brand,
                        style: AppTypography.titleMd.copyWith(
                          color: const Color(0xFF1A1A2E),
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // QR code
                  QrImageView(
                    data: _generatedQrData,
                    version: QrVersions.auto,
                    size: 280,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Color(0xFF1A1A2E), // QR print-black on white card
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.circle,
                      color: Color(0xFF1A1A2E), // QR print-black on white card
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Handle
                  Text(
                    handle.isEmpty ? '—' : handle,
                    style: AppTypography.titleLg.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      letterSpacing: 1.5,
                    ),
                  ),
                  // Amount (if entered)
                  if (amount.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '$currency $amount',
                      style: AppTypography.bodyLg.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          // Download QR button
          _buildPrimaryButton(label: 'Download QR', onPressed: _downloadQr),
        ],
      ),
    );
  }

  // ─── Number / Code pill toggle ───
  Widget _buildHandleTypePill() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).extension<MobiThemeExtension>()!.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: BiopayHandleType.values.map((type) {
          final isActive = _selectedType == type;
          return GestureDetector(
            onTap: () => setState(() {
              _selectedType = type;
              _handleController.clear();
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: isActive
                    ? Theme.of(context).colorScheme.surface
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                type.label,
                style: AppTypography.labelLg.copyWith(
                  fontWeight: FontWeight.w800,
                  color: isActive
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── Primary action button (green pill) ───
  Widget _buildPrimaryButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return MobiButton(
      onPressed: onPressed,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 40),
      child: Text(label),
    );
  }
}

class _ThousandSeparatorFormatter extends TextInputFormatter {
  final _formatter = NumberFormat('#,###', 'en_US');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) {
      return newValue.copyWith(
        text: '',
        selection: const TextSelection.collapsed(offset: 0),
      );
    }

    final number = int.tryParse(digitsOnly);
    if (number == null) return newValue;

    final formatted = _formatter.format(number);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
