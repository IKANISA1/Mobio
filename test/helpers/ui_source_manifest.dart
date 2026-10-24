import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

/// Reads the host wrapper's canonical Git manifest without starting a process
/// inside flutter_tester. The host also verifies additions/removals afterward.
final class UiSourceManifest {
  UiSourceManifest._(this._root, this._summary, this._records);

  final String _root;
  final Map<String, dynamic> _summary;
  final List<({String path, String sha256})> _records;

  static final _hashPattern = RegExp(r'^[0-9a-f]{64}$');
  static const _excludedParts = {
    '.git',
    '.dart_tool',
    '.gradle',
    '.cache',
    '.symlinks',
    '.venv',
    'build',
    'Pods',
    'node_modules',
    '__pycache__',
    'test',
    'androidTest',
    'testFixtures',
  };
  static const _secretSuffixes = {
    '.jks',
    '.keystore',
    '.key',
    '.pem',
    '.p12',
    '.p8',
  };
  static const _secretNames = {
    'key.properties',
    'google-services.json',
    'googleservice-info.plist',
    'credentials.json',
    'secrets.json',
  };

  factory UiSourceManifest.fromEnvironment({
    Map<String, String>? environment,
    Directory? projectRoot,
  }) {
    final path =
        (environment ?? Platform.environment)['MOBIO_UI_SOURCE_MANIFEST'];
    if (path == null || path.isEmpty) {
      throw StateError(
        'MOBIO_UI_SOURCE_MANIFEST is required for source-bound captures. '
        'Run python3 scripts/qa/run_flutter_tests.py '
        '--flutter-bin <configured absolute Flutter executable> -- '
        '<Flutter test arguments>.',
      );
    }
    return UiSourceManifest.load(path, projectRoot: projectRoot);
  }

  factory UiSourceManifest.load(String manifestPath, {Directory? projectRoot}) {
    if (!File(manifestPath).isAbsolute) {
      throw StateError('The UI source manifest path must be absolute.');
    }
    final root = (projectRoot ?? Directory.current).resolveSymbolicLinksSync();
    final Object? decoded;
    try {
      decoded = jsonDecode(File(manifestPath).readAsStringSync());
    } on Object catch (error) {
      throw StateError('Cannot read the UI source manifest: $error');
    }
    if (decoded is! Map<String, dynamic> ||
        decoded['schema_version'] != 1 ||
        decoded['product'] != 'Mobio' ||
        decoded['acceptance_effect'] != 'none') {
      throw StateError('Invalid UI source manifest schema or product.');
    }
    final boundRoot = decoded['project_root'];
    if (boundRoot is! String ||
        !Directory(boundRoot).isAbsolute ||
        Directory(boundRoot).resolveSymbolicLinksSync() != root) {
      throw StateError(
        'The UI source manifest belongs to another project root.',
      );
    }
    final scope = _pathList(decoded['scope'], 'scope', directories: true);
    final configFiles = _pathList(decoded['config_files'], 'config_files');
    final files = decoded['files'];
    final sourceHash = decoded['source_sha256'];
    if (files is! List ||
        files.isEmpty ||
        decoded['file_count'] != files.length ||
        sourceHash is! String ||
        !_hashPattern.hasMatch(sourceHash)) {
      throw StateError(
        'The UI source manifest needs a nonempty file/hash set.',
      );
    }
    final records = <({String path, String sha256})>[];
    final seen = <String>{};
    String? previous;
    for (final item in files) {
      if (item is! Map<String, dynamic>) {
        throw StateError('Invalid UI source manifest file record.');
      }
      final path = item['path'];
      final hash = item['sha256'];
      if (path is! String ||
          !_safePath(path) ||
          hash is! String ||
          !_hashPattern.hasMatch(hash)) {
        throw StateError('Invalid UI source manifest path or SHA-256.');
      }
      if (!seen.add(path)) {
        throw StateError('Duplicate UI source manifest path: $path');
      }
      if (previous != null && _comparePaths(previous, path) >= 0) {
        throw StateError(
          'UI source manifest paths must be canonically ordered.',
        );
      }
      if (!(configFiles.contains(path) || scope.any(path.startsWith)) ||
          !_permittedSource(path)) {
        throw StateError(
          'UI source manifest path is outside its safe scope: $path',
        );
      }
      records.add((path: path, sha256: hash));
      previous = path;
    }
    if (_aggregate(records) != sourceHash) {
      throw StateError(
        'UI source manifest aggregate does not match its files.',
      );
    }
    final summary = Map<String, dynamic>.from(decoded)
      ..remove('project_root')
      ..remove('config_files')
      ..remove('files');
    return UiSourceManifest._(root, summary, records);
  }

  /// Hashes the real files synchronously, avoiding native child-process startup.
  /// Initial reads require manifest equality. Final reads can return changed
  /// hashes so the existing capture provenance records the observed difference.
  Map<String, dynamic> fingerprint({bool requireManifestHashes = true}) {
    final actual = <({String path, String sha256})>[];
    for (final record in _records) {
      final file = File('$_root/${record.path}');
      if (!file.existsSync()) {
        throw StateError('UI source manifest file is missing: ${record.path}');
      }
      final resolved = file.resolveSymbolicLinksSync();
      if (!resolved.startsWith('$_root${Platform.pathSeparator}')) {
        throw StateError(
          'UI source symlink leaves the project root: ${record.path}',
        );
      }
      final hash = sha256.convert(File(resolved).readAsBytesSync()).toString();
      if (requireManifestHashes && hash != record.sha256) {
        throw StateError(
          'UI source changed after host binding: ${record.path}',
        );
      }
      actual.add((path: record.path, sha256: hash));
    }
    return {..._summary, 'source_sha256': _aggregate(actual)};
  }

  static List<String> _pathList(
    Object? value,
    String label, {
    bool directories = false,
  }) {
    if (value is! List || value.isEmpty) {
      throw StateError('The UI source manifest needs a nonempty $label.');
    }
    final paths = <String>[];
    for (final item in value) {
      if (item is! String ||
          (directories && !item.endsWith('/')) ||
          !_safePath(directories ? item.substring(0, item.length - 1) : item) ||
          paths.contains(item)) {
        throw StateError('Invalid UI source manifest $label.');
      }
      paths.add(item);
    }
    return paths;
  }

  static bool _safePath(String path) =>
      path.isNotEmpty &&
      !path.startsWith('/') &&
      !path.contains('\\') &&
      !path.contains('\u0000') &&
      !RegExp(r'^[A-Za-z]:').hasMatch(path) &&
      !path
          .split('/')
          .any((part) => part.isEmpty || part == '.' || part == '..');

  static bool _permittedSource(String path) {
    final parts = path.split('/');
    final name = parts.last.toLowerCase();
    final dot = name.lastIndexOf('.');
    final suffix = dot < 0 ? '' : name.substring(dot);
    return !parts.any(_excludedParts.contains) &&
        !name.startsWith('.env') &&
        !_secretNames.contains(name) &&
        !_secretSuffixes.contains(suffix) &&
        !name.contains('service-account') &&
        !name.contains('service_account') &&
        !name.contains('generatedpluginregistrant') &&
        !{'.md', '.log', '.pyc'}.contains(suffix);
  }

  static int _comparePaths(String left, String right) {
    final a = left.runes.toList();
    final b = right.runes.toList();
    for (var index = 0; index < a.length && index < b.length; index++) {
      final difference = a[index].compareTo(b[index]);
      if (difference != 0) return difference;
    }
    return a.length.compareTo(b.length);
  }

  static String _aggregate(List<({String path, String sha256})> records) =>
      sha256
          .convert(
            utf8.encode(
              records
                  .map((record) => '${record.path}\u0000${record.sha256}\n')
                  .join(),
            ),
          )
          .toString();
}
