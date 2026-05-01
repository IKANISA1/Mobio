import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/features/biopay/biopay_strings.dart';

class ManagementCodeCard extends StatelessWidget {
  const ManagementCodeCard({
    super.key,
    required this.code,
    required this.onCopy,
  });

  final String code;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3C2B08), Color(0xFF6C4D12), Color(0xFF2E2206)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFFFD67A).withValues(alpha: 0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFC857).withValues(alpha: 0.16),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  BiopayStrings.managementCodeTitle,
                  style: AppTypography.titleMd.copyWith(
                    color: const Color(0xFFFFE4A4),
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onCopy,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFFFE4A4),
                ),
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: Text(
                  'COPY',
                  style: AppTypography.labelMd.copyWith(letterSpacing: 0.6),
                ),
              ),
            ],
          ),
          Text(
            BiopayStrings.managementCodeBody,
            style: AppTypography.bodySm.copyWith(
              color: Colors.white.withValues(alpha: 0.86),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            code,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
