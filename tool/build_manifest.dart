/// `content/` 配下のファイルから配信用 manifest.json を生成する
/// （choimana_core の ManifestBuilder を使う。共通基盤設計 v0.5 §5・§9）。
///
/// 使い方: `dart run tool/build_manifest.dart [出力先ディレクトリ(既定: build/manifest)]`
///
/// 配信前に必ず `tool/validate_content.dart` を実行し、エラーがないことを
/// 確認してから使うこと（このスクリプト自体はコンテンツの正しさを検証しない）。
///
/// 署名鍵の本番運用は未決定（お金 企画設計書 v0.2 では配信サーバー側の鍵管理が
/// TODOのまま）。ここでは [_HmacDevSigner]（HMAC-SHA256）を暫定的な開発用
/// signer として使い、環境変数 `MANIFEST_SIGNING_KEY` が未設定の場合は
/// 固定の開発用キーにフォールバックして警告を出す。本番の鍵管理方式が決まったら
/// [ManifestSigner] の実装を差し替えるだけでよい。
library;

import 'dart:convert';
import 'dart:io';

import 'package:choimana_okane/choimana_okane.dart';
import 'package:crypto/crypto.dart';

const _devSigningKey = 'choimana-okane-dev-signing-key-DO-NOT-USE-IN-PRODUCTION';

class _HmacDevSigner implements ManifestSigner {
  _HmacDevSigner(this.key);

  final String key;

  @override
  String sign(Map<String, dynamic> signedPayload) {
    final bytes = utf8.encode(jsonEncode(signedPayload));
    final hmac = Hmac(sha256, utf8.encode(key));
    return hmac.convert(bytes).toString();
  }
}

Future<void> main(List<String> args) async {
  final outDir = args.isNotEmpty ? args.first : 'build/manifest';
  const contentRoot = 'content';
  const dirs = ['lessons', 'boundary_rules', 'glossary'];

  final signingKey = Platform.environment['MANIFEST_SIGNING_KEY'];
  if (signingKey == null) {
    stderr.writeln(
      '警告: 環境変数 MANIFEST_SIGNING_KEY が未設定のため、開発用の固定鍵で署名します。'
      '本番配信には使わないこと。',
    );
  }

  final files = <String, List<int>>{};
  for (final dirName in dirs) {
    final dir = Directory('$contentRoot/$dirName');
    if (!dir.existsSync()) continue;
    for (final entity in dir.listSync()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      final manifestPath = '$dirName/${entity.uri.pathSegments.last}';
      files[manifestPath] = await entity.readAsBytes();
    }
  }

  if (files.isEmpty) {
    stderr.writeln('content/ 配下に対象ファイルが見つかりませんでした。');
    exit(1);
  }

  final manifest = ManifestBuilder.build(
    files: files,
    minAppVersion: '0.1.0',
    signer: _HmacDevSigner(signingKey ?? _devSigningKey),
  );

  final outputDir = Directory(outDir);
  outputDir.createSync(recursive: true);
  final manifestFile = File('${outputDir.path}/manifest.json');
  manifestFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(manifest.toJson()),
  );

  for (final entry in files.entries) {
    final target = File('${outputDir.path}/${entry.key}');
    target.parent.createSync(recursive: true);
    target.writeAsBytesSync(entry.value);
  }

  stdout.writeln(
    'manifest.json を生成しました（${files.length}ファイル、出力先: ${outputDir.path}）',
  );
}
