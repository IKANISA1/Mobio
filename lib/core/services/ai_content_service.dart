import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobi_app/core/config/supabase_config.dart';

/// Categories of promotional content matching empty state contexts.
enum PromoCategory {
  nearbyDrivers,
  scheduledTrips,
  nearbyTrips,
  errorRetry,
}

/// Metadata for a single promotional media asset.
class PromoAsset {
  final String url;
  final String category;
  final String type; // 'image' | 'video'
  final DateTime generatedAt;

  const PromoAsset({
    required this.url,
    required this.category,
    required this.type,
    required this.generatedAt,
  });

  Map<String, dynamic> toJson() => {
        'url': url,
        'category': category,
        'type': type,
        'generated_at': generatedAt.toIso8601String(),
      };

  factory PromoAsset.fromJson(Map<String, dynamic> json) => PromoAsset(
        url: json['url'] as String,
        category: json['category'] as String,
        type: json['type'] as String? ?? 'image',
        generatedAt: DateTime.tryParse(json['generated_at'] as String? ?? '') ??
            DateTime.now(),
      );
}

/// Service that fetches pre-generated promotional media from Supabase Storage.
///
/// Assets are cached locally in Hive with a 24-hour TTL.
/// Falls back to empty list (triggering gradient-only empty states) if
/// network/storage is unavailable.
class AiContentService {
  static const _boxName = 'promo_content_cache';
  static const _cacheTtl = Duration(hours: 24);
  static const _storageBucket = 'promo-media';

  static AiContentService? _instance;
  factory AiContentService() => _instance ??= AiContentService._();
  AiContentService._();

  Box? _box;

  /// Initialize the Hive cache box. Call once at app startup.
  Future<void> init() async {
    try {
      _box = await Hive.openBox(_boxName);
    } catch (e) {
      debugPrint('AiContentService: Failed to open cache box: $e');
    }
  }

  /// Get the Supabase Storage bucket name for a category.
  String _storagePath(PromoCategory category) {
    switch (category) {
      case PromoCategory.nearbyDrivers:
        return 'nearby-drivers';
      case PromoCategory.scheduledTrips:
        return 'scheduled-trips';
      case PromoCategory.nearbyTrips:
        return 'nearby-trips';
      case PromoCategory.errorRetry:
        return 'error-retry';
    }
  }

  /// Fetch promotional images for a given category.
  ///
  /// Returns up to 4 image URLs from Supabase Storage, using cached
  /// URLs if available and fresh (< 24h old).
  Future<List<String>> fetchPromoImages(PromoCategory category) async {
    final cacheKey = 'images_${_storagePath(category)}';

    // Check cache
    final cached = _getCached(cacheKey);
    if (cached != null) return cached;

    // Fetch from Supabase Storage
    if (!SupabaseConfig.isConfigured) return [];

    try {
      final client = Supabase.instance.client;
      final files = await client.storage
          .from(_storageBucket)
          .list(path: '${_storagePath(category)}/images');

      final imageFiles = files
          .where((f) =>
              f.name.endsWith('.png') ||
              f.name.endsWith('.jpg') ||
              f.name.endsWith('.webp'))
          .take(4)
          .toList();

      final urls = imageFiles
          .map((f) => client.storage
              .from(_storageBucket)
              .getPublicUrl('${_storagePath(category)}/images/${f.name}'))
          .toList();

      // Cache
      _setCache(cacheKey, urls);
      return urls;
    } catch (e) {
      debugPrint('AiContentService: Failed to fetch images: $e');
      return [];
    }
  }

  /// Fetch a promotional video URL for a given category.
  ///
  /// Returns null if no video is available or if fetch fails.
  Future<String?> fetchPromoVideo(PromoCategory category) async {
    final cacheKey = 'video_${_storagePath(category)}';

    // Check cache
    final cached = _getCached(cacheKey);
    if (cached != null && cached.isNotEmpty) return cached.first;

    if (!SupabaseConfig.isConfigured) return null;

    try {
      final client = Supabase.instance.client;
      final files = await client.storage
          .from(_storageBucket)
          .list(path: '${_storagePath(category)}/videos');

      final videoFiles = files
          .where((f) => f.name.endsWith('.mp4') || f.name.endsWith('.webm'))
          .take(1)
          .toList();

      if (videoFiles.isEmpty) return null;

      final url = client.storage
          .from(_storageBucket)
          .getPublicUrl(
              '${_storagePath(category)}/videos/${videoFiles.first.name}');

      _setCache(cacheKey, [url]);
      return url;
    } catch (e) {
      debugPrint('AiContentService: Failed to fetch video: $e');
      return null;
    }
  }

  /// Clear all cached promo content.
  Future<void> clearCache() async {
    await _box?.clear();
  }

  // ─── Cache helpers ───

  List<String>? _getCached(String key) {
    if (_box == null) return null;
    try {
      final data = _box!.get(key);
      if (data == null) return null;

      final cachedAt = _box!.get('${key}_ts');
      if (cachedAt is int) {
        final ts = DateTime.fromMillisecondsSinceEpoch(cachedAt);
        if (DateTime.now().difference(ts) > _cacheTtl) {
          _box!.delete(key);
          _box!.delete('${key}_ts');
          return null;
        }
      }

      return List<String>.from(data as List);
    } catch (_) {
      return null;
    }
  }

  void _setCache(String key, List<String> urls) {
    try {
      _box?.put(key, urls);
      _box?.put('${key}_ts', DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }
}
