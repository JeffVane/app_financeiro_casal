import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class ExpenseListPage extends StatefulWidget {
  const ExpenseListPage({super.key});

  @override
  State<ExpenseListPage> createState() => _ExpenseListPageState();
}

class _ExpenseListPageState extends State<ExpenseListPage> {
  bool loading = true;
  List expenses = [];

  @override
  void initState() {
    super.initState();
    carregarGastos();
  }

  Future<void> carregarGastos() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final agora = DateTime.now();
    final inicioMes = DateTime(agora.year, agora.month, 1).toIso8601String();

    final resp = await Supabase.instance.client
        .from("expenses")
        .select("id, type, value, created_at")
        .eq("user_id", user.id)
        .gte("created_at", inicioMes)
        .order("created_at", ascending: false);

    setState(() {
      expenses = resp;
      loading = false;
    });
  }

  String formatarData(String iso) {
    final date = DateTime.parse(iso);
    return DateFormat("dd/MM").format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Seus Gastos")),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: expenses.length,
              itemBuilder: (context, index) {
                final item = expenses[index];

                return Card(
                  child: ListTile(
                    title: Text(item["type"]),
                    subtitle: Text("Data: ${formatarData(item["created_at"])}"),
                    trailing: Text(
                      "R\$ ${(item["value"] as num).toStringAsFixed(2)}",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
