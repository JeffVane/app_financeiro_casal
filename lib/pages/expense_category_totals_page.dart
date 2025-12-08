import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ExpenseCategoryTotalsPage extends StatefulWidget {
  const ExpenseCategoryTotalsPage({super.key});

  @override
  State<ExpenseCategoryTotalsPage> createState() =>
      _ExpenseCategoryTotalsPageState();
}

class _ExpenseCategoryTotalsPageState
    extends State<ExpenseCategoryTotalsPage> {
  bool loading = true;
  List<Map<String, dynamic>> totais = [];

  @override
  void initState() {
    super.initState();
    carregarTotais();
  }

  Future<void> carregarTotais() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final agora = DateTime.now();
    final inicioMes =
        DateTime(agora.year, agora.month, 1).toIso8601String();

    // Busca gastos do mês
    final data = await Supabase.instance.client
    .from("expenses")
    .select("type, value")
    .gte("created_at", inicioMes);

Map<String, double> mapa = {};

// Agrupando
for (var item in data) {
  final categoria = item["type"];
  final valor = (item["value"] as num).toDouble();

  mapa[categoria] = (mapa[categoria] ?? 0) + valor;
}


    // Converter para lista ordenada
    final listaOrdenada = mapa.entries
        .map((e) => {"categoria": e.key, "total": e.value})
        .toList()
      ..sort((a, b) =>
          (b["total"] as double).compareTo(a["total"] as double));

    setState(() {
      totais = listaOrdenada;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Gastos por categoria")),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: totais.length,
              itemBuilder: (context, index) {
                final item = totais[index];

                return Card(
                  child: ListTile(
                    title: Text(item["categoria"]),
                    trailing: Text(
                      "R\$ ${item["total"].toStringAsFixed(2)}",
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
