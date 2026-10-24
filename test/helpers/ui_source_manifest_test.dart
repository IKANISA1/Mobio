import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_source_manifest.dart';

void main() {
  late Directory directory;
  late Directory root;
  late File manifest;
  late Map<String, dynamic> document;

  void save() => manifest.writeAsStringSync(jsonEncode(document));

  void bind(List<String> paths) {
    final records = paths
        .map(
          (path) => {
            'path': path,
            'sha256': sha256
                .convert(File('${root.path}/$path').readAsBytesSync())
                .toString(),
          },
        )
        .toList();
    document['files'] = records;
    document['file_count'] = records.length;
    document['source_sha256'] = sha256
        .convert(
          utf8.encode(
            records
                .map((record) => '${record['path']}\u0000${record['sha256']}\n')
                .join(),
          ),
        )
        .toString();
    save();
  }

  setUp(() {
    directory = Directory.systemTemp.createTempSync('mobio-ui-manifest-test-');
    root = Directory('${directory.path}/project')..createSync();
    Directory('${root.path}/lib').createSync();
    File('${root.path}/lib/main.dart').writeAsStringSync('bound UI');
    File('${root.path}/pubspec.yaml').writeAsStringSync('bound configuration');
    manifest = File('${directory.path}/manifest.json');
    document = {
      'schema_version': 1,
      'product': 'Mobio',
      'acceptance_effect': 'none',
      'project_root': root.resolveSymbolicLinksSync(),
      'scope': ['lib/'],
      'config_files': ['pubspec.yaml'],
      'selection': 'tracked and nonignored untracked UI sources',
    };
    bind(['lib/main.dart', 'pubspec.yaml']);
  });

  tearDown(() => directory.deleteSync(recursive: true));

  test('uses real file hashes with the canonical NUL/newline aggregate', () {
    final source = UiSourceManifest.load(manifest.path, projectRoot: root);
    final snapshot = source.fingerprint();
    expect(snapshot['source_sha256'], document['source_sha256']);
    expect(snapshot['file_count'], 2);
    expect(snapshot.containsKey('files'), isFalse);
  });

  test('missing environment binding has an actionable wrapper instruction', () {
    expect(
      () =>
          UiSourceManifest.fromEnvironment(environment: {}, projectRoot: root),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('run_flutter_tests.py'),
        ),
      ),
    );
  });

  test('rejects a relative manifest and a manifest for another root', () {
    expect(
      () => UiSourceManifest.load('manifest.json', projectRoot: root),
      throwsStateError,
    );
    document['project_root'] = directory.path;
    save();
    expect(
      () => UiSourceManifest.load(manifest.path, projectRoot: root),
      throwsStateError,
    );
  });

  test('rejects malformed JSON and an empty declared scope', () {
    manifest.writeAsStringSync('{');
    expect(
      () => UiSourceManifest.load(manifest.path, projectRoot: root),
      throwsStateError,
    );
    document['scope'] = [];
    save();
    expect(
      () => UiSourceManifest.load(manifest.path, projectRoot: root),
      throwsStateError,
    );
  });

  test('rejects an empty file set and incorrect aggregate', () {
    document['files'] = [];
    document['file_count'] = 0;
    save();
    expect(
      () => UiSourceManifest.load(manifest.path, projectRoot: root),
      throwsStateError,
    );
    bind(['lib/main.dart', 'pubspec.yaml']);
    document['source_sha256'] = '0' * 64;
    save();
    expect(
      () => UiSourceManifest.load(manifest.path, projectRoot: root),
      throwsStateError,
    );
  });

  test('rejects duplicate and noncanonical file order', () {
    bind(['lib/main.dart', 'lib/main.dart']);
    expect(
      () => UiSourceManifest.load(manifest.path, projectRoot: root),
      throwsStateError,
    );
    bind(['pubspec.yaml', 'lib/main.dart']);
    expect(
      () => UiSourceManifest.load(manifest.path, projectRoot: root),
      throwsStateError,
    );
  });

  test('rejects traversal, absolute paths, out-of-scope and private paths', () {
    final original = List<Map<String, String>>.from(document['files'] as List);
    for (final path in [
      'lib/../pubspec.yaml',
      '/lib/main.dart',
      'other/main.dart',
      'lib/.env',
    ]) {
      document['files'] = [
        {...original.first, 'path': path},
        original.last,
      ];
      save();
      expect(
        () => UiSourceManifest.load(manifest.path, projectRoot: root),
        throwsStateError,
        reason: path,
      );
    }
  });

  test('rejects missing source files', () {
    final source = UiSourceManifest.load(manifest.path, projectRoot: root);
    File('${root.path}/lib/main.dart').deleteSync();
    expect(source.fingerprint, throwsStateError);
  });

  test('rejects source symlinks that escape the bound root', () {
    final source = UiSourceManifest.load(manifest.path, projectRoot: root);
    final file = File('${root.path}/lib/main.dart')..deleteSync();
    final external = File('${directory.path}/outside.dart')
      ..writeAsStringSync('bound UI');
    Link(file.path).createSync(external.path);
    expect(source.fingerprint, throwsStateError);
  });

  test('allows internal symlinks while hashing their actual target', () {
    File('${root.path}/lib/internal.dart').writeAsStringSync('internal UI');
    Link(
      '${root.path}/lib/link.dart',
    ).createSync('${root.path}/lib/internal.dart');
    bind([
      'lib/internal.dart',
      'lib/link.dart',
      'lib/main.dart',
      'pubspec.yaml',
    ]);
    expect(
      UiSourceManifest.load(
        manifest.path,
        projectRoot: root,
      ).fingerprint()['file_count'],
      4,
    );
  });

  test(
    'initial stale files fail and final changed fingerprints remain observable',
    () {
      final source = UiSourceManifest.load(manifest.path, projectRoot: root);
      final before = source.fingerprint();
      File('${root.path}/lib/main.dart').writeAsStringSync('changed UI');
      expect(source.fingerprint, throwsStateError);
      final after = source.fingerprint(requireManifestHashes: false);
      expect(after['source_sha256'], isNot(before['source_sha256']));
    },
  );
}
