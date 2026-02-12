import 'package:flutter_test/flutter_test.dart';
import 'package:optidesk/main.dart'; // Asegúrate de que el nombre coincida

void main() {
  testWidgets('Carga inicial de OptiDesk', (WidgetTester tester) async {
    // Carga la app real
    await tester.pumpWidget(const OptiDeskApp());

    // Verifica que el título del Dashboard aparezca en pantalla
    expect(find.text('Hardware'), findsWidgets);
  });
}