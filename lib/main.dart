import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const YourClosetApp());

class YourClosetApp extends StatelessWidget {
  const YourClosetApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ユアクロ (Demo)',
      theme: ThemeData(useMaterial3: true),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_tab == 0 ? '販売者モード' : '購入者ページ')),
      body: _tab == 0 ? const SellerView() : const BuyerView(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.store), label: '販売者'),
          NavigationDestination(icon: Icon(Icons.shopping_bag), label: '購入者'),
        ],
      ),
    );
  }
}

const _prefsKey = 'yurakuro_items';

class SellerView extends StatefulWidget {
  const SellerView({super.key});
  @override
  State<SellerView> createState() => _SellerViewState();
}

class _SellerViewState extends State<SellerView> {
  final _name = TextEditingController();
  final _price = TextEditingController();

  Future<void> _saveItem() async {
    final name = _name.text.trim();
    final price = _price.text.trim();
    if (name.isEmpty || price.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    final List items = raw == null ? [] : jsonDecode(raw) as List;
    items.add({'name': name, 'price': price, 'ts': DateTime.now().toIso8601String()});
    await prefs.setString(_prefsKey, jsonEncode(items));

    if (mounted) {
      _name.clear();
      _price.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存しました（ローカル）')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(controller: _name, decoration: const InputDecoration(labelText: '商品名')),
          const SizedBox(height: 12),
          TextField(controller: _price, decoration: const InputDecoration(labelText: '価格（例: 2200）'), keyboardType: TextInputType.number),
          const SizedBox(height: 16),
          FilledButton(onPressed: _saveItem, child: const Text('保存')),
          const SizedBox(height: 12),
          const Text('※まずは端末内に保存して掲載確認（SafariのLocalStorage）'),
        ],
      ),
    );
  }
}

class BuyerView extends StatefulWidget {
  const BuyerView({super.key});
  @override
  State<BuyerView> createState() => _BuyerViewState();
}

class _BuyerViewState extends State<BuyerView> {
  List<Map<String, dynamic>> items = [];

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    final List list = raw == null ? [] : jsonDecode(raw) as List;
    items = list.cast<Map<String, dynamic>>();
    if (mounted) setState(() {});
  }

  Future<void> _clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    await _load();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('掲載はまだありません'));
    }
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (_, i) {
              final it = items[i];
              return ListTile(
                title: Text(it['name'] ?? ''),
                subtitle: Text('¥${it['price'] ?? ''}'),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: OutlinedButton(onPressed: _clear, child: const Text('全部消去（テスト用）')),
        ),
      ],
    );
  }
}
