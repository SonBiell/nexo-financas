import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'dashboard_screen.dart';

int cents(String text) {
  final clean = text
      .replaceAll(RegExp(r'[^0-9,\.]'), '')
      .replaceAll('.', '')
      .replaceAll(',', '.');
  return ((double.tryParse(clean) ?? 0) * 100).round();
}

class TransactionsScreen extends StatefulWidget {
  final Future<void> Function() onChanged;
  const TransactionsScreen({super.key, required this.onChanged});
  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
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
          [AuthService().transactions(), AuthService().categories()]);
      if (mounted) {
        setState(() {
          items = values[0]['transactions'] ?? [];
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
        notes = TextEditingController();
    String type = 'income';
    int? categoryId;
    final ok = await showDialog<bool>(
        context: context,
        builder: (c) => StatefulBuilder(
            builder: (c, setDialog) => AlertDialog(
                    title: const Text('Nova transaÃ§Ã£o'),
                    content: SizedBox(
                        width: 460,
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          TextField(
                              controller: description,
                              decoration: const InputDecoration(
                                  labelText: 'DescriÃ§Ã£o')),
                          const SizedBox(height: 12),
                          TextField(
                              controller: amount,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                  labelText: 'Valor', prefixText: 'R\$ ')),
                          const SizedBox(height: 12),
                          SegmentedButton<String>(
                              segments: const [
                                ButtonSegment(
                                    value: 'income',
                                    label: Text('Entrada'),
                                    icon: Icon(Icons.south_west)),
                                ButtonSegment(
                                    value: 'expense',
                                    label: Text('SaÃ­da'),
                                    icon: Icon(Icons.north_east))
                              ],
                              selected: {
                                type
                              },
                              onSelectionChanged: (v) =>
                                  setDialog(() => type = v.first)),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<int>(
                              initialValue: categoryId,
                              decoration:
                                  const InputDecoration(labelText: 'Categoria'),
                              items: categories.map((raw) {
                                final item = raw as Map<String, dynamic>;
                                return DropdownMenuItem(
                                    value: item['id'] as int,
                                    child: Text('${item['name']}'));
                              }).toList(),
                              onChanged: (v) => categoryId = v),
                          const SizedBox(height: 12),
                          TextField(
                              controller: notes,
                              decoration: const InputDecoration(
                                  labelText: 'ObservaÃ§Ãµes'))
                        ])),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(c, false),
                          child: const Text('Cancelar')),
                      FilledButton(
                          onPressed: () => Navigator.pop(c, true),
                          child: const Text('Adicionar'))
                    ])));
    if (ok != true) return;
    try {
      await AuthService().createTransaction({
        'description': description.text,
        'amount_cents': cents(amount.text),
        'type': type,
        'category_id': categoryId,
        'occurred_on': DateTime.now().toIso8601String().substring(0, 10),
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

  Future<void> remove(int id) async {
    try {
      await AuthService().deleteTransaction(id);
      await load();
      await widget.onChanged();
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
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
                  Text('CARTEIRA',
                      style: TextStyle(
                          color: Color(0xFF5EEAD4),
                          fontSize: 11,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w800)),
                  SizedBox(height: 7),
                  Text('Extrato de transaÃ§Ãµes',
                      style:
                          TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                ])),
            FilledButton.icon(
                onPressed: create,
                icon: const Icon(Icons.add),
                label: const Text('Nova transaÃ§Ã£o')),
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
                                child: Text('Nenhuma transaÃ§Ã£o registrada.',
                                    style: TextStyle(color: muted)))
                            : ListView.separated(
                                padding: const EdgeInsets.all(18),
                                itemCount: items.length,
                                separatorBuilder: (context, index) =>
                                    const Divider(color: line),
                                itemBuilder: (context, index) {
                                  final item =
                                      items[index] as Map<String, dynamic>;
                                  final income = item['type'] == 'income';
                                  return ListTile(
                                    leading: CircleAvatar(
                                        backgroundColor: (income
                                                ? const Color(0xFF4ADE80)
                                                : const Color(0xFFFB7185))
                                            .withValues(alpha: .14),
                                        child: Icon(
                                            income
                                                ? Icons.south_west
                                                : Icons.north_east,
                                            color: income
                                                ? const Color(0xFF4ADE80)
                                                : const Color(0xFFFB7185))),
                                    title: Text('${item['description']}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700)),
                                    subtitle: Text(
                                        '${item['category_name']} â€¢ ${item['occurred_on']}',
                                        style: const TextStyle(color: muted)),
                                    trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                              '${income ? '+' : '-'} ${money(item['amount_cents'])}',
                                              style: TextStyle(
                                                  color: income
                                                      ? const Color(0xFF4ADE80)
                                                      : const Color(0xFFFB7185),
                                                  fontWeight: FontWeight.w800)),
                                          if (item['source'] == 'manual')
                                            IconButton(
                                                onPressed: () =>
                                                    remove(item['id']),
                                                icon: const Icon(
                                                    Icons.delete_outline,
                                                    color: Color(0xFFFB7185))),
                                        ]),
                                  );
                                },
                              )),
          ),
        ]),
      );
}
