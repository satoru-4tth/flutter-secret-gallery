import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calculator Disguise App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Calculator'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String input = '';

  void _onButtonPressed(String value) {
    setState(() {
      if (value == 'C') {
        input = '';
      } else if (value == '=') {
        if (input == '1234') {
          // 秘密コードを検出！今後ここにギャラリー画面へ遷移するコードを追加予定
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('秘密の画面に遷移します！（仮）')),
          );
        } else {
          // 計算を行う（簡易的に例として eval 風に）
          try {
            final result = _calculate(input);
            input = result.toString();
          } catch (e) {
            input = 'Error';
          }
        }
      } else {
        input += value;
      }
    });
  }

  double _calculate(String expression) {
    // 簡易計算処理： +,-,*,/ のみサポート（安全なパーサーではありません）
    // ※後で拡張する場合は `math_expressions` パッケージなどが便利
    try {
      expression = expression.replaceAll('×', '*').replaceAll('÷', '/');
      final result = double.parse(expression); // 本来は安全にパースする処理が必要
      return result;
    } catch (_) {
      return 0;
    }
  }

  Widget _buildButton(String text) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(6.0),
        child: ElevatedButton(
          onPressed: () => _onButtonPressed(text),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 24),
          ),
          child: Text(text, style: const TextStyle(fontSize: 24)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final buttons = [
      ['7', '8', '9', '÷'],
      ['4', '5', '6', '×'],
      ['1', '2', '3', '-'],
      ['C', '0', '=', '+'],
    ];

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.centerRight,
            child: Text(
              input,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(),
          ...buttons.map((row) {
            return Row(
              children: row.map(_buildButton).toList(),
            );
          }),
        ],
      ),
    );
  }
}
