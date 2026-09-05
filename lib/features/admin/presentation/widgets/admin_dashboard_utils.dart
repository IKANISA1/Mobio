import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/features/admin/data/admin_service.dart';
import 'package:mobi_app/shared/widgets/mobi_status_badge.dart';
import 'package:mobi_design_system/theme/mobi_theme_extension.dart';

class AdminDashboardUtils {
  static String formatTimestamp(String? value) {
    if (value == null || value.trim().isEmpty) return 'Now';
    final parsed = DateTime.tryParse(value)?.toLocal();
    if (parsed == null) return value;
    return DateFormat('dd MMM • HH:mm').format(parsed);
  }

  static String statusLabel(String raw) {
    final normalized = raw.trim().replaceAll('_', ' ');
    if (normalized.isEmpty) return raw;
    return normalized
        .split(' ')
        .map(
          (part) => part.isEmpty
              ? part
              : '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  static String localPhone(String? phoneE164, String? countryCode) {
    if (phoneE164 == null || phoneE164.trim().isEmpty) return '';
    if (countryCode != null &&
        countryCode.isNotEmpty &&
        phoneE164.startsWith(countryCode)) {
      return phoneE164.substring(countryCode.length);
    }
    return phoneE164.replaceFirst(RegExp(r'^\+\d{1,4}'), '');
  }

  static bool isPositiveAttempt(String status) {
    final normalized = status.trim().toLowerCase();
    return normalized == 'approved' ||
        normalized == 'allowed' ||
        normalized == 'success';
  }

  static MobiStatusBadgeTone attemptTone(String status) {
    final normalized = status.trim().toLowerCase();
    if (isPositiveAttempt(normalized)) return MobiStatusBadgeTone.positive;
    if (normalized.contains('pending') || normalized.contains('review')) {
      return MobiStatusBadgeTone.warning;
    }
    return MobiStatusBadgeTone.danger;
  }

  static MobiStatusBadgeTone alertTone(AdminNotificationItem alert) {
    final type = alert.type.toLowerCase();
    final title = alert.title.toLowerCase();
    if (type.contains('error') ||
        title.contains('error') ||
        title.contains('failed')) {
      return MobiStatusBadgeTone.danger;
    }
    if (type.contains('access') ||
        title.contains('review') ||
        title.contains('pending')) {
      return MobiStatusBadgeTone.warning;
    }
    if (type.contains('promo') || type.contains('announcement')) {
      return MobiStatusBadgeTone.info;
    }
    return MobiStatusBadgeTone.brand;
  }

  static IconData alertIcon(AdminNotificationItem alert) {
    final type = alert.type.toLowerCase();
    if (type.contains('error')) return LucideIcons.alertTriangle;
    if (type.contains('access')) return LucideIcons.shield;
    if (type.contains('promo')) return LucideIcons.megaphone;
    return LucideIcons.bellRing;
  }

  static Color toneColor(BuildContext context, MobiStatusBadgeTone tone) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;
    return switch (tone) {
      MobiStatusBadgeTone.brand => cs.primary,
      MobiStatusBadgeTone.positive => cs.tertiary,
      MobiStatusBadgeTone.info => ext.info,
      MobiStatusBadgeTone.warning => ext.caution,
      MobiStatusBadgeTone.danger => cs.error,
      MobiStatusBadgeTone.neutral => cs.onSurfaceVariant,
    };
  }

  static Color toneFill(BuildContext context, MobiStatusBadgeTone tone) {
    final accent = toneColor(context, tone);
    return accent.withValues(
      alpha: tone == MobiStatusBadgeTone.neutral ? 0.06 : 0.1,
    );
  }
}
