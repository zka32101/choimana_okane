# content/

choimana_core の `Lesson.toJson()` / `BoundaryRule.toJson()` / `GlossaryTerm.toJson()` 形式。
`tool/validate_content.dart` が `lessons/` `boundary_rules/` `glossary/` の3ディレクトリを検証する。

- `lessons/` — 3分レッスン（kind: basic/predict/boundary/...）
- `boundary_rules/` — 境界線スライダー（型①）の条件→結論表
- `glossary/` — 用語集。kinnyuの`GlossaryData`から、お金ジャンルの初期トラック
  （手取りと税金・社会保険）に関連する用語を優先して移植している。数値・施行日を
  持たないため `Calculator`/`BoundaryRule` と違って出典・鮮度チェックは必須にして
  いないが、断定・勧誘表現の禁止語チェックは行う。
