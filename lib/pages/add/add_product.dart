import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AddProductPage extends StatefulWidget {
  @override
  _AddProductPageState createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _stockController = TextEditingController();
  String? _storeName;
  DocumentReference? _selectedStore;

  @override
  void initState() {
    super.initState();
    _loadInitialStore();
  }

  Future<void> _loadInitialStore() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final code = prefs.getString('code');

    if (code == '22100036') {
      final storeRef = FirebaseFirestore.instance.doc('stores/2');
      final storeSnapshot = await storeRef.get();
      final data = storeSnapshot.data() as Map<String, dynamic>;

      setState(() {
        _selectedStore = storeRef;
        _storeName = data['name'] ?? 'Tanpa Nama';
      });
    }
  }

  void _saveProduct() async {
    final name = _nameController.text.trim();
    final stockText = _stockController.text.trim();
    final stock = int.tryParse(stockText);

    if (name.isEmpty || stock == null || _selectedStore == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nama, stok awal, dan toko wajib diisi')),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('products').add({
        'name': name,
        'stock': stock,
        'store_ref': _selectedStore,
      });

      Navigator.pop(context); // Kembali ke halaman sebelumnya
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Produk berhasil ditambahkan')),
      );
    } catch (e) {
      print('Error saving product: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan produk')),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Tambah Produk')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: 'Nama Produk'),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _stockController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'Stok Awal'),
            ),
            SizedBox(height: 16),
            _storeName == null
                ? CircularProgressIndicator()
                : TextFormField(
                    initialValue: _storeName,
                    readOnly: true,
                    decoration: InputDecoration(labelText: 'Toko'),
                  ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saveProduct,
              child: Text('Simpan Produk'),
            ),
          ],
        ),
      ),
    );
  }
}
