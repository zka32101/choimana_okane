/// 配信前CIで実行する検証コマンド（choimana_core の検証ロジックを使う）。
/// `content/lessons/*.json` と `content/boundary_rules/*.json` を検証する。
library;

import 'dart:convert';
import 'dart:io';

import 'package:choimana_okane/choimana_okane.dart';

Future<void> main(List<String> args) async {
  final root = args.isNotEmpty ? args.first : 'content';
  final now = DateTime.now();

  final issues = <ValidationIssue>[];
  var checked = 0;

  checked += await _validateDir(
    Directory('$root/lessons'),
    (json) => validateLesson(Lesson.fromJson(json), now),
    issues,
  );
  checked += await _validateDir(
    Directory('$root/boundary_rules'),
    (json) => validateBoundaryRule(BoundaryRule.fromJson(json), now),
    issues,
  );

  for (final issue in issues) {
    stderr.writeln(issue.toString());
  }

  final errorCount = issues.where((i) => i.level == IssueLevel.error).length;
  final warnCount = issues.length - errorCount;
  stdout.writeln('検証対象: $checked件 / エラー: $errorCount件 / 警告: $warnCount件');

  if (errorCount > 0) exit(1);
}

Future<int> _validateDir(
  Directory dir,
  List<ValidationIssue> Function(Map<String, dynamic>) validate,
  List<ValidationIssue> issues,
) async {
  if (!dir.existsSync()) return 0;
  var count = 0;
  final files = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  for (final file in files) {
    count++;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) {
        issues.add(
          ValidationIssue(
            level: IssueLevel.error,
            contentId: file.path,
            message: 'JSONのトップレベルはオブジェクトである必要があります',
          ),
        );
        continue;
      }
      issues.addAll(validate(decoded));
    } on FormatException catch (e) {
      issues.add(
        ValidationIssue(level: IssueLevel.error, contentId: file.path, message: e.message),
      );
    }
  }
  return count;
}
