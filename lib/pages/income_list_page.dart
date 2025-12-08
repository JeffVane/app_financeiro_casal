import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class IncomeListPage extends StatefulWidget {
  const IncomeListPage({super.key});

  @override
  State<IncomeListPage> createState() => _IncomeListPageState();
}

class _IncomeListPageState extends State<IncomeListPage> {
  bool loading = true;
  List incomes = [];

  @override
  void initState() {
    super.initState();
    carregarGanhos();
  }

  Future<void> carregarGanhos() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final agora = DateTime.now();
    final inicioMes = DateTime(agora.year, agora.month, 1).toIso8601String();

    final resp = await Supabase.instance.client
        .from("incomes")
        .select("id, type, value, created_at")
        .eq("user_id", user.id)
        .gte("created_at", inicioMes)
        .order("created_at", ascending: false);

    setState(() {
      incomes = resp;
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
      appBar: AppBar(title: const Text("Seus Ganhos")),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: incomes.length,
              itemBuilder: (context, index) {
                final item = incomes[index];

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
