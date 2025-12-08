import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ManageExpenseCategoriesPage extends StatefulWidget {
  const ManageExpenseCategoriesPage({super.key});

  @override
  State<ManageExpenseCategoriesPage> createState() =>
      _ManageExpenseCategoriesPageState();
}

class _ManageExpenseCategoriesPageState
    extends State<ManageExpenseCategoriesPage> {
  List categorias = [];
  final controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadCategories();
  }

  Future<void> loadCategories() async {
    try {
      final data = await Supabase.instance.client
          .from('expense_categories')
          .select('id, name')
          .order('name');

      setState(() {
        categorias = data;
      });
    } catch (e) {
      print("Erro ao carregar categorias: $e");
    }
  }

  Future<void> addCategory() async {
    final nome = controller.text.trim();
    if (nome.isEmpty) return;

    try {
      await Supabase.instance.client
          .from('expense_categories')
          .insert({"name": nome}); // sem user_id

      controller.clear();
      await loadCategories();
    } catch (e) {
      print("Erro ao criar categoria: $e");
    }
  }

  Future<void> deleteCategory(int id) async {
    try {
      await Supabase.instance.client
          .from('expense_categories')
          .delete()
          .eq('id', id);

      await loadCategories();
    } catch (e) {
      print('Erro ao excluir: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Categorias de Gastos")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                  hintText: "Nova categoria de gasto"),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: addCategory,
              child: const Text("Adicionar"),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: categorias.length,
                itemBuilder: (context, i) {
                  final cat = categorias[i];
                  return ListTile(
                    title: Text(cat["name"]),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => deleteCategory(cat["id"]),
                    ),
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}
