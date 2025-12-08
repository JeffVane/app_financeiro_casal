import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pages/welcome_page.dart';
import 'pages/login_page.dart';
import 'pages/signup_page.dart';
import 'pages/home_page.dart';
import 'pages/income_page.dart';
import 'pages/manage_categories_page.dart';
import 'pages/expense_page.dart';
import 'pages/manage_expense_categories_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/income_list_page.dart';
import 'pages/expense_list_page.dart';
import 'pages/income_category_totals_page.dart';
import 'pages/expense_category_totals_page.dart';
import 'pages/expense_pie_page.dart';
import 'pages/income_pie_page.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR', null);

  await Supabase.initialize(
    url: 'https://kechmxpwnvhuogfnsvys.supabase.co',
    anonKey: 'sb_secret_SQKzovdYtESoV5xql_3Z_w_Eqaz6e3q',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Financeiro do Casal',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const WelcomePage(),
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignupPage(),
        '/home': (context) => const HomePage(),
        '/income': (context) => const IncomePage(),
        '/manage_categories': (context) => const ManageCategoriesPage(),
        '/expense': (context) => const ExpensePage(),
        '/manage_expense_categories': (context) => const ManageExpenseCategoriesPage(),
        '/dashboard': (context) => const DashboardPage(),
        '/income_list': (context) => const IncomeListPage(),
        '/expense_list': (context) => const ExpenseListPage(),
        '/income_totals': (context) => const IncomeCategoryTotalsPage(),
        '/expense_totals': (context) => const ExpenseCategoryTotalsPage(),
        '/expense_pie': (context) => const ExpensePiePage(),
        '/income_pie': (context) => const IncomePiePage(),
      },
    );
  }
}
