# choimana_okane

ちょいまな お金。資格以外の大人の学び（お金ジャンル）。毎日3分で手取り・税金・年金・詐欺の見分け方を学ぶ。

## 位置づけ

```
choimana_okane（このリポジトリ）
 → choimana_core（共通基盤: Lesson・Track・Freshness・BoundaryRule・Calculator・DeliveryClient）
 → yourwish_learn（学習の共通部分。未切り出し）
 → app_common_kit（フィードバック・権利・広告ゲート・テーマ・UI・推し・コイン）
```

既存アプリ `kinnyu`（アプリ名「金融・家計学校」）は廃止し、本リポジトリを新規に立てる方針（2026-10-07決定）。

## v0.1の状態

- `choimana_core` への依存を commit 固定で配線済み（スモークテストで確認）
- `TakeHomePayCalculator` を kinnyu から移植（下記カタログ参照）。**定数は出典未確認**のため、
  `Parameter.expiresAt` を意図的に過去日付にしてあり、`parametersValidAt()` が常に false を返す
  （実データとして配信できない状態を機械的に強制している）
- CI骨子（`dart analyze`/`test` → 出典・鮮度・禁止語チェック → gitleaks）を choimana_core と同じ構成で用意
- `tool/build_manifest.dart` — `content/` 配下を choimana_core の `ManifestBuilder` に渡し、
  配信用 `manifest.json` を生成する（`dart run tool/build_manifest.dart [出力先]`）。
  署名鍵の本番運用はまだ未決定のため、暫定的に HMAC-SHA256 の開発用鍵（環境変数
  `MANIFEST_SIGNING_KEY` 未設定時は固定の開発用キー）で署名している。本番の鍵管理方式が
  決まったら `ManifestSigner` の実装を差し替えるだけでよい設計にしてある。
  `test/build_manifest_integration_test.dart` で、生成した manifest を `DeliveryClient` が
  実際に検証・保存できることを確認済み

## kinnyu 計算ロジックの移植カタログ（12本）

kinnyu（`lib/features/simulation/domain/models/`）を調査した結果。「年度依存」は定数が
年度ごとの制度（税率・保険料率等）に基づき、2026年度での再確認が必須なもの。

| # | 元ファイル | 状態 | 年度依存 | 備考 |
|---|---|---|---|---|
| 1 | `take_home_pay_calculator.dart` | **移植済み**（`lib/calculators/take_home_pay_calculator.dart`） | あり | 社会保険料率（健康・介護・厚生年金・雇用保険）と標準報酬月額の上限は**2026-10-13に令和8年度の実データで出典確認済み**（2027-04まで配信可）。所得税/住民税の基礎控除・扶養控除は令和8年度税制改正で段階制に変わり未反映のため、依然期限切れ（配信不可） |
| 2 | `furusato_nozei_calculator.dart` | **移植済み**（`lib/calculators/furusato_nozei_calculator.dart`） | 自身の定数はなし／`TakeHomePayCalculator`に依存 | 総務省の近似式。依存先の定数が出典未確認の間は配信不可（`isDeliverableAt`で連動） |
| 3 | `compound_simulator.dart` | **移植済み**（`lib/calculators/compound_calculator.dart`） | なし | 純粋な複利計算。年度依存の定数がないため即配信可能（`Parameter`が空）。ランダム変動版（`simulateRandom`）は未移植 |
| 4 | `nisa_ideco_calculator.dart` | **移植済み**（`lib/calculators/nisa_calculator.dart`・`lib/calculators/ideco_calculator.dart`） | あり | NISA枠（年120万/240万、生涯1,800万）・iDeCo月額上限（加入区分別）とも出典未確認で意図的に配信不可。**投資の基礎（NISA/iDeCo）はMVPから除外する方針**（企画設計書 v0.2 §3-1）のため、コードは用意するがLesson化・UI公開はしない。年次複利版（`CompoundGrowthSimulator`）は`CompoundCalculator`と機能が重なるため移植せず |
| 5 | `pension_estimator.dart` | **一部移植済み**（`lib/calculators/pension_estimator_calculator.dart`） | あり | 年金額（基礎・厚生）のみ移植。**退職金の概算部分は移植していない**（企業規模別係数2.0/1.5/1.0が公的出典のない独自の仮定値だったため） |
| 6 | `loan_repayment_simulator.dart` | **移植済み**（`lib/calculators/loan_repayment_calculator.dart`） | なし | 元利均等・元金均等の2方式。金利計算のみで年度依存の定数なし |
| 7 | `rent_vs_buy_calculator.dart` | **移植済み**（`lib/calculators/rent_vs_buy_calculator.dart`） | なし | 住宅購入vs賃貸の比較。`LoanRepaymentCalculator`に依存。MVPから除外候補（既存アプリ共通基盤化候補 v0.1 §9-2） |
| 8 | `education_cost_planner.dart` | **移植済み**（`lib/calculators/education_cost_calculator.dart`） | あり（出典不明確） | 段階別・進路別の教育費テーブルがkinnyu側で「文科省調査等を参考」とコメントのみで具体的出典なし。意図的に期限切れにして配信不可。MVPから除外候補 |
| 9 | `emergency_fund_planner.dart` | **移植済み**（`lib/calculators/emergency_fund_calculator.dart`） | なし | 生活防衛資金の目標額。カバー月数はユーザー入力で制度定数なし。MVPから除外候補 |
| 10 | `insurance_coverage_calculator.dart` | **移植済み**（`lib/calculators/insurance_coverage_calculator.dart`） | なし | 必要な保険金額の目安。全て入力値ベース。MVPから除外候補 |
| 11 | `household_simulator.dart` | 移植しない（決定） | - | 世帯機能は切り離し対象（個人情報なし・比較なしの方針と衝突） |
| 12 | `investment_simulation_pattern.dart` | 移植しない（MVPでは） | - | 投資基礎はMVP除外。仮想運用の扱いは要確認 |

計算12本のうち11本を調査・移植済み（household のみ移植しない決定）。
年度依存なしの7本（compound・loan_repayment・rent_vs_buy・
emergency_fund・insurance_coverage ほか）は**即配信可能**。年度依存あり
の6本中、pension_estimator・education_cost・nisa は出典確認済みで
配信可能になった。ideco は2026年11月まで配信可能（12月の制度改正で停止）。
take_home_pay・furusato_nozei は基礎控除以外の一部定数（扶養控除・
住民税均等割の区分別金額）がまだ未検証のため配信不可のまま
（nisa・idecoはMVP除外方針もあり、出典確認済みでもLesson化・UI公開はしない）。

## 次の作業（お金 企画設計書 v0.2 §9-3より）

1. **出典未確認の定数を実際の出典で確認する**
   - [x] `TakeHomePayCalculator` の社会保険料率4種・標準報酬月額の上限（2026-10-13確認済み）
   - [x] 所得税の基礎控除を令和8年度税制改正の段階制（本則62万+合計所得489万円以下は加算42万=最大104万、
     655万円以下は67万、2,350万円以下は62万、以降段階的に減少し2,500万超で0円）に合わせて
     `_basicDeductionIncomeTax` 速算表関数として再実装（国税庁資料で確認済み）。住民税の基礎控除（43万円・
     変更なし）と所得割の標準税率（10%）も検証済みにした
   - [ ] 扶養控除（所得税・住民税とも「1人あたり概算」の簡略化。実際は一般/特定/老人/同居老親等で
     金額が異なり、特定親族特別控除の新設も未反映）・住民税均等割（自治体により変動）は依然未検証。
     完了すれば `FurusatoNozeiCalculator` も連動して配信可能になる
   - [x] `PensionEstimatorCalculator` — 基礎年金満額（令和8年度847,296円）・報酬比例の乗率
     （5.481/1000）・繰上げ繰下げ率を日本年金機構の公表資料で確認済み（2027-04まで配信可）
   - [x] `EducationCostCalculator` — 幼稚園〜高校は文部科学省「令和5年度子供の学習費調査」の
     年間学習費総額×年数、大学は同調査を基にした二次情報で確認済み（調査が概ね2年おきのため
     2028年頃の次回調査まで配信可）
   - [x] `NisaCalculator` — つみたて/成長投資枠・生涯投資枠は2026年度も変更なしと確認済み
     （2027年1月の18歳未満向け枠新設を節目に再確認が必要）
   - [x] `IdecoCalculator` — 2026年11月までの値として確認済み。**2026年12月1日に拠出限度額の
     制度改正が施行される**（第1号6.8万→7.5万円等）ため、改正後の計算式（企業年金の有無・額に
     応じた計算が必要）への再実装がさらに必要（MVP除外方針のため優先度低）
2. Question／用語／制度のデータを JSON に分離（出典・lawVersion付き）
   - [x] 用語集: choimana_core に `GlossaryTerm`/`validateGlossaryTerm` を追加し、kinnyu の
     `GlossaryData` から手取り・税トラックに関連する9語を `content/glossary/*.json` に移植
     （数値・施行日を持たないため出典・鮮度は必須にしていないが、禁止語チェックは行う）
   - [x] `LessonCard.termRefs` でレッスンの要点カードから用語集にリンク（take-home-pay-001・
     furusato-nozei-001/002に適用済み）。`tool/validate_content.dart` が
     `validateCrossReferences`（choimana_core 22509b0）で `ruleId`/`calcId`/`termRefs` の
     参照整合性を検証する（存在しないIDへの参照は配信前CIで検出される）
   - [ ] 残りの用語（投資・保険カテゴリ）はMVP対象トラックができてから移植する
3. 3分レッスン化（MVP 30レッスン、3トラック：手取りと税金・社会保険／家計とライフイベント／お金のトラブル・詐欺）
   - `content/lessons/take-home-pay-001.json`（`kind: predict`、`calcId: take-home-pay`）
   - `content/lessons/furusato-nozei-001.json`（`kind: predict`、`calcId: furusato-nozei`）
   - `content/lessons/furusato-nozei-002.json`（`kind: boundary`、`ruleId: furusato-nozei-one-stop`）
   - `content/boundary_rules/furusato-nozei-one-stop.json` — 型①（境界線スライダー）の最初の実例。
     「寄付先が5自治体以内か」「もともと確定申告が必要な人か」の2条件からワンストップ特例の
     対象かどうかを判定する。`test/boundary_rule_content_test.dart` で組み合わせごとの結論を確認済み
   - `test/daily_pick_wiring_test.dart` で DailyPickSelector・Lesson・Calculator の結合を確認し、
     **既知のギャップ**を明示した: `DailyPickSelector`/`Lesson.isDeliverableAt` はレッスンの鮮度しか見ないため、
     `kind: predict` のレッスンを実際に表示するアプリ側は `lesson.calcId` で参照する Calculator の
     `isFullyDeliverableAt()`（choimana_core 0781435 以降）も別途チェックする必要がある

## 注意: kinnyu リポジトリの公開リスク（既知・未対応）

kinnyu の `CLAUDE.md` に、iOS証明書保管庫のリポジトリ名・GitHub Secrets名・Android keystore
生成手順などの運用情報がそのまま残っている（ちょいまな お金 既存アプリ共通基盤化候補 v0.1 §6-1
で指摘済み）。本リポジトリ（choimana_okane）には影響しないが、kinnyu 側の整理はまだ実施されていない。

## 開発

```
dart pub get
dart analyze
dart test
```
