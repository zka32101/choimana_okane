import 'dart:convert';
import 'dart:io';

import 'package:choimana_okane/choimana_okane.dart';
import 'package:crypto/crypto.dart';
import 'package:test/test.dart';

class _FakeHmacSigner implements ManifestSigner {
  _FakeHmacSigner(this.key);
  final String key;

  @override
  String sign(Map<String, dynamic> signedPayload) {
    final bytes = utf8.encode(jsonEncode(signedPayload));
    return Hmac(sha256, utf8.encode(key)).convert(bytes).toString();
  }
}

class _HmacVerifier implements ManifestSignatureVerifier {
  _HmacVerifier(this.key);
  final String key;

  @override
  bool verify(Map<String, dynamic> signedPayload, String signature) {
    final bytes = utf8.encode(jsonEncode(signedPayload));
    final expected = Hmac(sha256, utf8.encode(key)).convert(bytes).toString();
    return expected == signature;
  }
}

class _OneShotTransport implements DeliveryTransport {
  _OneShotTransport(this.manifestBytes, this.files);
  final List<int> manifestBytes;
  final Map<String, List<int>> files;

  @override
  Future<ManifestFetchResult> fetchManifest({String? ifNoneMatchEtag}) async =>
      ManifestFetchResult(bodyBytes: manifestBytes, etag: 'e1');

  @override
  Future<List<int>> fetchFile(String path) async => files[path]!;
}

class _InMemoryStore implements DeliveryStore {
  Manifest? manifest;
  String? etag;
  final Map<String, List<int>> saved = {};

  @override
  Future<Manifest?> loadManifest() async => manifest;
  @override
  Future<String?> loadEtag() async => etag;
  @override
  Future<void> save(Manifest m, String? e, Map<String, List<int>> files) async {
    manifest = m;
    etag = e;
    saved.addAll(files);
  }

  @override
  Future<List<int>?> loadFile(String path) async => saved[path];
}

/// content/ の実データ → ManifestBuilder（choimana_core）で生成した manifest →
/// DeliveryClient（同署名方式で検証）という配信パイプライン全体が通ることを
/// 確認する結合テスト。tool/build_manifest.dart のロジックと同じ流れを
/// テスト内で再現する。
void main() {
  test('content/のファイルからManifestを作り、DeliveryClientが検証・保存できる', () async {
    const dirs = ['lessons', 'boundary_rules', 'glossary'];
    final files = <String, List<int>>{};
    for (final dirName in dirs) {
      final dir = Directory('content/$dirName');
      if (!dir.existsSync()) continue;
      for (final entity in dir.listSync()) {
        if (entity is! File || !entity.path.endsWith('.json')) continue;
        files['$dirName/${entity.uri.pathSegments.last}'] = await entity.readAsBytes();
      }
    }
    expect(files, isNotEmpty);

    const key = 'test-signing-key';
    final manifest = ManifestBuilder.build(
      files: files,
      minAppVersion: '0.1.0',
      signer: _FakeHmacSigner(key),
      generatedAt: DateTime(2026, 10, 13),
    );

    final transport = _OneShotTransport(
      utf8.encode(jsonEncode(manifest.toJson())),
      files,
    );
    final store = _InMemoryStore();
    final client = DeliveryClient(
      transport: transport,
      verifier: _HmacVerifier(key),
      store: store,
    );

    final result = await client.sync();

    expect(result, isNotNull);
    expect(store.saved.length, files.length);
    for (final entry in files.entries) {
      expect(store.saved[entry.key], entry.value);
    }
  });
}
