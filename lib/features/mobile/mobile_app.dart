import 'package:flutter/material.dart';
import '../../data/repositories/car_repository.dart';
import '../../models/car.dart';

class MobileApp extends StatelessWidget {
  const MobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Araç Kiralama - Mobil',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const _BrowseCarsPage(),
    );
  }
}

class _BrowseCarsPage extends StatefulWidget {
  const _BrowseCarsPage();

  @override
  State<_BrowseCarsPage> createState() => _BrowseCarsPageState();
}

class _BrowseCarsPageState extends State<_BrowseCarsPage> {
  final _repo = CarRepository();
  final _search = TextEditingController();
  List<Car> _items = [];
  bool _loading = true;

  final int _demoSubeId = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({String? q}) async {
    setState(() => _loading = true);
    final data = await _repo.listBySube(
      subeId: _demoSubeId,
      q: (q == null || q.isEmpty) ? null : q,
      page: 1,
      pageSize: 50,
    );
    setState(() {
      _items = data;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Araçlar'),
        actions: [
          IconButton(onPressed: () => _load(q: _search.text), icon: const Icon(Icons.search)),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Marka / Model / Plaka ara...',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (v) => _load(q: v),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (_, i) {
                      final c = _items[i];
                      return ListTile(
                        leading: const Icon(Icons.directions_car),
                        title: Text('${c.marka} ${c.model} (${c.yil})'),
                        subtitle: Text('Plaka: ${c.plaka} • ${c.gunlukKira.toStringAsFixed(0)} TL/gün'),
                        trailing: FilledButton(
                          onPressed: () {
                            // TODO: Rezervasyon akışı
                          },
                          child: const Text('Kirala'),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}