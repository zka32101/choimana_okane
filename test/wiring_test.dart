// choimana_core への依存が正しく配線されていることを確認するスモークテスト。
// ここで使う数値はすべて架空（出典なし）。実際の税率・控除額は kinnyu の
// 既存計算の出典確認後に Parameter 表として追加する（お金 企画設計書 v0.2 §9）。
import 'package:choimana_okane/choimana_okane.dart';
import 'package:test/test.dart';

class _FakeCalculator extends Calculator {
  _FakeCalculator()
      : super(
          calcId: 'fake-smoke-test',
          title: '架空の計算（配線確認用）',
          parameters: [
            Parameter(
              paramId: 'fake-rate',
              value: 0.1,
              unit: '割合',
              basis: '架空の値（配線確認用。実データではない）',
              lawVersion: 'n/a',
              retrievedAt: DateTime(2026, 1, 1),
              expiresAt: DateTime(2099, 1, 1),
            ),
          ],
          sources: [
            Source(
              title: '配線確認用の架空出典',
              url: 'https://example.com',
              publisher: 'n/a',
              retrievedAt: DateTime(2026, 1, 1),
            ),
          ],
          reviewedAt: DateTime(2026, 1, 1),
        );

  @override
  CalculatorResult compute(Map<String, double> inputs) {
    return CalculatorResult(value: inputs['x']! * (1 - parameters.single.value));
  }
}

void main() {
  test('choimana_core の Calculator を継承できる', () {
    final calc = _FakeCalculator();
    expect(calc.compute({'x': 100}).value, closeTo(90, 0.001));
    expect(calc.compute({'x': 100}).note, '目安');
  });
}
