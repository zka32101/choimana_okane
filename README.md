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
- 固有コンテンツ・計算ロジック（手取り・ふるさと納税・NISA等）は**まだ実装していない**。
  kinnyu の既存計算は定数が出典・施行日なしでコードに直書きされているため、
  Rule/Parameter 表に出典・施行日をつけてから移植する（お金 企画設計書 v0.2 §9）
- CI骨子（`dart analyze`/`test` → 出典・鮮度・禁止語チェック → gitleaks）を choimana_kit と同じ構成で用意

## 次の作業（お金 企画設計書 v0.2 §9-3より）

1. 制度の数値・条件の出典一覧を確定（国税庁・日本年金機構・厚労省等）
2. kinnyu の計算12本にテストを追加し、定数を Parameter 表に出す
3. Question／用語／制度のデータを JSON に分離（出典・lawVersion付き）
4. 3分レッスン化（MVP 30レッスン、3トラック：手取りと税金・社会保険／家計とライフイベント／お金のトラブル・詐欺）

## 開発

```
dart pub get
dart analyze
dart test
```
