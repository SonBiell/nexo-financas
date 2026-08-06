import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'dashboard_screen.dart';

class CategoriesScreen extends StatefulWidget {
  final Future<void> Function() onChanged;
  const CategoriesScreen({super.key, required this.onChanged});
  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  List<dynamic> items = const [];
  bool loading = true;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final data = await AuthService().categories();
      if (mounted) {
        setState(() {
          items = data['categories'] ?? [];
          error = null;
        });
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> edit([Map<String, dynamic>? item]) async {
    final name = TextEditingController(text: item?['name']?.toString());
    final color =
        TextEditingController(text: item?['color']?.toString() ?? '#14B8A6');
    final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title:
                    Text(item == null ? 'Nova categoria' : 'Editar categoria'),
                content: SizedBox(
                    width: 420,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      TextField(
                          controller: name,
                          decoration: const InputDecoration(labelText: 'Nome')),
                      const SizedBox(height: 14),
                      TextField(
                          controller: color,
                          decoration: const InputDecoration(
                              labelText: 'Cor hexadecimal'))
                    ])),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Salvar'))
                ]));
    if (accepted != true) return;
    try {
      if (item == null) {
        await AuthService()
            .createCategory({'name': name.text, 'color': color.text});
      } else {
        await AuthService().updateCategory(
            item['id'], {'name': name.text, 'color': color.text});
      }
      await load();
      await widget.onChanged();
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> remove(Map<String, dynamic> item) async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                title: const Text('Excluir categoria?'),
                content: Text(
                    'â€œ${item['name']}â€ serÃ¡ removida. Os lanÃ§amentos ficarÃ£o sem categoria.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Cancelar')),
                  FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Excluir'))
                ]));
    if (ok == true) {
      await AuthService().deleteCategory(item['id']);
      await load();
      await widget.onChanged();
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
                Text('CATEGORIAS',
                    style: TextStyle(
                        color: Color(0xFF5EEAD4),
                        fontSize: 11,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w800)),
                SizedBox(height: 7),
                Text('Organize seus lanÃ§amentos',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800))
              ])),
          FilledButton.icon(
              onPressed: () => edit(),
              icon: const Icon(Icons.add),
              label: const Text('Nova categoria'))
        ]),
        const SizedBox(height: 24),
        Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : error != null
                    ? Center(child: Text(error!))
                    : GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 360,
                                mainAxisExtent: 110,
                                crossAxisSpacing: 14,
                                mainAxisSpacing: 14),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index] as Map<String, dynamic>;
                          final parsed = int.tryParse(
                                  item['color']
                                      .toString()
                                      .replaceFirst('#', ''),
                                  radix: 16) ??
                              0x14B8A6;
                          final color = Color(0xFF000000 | parsed);
                          return Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                  color: panel,
                                  border: Border.all(color: line),
                                  borderRadius: BorderRadius.circular(16)),
                              child: Row(children: [
                                Container(
                                    width: 8,
                                    decoration: BoxDecoration(
                                        color: color,
                                        borderRadius:
                                            BorderRadius.circular(8))),
                                const SizedBox(width: 14),
                                Expanded(
                                    child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text('${item['name']}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w800)),
                                      Text(
                                          '${item['expense_count']} despesa(s)',
                                          style: const TextStyle(
                                              color: muted, fontSize: 12))
                                    ])),
                                IconButton(
                                    onPressed: () => edit(item),
                                    icon: const Icon(Icons.edit_outlined)),
                                IconButton(
                                    onPressed: () => remove(item),
                                    icon: const Icon(Icons.delete_outline,
                                        color: Color(0xFFFB7185)))
                              ]));
                        }))
      ]));
}
