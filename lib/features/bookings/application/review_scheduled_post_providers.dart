import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/features/bookings/application/review_scheduled_posts.dart';
import 'package:mobi_app/features/store_review/domain/review_world_authority.dart';

/// Root overrides only in its explicitly selected review marketplace scope.
/// A null gateway never permits review transport to fall through to ordinary IO.
final reviewScheduledPostGatewayProvider =
    Provider<ReviewScheduledPostGateway?>((ref) => null);

final reviewScheduledPostsSelectedProvider = Provider<bool>(
  (ref) =>
      ref.watch(reviewScheduledPostGatewayProvider) != null ||
      AccountContext.hasReviewTransport,
);

ReviewScheduledPostGateway requireReviewScheduledPosts(
  ReviewScheduledPostGateway? gateway,
) =>
    gateway ??
    (throw const ReviewWorldUnavailable('review_composition_unavailable'));
