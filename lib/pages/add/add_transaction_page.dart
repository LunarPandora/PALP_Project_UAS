import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class AddTransactionPage extends StatefulWidget {
  @override
  _AddTransactionPageState createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage> {
  final _formKey = GlobalKey<FormState>();
  final _detailFormKey = GlobalKey<FormState>();

  List<DocumentSnapshot> _productOptions = [];
  List<DocumentSnapshot> _supplierOptions = [];
  List<DocumentSnapshot> _warehouseOptions = [];
  String? _selectedProductRef;
  String? _selectedSupplierRef;
  String? _selectedWarehouseRef;

  String _getProductName(String productRef) {
  final matchedProduct = _productOptions.where((product) => 'products/${product.id}' == productRef).toList();
  if (matchedProduct.isNotEmpty) {
    return matchedProduct.first.get('name') ?? 'Tanpa Nama';
  }
  return 'Produk tidak ditemukan';
}

  final TextEditingController _noFormController = TextEditingController();
  final TextEditingController _postDateController = TextEditingController();
  //final TextEditingController _supplierRefController = TextEditingController();
  //final TextEditingController _warehouseRefController = TextEditingController();

  //final TextEditingController _productRefController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _unitNameController = TextEditingController();
  final TextEditingController _batchNumberController = TextEditingController();
  final TextEditingController _expirationDateController = TextEditingController();


  bool _isSaving = false;
  List<Map<String, dynamic>> _details = [];

  void _addDetail() {
    if (_detailFormKey.currentState!.validate()) {
      final double qty = double.tryParse(_qtyController.text) ?? 0;
      final double price = double.tryParse(_priceController.text) ?? 0;
      final double subtotal = qty * price;

      setState(() {
        _details.add({
          'product_ref': _selectedProductRef,
          'qty': qty,
          'price': price,
          'subtotal': subtotal,
          'unit_name': _unitNameController.text,
          'batch_number': _batchNumberController.text,
          'expiration_date': _expirationDateController.text,
        });

        _selectedProductRef = null;
        _qtyController.clear();
        _priceController.clear();
        _unitNameController.clear();
        _batchNumberController.clear();
        _expirationDateController.clear();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchProducts();
    _fetchSuppliers();
    _fetchWarehouses();
  }

  Future<void> _fetchProducts() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? code = prefs.getString('code');

    if (code == null) return;

    DocumentReference storeRef = FirebaseFirestore.instance
        .doc(code == '22100036' ? 'stores/2' : 'stores/default');

    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('products')
        .where('store_ref', isEqualTo: storeRef)
        .get();

    setState(() {
      _productOptions = snapshot.docs;
    });
  }

  Future<void> _fetchSuppliers() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? code = prefs.getString('code');

    if (code == null) return;

    DocumentReference storeRef = FirebaseFirestore.instance
        .doc(code == '22100036' ? 'stores/2' : 'stores/default');

    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('suppliers')
        .where('store_ref', isEqualTo: storeRef)
        .get();

    setState(() {
      _supplierOptions = snapshot.docs;
    });
  }

  Future<void> _fetchWarehouses() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? code = prefs.getString('code');

    if (code == null) return;

    DocumentReference storeRef = FirebaseFirestore.instance
        .doc(code == '22100036' ? 'stores/2' : 'stores/default');

    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('warehouses')
        .where('store_ref', isEqualTo: storeRef)
        .get();

    setState(() {
      _warehouseOptions = snapshot.docs;
    });
  }

  Future<void> _selectPostDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_postDateController.text) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _postDateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _selectExpirationDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _expirationDateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate() || _details.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lengkapi informasi transaksi dan minimal 1 detail barang.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? code = prefs.getString('code');
      String? name = prefs.getString('name');

      if (code == null || name == null) {
        throw Exception('Informasi toko tidak ditemukan.');
      }

      double grandTotal = _details.fold(0, (sum, item) => sum + item['subtotal']);

      DocumentReference transactionRef = await FirebaseFirestore.instance.collection('purchaseGoodsReceipts').add({
        'no_form': _noFormController.text,
        'grandtotal': grandTotal,
        'item_total': _details.length,
        'post_date': _postDateController.text,
        'created_at': FieldValue.serverTimestamp(),
        'synced': true,
        'store_ref': code == '22100036'
            ? FirebaseFirestore.instance.doc('stores/2')
            : FirebaseFirestore.instance.doc('stores/default'),
        'supplier_ref': FirebaseFirestore.instance.doc(_selectedSupplierRef!),
        'warehouse_ref': FirebaseFirestore.instance.doc(_selectedWarehouseRef!),
        'store_code': code,
      });

      for (var detail in _details) {
        final productRef = FirebaseFirestore.instance.doc(detail['product_ref']);

        // Simpan detail transaksi
        await transactionRef.collection('details').add({
          'product_ref': productRef,
          'qty': detail['qty'],
          'price': detail['price'],
          'subtotal': detail['subtotal'],
          'unit_name': detail['unit_name'],
          'batch_number': detail['batch_number'],
          'expiration_date': detail['expiration_date'],
        });

        // Update stok produk
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          DocumentSnapshot snapshot = await transaction.get(productRef);
          final currentStock = snapshot.get('stock') ?? 0;
          final updatedStock = currentStock + detail['qty'];
          transaction.update(productRef, {'stock': updatedStock});
        });
      }

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan: $e')),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Tambah Transaksi")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isSaving
            ? Center(child: CircularProgressIndicator())
            : ListView(
                children: [
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Informasi Transaksi", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        TextFormField(
                          controller: _noFormController,
                          decoration: InputDecoration(labelText: 'No Form'),
                          validator: (value) => value == null || value.isEmpty ? 'Wajib diisi' : null,
                        ),
                        TextFormField(
                          controller: _postDateController,
                          readOnly: true,
                          onTap: () => _selectPostDate(context),
                          decoration: InputDecoration(
                            labelText: 'Tanggal Posting',
                            suffixIcon: Icon(Icons.calendar_today),
                          ),
                          validator: (value) => value == null || value.isEmpty ? 'Wajib diisi' : null,
                        ),
                        DropdownButtonFormField<String>(
                          value: _selectedSupplierRef,
                          items: _supplierOptions.map((doc) {
                            String id = doc.id;
                            String name = doc.get('name');
                            return DropdownMenuItem(
                              value: 'suppliers/$id',
                              child: Text(name),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedSupplierRef = value;
                            });
                          },
                          decoration: InputDecoration(labelText: 'Pilih Supplier'),
                          validator: (value) => value == null || value.isEmpty ? 'Wajib pilih supplier' : null,
                        ),
                        DropdownButtonFormField<String>(
                          value: _selectedWarehouseRef,
                          items: _warehouseOptions.map((doc) {
                            String id = doc.id;
                            String name = doc.get('name');
                            return DropdownMenuItem(
                              value: 'warehouses/$id',
                              child: Text(name),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedWarehouseRef = value;
                            });
                          },
                          decoration: InputDecoration(labelText: 'Pilih Gudang'),
                          validator: (value) => value == null || value.isEmpty ? 'Wajib pilih gudang' : null,
                        ),
                        SizedBox(height: 20),
                      ],
                    ),
                  ),
                  Form(
                    key: _detailFormKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Detail Barang", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        DropdownButtonFormField<String>(
                          value: _selectedProductRef,
                          items: _productOptions.map((doc) {
                            String id = doc.id;
                            String name = doc.get('name');
                            return DropdownMenuItem(
                              value: 'products/$id',
                              child: Text(name),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedProductRef = value;
                            });
                          },
                          decoration: InputDecoration(labelText: 'Pilih Produk'),
                          validator: (value) => value == null || value.isEmpty ? 'Wajib pilih produk' : null,
                        ),
                        TextFormField(
                          controller: _qtyController,
                          decoration: InputDecoration(labelText: 'Qty'),
                          keyboardType: TextInputType.number,
                          validator: (value) => value == null || value.isEmpty ? 'Wajib diisi' : null,
                        ),
                        TextFormField(
                          controller: _priceController,
                          decoration: InputDecoration(labelText: 'Harga'),
                          keyboardType: TextInputType.number,
                          validator: (value) => value == null || value.isEmpty ? 'Wajib diisi' : null,
                        ),
                        TextFormField(
                          controller: _unitNameController,
                          decoration: InputDecoration(labelText: 'Unit Name'),
                          validator: (value) => value == null || value.isEmpty ? 'Wajib diisi' : null,
                        ),
                        TextFormField(
                          controller: _batchNumberController,
                          decoration: InputDecoration(labelText: 'Batch Number'),
                          validator: (value) => value == null || value.isEmpty ? 'Wajib diisi' : null,
                        ),
                        TextFormField(
                          controller: _expirationDateController,
                          readOnly: true,
                          onTap: () => _selectExpirationDate(context),
                          decoration: InputDecoration(
                            labelText: 'Expiration Date',
                            suffixIcon: Icon(Icons.calendar_today),
                          ),
                          validator: (value) => value == null || value.isEmpty ? 'Wajib diisi' : null,
                        ),
                        SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: _addDetail,
                          child: Text('Tambah Detail Barang'),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),
                  Text("Daftar Detail Barang:", style: TextStyle(fontWeight: FontWeight.bold)),
                  ..._details.map((item) => ListTile(
                    title: Text(_getProductName(item['product_ref'])),
                    subtitle: Text(
                      'Batch: ${item['batch_number']}, Exp: ${item['expiration_date']}\n'
                      'Qty: ${item['qty']} ${item['unit_name']}, Harga: ${item['price']}, Subtotal: ${item['subtotal']}',
                    ),
                  )),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _saveTransaction,
                    child: Text('Simpan Transaksi & Semua Detail'),
                  ),
                ],
              ),
      ),
    );
  }
}
