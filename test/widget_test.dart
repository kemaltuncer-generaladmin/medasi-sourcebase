import 'package:cardstation_app/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows CardStation login flow entry', (tester) async {
    await tester.pumpWidget(const CardStationApp());

    expect(
      find.text('Tekrar etmeye kaldığın\nyerden devam et'),
      findsOneWidget,
    );
    expect(find.text('Giriş Yap'), findsOneWidget);
    expect(find.text('Kayıt Ol'), findsOneWidget);
    expect(find.text('Apple ile devam et'), findsNothing);
    expect(find.text('Google ile devam et'), findsNothing);
  });
}
