import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/errors/app_exception.dart';
import 'package:mobi_app/features/admin/application/admin_services.dart';
import 'package:mobi_app/features/admin/data/admin_service.dart';
import 'package:mobi_app/features/admin/presentation/widgets/admin_ui.dart';
import 'package:mobi_app/shared/widgets/mobi_bottom_sheet.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';
import 'package:mobi_app/shared/widgets/mobi_confirm_dialog.dart';
import 'package:mobi_app/shared/widgets/mobi_status_badge.dart';
import 'package:mobi_design_system/theme/app_spacing.dart';
import 'package:mobi_design_system/theme/app_typography.dart';
import 'package:mobi_design_system/theme/mobi_theme_extension.dart';

enum BroadcastType { promo, announcement }

/// Admin screen for audited operational messages and approved promo campaigns.
class AdminBroadcastsScreen extends ConsumerStatefulWidget {
  final VoidCallback onBack;

  const AdminBroadcastsScreen({super.key, required this.onBack});

  @override
  ConsumerState<AdminBroadcastsScreen> createState() =>
      _AdminBroadcastsScreenState();
}

class _AdminBroadcastsScreenState extends ConsumerState<AdminBroadcastsScreen> {
  AdminService get _adminService => ref.read(adminServiceProvider);

  BroadcastType _type = BroadcastType.announcement;
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _campaignSearchController = TextEditingController();
  Timer? _campaignSearchDebounce;

  bool _isSending = false;
  bool _isLoadingCampaigns = false;
  String? _campaignError;
  String _campaignStatus = 'pending_approval';
  String _campaignSearch = '';
  int _campaignPage = 0;
  int _campaignRowsPerPage = 10;
  int _campaignTotal = 0;
  String? _campaignActionId;
  List<AdminCampaignApprovalItem> _campaigns = const [];
  List<AdminNotificationConsentSummary> _consentSummaries = const [];
  List<AdminNotificationConsentTrendPoint> _consentTrendPoints = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_loadCampaigns());
  }

  @override
  void dispose() {
    _campaignSearchDebounce?.cancel();
    _titleController.dispose();
    _bodyController.dispose();
    _campaignSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadCampaigns() async {
    setState(() {
      _isLoadingCampaigns = true;
      _campaignError = null;
    });

    try {
      final campaigns = await _adminService.listCampaignApprovals(
        status: _campaignStatus,
        campaignType: 'promo',
        search: _campaignSearch,
        limit: _campaignRowsPerPage,
        offset: _campaignPage * _campaignRowsPerPage,
      );
      final consentSummaries = await _adminService
          .getNotificationConsentSummary();
      final consentTrendPoints = await _adminService
          .getNotificationConsentTrend(days: 14);
      if (!mounted) return;
      setState(() {
        _campaigns = campaigns;
        _consentSummaries = consentSummaries;
        _consentTrendPoints = consentTrendPoints;
        final reportedTotal = campaigns.isEmpty
            ? 0
            : campaigns.first.totalCount;
        _campaignTotal = reportedTotal > 0
            ? reportedTotal
            : (_campaignPage * _campaignRowsPerPage) + campaigns.length;
      });
    } on Object {
      if (!mounted) return;
      setState(() => _campaignError = 'Campaign status is unavailable. Try refreshing.');
    } finally {
      if (mounted) setState(() => _isLoadingCampaigns = false);
    }
  }

  void _onCampaignSearchChanged(String value) {
    _campaignSearchDebounce?.cancel();
    setState(() {
      _campaignSearch = value;
      _campaignPage = 0;
    });
    _campaignSearchDebounce = Timer(
      const Duration(milliseconds: 300),
      () => unawaited(_loadCampaigns()),
    );
  }

  Future<void> _sendBroadcast() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (title.isEmpty || body.isEmpty) {
      _showSnackBar('Enter title and body.', isError: true);
      return;
    }

    final confirmed = await _showConfirmDialog();
    if (confirmed != true) return;

    setState(() => _isSending = true);

    try {
      if (_type == BroadcastType.promo) {
        await _adminService.requestPromoApproval(title: title, body: body);
      } else {
        final count = await _adminService.sendAnnouncement(
          title: title,
          body: body,
        );
        if (mounted) {
          _showSnackBar(
            'Queued ${_broadcastLabel(_type).toLowerCase()} for $count members.',
          );
        }
      }

      if (mounted) {
        if (_type == BroadcastType.promo) {
          _showSnackBar('Promo submitted for approval.');
          await _loadCampaigns();
        }
        _titleController.clear();
        _bodyController.clear();
      }
    } on MutationOutcomeUnknownException catch (error) {
      if (mounted) _showSnackBar(error.message, isError: true);
      if (mounted) await _loadCampaigns();
    } on Object {
      if (mounted) _showSnackBar('Unable to submit the broadcast.', isError: true);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _reviewCampaign(
    AdminCampaignApprovalItem campaign, {
    required bool approved,
  }) async {
    final confirmed = await MobiConfirmDialog.show(
      context: context,
      title: approved ? 'Approve promo' : 'Reject promo',
      body: approved
          ? 'Approve this promo for consent-gated sending.'
          : 'Reject this promo request. It will not be sent.',
      confirmLabel: approved ? 'Approve' : 'Reject',
      cancelLabel: 'Back',
    );
    if (confirmed != true) return;

    setState(() => _campaignActionId = campaign.id);

    try {
      await _adminService.approveCampaign(
        campaignId: campaign.id,
        approved: approved,
      );
      if (!mounted) return;
      _showSnackBar(approved ? 'Promo approved.' : 'Promo rejected.');
      await _loadCampaigns();
    } on MutationOutcomeUnknownException catch (error) {
      if (mounted) _showSnackBar(error.message, isError: true);
      await _loadCampaigns();
    } on Object {
      if (mounted) _showSnackBar('Unable to review this campaign.', isError: true);
    } finally {
      if (mounted) setState(() => _campaignActionId = null);
    }
  }

  Future<void> _sendApprovedCampaign(AdminCampaignApprovalItem campaign) async {
    setState(() => _campaignActionId = campaign.id);

    try {
      final preview = await _adminService.getCampaignAudiencePreview(
        campaignId: campaign.id,
      );

      if (campaign.isPromo && !preview.hasPromotionalRecipients) {
        if (!mounted) return;
        _showSnackBar(
          'Promo cannot be sent because no members have granted promotional consent.',
          isError: true,
        );
        return;
      }

      if (!mounted) return;
      final confirmed = await MobiConfirmDialog.show(
        context: context,
        title: 'Send approved promo',
        body:
            'Eligible members: ${preview.eligibleRecipientCount}. '
            'Promotional consent: ${preview.promotionalConsentCount} '
            '(${preview.promotionalInAppCount} in-app, '
            '${preview.promotionalPushCount} push). '
            'Already sent for this campaign: ${preview.alreadySentCount}. '
            'Send only to currently consenting members?',
        confirmLabel: 'Send',
        cancelLabel: 'Back',
      );
      if (confirmed != true) return;

      final count = await _adminService.sendApprovedCampaign(
        campaignId: campaign.id,
      );
      if (!mounted) return;
      _showSnackBar('Promo sent to $count consenting members.');
      await _loadCampaigns();
    } on MutationOutcomeUnknownException catch (error) {
      if (mounted) _showSnackBar(error.message, isError: true);
      await _loadCampaigns();
    } on Object {
      if (mounted) _showSnackBar('Unable to confirm this send.', isError: true);
    } finally {
      if (mounted) setState(() => _campaignActionId = null);
    }
  }

  Future<void> _showCampaignDetails(AdminCampaignApprovalItem campaign) async {
    final detailFuture = _loadCampaignDetail(campaign.id);
    await MobiBottomSheet.show<void>(
      context: context,
      title: campaign.title,
      maxHeightFraction: 0.9,
      builder: (context) =>
          _CampaignDetailSheet(campaign: campaign, detailFuture: detailFuture),
    );
  }

  Future<_CampaignDetailData> _loadCampaignDetail(String campaignId) async {
    final preview = await _adminService.getCampaignAudiencePreview(
      campaignId: campaignId,
    );
    final timeline = await _adminService.listCampaignAuditTimeline(
      campaignId: campaignId,
    );
    return _CampaignDetailData(preview: preview, timeline: timeline);
  }

  Future<bool?> _showConfirmDialog() {
    final t = _broadcastLabel(_type);
    final body = _type == BroadcastType.promo
        ? 'Submit this promo for approval. It will only send after approval and only to users with promotional consent.'
        : 'Send this operational message to members in your organization.';
    return MobiConfirmDialog.show(
      context: context,
      title: _type == BroadcastType.promo ? 'Submit $t' : 'Queue $t',
      body: body,
      confirmLabel: _type == BroadcastType.promo ? 'Submit' : 'Queue',
      cancelLabel: 'Back',
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: AdminWorkspaceFrame(
          onBack: widget.onBack,
          currentTab: AdminWorkspaceTab.broadcasts,
          title: 'Broadcasts',
          subtitle: 'System messages and approved promos.',
          child: SingleChildScrollView(
            padding: AdminLayoutTokens.overlayPagePadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTypeSelector(),
                const SizedBox(height: AppSpacing.lg),
                _buildComposerBox(cs, ext),
                const SizedBox(height: AppSpacing.lg),
                _buildPreviewPanel(cs, ext),
                const SizedBox(height: AppSpacing.xl),
                MobiButton(
                  width: double.infinity,
                  isLoading: _isSending,
                  onPressed: _isSending ? null : _sendBroadcast,
                  child: Text(
                    _type == BroadcastType.promo
                        ? 'Submit for approval'
                        : 'Queue message',
                    style: AppTypography.titleMd.copyWith(color: cs.onPrimary),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                _buildApprovalQueue(cs, ext),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return AdminPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdminSectionHeader(title: 'Type', subtitle: 'Channel'),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _BroadcastTypeCard(
                  type: BroadcastType.announcement,
                  title: 'System',
                  icon: LucideIcons.bellRing,
                  isSelected: _type == BroadcastType.announcement,
                  tone: MobiStatusBadgeTone.info,
                  onTap: () =>
                      setState(() => _type = BroadcastType.announcement),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _BroadcastTypeCard(
                  type: BroadcastType.promo,
                  title: 'Promo',
                  icon: LucideIcons.tag,
                  isSelected: _type == BroadcastType.promo,
                  tone: MobiStatusBadgeTone.brand,
                  onTap: () => setState(() => _type = BroadcastType.promo),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildComposerBox(ColorScheme cs, MobiThemeExtension ext) {
    return AdminPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdminSectionHeader(title: 'Draft', subtitle: 'Message'),
          const SizedBox(height: AppSpacing.lg),
          _buildInputSurface(
            cs: cs,
            ext: ext,
            child: TextField(
              controller: _titleController,
              onChanged: (_) => setState(() {}),
              textCapitalization: TextCapitalization.sentences,
              style: AppTypography.titleMd.copyWith(color: cs.onSurface),
              decoration: InputDecoration(
                labelText: 'Title',
                hintText: 'Maintenance notice',
                hintStyle: AppTypography.titleMd.copyWith(
                  color: cs.onSurfaceVariant,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _buildInputSurface(
            cs: cs,
            ext: ext,
            child: TextField(
              controller: _bodyController,
              onChanged: (_) => setState(() {}),
              textCapitalization: TextCapitalization.sentences,
              maxLines: 4,
              style: AppTypography.bodyMd.copyWith(color: cs.onSurface),
              decoration: InputDecoration(
                labelText: 'Body',
                hintText: 'Message body',
                hintStyle: AppTypography.bodyMd.copyWith(
                  color: cs.onSurfaceVariant,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewPanel(ColorScheme cs, MobiThemeExtension ext) {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    return AdminPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdminSectionHeader(title: 'Preview', subtitle: 'Audience'),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              MobiStatusBadge(
                label: _broadcastLabel(_type),
                icon: _type == BroadcastType.promo
                    ? LucideIcons.tag
                    : LucideIcons.bellRing,
                tone: _type == BroadcastType.promo
                    ? MobiStatusBadgeTone.brand
                    : MobiStatusBadgeTone.info,
              ),
              const MobiStatusBadge(
                label: 'Organization members',
                icon: LucideIcons.smartphone,
                tone: MobiStatusBadgeTone.neutral,
              ),
              MobiStatusBadge(
                label: _type == BroadcastType.promo
                    ? 'Consent required'
                    : 'Audited send',
                icon: _type == BroadcastType.promo
                    ? LucideIcons.shieldCheck
                    : LucideIcons.send,
                tone: MobiStatusBadgeTone.neutral,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: ext.surfaceContainerLow,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.isEmpty ? 'Notification title' : title,
                  style: AppTypography.titleMd.copyWith(
                    color: title.isEmpty ? cs.onSurfaceVariant : cs.onSurface,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  body.isEmpty ? 'Message preview' : body,
                  style: AppTypography.bodySm.copyWith(
                    color: body.isEmpty
                        ? cs.onSurfaceVariant
                        : cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalQueue(ColorScheme cs, MobiThemeExtension ext) {
    return AdminPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: AdminSectionHeader(
                  title: 'Promo approvals',
                  subtitle: 'Review queue',
                ),
              ),
              AdminIconButton(
                icon: LucideIcons.refreshCw,
                label: 'Refresh approvals',
                onPressed: _isLoadingCampaigns ? null : _loadCampaigns,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _buildCampaignStatusFilters(),
          const SizedBox(height: AppSpacing.md),
          AdminSearchField(
            controller: _campaignSearchController,
            hintText: 'Search title, organization, actor, campaign ID',
            onChanged: _onCampaignSearchChanged,
          ),
          if (_consentSummaries.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _buildConsentSummary(cs),
          ],
          if (_consentTrendPoints.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _buildConsentTrend(cs),
          ],
          const SizedBox(height: AppSpacing.lg),
          if (_isLoadingCampaigns)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_campaignError != null)
            _buildInlineState(
              cs: cs,
              ext: ext,
              icon: LucideIcons.alertTriangle,
              title: 'Approval queue unavailable',
              message: _campaignError!,
            )
          else if (_campaigns.isEmpty)
            _buildInlineState(
              cs: cs,
              ext: ext,
              icon: LucideIcons.inbox,
              title: 'No ${_statusLabel(_campaignStatus).toLowerCase()} promos',
              message: 'Promo requests will appear here after submission.',
            )
          else
            Column(
              children: [
                for (final campaign in _campaigns) ...[
                  _buildCampaignRow(cs, ext, campaign),
                  if (campaign != _campaigns.last)
                    const SizedBox(height: AppSpacing.md),
                ],
                const SizedBox(height: AppSpacing.sm),
                AdminPaginationBar(
                  totalItems: _campaignTotal,
                  page: _campaignPage,
                  rowsPerPage: _campaignRowsPerPage,
                  onPageChanged: (page) {
                    setState(() => _campaignPage = page);
                    unawaited(_loadCampaigns());
                  },
                  onRowsPerPageChanged: (rows) {
                    setState(() {
                      _campaignRowsPerPage = rows;
                      _campaignPage = 0;
                    });
                    unawaited(_loadCampaigns());
                  },
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildConsentSummary(ColorScheme cs) {
    final eligible = _consentSummaries.fold<int>(
      0,
      (sum, item) => sum + item.eligibleProfileCount,
    );
    final consented = _consentSummaries.fold<int>(
      0,
      (sum, item) => sum + item.promotionalAnyCount,
    );
    final inApp = _consentSummaries.fold<int>(
      0,
      (sum, item) => sum + item.promotionalInAppCount,
    );
    final push = _consentSummaries.fold<int>(
      0,
      (sum, item) => sum + item.promotionalPushCount,
    );
    final revoked = _consentSummaries.fold<int>(
      0,
      (sum, item) => sum + item.revokedOrDeniedCount,
    );
    final coverage = eligible == 0 ? 0 : ((consented / eligible) * 100).round();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.primary.withValues(alpha: 0.16)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            MobiStatusBadge(
              label: '$coverage% opted in',
              icon: LucideIcons.pieChart,
              tone: MobiStatusBadgeTone.brand,
            ),
            MobiStatusBadge(
              label: '$consented of $eligible eligible',
              icon: LucideIcons.users,
              tone: MobiStatusBadgeTone.neutral,
            ),
            MobiStatusBadge(
              label: '$inApp in-app',
              icon: LucideIcons.bell,
              tone: MobiStatusBadgeTone.neutral,
            ),
            MobiStatusBadge(
              label: '$push push',
              icon: LucideIcons.smartphone,
              tone: MobiStatusBadgeTone.neutral,
            ),
            MobiStatusBadge(
              label: '$revoked denied/revoked',
              icon: LucideIcons.bellOff,
              tone: MobiStatusBadgeTone.warning,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConsentTrend(ColorScheme cs) {
    final granted = _consentTrendPoints.fold<int>(
      0,
      (sum, point) => sum + point.grantedCount,
    );
    final revoked = _consentTrendPoints.fold<int>(
      0,
      (sum, point) => sum + point.revokedOrDeniedCount,
    );
    final inApp = _consentTrendPoints.fold<int>(
      0,
      (sum, point) => sum + point.inAppGrantedCount,
    );
    final push = _consentTrendPoints.fold<int>(
      0,
      (sum, point) => sum + point.pushGrantedCount,
    );
    final net = granted - revoked;
    final latestDate = _consentTrendPoints.last.bucketDate;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.secondary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.secondary.withValues(alpha: 0.16)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            MobiStatusBadge(
              label: '14d net ${net >= 0 ? '+' : ''}$net',
              icon: LucideIcons.trendingUp,
              tone: net >= 0
                  ? MobiStatusBadgeTone.positive
                  : MobiStatusBadgeTone.warning,
            ),
            MobiStatusBadge(
              label: '$granted grants',
              icon: LucideIcons.bellPlus,
              tone: MobiStatusBadgeTone.neutral,
            ),
            MobiStatusBadge(
              label: '$revoked revoked/denied',
              icon: LucideIcons.bellOff,
              tone: MobiStatusBadgeTone.warning,
            ),
            MobiStatusBadge(
              label: '$inApp in-app',
              icon: LucideIcons.bell,
              tone: MobiStatusBadgeTone.neutral,
            ),
            MobiStatusBadge(
              label: '$push push',
              icon: LucideIcons.smartphone,
              tone: MobiStatusBadgeTone.neutral,
            ),
            MobiStatusBadge(
              label: 'through $latestDate',
              icon: LucideIcons.calendarDays,
              tone: MobiStatusBadgeTone.neutral,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCampaignStatusFilters() {
    const filters = <String, ({String label, IconData icon})>{
      'pending_approval': (label: 'Pending', icon: LucideIcons.clock3),
      'approved': (label: 'Approved', icon: LucideIcons.checkCircle2),
      'sent': (label: 'Sent', icon: LucideIcons.send),
      'rejected': (label: 'Rejected', icon: LucideIcons.xCircle),
    };

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final entry in filters.entries)
          AdminFilterChip(
            label: entry.value.label,
            icon: entry.value.icon,
            isSelected: _campaignStatus == entry.key,
            onTap: () {
              if (_campaignStatus == entry.key) return;
              setState(() {
                _campaignStatus = entry.key;
                _campaignPage = 0;
              });
              unawaited(_loadCampaigns());
            },
          ),
      ],
    );
  }

  Widget _buildCampaignRow(
    ColorScheme cs,
    MobiThemeExtension ext,
    AdminCampaignApprovalItem campaign,
  ) {
    final isBusy = _campaignActionId == campaign.id;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: ext.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                MobiStatusBadge(
                  label: _statusLabel(campaign.status),
                  icon: _statusIcon(campaign.status),
                  tone: _statusTone(campaign.status),
                ),
                MobiStatusBadge(
                  label: campaign.organizationName,
                  icon: LucideIcons.building2,
                  tone: MobiStatusBadgeTone.neutral,
                ),
                if (campaign.isPromo)
                  MobiStatusBadge(
                    label:
                        '${campaign.promotionalConsentCount}/${campaign.eligibleRecipientCount} consented',
                    icon: LucideIcons.shieldCheck,
                    tone: MobiStatusBadgeTone.brand,
                  ),
                if (campaign.auditEventCount > 0)
                  MobiStatusBadge(
                    label: '${campaign.auditEventCount} audit events',
                    icon: LucideIcons.clipboardList,
                    tone: MobiStatusBadgeTone.neutral,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              campaign.title,
              style: AppTypography.titleMd.copyWith(color: cs.onSurface),
            ),
            if ((campaign.body ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                campaign.body!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodySm.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.xs,
              children: [
                _MetaText(
                  icon: LucideIcons.user,
                  text: 'Requested by ${campaign.requestedByName}',
                ),
                _MetaText(
                  icon: LucideIcons.calendarClock,
                  text: _formatDate(campaign.requestedAt),
                ),
                if (campaign.isSent)
                  _MetaText(
                    icon: LucideIcons.users,
                    text: '${campaign.recipientCount} recipients',
                  ),
                if (campaign.latestAuditAt != null)
                  _MetaText(
                    icon: LucideIcons.clipboardCheck,
                    text: 'Last audit ${_formatDate(campaign.latestAuditAt)}',
                  ),
              ],
            ),
            if (campaign.isApproved || campaign.isSent) ...[
              const SizedBox(height: AppSpacing.xs),
              _MetaText(
                icon: LucideIcons.shieldCheck,
                text:
                    'Approved by ${campaign.approvedByName ?? 'Platform admin'}',
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                AdminActionChip(
                  label: 'Details',
                  icon: LucideIcons.panelRight,
                  tone: MobiStatusBadgeTone.neutral,
                  onTap: isBusy ? null : () => _showCampaignDetails(campaign),
                ),
                if (campaign.isPending) ...[
                  AdminActionChip(
                    label: 'Approve',
                    icon: LucideIcons.check,
                    tone: MobiStatusBadgeTone.positive,
                    isBusy: isBusy,
                    onTap: isBusy
                        ? null
                        : () => _reviewCampaign(campaign, approved: true),
                  ),
                  AdminActionChip(
                    label: 'Reject',
                    icon: LucideIcons.x,
                    tone: MobiStatusBadgeTone.danger,
                    isBusy: isBusy,
                    onTap: isBusy
                        ? null
                        : () => _reviewCampaign(campaign, approved: false),
                  ),
                ],
                if (campaign.isApproved)
                  AdminActionChip(
                    label: 'Send',
                    icon: LucideIcons.send,
                    tone: MobiStatusBadgeTone.brand,
                    isBusy: isBusy,
                    onTap: isBusy
                        ? null
                        : () => _sendApprovedCampaign(campaign),
                  ),
                if (campaign.auditEventCount > 0)
                  AdminActionChip(
                    label: 'Audit',
                    icon: LucideIcons.clipboardList,
                    tone: MobiStatusBadgeTone.neutral,
                    onTap: isBusy
                        ? null
                        : () => context.go(
                            '/admin/audit?search=${Uri.encodeComponent(campaign.id)}',
                          ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInlineState({
    required ColorScheme cs,
    required MobiThemeExtension ext,
    required IconData icon,
    required String title,
    required String message,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ext.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: cs.onSurfaceVariant),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.titleMd.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    message,
                    style: AppTypography.bodySm.copyWith(
                      color: cs.onSurfaceVariant,
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

  Widget _buildInputSurface({
    required ColorScheme cs,
    required MobiThemeExtension ext,
    required Widget child,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ext.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.1)),
      ),
      child: child,
    );
  }
}

String _broadcastLabel(BroadcastType type) {
  return switch (type) {
    BroadcastType.promo => 'Promo',
    BroadcastType.announcement => 'System message',
  };
}

String _statusLabel(String status) {
  return switch (status) {
    'pending_approval' => 'Pending',
    'approved' => 'Approved',
    'sent' => 'Sent',
    'rejected' => 'Rejected',
    'cancelled' => 'Cancelled',
    _ => status,
  };
}

IconData _statusIcon(String status) {
  return switch (status) {
    'pending_approval' => LucideIcons.clock3,
    'approved' => LucideIcons.checkCircle2,
    'sent' => LucideIcons.send,
    'rejected' => LucideIcons.xCircle,
    'cancelled' => LucideIcons.circleSlash,
    _ => LucideIcons.circle,
  };
}

MobiStatusBadgeTone _statusTone(String status) {
  return switch (status) {
    'pending_approval' => MobiStatusBadgeTone.warning,
    'approved' => MobiStatusBadgeTone.positive,
    'sent' => MobiStatusBadgeTone.brand,
    'rejected' => MobiStatusBadgeTone.danger,
    'cancelled' => MobiStatusBadgeTone.neutral,
    _ => MobiStatusBadgeTone.neutral,
  };
}

String _formatDate(String? iso) {
  if (iso == null || iso.isEmpty) return 'Date unavailable';
  final parsed = DateTime.tryParse(iso)?.toLocal();
  if (parsed == null) return iso;
  final year = parsed.year.toString().padLeft(4, '0');
  final month = parsed.month.toString().padLeft(2, '0');
  final day = parsed.day.toString().padLeft(2, '0');
  final hour = parsed.hour.toString().padLeft(2, '0');
  final minute = parsed.minute.toString().padLeft(2, '0');
  return '$year-$month-$day $hour:$minute';
}

String _auditActionLabel(String action) {
  final words = action.split('_').where((word) => word.isNotEmpty).toList();
  if (words.isEmpty) return action;
  return words
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}

class _CampaignDetailData {
  final AdminCampaignAudiencePreview preview;
  final List<AdminAuditLogItem> timeline;

  const _CampaignDetailData({required this.preview, required this.timeline});
}

class _CampaignDetailSheet extends StatelessWidget {
  final AdminCampaignApprovalItem campaign;
  final Future<_CampaignDetailData> detailFuture;

  const _CampaignDetailSheet({
    required this.campaign,
    required this.detailFuture,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.72,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, 0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _statusLabel(campaign.status),
                    style: AppTypography.bodySm.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(LucideIcons.x),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: FutureBuilder<_CampaignDetailData>(
                future: detailFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return _DetailState(
                      icon: LucideIcons.alertTriangle,
                      title: 'Campaign details unavailable',
                      message: snapshot.error.toString(),
                    );
                  }
                  final detail = snapshot.data;
                  if (detail == null) {
                    return const _DetailState(
                      icon: LucideIcons.inbox,
                      title: 'No details returned',
                      message: 'The campaign detail RPC returned no rows.',
                    );
                  }
                  return _CampaignDetailContent(
                    campaign: campaign,
                    detail: detail,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CampaignDetailContent extends StatelessWidget {
  final AdminCampaignApprovalItem campaign;
  final _CampaignDetailData detail;

  const _CampaignDetailContent({required this.campaign, required this.detail});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final preview = detail.preview;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              MobiStatusBadge(
                label: _statusLabel(campaign.status),
                icon: _statusIcon(campaign.status),
                tone: _statusTone(campaign.status),
              ),
              MobiStatusBadge(
                label: campaign.organizationName,
                icon: LucideIcons.building2,
                tone: MobiStatusBadgeTone.neutral,
              ),
              MobiStatusBadge(
                label: '${preview.promotionalCoveragePercent}% opted in',
                icon: LucideIcons.shieldCheck,
                tone: MobiStatusBadgeTone.brand,
              ),
            ],
          ),
          if ((campaign.body ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              campaign.body!,
              style: AppTypography.bodyMd.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              _DetailMetric(
                label: 'Eligible',
                value: '${preview.eligibleRecipientCount}',
                icon: LucideIcons.users,
              ),
              _DetailMetric(
                label: 'Consented',
                value: '${preview.promotionalConsentCount}',
                icon: LucideIcons.userCheck,
                tone: MobiStatusBadgeTone.positive,
              ),
              _DetailMetric(
                label: 'In-app',
                value: '${preview.promotionalInAppCount}',
                icon: LucideIcons.bell,
              ),
              _DetailMetric(
                label: 'Push',
                value: '${preview.promotionalPushCount}',
                icon: LucideIcons.smartphone,
              ),
              _DetailMetric(
                label: 'Revoked/denied',
                value: '${preview.revokedOrDeniedCount}',
                icon: LucideIcons.bellOff,
                tone: MobiStatusBadgeTone.warning,
              ),
              _DetailMetric(
                label: 'Already sent',
                value: '${preview.alreadySentCount}',
                icon: LucideIcons.send,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Audit timeline',
            style: AppTypography.titleMd.copyWith(color: cs.onSurface),
          ),
          const SizedBox(height: AppSpacing.md),
          if (detail.timeline.isEmpty)
            const _DetailState(
              icon: LucideIcons.clipboardList,
              title: 'No audit events',
              message: 'No campaign audit rows were returned.',
            )
          else
            Column(
              children: [
                for (final item in detail.timeline) ...[
                  _AuditTimelineRow(item: item),
                  if (item != detail.timeline.last)
                    const SizedBox(height: AppSpacing.sm),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _DetailMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final MobiStatusBadgeTone tone;

  const _DetailMetric({
    required this.label,
    required this.value,
    required this.icon,
    this.tone = MobiStatusBadgeTone.neutral,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;
    final accent = switch (tone) {
      MobiStatusBadgeTone.positive => cs.tertiary,
      MobiStatusBadgeTone.warning => ext.caution,
      MobiStatusBadgeTone.danger => cs.error,
      MobiStatusBadgeTone.brand => cs.primary,
      MobiStatusBadgeTone.info => ext.info,
      MobiStatusBadgeTone.neutral => cs.onSurfaceVariant,
    };

    return SizedBox(
      width: 150,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: ext.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.22)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: accent),
              const SizedBox(height: AppSpacing.sm),
              Text(
                value,
                style: AppTypography.titleLg.copyWith(color: cs.onSurface),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                label,
                style: AppTypography.labelMd.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuditTimelineRow extends StatelessWidget {
  final AdminAuditLogItem item;

  const _AuditTimelineRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: ext.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(LucideIcons.clipboardCheck, size: 18, color: cs.primary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _auditActionLabel(item.action),
                    style: AppTypography.titleMd.copyWith(color: cs.onSurface),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${item.adminName} • ${_formatDate(item.createdAt)}',
                    style: AppTypography.bodySm.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  if (item.details.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      item.details.toString(),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelMd.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _DetailState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: cs.onSurfaceVariant),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.titleMd.copyWith(color: cs.onSurface),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.bodySm.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaText extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaText({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: cs.onSurfaceVariant),
        const SizedBox(width: AppSpacing.xs),
        Text(
          text,
          style: AppTypography.labelMd.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _BroadcastTypeCard extends StatelessWidget {
  final BroadcastType type;
  final String title;
  final IconData icon;
  final bool isSelected;
  final MobiStatusBadgeTone tone;
  final VoidCallback onTap;

  const _BroadcastTypeCard({
    required this.type,
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.tone,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? ext.surfaceContainerLow
              : ext.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? cs.primary.withValues(alpha: 0.5)
                : cs.outlineVariant.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 28,
              color: isSelected ? cs.primary : cs.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: AppTypography.labelSm.copyWith(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w600,
                color: isSelected ? cs.onSurface : cs.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
