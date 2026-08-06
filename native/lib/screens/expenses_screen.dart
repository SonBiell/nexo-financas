import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'dashboard_screen.dart';
import 'transactions_screen.dart';

class ExpensesScreen extends StatefulWidget {
  final Future<void> Function() onChanged;
  const ExpensesScreen({super.key, required this.onChanged});
  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  List<dynamic> items = const [], categories = const [];
  bool loading = true;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final values = await Future.wait(
          [AuthService().expenses(), AuthService().categories()]);
      if (mounted) {
        setState(() {
          items = values[0]['expenses'] ?? [];
          categories = values[1]['categories'] ?? [];
          error = null;
        });
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> create() async {
    final description = TextEditingController(),
        amount = TextEditingController(),
        due = TextEditingController(
            text: DateTime.now().toIso8601String().substring(0, 10)),
        installments = TextEditingController(text: '1'),
        notes = TextEditingController();
    int? categoryId;
    bool recurring = false;
    final ok = await showDialog<bool>(
        context: context,
        builder: (c) => StatefulBuilder(
            builder: (c, setDialog) => AlertDialog(
                    title: const Text('Nova despesa'),
                    content: SizedBox(
                        width: 480,
                        child: SingleChildScrollView(
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                              TextField(
                                  controller: description,
                                  decoration: const InputDecoration(
                                      labelText: 'DescriÃ§Ã£o')),
                              const SizedBox(height: 12),
                              TextField(
                                  controller: amount,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                      labelText: 'Valor de cada parcela',
                                      prefixText: 'R\$ ')),
                              const SizedBox(height: 12),
                              Row(children: [
                                Expanded(
                                    child: TextField(
                                        controller: due,
                                        decoration: const InputDecoration(
                                            labelText:
                                                'Vencimento (AAAA-MM-DD)'))),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: TextField(
                                        controller: installments,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                            labelText:
                                                'Quantidade de parcelas')))
                              ]),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<int>(
                                  initialValue: categoryId,
                                  decoration: const InputDecoration(
                                      labelText: 'Categoria'),
                                  items: categories.map((raw) {
                                    final item = raw as Map<String, dynamic>;
                                    return DropdownMenuItem(
                                        value: item['id'] as int,
                                        child: Text('${item['name']}'));
                                  }).toList(),
                                  onChanged: (v) => categoryId = v),
                              const SizedBox(height: 10),
                              SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  value: recurring,
                                  onChanged: (v) =>
                                      setDialog(() => recurring = v),
                                  title: const Text(
                                      'Repetir o mesmo valor todo mÃªs')),
                              TextField(
                                  controller: notes,
                                  decoration: const InputDecoration(
                                      labelText: 'ObservaÃ§Ãµes'))
                            ]))),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(c, false),
                          child: const Text('Cancelar')),
                      FilledButton(
                          onPressed: () => Navigator.pop(c, true),
                          child: const Text('Cadastrar'))
                    ])));
    if (ok != true) return;
    try {
      await AuthService().createExpense({
        'description': description.text,
        'amount_cents': cents(amount.text),
        'due_on': due.text,
        'installment_count': int.tryParse(installments.text) ?? 1,
        'category_id': categoryId,
        'recurring_monthly': recurring,
        'notes': notes.text
      });
      await load();
      await widget.onChanged();
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> action(Future<dynamic> Function() operation) async {
    try {
      await operation();
      await load();
      await widget.onChanged();
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.message),
            backgroundColor: const Color(0xFF9F1239)));
      }
    }
  }

  String status(Map<String, dynamic> item) {
    if (item['paid_at'] != null) return 'Pago';
    if ('${item['due_on']}'
            .compareTo(DateTime.now().toIso8601String().substring(0, 10)) <
        0) {
      return 'Atrasado';
    }
    return 'Pendente';
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(34),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('CONTAS A PAGAR',
                      style: TextStyle(
                          color: Color(0xFF5EEAD4),
                          fontSize: 11,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w800)),
                  SizedBox(height: 7),
                  Text('Despesas',
                      style:
                          TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                ])),
            FilledButton.icon(
                onPressed: create,
                icon: const Icon(Icons.add),
                label: const Text('Nova despesa')),
          ]),
          const SizedBox(height: 24),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : error != null
                    ? Center(child: Text(error!))
                    : Container(
                        decoration: BoxDecoration(
                            color: panel,
                            border: Border.all(color: line),
                            borderRadius: BorderRadius.circular(16)),
                        child: items.isEmpty
                            ? const Center(
                                child: Text('Nenhuma despesa cadastrada.',
                                    style: TextStyle(color: muted)))
                            : SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: SizedBox(
                                    width: 1050,
                                    child: ListView.builder(
                                      itemCount: items.length + 1,
                                      itemBuilder: (context, index) {
                                        if (index == 0) {
                                          return const _ExpenseHeader();
                                        }
                                        final item = items[index - 1]
                                            as Map<String, dynamic>;
                                        final state = status(item);
                                        final paid = (item['installments_paid']
                                                    as num? ??
                                                0)
                                            .toInt();
                                        final count = (item['installment_count']
                                                    as num? ??
                                                1)
                                            .toInt();
                                        return Container(
                                            height: 76,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 18),
                                            decoration: const BoxDecoration(
                                                border: Border(
                                                    bottom: BorderSide(
                                                        color: line))),
                                            child: Row(children: [
                                              Expanded(
                                                  flex: 22,
                                                  child: Text(
                                                      '${item['description']}',
                                                      style: const TextStyle(
                                                          fontWeight: FontWeight
                                                              .w700))),
                                              Expanded(
                                                  flex: 14,
                                                  child: Text(
                                                      '${item['category_name']}')),
                                              Expanded(
                                                  flex: 13,
                                                  child: Text(
                                                      '${item['due_on']}')),
                                              Expanded(
                                                  flex: 13,
                                                  child: Text(
                                                      money(
                                                          item['amount_cents']),
                                                      style: const TextStyle(
                                                          fontWeight: FontWeight
                                                              .w800))),
                                              Expanded(
                                                  flex: 14,
                                                  child: Column(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                            '$count x ${money(item['amount_cents'])}'),
                                                        Text(
                                                            '${money((item['amount_cents'] as num) * count)} total',
                                                            style:
                                                                const TextStyle(
                                                                    color:
                                                                        muted,
                                                                    fontSize:
                                                                        11))
                                                      ])),
                                              Expanded(
                                                  flex: 10,
                                                  child:
                                                      Text('$paid / $count')),
                                              Expanded(
                                                  flex: 11,
                                                  child: Text(state,
                                                      style: TextStyle(
                                                          color: state == 'Pago'
                                                              ? const Color(
                                                                  0xFF4ADE80)
                                                              : state ==
                                                                      'Atrasado'
                                                                  ? const Color(
                                                                      0xFFFB7185)
                                                                  : const Color(
                                                                      0xFFFBBF24),
                                                          fontWeight: FontWeight
                                                              .w800))),
                                              Expanded(
                                                  flex: 18,
                                                  child: Wrap(
                                                      spacing: 4,
                                                      children: [
                                                        if (item['paid_at'] ==
                                                            null)
                                                          IconButton(
                                                              tooltip:
                                                                  'Pagar parcela',
                                                              onPressed: () => action(() =>
                                                                  AuthService()
                                                                      .payExpense(
                                                                          item[
                                                                              'id'])),
                                                              icon: const Icon(
                                                                  Icons
                                                                      .check_circle_outline,
                                                                  color: Color(
                                                                      0xFF4ADE80))),
                                                        if (paid > 0)
                                                          IconButton(
                                                              tooltip:
                                                                  'Restaurar parcela',
                                                              onPressed: () => action(() =>
                                                                  AuthService()
                                                                      .restoreExpense(
                                                                          item[
                                                                              'id'])),
                                                              icon: const Icon(
                                                                  Icons.restore,
                                                                  color: Color(
                                                                      0xFF38BDF8))),
                                                        IconButton(
                                                            tooltip: 'Excluir',
                                                            onPressed: () => action(
                                                                () => AuthService()
                                                                    .deleteExpense(
                                                                        item[
                                                                            'id'])),
                                                            icon: const Icon(
                                                                Icons
                                                                    .delete_outline,
                                                                color: Color(
                                                                    0xFFFB7185))),
                                                      ])),
                                            ]));
                                      },
                                    )))),
          ),
        ]),
      );
}

class _ExpenseHeader extends StatelessWidget {
  const _ExpenseHeader();
  @override
  Widget build(BuildContext context) => Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
          color: Color(0xFF0D171E),
          border: Border(bottom: BorderSide(color: line))),
      child: const Row(children: [
        Expanded(flex: 22, child: Text('DESCRIÃ‡ÃƒO')),
        Expanded(flex: 14, child: Text('CATEGORIA')),
        Expanded(flex: 13, child: Text('VENCIMENTO')),
        Expanded(flex: 13, child: Text('VALOR')),
        Expanded(flex: 14, child: Text('PARCELA')),
        Expanded(flex: 10, child: Text('PARCELAS')),
        Expanded(flex: 11, child: Text('STATUS')),
        Expanded(flex: 18, child: Text('OPÃ‡Ã•ES'))
      ]));
}
