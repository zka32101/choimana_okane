/// 配信前CIで実行する検証コマンド（choimana_core の検証ロジックを使う）。
/// `content/lessons/*.json`・`content/boundary_rules/*.json`・
/// `content/glossary/*.json`・`content/tracks/*.json` を検証する。
library;

import 'dart:convert';
import 'dart:io';

import 'package:choimana_okane/choimana_okane.dart';

/// このアプリ（choimana_okane）が実装している Calculator の calcId 一覧。
/// Lesson.calcId がこれ以外を指していたら validateCrossReferences がエラーにする。
const _knownCalcIds = {
  'take-home-pay',
  'furusato-nozei',
  'compound',
  'loan-repayment',
  'rent-vs-buy',
  'pension-estimator',
  'education-cost',
  'emergency-fund',
  'insurance-coverage',
  'nisa',
  'ideco',
};

Future<void> main(List<String> args) async {
  final root = args.isNotEmpty ? args.first : 'content';
  final now = DateTime.now();

  final issues = <ValidationIssue>[];

  final lessons = await _loadAll(Directory('$root/lessons'), Lesson.fromJson, issues);
  final boundaryRules =
      await _loadAll(Directory('$root/boundary_rules'), BoundaryRule.fromJson, issues);
  final glossaryTerms =
      await _loadAll(Directory('$root/glossary'), GlossaryTerm.fromJson, issues);
  final tracks = await _loadAll(Directory('$root/tracks'), Track.fromJson, issues);

  for (final lesson in lessons) {
    issues.addAll(validateLesson(lesson, now));
  }
  for (final rule in boundaryRules) {
    issues.addAll(validateBoundaryRule(rule, now));
  }
  for (final term in glossaryTerms) {
    issues.addAll(validateGlossaryTerm(term));
  }
  issues.addAll(
    validateCrossReferences(
      lessons: lessons,
      boundaryRules: boundaryRules,
      glossaryTerms: glossaryTerms,
      knownCalcIds: _knownCalcIds,
      tracks: tracks,
    ),
  );

  for (final issue in issues) {
    stderr.writeln(issue.toString());
  }

  final checked = lessons.length + boundaryRules.length + glossaryTerms.length + tracks.length;
  final errorCount = issues.where((i) => i.level == IssueLevel.error).length;
  final warnCount = issues.length - errorCount;
  stdout.writeln('検証対象: $checked件 / エラー: $errorCount件 / 警告: $warnCount件');

  if (errorCount > 0) exit(1);
}

/// [dir] 内の `*.json` を読み込み [parse] でモデルに変換する。パース失敗は
/// [issues] にエラーとして積み、該当ファイルはスキップする。
Future<List<T>> _loadAll<T>(
  Directory dir,
  T Function(Map<String, dynamic>) parse,
  List<ValidationIssue> issues,
) async {
  if (!dir.existsSync()) return [];
  final results = <T>[];
  final files = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  for (final file in files) {
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
      results.add(parse(decoded));
    } on FormatException catch (e) {
      issues.add(
        ValidationIssue(level: IssueLevel.error, contentId: file.path, message: e.message),
      );
    }
  }
  return results;
}
