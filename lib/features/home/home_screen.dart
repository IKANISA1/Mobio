import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/theme/app_colors.dart';
import 'package:mobi_app/core/theme/app_shadows.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/core/constants/app_constants.dart';
import 'package:mobi_app/core/services/driver_location_service.dart';
import 'package:mobi_app/models/trip.dart';
import 'package:mobi_app/models/vehicle_type.dart';
import 'package:mobi_app/shared/widgets/driver_card.dart';
import 'package:mobi_app/shared/widgets/mobi_toggle.dart';
import 'package:mobi_app/shared/widgets/vehicle_filter_chips.dart';
import 'package:mobi_app/shared/widgets/loading_skeleton.dart';
import 'package:mobi_app/shared/widgets/ai_empty_state.dart';
import 'package:mobi_app/shared/widgets/mobi_surface_panel.dart';
import 'package:mobi_app/shared/widgets/soft_gradient.dart';
import 'package:mobi_app/core/services/ai_content_service.dart';

/// Home (Discover) screen matching transito design.
class HomeScreen extends StatefulWidget {
  final String mode;
  final ValueChanged<String> onModeChanged;
  final ValueChanged<Trip> onChat;
  final VoidCallback onViewNearby;
  final VoidCallback? onViewBookings;
  final VoidCallback? onSchedule;

  const HomeScreen({
    super.key,
    required this.mode,
    required this.onModeChanged,
    required this.onChat,
    required this.onViewNearby,
    this.onViewBookings,
    this.onSchedule,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  VehicleType _vehicle = VehicleType.cab;
  bool _isLoading = true;
  bool _isDriverOnline = false;
  int _nearbyCount = 0;
  final _driverLocationService = DriverLocationService();

  @override
  void initState() {
    super.initState();
    _loadLocationAndCount();
  }

  Future<void> _loadLocationAndCount() async {
    setState(() => _isLoading = true);
    if (mounted) {
      setState(() {
        _nearbyCount = 0;
        _isLoading = false;
      });
    }
  }

  void _switchVehicle(VehicleType v) {
    setState(() => _vehicle = v);
    _loadLocationAndCount();
  }

  void _toggleDriverOnline(bool value) {
    setState(() => _isDriverOnline = value);
    _driverLocationService.setDriverOnlineStatus(value);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;
    final mediaPadding = MediaQuery.paddingOf(context);
    final isDriver = widget.mode == 'driver';
    final List<Trip> nearbyPreview = [];
    final List<Trip> scheduledPreview = [];

    return SoftGradient(
      category: PromoCategory.nearbyDrivers,
      visibilityMode: SoftGradientVisibilityMode.reading,
      allowMotion: true,
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.only(bottom: 136 + mediaPadding.bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: MobiSurfacePanel(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                  borderRadius: 36,
                  child: Column(
                    children: [
                      _buildHeader(isDriver, cs, ext),
                      const SizedBox(height: 18),
                      MobiToggle(
                        labels: isDriver
                            ? const ['Passenger', 'Driver Mode']
                            : const ['Passenger', 'Driver'],
                        selectedIndex: isDriver ? 1 : 0,
                        onChanged: (i) => widget.onModeChanged(
                          i == 0 ? 'passenger' : 'driver',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _TappableContainer(
                  onTap: widget.onViewNearby,
                  child: _buildHeroCard(isDriver),
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildActionTile(
                        context: context,
                        icon: LucideIcons.mapPin,
                        label: 'Nearby',
                        subtitle: 'Find nearby drivers',
                        color: Theme.of(context).colorScheme.primary,
                        onTap: widget.onViewNearby,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionTile(
                        context: context,
                        icon: LucideIcons.calendarCheck,
                        label: 'Schedule',
                        subtitle: 'Manage your trips',
                        color: Theme.of(context).colorScheme.secondary,
                        onTap: () => widget.onViewBookings?.call(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: MobiSurfacePanel(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  borderRadius: 32,
                  child: VehicleFilterChips(
                    selected: _vehicle,
                    onSelected: _switchVehicle,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _buildSectionHeader(
                  context: context,
                  title: isDriver ? 'Nearby Passengers' : 'Nearby Drivers',
                  onViewAll: widget.onViewNearby,
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _isLoading
                    ? Column(
                        children: List.generate(
                          2,
                          (_) => const Padding(
                            padding: EdgeInsets.only(bottom: 16),
                            child: LoadingSkeleton(height: 100),
                          ),
                        ),
                      )
                    : nearbyPreview.isNotEmpty
                    ? Column(
                        children: nearbyPreview
                            .map(
                              (trip) => Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: DriverCard(
                                  trip: trip,
                                  onChat: () => widget.onChat(trip),
                                ),
                              ),
                            )
                            .toList(),
                      )
                    : AiEmptyState(
                        title:
                            'No nearby ${isDriver ? "passengers" : "drivers"} found.',
                        icon: LucideIcons.mapPin,
                        height: 200,
                      ),
              ),
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _buildSectionHeader(
                  context: context,
                  title: 'Scheduled',
                  onViewAll: () => widget.onViewBookings?.call(),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: scheduledPreview.isNotEmpty
                    ? Column(
                        children: scheduledPreview
                            .map(
                              (trip) => Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: _buildScheduledCard(context, trip),
                              ),
                            )
                            .toList(),
                      )
                    : AiEmptyState(
                        title: 'No scheduled trips.',
                        subtitle: 'Tap Nearby to find drivers.',
                        icon: LucideIcons.calendar,
                        height: 200,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDriver, ColorScheme cs, MobiThemeExtension ext) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              SizedBox.square(
                dimension: 24,
                child: ClipRect(
                  child: Transform.scale(
                    scale: 1.38,
                    child: Image.asset(
                      'icon/mobi_splash.png',
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  'Mobio',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.headlineMd.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (isDriver) const SizedBox(width: 12),
        if (isDriver)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ONLINE',
                style: AppTypography.labelSm.copyWith(
                  color: _isDriverOnline
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 28,
                child: Switch(
                  value: _isDriverOnline,
                  onChanged: _toggleDriverOnline,
                  activeThumbColor: Theme.of(context).colorScheme.primary,
                  activeTrackColor: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.3),
                  inactiveThumbColor: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant,
                  inactiveTrackColor: ext.surfaceContainer,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildHeroCard(bool isDriver) {
    final heroText = isDriver
        ? '$_nearbyCount\nPassengers\nNear You'
        : '$_nearbyCount\nDrivers\nNear You';

    return LayoutBuilder(
      builder: (context, constraints) {
        final titleSize = constraints.maxWidth < 300
            ? 40.0
            : constraints.maxWidth < 340
            ? 44.0
            : 52.0;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.primary,
                AppColors.primaryDim,
              ],
            ),
            borderRadius: BorderRadius.circular(40),
            boxShadow: AppShadows.premium,
          ),
          child: Text(
            heroText,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.displayLg.copyWith(
              fontSize: titleSize,
              height: 1.05,
              color: Theme.of(
                context,
              ).colorScheme.onPrimary.withValues(alpha: 0.85),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionTile({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return _TappableContainer(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: ext.surfaceContainerLowest.withValues(
            alpha: ext.surfacePanelAlpha,
          ),
          borderRadius: BorderRadius.circular(40),
          border: Border.all(
            color: cs.outlineVariant.withValues(
              alpha: ext.surfacePanelBorderAlpha,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(icon, size: 24, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: AppTypography.titleMd.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.labelSm.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required BuildContext context,
    required String title,
    VoidCallback? onViewAll,
  }) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return MobiSurfacePanel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      borderRadius: 28,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.headlineLg.copyWith(color: cs.onSurface),
            ),
          ),
          if (onViewAll != null) const SizedBox(width: 12),
          if (onViewAll != null)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onViewAll,
                borderRadius: BorderRadius.circular(999),
                splashColor: cs.primary.withValues(alpha: 0.12),
                child: Ink(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: ext.surfaceContainer,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Text(
                    'View All',
                    style: AppTypography.labelLg.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                      color: cs.primary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScheduledCard(BuildContext context, Trip trip) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: ext.surfaceContainerLowest.withValues(
          alpha: ext.surfacePanelAlpha,
        ),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(
          color: cs.outlineVariant.withValues(
            alpha: ext.surfacePanelBorderAlpha,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (trip.authorId.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                AppConstants.getDriverId(trip.authorId),
                style: AppTypography.labelMd.copyWith(
                  letterSpacing: 2,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          Text(
            '${trip.origin.toUpperCase()} → ${trip.destination.toUpperCase()}',
            style: AppTypography.titleMd.copyWith(
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            trip.departureTime,
            style: AppTypography.displayMd.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildChip(
                context: context,
                icon: _vehicleIcon(trip.effectiveVehicleType),
                label: trip.effectiveVehicleType.label.toUpperCase(),
              ),
              const SizedBox(width: 8),
              _buildChip(
                context: context,
                label: 'EXPIRES IN 45M',
                isHighlight: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _vehicleIcon(VehicleType type) {
    switch (type) {
      case VehicleType.moto:
        return LucideIcons.zap;
      case VehicleType.cab:
        return LucideIcons.car;
      case VehicleType.trike:
        return LucideIcons.truck;
      case VehicleType.truck:
        return LucideIcons.truck;
      case VehicleType.private_:
        return LucideIcons.car;
    }
  }

  Widget _buildChip({
    required BuildContext context,
    IconData? icon,
    required String label,
    bool isHighlight = false,
  }) {
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isHighlight
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
            : ext.surfaceContainerLowest.withValues(
                alpha: ext.surfacePanelAlpha - 0.08,
              ),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: isHighlight
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
              : Theme.of(context).colorScheme.outlineVariant.withValues(
                  alpha: ext.cardBorderAlpha,
                ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppTypography.labelSm.copyWith(
              letterSpacing: 0.5,
              color: isHighlight
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _TappableContainer extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;

  const _TappableContainer({required this.onTap, required this.child});

  @override
  State<_TappableContainer> createState() => _TappableContainerState();
}

class _TappableContainerState extends State<_TappableContainer> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: _isPressed ? 0.96 : 1.0,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 120),
          opacity: _isPressed ? 0.8 : 1.0,
          child: widget.child,
        ),
      ),
    );
  }
}
