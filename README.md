# choimana_okane

ちょいまな お金。資格以外の大人の学び（お金ジャンル）。毎日3分で手取り・税金・年金・詐欺の見分け方を学ぶ。

## 位置づけ

```
choimana_okane（このリポジトリ）
 → choimana_kit（共通基盤: Lesson・Track・Freshness・BoundaryRule・Calculator・DeliveryClient）
 → yourwish_learn（学習の共通部分。未切り出し）
 → app_common_kit（フィードバック・権利・広告ゲート・テーマ・UI・推し・コイン）
```

既存アプリ `kinnyu`（アプリ名「金融・家計学校」）は廃止し、本リポジトリを新規に立てる方針（2026-10-07決定）。

## v0.1の状態

- `choimana_kit` への依存を commit 固定で配線済み（スモークテストで確認）
- `TakeHomePayCalculator` を kinnyu から移植（下記カタログ参照）。**定数は出典未確認**のため、
  `Parameter.expiresAt` を意図的に過去日付にしてあり、`parametersValidAt()` が常に false を返す
  （実データとして配信できない状態を機械的に強制している）
- CI骨子（`dart analyze`/`test` → 出典・鮮度・禁止語チェック → gitleaks）を choimana_kit と同じ構成で用意

## kinnyu 計算ロジックの移植カタログ（12本）

kinnyu（`lib/features/simulation/domain/models/`）を調査した結果。「年度依存」は定数が
年度ごとの制度（税率・保険料率等）に基づき、2026年度での再確認が必須なもの。

| # | 元ファイル | 状態 | 年度依存 | 備考 |
|---|---|---|---|---|
| 1 | `take_home_pay_calculator.dart` | **移植済み**（`lib/calculators/take_home_pay_calculator.dart`） | あり | 定数は意図的に期限切れにして配信不可にしている |
| 2 | `furusato_nozei_calculator.dart` | **移植済み**（`lib/calculators/furusato_nozei_calculator.dart`） | 自身の定数はなし／`TakeHomePayCalculator`に依存 | 総務省の近似式。依存先の定数が出典未確認の間は配信不可（`isDeliverableAt`で連動） |
| 3 | `compound_simulator.dart` | **移植済み**（`lib/calculators/compound_calculator.dart`） | なし | 純粋な複利計算。年度依存の定数がないため即配信可能（`Parameter`が空）。ランダム変動版（`simulateRandom`）は未移植 |
| 4 | `nisa_ideco_calculator.dart` | 未移植 | あり | NISA枠（年120万/240万、生涯1,800万）は制度変更時に要更新。投資の基礎はMVPから除外中のため優先度低 |
| 5 | `pension_estimator.dart` | 未移植 | あり | 満額816,000円（2024年度）等。日本年金機構で再確認が必要 |
| 6 | `loan_repayment_simulator.dart` | **移植済み**（`lib/calculators/loan_repayment_calculator.dart`） | なし | 元利均等・元金均等の2方式。金利計算のみで年度依存の定数なし |
| 7 | `rent_vs_buy_calculator.dart` | 未移植 | 未調査 | MVPから除外候補（既存アプリ共通基盤化候補 v0.1 §9-2） |
| 8 | `education_cost_planner.dart` | 未移植 | 未調査 | MVPから除外候補 |
| 9 | `emergency_fund_planner.dart` | 未移植 | 未調査 | MVPから除外候補 |
| 10 | `insurance_coverage_calculator.dart` | 未移植 | 未調査 | MVPから除外候補 |
| 11 | `household_simulator.dart` | 移植しない（決定） | - | 世帯機能は切り離し対象（個人情報なし・比較なしの方針と衝突） |
| 12 | `investment_simulation_pattern.dart` | 移植しない（MVPでは） | - | 投資基礎はMVP除外。仮想運用の扱いは要確認 |

## 次の作業（お金 企画設計書 v0.2 §9-3より）

1. **`TakeHomePayCalculator` の定数を実際の出典で確認**（国税庁 所得税速算表・協会けんぽ東京都の料率を2026年度で再確認）し、`Parameter` の `retrievedAt`/`expiresAt` を更新する。確認できれば `FurusatoNozeiCalculator` も連動して配信可能になる
2. Question／用語／制度のデータを JSON に分離（出典・lawVersion付き）
3. 3分レッスン化（MVP 30レッスン、3トラック：手取りと税金・社会保険／家計とライフイベント／お金のトラブル・詐欺）

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
