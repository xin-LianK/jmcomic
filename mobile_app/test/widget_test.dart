import 'package:flutter_test/flutter_test.dart';

import 'package:jm_visual/main.dart';

void main() {
  testWidgets('JM Visual app shell renders', (WidgetTester tester) async {
    await tester.pumpWidget(const JmVisualApp());

    expect(find.text('列表'), findsWidgets);
    expect(find.text('下载'), findsWidgets);
    expect(find.text('设置'), findsWidgets);
  });
}
