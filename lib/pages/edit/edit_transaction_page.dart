import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class EditTransactionPage extends StatefulWidget {
  final String transactionId;

  const EditTransactionPage({Key? key, required this.transactionId}) : super(key: key);

  @override
  _EditTransactionPageState createState() => _EditTransactionPageState();
}

class _EditTransactionPageState extends State<EditTransactionPage> {
  final _formKey = GlobalKey<FormState>();
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  final List<Map<String, TextEditingController>> _detailControllers = [];

  final TextEditingController _noFormController = TextEditingController();
  final TextEditingController _postDateController = TextEditingController();
  final TextEditingController _supplierRefController = TextEditingController();
  final TextEditingController _warehouseRefController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadTransaction();
  }

  Future<void> _loadTransaction() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('purchaseGoodsReceipts')
          .doc(widget.transactionId)
          .get();

      if (!doc.exists) {
        throw Exception("Transaksi tidak ditemukan.");
      }

      final data = doc.data()!;
      _noFormController.text = data['no_form'] ?? '';
      _postDateController.text = data['post_date'] ?? '';
      _supplierRefController.text = (data['supplier_ref'] as DocumentReference).path;
      _warehouseRefController.text = (data['warehouse_ref'] as DocumentReference).path;

      final detailSnap = await doc.reference.collection('details').get();
      for (var detail in detailSnap.docs) {
        final detailData = detail.data();
        _detailControllers.add({
          'id': TextEditingController(text: detail.id),
          'productRef': TextEditingController(text: (detailData['product_ref'] as DocumentReference).path),
          'qty': TextEditingController(text: detailData['qty'].toString()),
          'price': TextEditingController(text: detailData['price'].toString()),
          'unitName': TextEditingController(text: detailData['unit_name'] ?? ''),
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat transaksi: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Future<String> _getDocName(String path, String field) async {
  //   final doc = await FirebaseFirestore.instance.doc(path).get();
  //   if (doc.exists) {
  //     return doc.data()?[field] ?? path;
  //   }
  //   return path;
  // }

  Future<void> _selectPostDate() async {
    DateTime initialDate;
    try {
      initialDate = _postDateController.text.isNotEmpty
          ? _dateFormat.parse(_postDateController.text)
          : DateTime.now();
    } catch (_) {
      initialDate = DateTime.now();
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _postDateController.text = _dateFormat.format(picked);
      });
    }
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      double grandTotal = 0;
      final transactionRef = FirebaseFirestore.instance
          .collection('purchaseGoodsReceipts')
          .doc(widget.transactionId);

      for (var detail in _detailControllers) {
        final qty = double.tryParse(detail['qty']!.text) ?? 0;
        final price = double.tryParse(detail['price']!.text) ?? 0;
        final subtotal = qty * price;
        grandTotal += subtotal;

        final productRef = FirebaseFirestore.instance.doc(detail['productRef']!.text);

        // Ambil stok lama
        final productSnap = await productRef.get();
        final currentStock = (productSnap.data()?['stock'] ?? 0).toDouble();

        // Update stok produk
        await productRef.update({
          'stock': currentStock - currentStock + qty,
        });

        // Update detail
        await transactionRef.collection('details').doc(detail['id']!.text).update({
          'product_ref': productRef,
          'qty': qty,
          'price': price,
          'subtotal': subtotal,
          'unit_name': detail['unitName']!.text,
        });
      }

      // Update dokumen utama
      await transactionRef.update({
        'no_form': _noFormController.text,
        'post_date': _postDateController.text,
        'grandtotal': grandTotal,
        'item_total': _detailControllers.length,
        'supplier_ref': FirebaseFirestore.instance.doc(_supplierRefController.text),
        'warehouse_ref': FirebaseFirestore.instance.doc(_warehouseRefController.text),
      });

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan perubahan: $e')),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }


  Widget _buildDetailForm(int index) {
    final detail = _detailControllers[index];
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('products').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return CircularProgressIndicator();
                final docs = snapshot.data!.docs;
                return DropdownButtonFormField<String>(
                  value: detail['productRef']!.text.isNotEmpty ? detail['productRef']!.text : null,
                  items: docs.map((doc) {
                    final name = doc['name'] ?? doc.id;
                    return DropdownMenuItem<String>(
                      value: doc.reference.path,
                      child: Text(name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      detail['productRef']!.text = value!;
                    });
                  },
                  decoration: InputDecoration(labelText: 'Pilih Produk'),
                  validator: (value) => value == null || value.isEmpty ? 'Wajib diisi' : null,
                );
              },
            ),
            TextFormField(
              controller: detail['qty'],
              decoration: InputDecoration(labelText: 'Qty'),
              keyboardType: TextInputType.number,
              validator: (value) => value == null || value.isEmpty ? 'Wajib diisi' : null,
            ),
            TextFormField(
              controller: detail['price'],
              decoration: InputDecoration(labelText: 'Harga'),
              keyboardType: TextInputType.number,
              validator: (value) => value == null || value.isEmpty ? 'Wajib diisi' : null,
            ),
            TextFormField(
              controller: detail['unitName'],
              decoration: InputDecoration(labelText: 'Unit Name'),
              validator: (value) => value == null || value.isEmpty ? 'Wajib diisi' : null,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Edit Transaksi")),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Padding(
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
                                decoration: InputDecoration(
                                  labelText: 'Tanggal Posting (YYYY-MM-DD)',
                                  suffixIcon: Icon(Icons.calendar_today),
                                ),
                                readOnly: true,
                                onTap: _selectPostDate,
                                validator: (value) => value == null || value.isEmpty ? 'Wajib diisi' : null,
                              ),
                              StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance.collection('suppliers').snapshots(),
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData) return CircularProgressIndicator();
                                  final docs = snapshot.data!.docs;
                                  return DropdownButtonFormField<String>(
                                    value: _supplierRefController.text.isNotEmpty ? _supplierRefController.text : null,
                                    items: docs.map((doc) {
                                      final name = doc['name'] ?? doc.id;
                                      return DropdownMenuItem<String>(
                                        value: doc.reference.path,
                                        child: Text(name),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        _supplierRefController.text = value!;
                                      });
                                    },
                                    decoration: InputDecoration(labelText: 'Pilih Supplier'),
                                    validator: (value) => value == null || value.isEmpty ? 'Wajib diisi' : null,
                                  );
                                },
                              ),
                              StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance.collection('warehouses').snapshots(),
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData) return CircularProgressIndicator();
                                  final docs = snapshot.data!.docs;
                                  return DropdownButtonFormField<String>(
                                    value: _warehouseRefController.text.isNotEmpty ? _warehouseRefController.text : null,
                                    items: docs.map((doc) {
                                      final name = doc['name'] ?? doc.id;
                                      return DropdownMenuItem<String>(
                                        value: doc.reference.path,
                                        child: Text(name),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        _warehouseRefController.text = value!;
                                      });
                                    },
                                    decoration: InputDecoration(labelText: 'Pilih Gudang'),
                                    validator: (value) => value == null || value.isEmpty ? 'Wajib diisi' : null,
                                  );
                                },
                              ),
                              SizedBox(height: 20),
                              Text("Detail Barang", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              ...List.generate(_detailControllers.length, _buildDetailForm),
                            ],
                          ),
                        ),
                        SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _saveTransaction,
                          child: Text('Simpan Perubahan'),
                        ),
                      ],
                    ),
            ),
    );
  }
}
