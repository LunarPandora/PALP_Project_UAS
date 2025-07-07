import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AddSupplierPage extends StatefulWidget {
  @override
  _AddSupplierPageState createState() => _AddSupplierPageState();
}

class _AddSupplierPageState extends State<AddSupplierPage> {
  final TextEditingController _nameController = TextEditingController();
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

    if (name.isEmpty || _selectedStore == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nama supplier dan toko wajib diisi')),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('suppliers').add({
        'name': name,
        'store_ref': _selectedStore,
      });

      Navigator.pop(context); // Kembali ke halaman sebelumnya
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Supplier berhasil ditambahkan')),
      );
    } catch (e) {
      print('Error saving product: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan supplier')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Tambah Supplier')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: 'Nama Supplier'),
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
              child: Text('Simpan Supplier'),
            ),
          ],
        ),
      ),
    );
  }
}
