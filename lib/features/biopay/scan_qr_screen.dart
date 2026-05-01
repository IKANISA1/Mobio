import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/providers/service_providers.dart';
import 'package:mobi_app/core/services/country_service.dart';
import 'package:mobi_app/core/services/profile_service.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/features/biopay/models/biopay_handle.dart';
import 'package:mobi_app/features/biopay/services/ussd_launcher_service.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Scan QR Screen — real camera-based QR scanner for BioPay identity resolution.
///
/// Scans a `biopay://<id>` URI, extracts the BioPay ID and optional amount/currency,
/// and displays the resolved profile for payment confirmation.
class ScanQrScreen extends ConsumerStatefulWidget {
  final VoidCallback onBack;

  const ScanQrScreen({super.key, required this.onBack});

  @override
  ConsumerState<ScanQrScreen> createState() => _ScanQrScreenState();
}

enum _ScanPhase { scanning, processing, resolved, invalidQr, error }

class _ScanQrScreenState extends ConsumerState<ScanQrScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  _ScanPhase _phase = _ScanPhase.scanning;
  bool _torchOn = false;

  // Parsed QR data
  String? _myCountryCode;
  String? _biopayId;
  String? _handleType;
  String? _amount;
  String? _currency;
  String? _ussdString;
  String? _momoBrand;
  String? _errorMessage;
  final _ussdLauncher = UssdLauncherService();
  CountryService get _countryService => ref.read(countryServiceProvider);

  late final ProfileService _profileService;

  @override
  void initState() {
    super.initState();
    _profileService = ProfileService();
    _loadMyProfile();
  }

  Future<void> _loadMyProfile() async {
    try {
      final profile = await _profileService.getMyProfile();
      if (mounted) {
        setState(() {
          _myCountryCode = profile?.countryCode;
        });
      }
    } on Object catch (_) {
      // Best effort load, if fails we assume Rwandan +250 or user will re-authenticate.
    }
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_phase != _ScanPhase.scanning) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final rawValue = barcodes.first.rawValue;
    if (rawValue == null || rawValue.isEmpty) return;

    // Parse biopay:// URI
    _parseAndResolve(rawValue);
  }

  Future<void> _parseAndResolve(String rawValue) async {
    setState(() => _phase = _ScanPhase.processing);

    try {
      // ── Handle tel: URIs (new QR format) ──
      // Format: tel:*182*8*1*PHONE%23 or tel:*182*8*1*AMOUNT*PHONE%23
      if (rawValue.toLowerCase().startsWith('tel:')) {
        var ussd = rawValue.substring(4); // strip "tel:"
        ussd = ussd.replaceAll('%23', '#');

        // Parse USSD to extract handle details
        final handle = await _countryService.parseBiopayUssd(ussd);

        if (!mounted) return;

        if (handle == null) {
          setState(() {
            _phase = _ScanPhase.invalidQr;
            _errorMessage = 'Could not parse the USSD from this QR.';
          });
          return;
        }

        final country = handle.countryId != null
            ? await _countryService.findById(handle.countryId!)
            : null;

        // Cross-border validation
        if (_myCountryCode != null &&
            country != null &&
            _myCountryCode != country.dialingCode) {
          if (!mounted) return;
          setState(() {
            _phase = _ScanPhase.invalidQr;
            _errorMessage =
                'Cross-border USSD payments are not supported.\nPlease pay with Cash.';
          });
          return;
        }

        setState(() {
          _biopayId = handle.value;
          _handleType = handle.type.name;
          _amount = handle.amount;
          _currency = country?.currency;
          _ussdString = ussd;
          _momoBrand = country?.momoBrand ?? 'USSD';
          _phase = _ScanPhase.resolved;
        });
        return;
      }

      // ── Handle legacy biopay:// URIs ──
      if (rawValue.startsWith('biopay://')) {
        final uri = Uri.parse(rawValue);
        final handle =
            uri.queryParameters['handle'] ?? uri.queryParameters['biopay_id'];
        if (handle == null || handle.isEmpty) {
          setState(() {
            _phase = _ScanPhase.invalidQr;
            _errorMessage = 'Invalid BioPay QR — no identity found.';
          });
          return;
        }

        final amount = uri.queryParameters['amount'];
        final currency = uri.queryParameters['currency'];
        final handleType = uri.queryParameters['type'] ?? 'number';
        var ussdString = uri.queryParameters['ussd'];

        if ((ussdString == null || ussdString.isEmpty) &&
            handleType == 'number') {
          ussdString = await _countryService.buildBiopayUssd(
            dialingCode: '+250',
            handleType: BiopayHandleType.fromStorage(handleType),
            handleValue: handle,
          );
        }

        String brand = 'USSD';
        if (ussdString != null && ussdString.isNotEmpty) {
          final parsedHandle = await _countryService.parseBiopayUssd(
            ussdString,
          );
          if (parsedHandle != null) {
            final country = parsedHandle.countryId != null
                ? await _countryService.findById(parsedHandle.countryId!)
                : null;
            brand = country?.momoBrand ?? 'USSD';

            // Cross-border validation
            if (_myCountryCode != null &&
                country != null &&
                _myCountryCode != country.dialingCode) {
              if (!mounted) return;
              setState(() {
                _phase = _ScanPhase.invalidQr;
                _errorMessage =
                    'Cross-border USSD payments are not supported.\nPlease pay with Cash.';
              });
              return;
            }
          }
        }

        if (!mounted) return;
        setState(() {
          _biopayId = handle;
          _handleType = handleType;
          _amount = amount;
          _currency = currency;
          _ussdString = ussdString;
          _momoBrand = brand;
          _phase = _ScanPhase.resolved;
        });
        return;
      }

      // ── Unknown format ──
      setState(() {
        _phase = _ScanPhase.invalidQr;
        _errorMessage = 'Not a recognized payment QR code.';
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _ScanPhase.error;
        _errorMessage = 'Failed to parse QR: $e';
      });
    }
  }

  Future<void> _toggleTorch() async {
    await _scannerController.toggleTorch();
    setState(() => _torchOn = !_torchOn);
  }

  void _retryScan() {
    setState(() {
      _phase = _ScanPhase.scanning;
      _biopayId = null;
      _handleType = null;
      _amount = null;
      _currency = null;
      _ussdString = null;
      _momoBrand = null;
      _errorMessage = null;
    });
    _scannerController.start();
  }

  Future<void> _launchUssd() async {
    var ussdString = _ussdString;
    if (ussdString == null || ussdString.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This QR does not include a payment handoff.'),
        ),
      );
      return;
    }

    if (_amount == null || _amount!.isEmpty) {
      final amountStr = await _promptAmountDialog();
      if (amountStr == null || amountStr.isEmpty) return; // User cancelled

      // Rebuild USSD with amount
      final handle = await _countryService.parseBiopayUssd(ussdString);
      if (handle != null) {
        final rebuilt = await _countryService.buildBiopayUssd(
          dialingCode: handle.countryCode,
          handleType: handle.type,
          handleValue: handle.value,
          amount: amountStr,
        );
        if (rebuilt != null && rebuilt.isNotEmpty) {
          ussdString = rebuilt;
        }
      }
    }

    final launched = await _ussdLauncher.launchUssdPayment(ussdString);
    if (!mounted) return;
    if (!launched) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to launch the payment string.')),
      );
    }
  }

  Future<String?> _promptAmountDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Theme.of(ctx).colorScheme.surface,
          title: Text('Enter Amount', style: AppTypography.titleLg),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Amount',
              hintText: 'e.g. 500',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isResultPhase =
        _phase == _ScanPhase.resolved ||
        _phase == _ScanPhase.invalidQr ||
        _phase == _ScanPhase.error;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 1) Top header — always above the camera
            _buildTopHeader(),

            // 2) Camera + overlays fill the remaining space
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Camera / scanner
                  Positioned.fill(
                    child: MobileScanner(
                      controller: _scannerController,
                      onDetect: _onDetect,
                    ),
                  ),

                  // Viewfinder overlay when scanning
                  if (_phase == _ScanPhase.scanning) _buildViewfinderOverlay(),

                  // Processing indicator
                  if (_phase == _ScanPhase.processing)
                    _buildProcessingOverlay(),

                  // Result screens as bottom sheets
                  if (isResultPhase)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
                        child: Material(
                          color: Theme.of(context).colorScheme.surface,
                          child: SafeArea(
                            top: false,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                24,
                                28,
                                24,
                                24,
                              ),
                              child: _phase == _ScanPhase.resolved
                                  ? _buildResolvedContent()
                                  : _buildErrorContent(),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Material(
            color: Colors.white.withValues(alpha: 0.15),
            shape: const CircleBorder(),
            child: InkWell(
              onTap: widget.onBack,
              customBorder: const CircleBorder(),
              splashColor: Colors.white.withValues(alpha: 0.2),
              child: const SizedBox(
                width: 44,
                height: 44,
                child: Icon(LucideIcons.x, size: 20, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Text(
            'SCANNING QR',
            style: AppTypography.titleLg.copyWith(
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewfinderOverlay() {
    return Stack(
      children: [
        // Semi-transparent overlay with maximised viewfinder
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _ViewfinderPainter(
                viewfinderFraction: 0.88,
                overlayColor: Colors.black.withValues(alpha: 0.5),
                borderColor: Theme.of(context).colorScheme.primary,
                borderWidth: 3,
                cornerLength: 32,
                borderRadius: 20,
              ),
            ),
          ),
        ),

        // Torch toggle
        Positioned(
          bottom: 48,
          left: 0,
          right: 0,
          child: Center(
            child: GestureDetector(
              onTap: _toggleTorch,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _torchOn
                      ? Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _torchOn
                        ? Theme.of(context).colorScheme.primary
                        : Colors.white.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Icon(
                  _torchOn ? LucideIcons.zapOff : LucideIcons.zap,
                  size: 24,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProcessingOverlay() {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.7),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Processing...',
                style: AppTypography.bodyMd.copyWith(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResolvedContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Icon(
            LucideIcons.checkCircle,
            color: Theme.of(context).colorScheme.primary,
            size: 40,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'BioPay QR Scanned',
          style: AppTypography.headlineMd.copyWith(letterSpacing: -1),
        ),
        const SizedBox(height: 20),
        _infoRow('Handle', _biopayId ?? '—'),
        _infoRow('Type', (_handleType ?? 'number').toUpperCase()),
        _infoRow(
          'Payment handoff',
          _ussdString?.isNotEmpty == true ? 'Available' : 'Unavailable',
        ),
        if (_amount != null && _amount!.isNotEmpty)
          _infoRow('Amount', '${_currency ?? ''} $_amount'.trim()),
        if (_ussdString?.isNotEmpty == true) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payment String',
                  style: AppTypography.labelSm.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _ussdString!,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        MobiButton(
          width: double.infinity,
          onPressed: _launchUssd,
          child: Text(
            'PAY VIA ${(_momoBrand ?? 'USSD').toUpperCase()}',
            style: AppTypography.labelLg.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ),
        const SizedBox(height: 12),
        MobiButton(
          width: double.infinity,
          variant: MobiButtonVariant.ghost,
          onPressed: _retryScan,
          child: Text(
            'SCAN ANOTHER',
            style: AppTypography.labelLg.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.secondary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Icon(
            LucideIcons.alertTriangle,
            color: Theme.of(context).colorScheme.secondary,
            size: 40,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          _phase == _ScanPhase.invalidQr ? 'Not a BioPay QR' : 'Scan Error',
          style: AppTypography.headlineMd.copyWith(letterSpacing: -1),
        ),
        const SizedBox(height: 12),
        Text(
          _errorMessage ?? 'An unexpected error occurred.',
          style: AppTypography.bodyMd.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.6,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        MobiButton(
          width: double.infinity,
          onPressed: _retryScan,
          child: Text(
            'TRY AGAIN',
            style: AppTypography.labelLg.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: AppTypography.labelSm.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value, style: AppTypography.bodyMd)),
        ],
      ),
    );
  }
}

/// Custom painter for the viewfinder cutout with corner brackets.
class _ViewfinderPainter extends CustomPainter {
  final double viewfinderFraction;
  final Color overlayColor;
  final Color borderColor;
  final double borderWidth;
  final double cornerLength;
  final double borderRadius;

  _ViewfinderPainter({
    required this.viewfinderFraction,
    required this.overlayColor,
    required this.borderColor,
    required this.borderWidth,
    required this.cornerLength,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final viewfinderSize = size.width * viewfinderFraction;
    final left = (size.width - viewfinderSize) / 2;
    final top = (size.height - viewfinderSize) / 2;
    final rect = Rect.fromLTWH(left, top, viewfinderSize, viewfinderSize);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    // Draw semi-transparent overlay with hole
    final overlayPaint = Paint()..color = overlayColor;
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(rrect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, overlayPaint);

    // Draw corner brackets
    final cornerPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeCap = StrokeCap.round;

    // Top-left
    canvas
      ..drawLine(
        Offset(left, top + cornerLength),
        Offset(left, top + borderRadius),
        cornerPaint,
      )
      ..drawArc(
        Rect.fromLTWH(left, top, borderRadius * 2, borderRadius * 2),
        3.14159,
        1.5708,
        false,
        cornerPaint,
      )
      ..drawLine(
        Offset(left + borderRadius, top),
        Offset(left + cornerLength, top),
        cornerPaint,
      );

    // Top-right
    final right = left + viewfinderSize;
    canvas
      ..drawLine(
        Offset(right - cornerLength, top),
        Offset(right - borderRadius, top),
        cornerPaint,
      )
      ..drawArc(
        Rect.fromLTWH(
          right - borderRadius * 2,
          top,
          borderRadius * 2,
          borderRadius * 2,
        ),
        -1.5708,
        1.5708,
        false,
        cornerPaint,
      )
      ..drawLine(
        Offset(right, top + borderRadius),
        Offset(right, top + cornerLength),
        cornerPaint,
      );

    // Bottom-left
    final bottom = top + viewfinderSize;
    canvas
      ..drawLine(
        Offset(left, bottom - cornerLength),
        Offset(left, bottom - borderRadius),
        cornerPaint,
      )
      ..drawArc(
        Rect.fromLTWH(
          left,
          bottom - borderRadius * 2,
          borderRadius * 2,
          borderRadius * 2,
        ),
        1.5708,
        1.5708,
        false,
        cornerPaint,
      )
      ..drawLine(
        Offset(left + borderRadius, bottom),
        Offset(left + cornerLength, bottom),
        cornerPaint,
      )
      // Bottom-right
      ..drawLine(
        Offset(right - cornerLength, bottom),
        Offset(right - borderRadius, bottom),
        cornerPaint,
      )
      ..drawArc(
        Rect.fromLTWH(
          right - borderRadius * 2,
          bottom - borderRadius * 2,
          borderRadius * 2,
          borderRadius * 2,
        ),
        0,
        1.5708,
        false,
        cornerPaint,
      )
      ..drawLine(
        Offset(right, bottom - borderRadius),
        Offset(right, bottom - cornerLength),
        cornerPaint,
      );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
