# content/

choimana_core の `Lesson.toJson()` / `BoundaryRule.toJson()` / `GlossaryTerm.toJson()` /
`Track.toJson()` 形式。`tool/validate_content.dart` が `lessons/` `boundary_rules/`
`glossary/` `tracks/` の4ディレクトリを検証する。

- `lessons/` — 3分レッスン（kind: basic/predict/boundary/...）
- `boundary_rules/` — 境界線スライダー（型①）の条件→結論表
- `glossary/` — 用語集。kinnyuの`GlossaryData`から、お金ジャンルの初期トラック
  （手取りと税金・社会保険）に関連する用語を優先して移植している。数値・施行日を
  持たないため `Calculator`/`BoundaryRule` と違って出典・鮮度チェックは必須にして
  いないが、断定・勧誘表現の禁止語チェックは行う。
- `tracks/` — ジャンル内の学習の道筋（`Track.lessonIds` の順序で `DailyPickSelector`
  がレッスンを選ぶ）。`validateCrossReferences` が各 `lessonIds` の参照整合性と
  `trackId` の重複を検証する（choimana_core c812c68/6b28c3a で追加）。
