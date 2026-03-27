import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mobi_app/core/config/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Categories of promotional content matching empty state contexts.
enum PromoCategory { nearbyDrivers, scheduledTrips, nearbyTrips, errorRetry }

/// Metadata for a single promotional media asset.
class PromoAsset {
  final String url;
  final String path;
  final String category;
  final String type; // 'image' | 'video'
  final DateTime generatedAt;
  final double focusX;
  final double focusY;
  final double safeTextX;
  final double safeTextY;
  final Map<String, dynamic> metadata;

  const PromoAsset({
    required this.url,
    required this.path,
    required this.category,
    required this.type,
    required this.generatedAt,
    this.focusX = 0.5,
    this.focusY = 0.5,
    this.safeTextX = 0.12,
    this.safeTextY = 0.12,
    this.metadata = const {},
  });

  Alignment get focusAlignment =>
      Alignment(_unitToAlignment(focusX), _unitToAlignment(focusY));

  Alignment get safeTextAlignment =>
      Alignment(_unitToAlignment(safeTextX), _unitToAlignment(safeTextY));

  Map<String, dynamic> toJson() => {
    'url': url,
    'path': path,
    'category': category,
    'type': type,
    'generated_at': generatedAt.toIso8601String(),
    'focus_x': focusX,
    'focus_y': focusY,
    'safe_text_x': safeTextX,
    'safe_text_y': safeTextY,
    'metadata': metadata,
  };

  factory PromoAsset.fromJson(Map<String, dynamic> json) => PromoAsset(
    url: json['url'] as String,
    path: (json['path'] as String?) ?? '',
    category: json['category'] as String,
    type: json['type'] as String? ?? 'image',
    generatedAt:
        DateTime.tryParse(json['generated_at'] as String? ?? '') ??
        DateTime.now(),
    focusX: _readUnitDouble(json, const ['focus_x', 'focusX']) ?? 0.5,
    focusY: _readUnitDouble(json, const ['focus_y', 'focusY']) ?? 0.5,
    safeTextX:
        _readUnitDouble(json, const ['safe_text_x', 'safeTextX']) ?? 0.12,
    safeTextY:
        _readUnitDouble(json, const ['safe_text_y', 'safeTextY']) ?? 0.12,
    metadata: json['metadata'] is Map
        ? Map<String, dynamic>.from(json['metadata'] as Map)
        : const {},
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

  Future<List<String>> fetchPromoImages(PromoCategory category) async {
    final assets = await fetchPromoImageAssets(category);
    return assets.map((asset) => asset.url).toList(growable: false);
  }

  /// Fetch promotional image assets for a given category.
  ///
  /// Returns up to 4 assets from Supabase Storage, using cached
  /// values if available and fresh (< 24h old).
  Future<List<PromoAsset>> fetchPromoImageAssets(PromoCategory category) async {
    final cacheKey = 'image_assets_${_storagePath(category)}';

    final cached = _getCachedAssets(cacheKey);
    if (cached != null) {
      return cached;
    }

    if (!SupabaseConfig.isConfigured) {
      return [];
    }

    try {
      final client = Supabase.instance.client;
      final files = await client.storage
          .from(_storageBucket)
          .list(path: '${_storagePath(category)}/images');

      final imageFiles =
          files
              .where(
                (file) =>
                    file.name.endsWith('.png') ||
                    file.name.endsWith('.jpg') ||
                    file.name.endsWith('.webp'),
              )
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name));

      final assets = imageFiles
          .take(4)
          .map(
            (file) => _toPromoAsset(
              file: file,
              category: category,
              type: 'image',
              client: client,
            ),
          )
          .toList(growable: false);

      _setAssetCache(cacheKey, assets);
      return assets;
    } catch (e) {
      debugPrint('AiContentService: Failed to fetch images: $e');
      return [];
    }
  }

  Future<String?> fetchPromoVideo(PromoCategory category) async {
    return (await fetchPromoVideoAsset(category))?.url;
  }

  /// Fetch a promotional video asset for a given category.
  ///
  /// Returns null if no video is available or if fetch fails.
  Future<PromoAsset?> fetchPromoVideoAsset(PromoCategory category) async {
    final cacheKey = 'video_asset_${_storagePath(category)}';

    final cached = _getCachedAssets(cacheKey);
    if (cached != null && cached.isNotEmpty) {
      return cached.first;
    }

    if (!SupabaseConfig.isConfigured) {
      return null;
    }

    try {
      final client = Supabase.instance.client;
      final files = await client.storage
          .from(_storageBucket)
          .list(path: '${_storagePath(category)}/videos');

      final videoFiles =
          files
              .where(
                (file) =>
                    file.name.endsWith('.mp4') || file.name.endsWith('.webm'),
              )
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name));

      if (videoFiles.isEmpty) {
        return null;
      }

      final asset = _toPromoAsset(
        file: videoFiles.first,
        category: category,
        type: 'video',
        client: client,
      );

      _setAssetCache(cacheKey, [asset]);
      return asset;
    } catch (e) {
      debugPrint('AiContentService: Failed to fetch video: $e');
      return null;
    }
  }

  /// Clear all cached promo content.
  Future<void> clearCache() async {
    await _box?.clear();
  }

  List<PromoAsset>? _getCachedAssets(String key) {
    if (_box == null) {
      return null;
    }

    try {
      final data = _box!.get(key);
      if (data == null) {
        return null;
      }

      final cachedAt = _box!.get('${key}_ts');
      if (cachedAt is int) {
        final ts = DateTime.fromMillisecondsSinceEpoch(cachedAt);
        if (DateTime.now().difference(ts) > _cacheTtl) {
          _box!.delete(key);
          _box!.delete('${key}_ts');
          return null;
        }
      }

      if (data is! List) {
        return null;
      }

      return data
          .whereType<Map>()
          .map(
            (item) =>
                PromoAsset.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(growable: false);
    } catch (_) {
      return null;
    }
  }

  void _setAssetCache(String key, List<PromoAsset> assets) {
    try {
      _box?.put(key, assets.map((asset) => asset.toJson()).toList());
      _box?.put('${key}_ts', DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  PromoAsset _toPromoAsset({
    required FileObject file,
    required PromoCategory category,
    required String type,
    required SupabaseClient client,
  }) {
    final folder = type == 'video' ? 'videos' : 'images';
    final storagePath = '${_storagePath(category)}/$folder/${file.name}';
    final metadata = _resolveAssetMetadata(
      category: category,
      type: type,
      fileName: file.name,
      rawMetadata: file.metadata,
    );

    return PromoAsset(
      url: client.storage.from(_storageBucket).getPublicUrl(storagePath),
      path: storagePath,
      category: _storagePath(category),
      type: type,
      generatedAt:
          DateTime.tryParse(file.updatedAt ?? file.createdAt ?? '') ??
          DateTime.now(),
      focusX: metadata['focus_x'] as double,
      focusY: metadata['focus_y'] as double,
      safeTextX: metadata['safe_text_x'] as double,
      safeTextY: metadata['safe_text_y'] as double,
      metadata: metadata,
    );
  }

  Map<String, dynamic> _resolveAssetMetadata({
    required PromoCategory category,
    required String type,
    required String fileName,
    Map<String, dynamic>? rawMetadata,
  }) {
    final defaults = _defaultLayout(category: category, type: type);
    final flatMetadata = _flattenMetadata(rawMetadata);
    final fileMetadata = _parseFilenameMetadata(fileName);

    final focusX =
        _readUnitDouble(flatMetadata, const [
          'focus_x',
          'focusX',
          'focal_x',
          'focalPointX',
        ]) ??
        fileMetadata['focus_x'] ??
        defaults['focus_x']!;
    final focusY =
        _readUnitDouble(flatMetadata, const [
          'focus_y',
          'focusY',
          'focal_y',
          'focalPointY',
        ]) ??
        fileMetadata['focus_y'] ??
        defaults['focus_y']!;
    final safeTextX =
        _readUnitDouble(flatMetadata, const [
          'safe_text_x',
          'safeTextX',
          'safe_x',
          'safeX',
        ]) ??
        fileMetadata['safe_text_x'] ??
        defaults['safe_text_x']!;
    final safeTextY =
        _readUnitDouble(flatMetadata, const [
          'safe_text_y',
          'safeTextY',
          'safe_y',
          'safeY',
        ]) ??
        fileMetadata['safe_text_y'] ??
        defaults['safe_text_y']!;

    return {
      ...flatMetadata,
      ...fileMetadata,
      'focus_x': focusX,
      'focus_y': focusY,
      'safe_text_x': safeTextX,
      'safe_text_y': safeTextY,
    };
  }

  Map<String, double> _defaultLayout({
    required PromoCategory category,
    required String type,
  }) {
    switch (category) {
      case PromoCategory.nearbyDrivers:
        return {
          'focus_x': type == 'video' ? 0.72 : 0.74,
          'focus_y': type == 'video' ? 0.36 : 0.40,
          'safe_text_x': 0.12,
          'safe_text_y': 0.10,
        };
      case PromoCategory.scheduledTrips:
        return {
          'focus_x': type == 'video' ? 0.68 : 0.70,
          'focus_y': 0.36,
          'safe_text_x': 0.12,
          'safe_text_y': 0.12,
        };
      case PromoCategory.nearbyTrips:
        return {
          'focus_x': 0.70,
          'focus_y': 0.42,
          'safe_text_x': 0.12,
          'safe_text_y': 0.12,
        };
      case PromoCategory.errorRetry:
        return {
          'focus_x': 0.62,
          'focus_y': 0.36,
          'safe_text_x': 0.14,
          'safe_text_y': 0.12,
        };
    }
  }

  Map<String, dynamic> _flattenMetadata(Map<String, dynamic>? metadata) {
    if (metadata == null) {
      return const {};
    }

    final flat = <String, dynamic>{...metadata};
    for (final key in const ['customMetadata', 'userMetadata', 'metadata']) {
      final nested = metadata[key];
      if (nested is Map) {
        flat.addAll(Map<String, dynamic>.from(nested as Map));
      }
    }
    return flat;
  }

  Map<String, double> _parseFilenameMetadata(String fileName) {
    final stem = fileName.split('.').first;

    double? capture(String pattern) {
      final match = RegExp(pattern, caseSensitive: false).firstMatch(stem);
      if (match == null) {
        return null;
      }
      return _coerceUnitDouble(match.group(1));
    }

    final focusX = capture(r'(?:^|[_-])fx(?:_|-)?([01](?:\.\d+)?)');
    final focusY = capture(r'(?:^|[_-])fy(?:_|-)?([01](?:\.\d+)?)');
    final safeTextX = capture(r'(?:^|[_-])sx(?:_|-)?([01](?:\.\d+)?)');
    final safeTextY = capture(r'(?:^|[_-])sy(?:_|-)?([01](?:\.\d+)?)');

    return {
      if (focusX != null) 'focus_x': focusX,
      if (focusY != null) 'focus_y': focusY,
      if (safeTextX != null) 'safe_text_x': safeTextX,
      if (safeTextY != null) 'safe_text_y': safeTextY,
    };
  }
}

double _unitToAlignment(double value) => (_clampUnit(value) * 2) - 1;

double _clampUnit(double value) => value.clamp(0.0, 1.0).toDouble();

double? _coerceUnitDouble(Object? value) {
  if (value is num) {
    return _clampUnit(value.toDouble());
  }
  if (value is String) {
    final parsed = double.tryParse(value.trim());
    if (parsed != null) {
      return _clampUnit(parsed);
    }
  }
  return null;
}

double? _readUnitDouble(Map<String, dynamic> source, List<String> keys) {
  for (final key in keys) {
    final parsed = _coerceUnitDouble(source[key]);
    if (parsed != null) {
      return parsed;
    }
  }
  return null;
}
