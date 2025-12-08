import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ManageCategoriesPage extends StatefulWidget {
  const ManageCategoriesPage({super.key});

  @override
  State<ManageCategoriesPage> createState() => _ManageCategoriesPageState();
}

class _ManageCategoriesPageState extends State<ManageCategoriesPage> {
  final categoryController = TextEditingController();
  bool loading = false;
  List<Map<String, dynamic>> incomeCategories = [];
  List<Map<String, dynamic>> expenseCategories = [];
  
  // Controla qual aba está ativa (0 = Ganhos, 1 = Gastos)
  int selectedTab = 0;

  @override
  void initState() {
    super.initState();
    loadCategories();
  }

  Future<void> loadCategories() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    // Carrega categorias de ganho
    final incomeResponse = await Supabase.instance.client
        .from('income_categories')
        .select('id, name')
        .order('id');

    // Carrega categorias de gasto
    final expenseResponse = await Supabase.instance.client
        .from('expense_categories')
        .select('id, name')
        .order('id');

    setState(() {
      incomeCategories = incomeResponse;
      expenseCategories = expenseResponse;
    });
  }

  Future<void> addCategory() async {
    final name = categoryController.text.trim();
    final user = Supabase.instance.client.auth.currentUser;

    if (name.isEmpty || user == null) return;

    setState(() => loading = true);

    try {
      // Adiciona na tabela correta dependendo da aba selecionada
      final tableName = selectedTab == 0 ? 'income_categories' : 'expense_categories';
      
      await Supabase.instance.client.from(tableName).insert({
        'name': name,
      });

      categoryController.clear();
      await loadCategories();
    } catch (e) {
      print('Erro ao adicionar categoria: $e');
    }

    setState(() => loading = false);
  }

  Future<void> deleteCategory(int id) async {
    try {
      // Deleta da tabela correta dependendo da aba selecionada
      final tableName = selectedTab == 0 ? 'income_categories' : 'expense_categories';
      
      await Supabase.instance.client
          .from(tableName)
          .delete()
          .eq('id', id);

      await loadCategories();
    } catch (e) {
      print('Erro ao excluir: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Lista da aba atual
    final currentCategories = selectedTab == 0 ? incomeCategories : expenseCategories;
    final categoryType = selectedTab == 0 ? 'Ganho' : 'Gasto';
    final categoryColor = selectedTab == 0 ? Colors.green : Colors.red;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerenciar Categorias'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => selectedTab = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: selectedTab == 0 ? Colors.green : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.arrow_upward,
                            color: selectedTab == 0 ? Colors.green : Colors.grey,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Ganhos',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: selectedTab == 0 ? Colors.green : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => selectedTab = 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: selectedTab == 1 ? Colors.red : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.arrow_downward,
                            color: selectedTab == 1 ? Colors.red : Colors.grey,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Gastos',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: selectedTab == 1 ? Colors.red : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Card com informação da categoria atual
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: categoryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: categoryColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    selectedTab == 0 ? Icons.add_circle_outline : Icons.remove_circle_outline,
                    color: categoryColor,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Adicionar categoria de $categoryType',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: categoryColor.withOpacity(0.9),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: categoryController,
              decoration: InputDecoration(
                labelText: 'Nome da categoria',
                hintText: 'Ex: Salário, Aluguel, Alimentação...',
                prefixIcon: Icon(Icons.label_outline, color: categoryColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: categoryColor, width: 2),
                ),
              ),
            ),

            const SizedBox(height: 15),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: loading ? null : addCategory,
                icon: loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.add),
                label: Text(loading ? 'Adicionando...' : 'Adicionar Categoria'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: categoryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
            const Divider(),

            // Título da lista
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.list_alt, color: Colors.grey[600], size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Categorias de $categoryType (${currentCategories.length})',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),

            // Lista de categorias
            Expanded(
              child: currentCategories.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inbox_outlined,
                            size: 64,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Nenhuma categoria de $categoryType cadastrada",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: currentCategories.length,
                      itemBuilder: (context, index) {
                        final item = currentCategories[index];

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: categoryColor.withOpacity(0.1),
                              child: Icon(
                                Icons.label,
                                color: categoryColor,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              item['name'],
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              color: Colors.red[400],
                              onPressed: () {
                                // Confirmação antes de deletar
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Confirmar exclusão'),
                                    content: Text(
                                      'Deseja realmente excluir a categoria "${item['name']}"?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: const Text('Cancelar'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(ctx);
                                          deleteCategory(item['id']);
                                        },
                                        child: const Text(
                                          'Excluir',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    categoryController.dispose();
    super.dispose();
  }
}