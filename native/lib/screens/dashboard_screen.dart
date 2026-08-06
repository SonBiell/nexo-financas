import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'categories_screen.dart';
import 'expenses_screen.dart';
import 'login_screen.dart';
import 'transactions_screen.dart';

const teal = Color(0xFF14B8A6);
const panel = Color(0xFF111C24);
const line = Color(0xFF243640);
const muted = Color(0xFF8FA6B2);

String money(dynamic cents) {
  final value = (cents as num? ?? 0).toInt();
  final absolute = value.abs();
  final units = absolute ~/ 100;
  final decimals = (absolute % 100).toString().padLeft(2, '0');
  final grouped = units
      .toString()
      .replaceAllMapped(RegExp(r'(?<=\d)(?=(\d{3})+$)'), (_) => '.');
  return '${value < 0 ? '-' : ''}R\$ $grouped,$decimals';
}

class DashboardScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const DashboardScreen({super.key, required this.user});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int selected = 0;
  Map<String, dynamic>? data;
  String? error;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }
    try {
      final value = await AuthService().dashboard();
      if (mounted) setState(() => data = value);
    } on AuthException catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> logout() async {
    await AuthService().logout();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child: FilledButton.icon(
                      onPressed: load,
                      icon: const Icon(Icons.refresh),
                      label: Text(error!)))
              : _DashboardHome(data: data!, user: widget.user, refresh: load),
      ExpensesScreen(onChanged: load),
      TransactionsScreen(onChanged: load),
      CategoriesScreen(onChanged: load),
    ];
    return Scaffold(
      body: LayoutBuilder(builder: (context, constraints) {
        const sidebarWidth = 240.0;
        return Stack(children: [
          Positioned.fill(
            left: sidebarWidth,
            child: ColoredBox(
              color: const Color(0xFF071015),
              child: SafeArea(
                child: ClipRect(
                  child: IndexedStack(
                    sizing: StackFit.expand,
                    index: selected,
                    children: pages,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: sidebarWidth,
            child: _Navigation(
              selected: selected,
              choose: (value) => setState(() => selected = value),
              logout: logout,
            ),
          ),
        ]);
      }),
    );
  }
}

class _Navigation extends StatelessWidget {
  final int selected;
  final ValueChanged<int> choose;
  final VoidCallback logout;
  const _Navigation(
      {required this.selected, required this.choose, required this.logout});
  @override
  Widget build(BuildContext context) => Container(
      width: double.infinity,
      decoration: const BoxDecoration(
          color: Color(0xFF0A1218),
          border: Border(right: BorderSide(color: line))),
      child: SafeArea(
          child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                const Row(children: [
                  FlutterLogo(size: 38),
                  SizedBox(width: 12),
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Nexo',
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w800)),
                        Text('FINANÃ‡AS',
                            style: TextStyle(
                                fontSize: 9, letterSpacing: 1.8, color: muted))
                      ])
                ]),
                const SizedBox(height: 38),
                ...[
                  (Icons.grid_view_rounded, 'Dashboard'),
                  (Icons.receipt_long_outlined, 'Despesas'),
                  (Icons.swap_horiz_rounded, 'TransaÃ§Ãµes'),
                  (Icons.category_outlined, 'Categorias')
                ].asMap().entries.map((entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: ListTile(
                        onTap: () => choose(entry.key),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        tileColor: selected == entry.key
                            ? teal.withValues(alpha: .16)
                            : null,
                        leading: Icon(entry.value.$1,
                            color: selected == entry.key
                                ? const Color(0xFF5EEAD4)
                                : muted),
                        title: Text(entry.value.$2,
                            style: TextStyle(
                                fontWeight: selected == entry.key
                                    ? FontWeight.w700
                                    : FontWeight.w500))))),
                const Spacer(),
                TextButton.icon(
                    onPressed: logout,
                    icon: const Icon(Icons.logout),
                    label: const Text('Sair da conta')),
              ]))));
}

class _DashboardHome extends StatelessWidget {
  final Map<String, dynamic> data, user;
  final Future<void> Function() refresh;
  const _DashboardHome(
      {required this.data, required this.user, required this.refresh});
  @override
  Widget build(BuildContext context) {
    final currentUser = data['user'] as Map<String, dynamic>? ?? user;
    final recent = data['recent_transactions'] as List<dynamic>? ?? const [];
    return RefreshIndicator(
        onRefresh: refresh,
        child: LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 36, vertical: 30),
                child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1320),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      const Text('VISÃƒO GERAL',
                                          style: TextStyle(
                                              color: Color(0xFF5EEAD4),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 1.5)),
                                      const SizedBox(height: 7),
                                      Text('OlÃ¡, ${currentUser['full_name']}',
                                          style: const TextStyle(
                                              fontSize: 30,
                                              fontWeight: FontWeight.w800)),
                                      const Text(
                                          'Seu dinheiro, organizado em um sÃ³ lugar.',
                                          style: TextStyle(color: muted))
                                    ])),
                                IconButton.filledTonal(
                                    onPressed: refresh,
                                    icon: const Icon(Icons.refresh))
                              ]),
                              const SizedBox(height: 28),
                              Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(28),
                                  decoration: BoxDecoration(
                                      gradient: const LinearGradient(colors: [
                                        Color(0xFF0F766E),
                                        Color(0xFF155E75)
                                      ]),
                                      borderRadius: BorderRadius.circular(22)),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text('SALDO DISPONÃVEL',
                                            style: TextStyle(
                                                color: Color(0xFFCCFBF1),
                                                letterSpacing: 1.3,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800)),
                                        const SizedBox(height: 8),
                                        Text(money(data['balance_cents']),
                                            style: const TextStyle(
                                                fontSize: 36,
                                                fontWeight: FontWeight.w900))
                                      ])),
                              const SizedBox(height: 16),
                              GridView.count(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  crossAxisCount: box.maxWidth > 850 ? 3 : 1,
                                  crossAxisSpacing: 14,
                                  mainAxisSpacing: 14,
                                  childAspectRatio:
                                      box.maxWidth > 850 ? 2.35 : 4,
                                  children: [
                                    _Metric(
                                        'Entradas do mÃªs',
                                        money(data['income_cents']),
                                        Icons.south_west,
                                        const Color(0xFF4ADE80)),
                                    _Metric(
                                        'SaÃ­das do mÃªs',
                                        money(data['expense_cents']),
                                        Icons.north_east,
                                        const Color(0xFFFB7185)),
                                    _Metric(
                                        'Despesas pendentes',
                                        '${data['pending_expenses'] ?? 0}',
                                        Icons.schedule,
                                        const Color(0xFFFBBF24)),
                                  ]),
                              const SizedBox(height: 16),
                              Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                      color: panel,
                                      border: Border.all(color: line),
                                      borderRadius: BorderRadius.circular(16)),
                                  child: Row(children: [
                                    Icon(
                                        (data['overdue_expenses'] ?? 0) > 0
                                            ? Icons.warning_amber_rounded
                                            : Icons.verified_outlined,
                                        color:
                                            (data['overdue_expenses'] ?? 0) > 0
                                                ? const Color(0xFFFB7185)
                                                : teal),
                                    const SizedBox(width: 14),
                                    Expanded(
                                        child: Text(
                                            (data['overdue_expenses'] ?? 0) ==
                                                        0 &&
                                                    (data['due_soon_expenses'] ??
                                                            0) ==
                                                        0
                                                ? 'Nenhuma conta urgente. Sua agenda estÃ¡ em dia.'
                                                : '${data['overdue_expenses']} atrasada(s) e ${data['due_soon_expenses']} prÃ³xima(s) do vencimento.',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w700)))
                                  ])),
                              const SizedBox(height: 16),
                              Container(
                                  padding: const EdgeInsets.all(22),
                                  decoration: BoxDecoration(
                                      color: panel,
                                      border: Border.all(color: line),
                                      borderRadius: BorderRadius.circular(16)),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text('Ãšltimas transaÃ§Ãµes',
                                            style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w800)),
                                        const SizedBox(height: 12),
                                        if (recent.isEmpty)
                                          const Padding(
                                              padding: EdgeInsets.all(24),
                                              child: Center(
                                                  child: Text(
                                                      'Nenhuma movimentaÃ§Ã£o registrada.',
                                                      style: TextStyle(
                                                          color: muted))))
                                        else
                                          ...recent.map((raw) {
                                            final item =
                                                raw as Map<String, dynamic>;
                                            final income =
                                                item['type'] == 'income';
                                            return ListTile(
                                                contentPadding: EdgeInsets.zero,
                                                leading: CircleAvatar(
                                                    backgroundColor: (income ? const Color(0xFF4ADE80) : const Color(0xFFFB7185))
                                                        .withValues(alpha: .14),
                                                    child: Icon(income ? Icons.south_west : Icons.north_east,
                                                        color: income
                                                            ? const Color(
                                                                0xFF4ADE80)
                                                            : const Color(
                                                                0xFFFB7185))),
                                                title: Text(
                                                    '${item['description']}'),
                                                subtitle: Text(
                                                    '${item['category_name']} â€¢ ${item['occurred_on']}',
                                                    style: const TextStyle(
                                                        color: muted)),
                                                trailing: Text(
                                                    '${income ? '+' : '-'} ${money(item['amount_cents'])}',
                                                    style: TextStyle(
                                                        color: income
                                                            ? const Color(0xFF4ADE80)
                                                            : const Color(0xFFFB7185),
                                                        fontWeight: FontWeight.w800)));
                                          })
                                      ])),
                            ]))))));
  }
}

class _Metric extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Color color;
  const _Metric(this.title, this.value, this.icon, this.color);
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: panel,
          border: Border.all(color: line),
          borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Icon(icon, color: color),
        const SizedBox(width: 14),
        Expanded(
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(title, style: const TextStyle(color: muted, fontSize: 12)),
              const SizedBox(height: 5),
              Text(value,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800),
                  overflow: TextOverflow.ellipsis)
            ]))
      ]));
}
