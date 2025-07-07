import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class AddShipmentPage extends StatefulWidget {
  @override
  _AddShipmentPageState createState() => _AddShipmentPageState();
}

class _AddShipmentPageState extends State<AddShipmentPage> {
  final _formKey = GlobalKey<FormState>();
  final _detailFormKey = GlobalKey<FormState>();

  final TextEditingController _noFormController = TextEditingController();
  final TextEditingController _postDateController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController();
  final TextEditingController _unitNameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  List<DocumentSnapshot> _productOptions = [];
  List<DocumentSnapshot> _warehouseOptions = [];
  List<DocumentSnapshot> _batchOptions = [];
  String? _selectedProductRef;
  String? _selectedBatchRef;
  String? _selectedWarehouseRef;

  List<Map<String, dynamic>> _items = [];
  bool _isSaving = false;

  String? _storeCode;
  String? _storeName;

  @override
  void initState() {
    super.initState();
    _loadStoreInfo();
    _fetchProducts();
    _fetchWarehouses();
  }

  Future<void> _loadStoreInfo() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _storeCode = prefs.getString('code');
      _storeName = prefs.getString('name');
    });
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

  Future<void> _fetchBatchesForProduct(String productRef) async {
    final productDoc = FirebaseFirestore.instance.doc(productRef);

    final snapshot = await FirebaseFirestore.instance
        .collection('purchaseGoodsReceipts')
        .get();

    List<QueryDocumentSnapshot> allDetails = [];

    for (var doc in snapshot.docs) {
      final detailsSnapshot = await doc.reference
          .collection('details')
          .where('product_ref', isEqualTo: productDoc)
          .where('qty', isGreaterThan: 0)
          .get();

      allDetails.addAll(detailsSnapshot.docs);
    }

    setState(() {
      _batchOptions = allDetails;
    });
  }

  String _getProductName(String productRef) {
    try {
      final matchedProduct = _productOptions.firstWhere(
        (product) => 'products/${product.id}' == productRef,
      );
      return matchedProduct.get('name');
    } catch (e) {
      return 'Produk tidak ditemukan';
    }
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

  void _addDetail() {
    if (_detailFormKey.currentState!.validate()) {
      final qty = double.tryParse(_qtyController.text) ?? 0;
      final price = double.tryParse(_priceController.text) ?? 0;
      final subtotal = qty * price;

      final selectedBatch = _batchOptions.firstWhere(
        (doc) => doc.reference.path == _selectedBatchRef,
        orElse: () => throw Exception('Batch tidak ditemukan'),
      );

      final batchNumber = selectedBatch.get('batch_number') ?? selectedBatch.id;

      setState(() {
        _items.add({
          'product_ref': _selectedProductRef,
          'qty': qty,
          'price': price,
          'subtotal': subtotal,
          'unit_name': _unitNameController.text,
          'batch_ref': _selectedBatchRef,
          'batch_number': batchNumber,
        });

        _selectedProductRef = null;
        _selectedBatchRef = null;
        _qtyController.clear();
        _priceController.clear();
        _unitNameController.clear();
        _batchOptions.clear();
      });
    }
  }

  Future<void> _saveShipment() async {
    if (!_formKey.currentState!.validate() || _items.isEmpty || _selectedWarehouseRef == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lengkapi form dan tambahkan minimal 1 item, serta pilih gudang.')),
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

      double grandTotal = _items.fold(0, (sum, item) => sum + item['subtotal']);
      int itemTotal = _items.length;

      DocumentReference storeRef = code == '22100036'
          ? FirebaseFirestore.instance.doc('stores/2')
          : FirebaseFirestore.instance.doc('stores/default');

      DocumentReference warehouseRef = FirebaseFirestore.instance.doc(_selectedWarehouseRef!);

      DocumentReference shipmentRef = await FirebaseFirestore.instance.collection('shipmentReceipts').add({
        'no_form': _noFormController.text,
        'post_date': _postDateController.text,
        'created_at': FieldValue.serverTimestamp(),
        'grandtotal': grandTotal,
        'item_total': itemTotal,
        'store_code': _storeCode,
        'store_name': _storeName,
        'store_ref': storeRef,
        'warehouse_ref': warehouseRef,
        'synced': false,
      });

      for (var item in _items) {
        final productRef = FirebaseFirestore.instance.doc(item['product_ref']);
        final batchRef = FirebaseFirestore.instance.doc(item['batch_ref']);

        // Simpan detail pengiriman
        await shipmentRef.collection('details').add({
          'product_ref': productRef,
          'qty': item['qty'],
          'price': item['price'],
          'subtotal': item['subtotal'],
          'unit_name': item['unit_name'],
          'batch_ref': batchRef,
          'batch_number': item['batch_number'],
        });

        // Transaksi untuk update batch dan stok total produk
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          // Semua pembacaan dilakukan dulu di awal
          final batchSnapshot = await transaction.get(batchRef);
          final productSnapshot = await transaction.get(productRef);

          final num batchQty = (batchSnapshot.get('qty') ?? 0);
          final num productQty = (productSnapshot.get('stock') ?? 0);
          final double itemQty = (item['qty'] ?? 0) * 1.0;

          debugPrint('Stok batch: $batchQty | Stok produk: $productQty | Qty dikurang: $itemQty');

          if (batchQty < itemQty) {
            throw Exception('Stok batch tidak mencukupi untuk produk ${_getProductName(item['product_ref'])}');
          }

          final updatedBatchQty = batchQty - itemQty;
          final updatedProductStock = productQty - itemQty;

          transaction.update(batchRef, {'qty': updatedBatchQty});
          transaction.update(productRef, {'stock': updatedProductStock});
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Pengiriman berhasil disimpan')));
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Tambah Pengiriman')),
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
                        Text("Informasi Pengiriman", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                          value: _selectedWarehouseRef,
                          items: _warehouseOptions.map((doc) {
                            return DropdownMenuItem(
                              value: 'warehouses/${doc.id}',
                              child: Text(doc.get('name')),
                            );
                          }).toList(),
                          onChanged: (value) => setState(() => _selectedWarehouseRef = value),
                          decoration: InputDecoration(labelText: 'Pilih Gudang'),
                          validator: (value) => value == null ? 'Wajib pilih gudang' : null,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                  Form(
                    key: _detailFormKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Detail Barang", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        DropdownButtonFormField<String>(
                          value: _selectedProductRef,
                          items: _productOptions.map((doc) {
                            return DropdownMenuItem(
                              value: 'products/${doc.id}',
                              child: Text(doc.get('name')),
                            );
                          }).toList(),
                          onChanged: (value) async {
                            setState(() {
                              _selectedProductRef = value;
                              _selectedBatchRef = null;
                              _batchOptions = [];
                            });
                            if (value != null) {
                              await _fetchBatchesForProduct(value);
                            }
                          },
                          decoration: InputDecoration(labelText: 'Pilih Produk'),
                          validator: (value) => value == null ? 'Wajib pilih produk' : null,
                        ),
                        DropdownButtonFormField<String>(
                          value: _selectedBatchRef,
                          items: _batchOptions.map((doc) {
                            final batchNumber = doc.data().toString().contains('batch_number')
                                ? doc.get('batch_number')
                                : doc.id;
                            return DropdownMenuItem(
                              value: doc.reference.path,
                              child: Text('Batch: $batchNumber, Qty: ${doc.get('qty')}'),
                            );
                          }).toList(),
                          onChanged: (value) => setState(() => _selectedBatchRef = value),
                          decoration: InputDecoration(labelText: 'Pilih Batch'),
                          validator: (value) => value == null ? 'Wajib pilih batch' : null,
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
                  ..._items.map((item) => ListTile(
                        title: Text(_getProductName(item['product_ref'] ?? '')),
                        subtitle: Text(
                            'Batch: ${item['batch_number']}, Qty: ${item['qty']} ${item['unit_name']}, Harga: ${item['price']}, Subtotal: ${item['subtotal']}'),
                      )),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _saveShipment,
                    child: Text('Simpan Pengiriman & Semua Detail'),
                  ),
                ],
              ),
      ),
    );
  }
}
