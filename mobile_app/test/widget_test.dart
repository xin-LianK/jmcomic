import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jm_visual/main.dart';

void main() {
  testWidgets('JM Visual app shell renders', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const JmVisualApp());
    await tester.pumpAndSettle();

    expect(find.text('列表'), findsWidgets);
    expect(find.text('书架'), findsWidgets);
    expect(find.text('下载'), findsWidgets);
    expect(find.text('设置'), findsWidgets);
  });
}
