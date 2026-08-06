import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:nexo_financas/main.dart';
import 'package:nexo_financas/screens/dashboard_screen.dart';

void main() {
  testWidgets('exibe a tela de login do Nexo', (tester) async {
    await tester.pumpWidget(const NexoApp());

    expect(find.text('Acesse sua carteira'), findsOneWidget);
    expect(find.text('Entrar com seguranÃ§a'), findsOneWidget);
    expect(find.text('Criar uma nova conta'), findsOneWidget);
  });

  testWidgets('dashboard renderiza menu, saldo e resumo financeiro',
      (tester) async {
    const user = <String, dynamic>{
      'id': 7,
      'full_name': 'Brian Gabriel da Silva',
      'username': 'bgabriell',
    };
    const dashboard = <String, dynamic>{
      'user': user,
      'balance_cents': 125050,
      'income_cents': 150000,
      'expense_cents': 24950,
      'pending_expenses': 2,
      'overdue_expenses': 1,
      'due_soon_expenses': 1,
      'recent_transactions': <dynamic>[],
    };

    await tester.pumpWidget(const MaterialApp(
      home: DashboardScreen(user: user, initialData: dashboard),
    ));
    await tester.pump();

    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('OlÃ¡, Brian Gabriel da Silva'), findsOneWidget);
    expect(find.text(r'R$ 1.250,50'), findsOneWidget);
    expect(find.text('Entradas do mÃªs'), findsOneWidget);
    expect(find.text('Ãšltimas transaÃ§Ãµes'), findsOneWidget);
  });
}
