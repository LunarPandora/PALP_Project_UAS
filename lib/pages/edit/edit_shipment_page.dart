// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:intl/intl.dart';

// class EditShipmentPage extends StatefulWidget {
//   final String shipmentId;

//   EditShipmentPage({required this.shipmentId});

//   @override
//   _EditShipmentPageState createState() => _EditShipmentPageState();
// }

// class _EditShipmentPageState extends State<EditShipmentPage> {
//   final _formKey = GlobalKey<FormState>();
//   final _noFormController = TextEditingController();
//   final _postDateController = TextEditingController();

//   String? _selectedWarehouseRef;
//   List<DocumentSnapshot> _warehouseOptions = [];
//   List<Map<String, TextEditingController>> _detailControllers = [];

//   DocumentReference? _shipmentRef;
//   bool _isLoading = true;
//   bool _isSaving = false;

//   @override
//   void initState() {
//     super.initState();
//     _loadShipment();
//     _fetchWarehouses();
//   }

//   Future<void> _fetchWarehouses() async {
//     final snapshot = await FirebaseFirestore.instance.collection('warehouses').get();
//     setState(() {
//       _warehouseOptions = snapshot.docs;
//     });
//   }

//   Future<void> _loadShipment() async {
//     _shipmentRef = FirebaseFirestore.instance.collection('shipmentReceipts').doc(widget.shipmentId);
//     final snapshot = await _shipmentRef!.get();
//     final data = snapshot.data()!;

//     _noFormController.text = data['no_form'] ?? '';
//     _postDateController.text = data['post_date'] ?? '';
//     _selectedWarehouseRef = data['warehouse_ref']?.path;

//     final detailSnapshot = await _shipmentRef!.collection('details').get();
//     _detailControllers = detailSnapshot.docs.map((doc) {
//       final detail = doc.data();
//       return {
//         'id': TextEditingController(text: doc.id),
//         'productRef': TextEditingController(text: (detail['product_ref'] as DocumentReference).path),
//         'qty': TextEditingController(text: detail['qty'].toString()),
//         'price': TextEditingController(text: detail['price'].toString()),
//         'unitName': TextEditingController(text: detail['unit_name'] ?? ''),
//       };
//     }).toList();

//     setState(() => _isLoading = false);
//   }

//   Future<void> _selectPostDate(BuildContext context) async {
//     final picked = await showDatePicker(
//       context: context,
//       initialDate: DateTime.tryParse(_postDateController.text) ?? DateTime.now(),
//       firstDate: DateTime(2000),
//       lastDate: DateTime(2100),
//     );
//     if (picked != null) {
//       setState(() {
//         _postDateController.text = DateFormat('yyyy-MM-dd').format(picked);
//       });
//     }
//   }

//   Future<void> _saveChanges() async {
//     if (!_formKey.currentState!.validate()) return;

//     setState(() => _isSaving = true);
//     try {
//       double grandtotal = 0;
//       int itemTotal = _detailControllers.length;

//       // Update header
//       await _shipmentRef!.update({
//         'no_form': _noFormController.text,
//         'post_date': _postDateController.text,
//         'warehouse_ref': FirebaseFirestore.instance.doc(_selectedWarehouseRef!),
//       });

//       // Update detail
//       for (var detail in _detailControllers) {
//         final qty = double.tryParse(detail['qty']!.text) ?? 0;
//         final price = double.tryParse(detail['price']!.text) ?? 0;
//         final subtotal = qty * price;
//         grandtotal += subtotal;

//         final productRef = FirebaseFirestore.instance.doc(detail['productRef']!.text);

//         await _shipmentRef!.collection('details').doc(detail['id']!.text).update({
//           'product_ref': productRef,
//           'qty': qty,
//           'price': price,
//           'subtotal': subtotal,
//           'unit_name': detail['unitName']!.text,
//         });
//       }

//       await _shipmentRef!.update({'grandtotal': grandtotal, 'item_total': itemTotal});

//       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Berhasil memperbarui pengiriman.')));
//       Navigator.pop(context);
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menyimpan perubahan: $e')));
//     } finally {
//       setState(() => _isSaving = false);
//     }
//   }

//   Future<void> _deleteDetail(String id, num qty, String productRefPath) async {
//     try {
//       final productRef = FirebaseFirestore.instance.doc(productRefPath);
//       final productDoc = await productRef.get();
//       final currentStock = productDoc['stock'] ?? 0;
//       await productRef.update({'stock': currentStock + qty});
//       await _shipmentRef!.collection('details').doc(id).delete();

//       setState(() {
//         _detailControllers.removeWhere((item) => item['id']!.text == id);
//       });
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menghapus detail: $e')));
//     }
//   }

//   Widget _buildDetailForm(int index) {
//     final detail = _detailControllers[index];
//     return Card(
//       margin: EdgeInsets.symmetric(vertical: 8),
//       child: Padding(
//         padding: const EdgeInsets.all(8.0),
//         child: Column(
//           children: [
//             StreamBuilder<QuerySnapshot>(
//               stream: FirebaseFirestore.instance.collection('products').snapshots(),
//               builder: (context, snapshot) {
//                 if (!snapshot.hasData) return CircularProgressIndicator();
//                 final docs = snapshot.data!.docs;
//                 return DropdownButtonFormField<String>(
//                   value: detail['productRef']!.text.isNotEmpty ? detail['productRef']!.text : null,
//                   items: docs.map((doc) {
//                     final name = doc['name'] ?? doc.id;
//                     return DropdownMenuItem<String>(
//                       value: doc.reference.path,
//                       child: Text(name),
//                     );
//                   }).toList(),
//                   onChanged: (value) => setState(() => detail['productRef']!.text = value!),
//                   decoration: InputDecoration(labelText: 'Produk'),
//                   validator: (value) => value == null || value.isEmpty ? 'Wajib diisi' : null,
//                 );
//               },
//             ),
//             TextFormField(
//               controller: detail['qty'],
//               decoration: InputDecoration(labelText: 'Qty'),
//               keyboardType: TextInputType.number,
//               validator: (value) => value == null || value.isEmpty ? 'Wajib diisi' : null,
//             ),
//             TextFormField(
//               controller: detail['price'],
//               decoration: InputDecoration(labelText: 'Harga'),
//               keyboardType: TextInputType.number,
//               validator: (value) => value == null || value.isEmpty ? 'Wajib diisi' : null,
//             ),
//             TextFormField(
//               controller: detail['unitName'],
//               decoration: InputDecoration(labelText: 'Unit'),
//               validator: (value) => value == null || value.isEmpty ? 'Wajib diisi' : null,
//             ),
//             Align(
//               alignment: Alignment.centerRight,
//               child: IconButton(
//                 icon: Icon(Icons.delete, color: Colors.red),
//                 onPressed: () => _deleteDetail(detail['id']!.text, double.tryParse(detail['qty']!.text) ?? 0, detail['productRef']!.text),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text("Edit Pengiriman")),
//       body: _isLoading
//           ? Center(child: CircularProgressIndicator())
//           : Padding(
//               padding: const EdgeInsets.all(16.0),
//               child: ListView(
//                 children: [
//                   Form(
//                     key: _formKey,
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text("Informasi Utama", style: TextStyle(fontWeight: FontWeight.bold)),
//                         TextFormField(
//                           controller: _noFormController,
//                           decoration: InputDecoration(labelText: "No Form"),
//                           validator: (v) => v == null || v.isEmpty ? "Wajib diisi" : null,
//                         ),
//                         TextFormField(
//                           controller: _postDateController,
//                           readOnly: true,
//                           onTap: () => _selectPostDate(context),
//                           decoration: InputDecoration(
//                             labelText: "Tanggal Posting",
//                             suffixIcon: Icon(Icons.calendar_today),
//                           ),
//                           validator: (v) => v == null || v.isEmpty ? "Wajib diisi" : null,
//                         ),
//                         DropdownButtonFormField<String>(
//                           value: _selectedWarehouseRef,
//                           items: _warehouseOptions.map((doc) {
//                             return DropdownMenuItem(
//                               value: 'warehouses/${doc.id}',
//                               child: Text(doc.get('name')),
//                             );
//                           }).toList(),
//                           onChanged: (value) => setState(() => _selectedWarehouseRef = value),
//                           decoration: InputDecoration(labelText: 'Gudang'),
//                           validator: (value) => value == null ? 'Wajib pilih gudang' : null,
//                         ),
//                         SizedBox(height: 20),
//                         Text("Detail Barang", style: TextStyle(fontWeight: FontWeight.bold)),
//                         ...List.generate(_detailControllers.length, _buildDetailForm),
//                         SizedBox(height: 20),
//                         ElevatedButton(
//                           onPressed: _isSaving ? null : _saveChanges,
//                           child: Text('Simpan Perubahan'),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class EditShipmentPage extends StatefulWidget {
  final String shipmentId;

  const EditShipmentPage({Key? key, required this.shipmentId}) : super(key: key);

  @override
  _EditShipmentPageState createState() => _EditShipmentPageState();
}

class _EditShipmentPageState extends State<EditShipmentPage> {
  final _formKey = GlobalKey<FormState>();
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  final List<Map<String, dynamic>> _detailControllers = [];

  final TextEditingController _noFormController = TextEditingController();
  final TextEditingController _postDateController = TextEditingController();
  final TextEditingController _warehouseRefController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadShipment();
  }

  Future<void> _loadShipment() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('shipmentReceipts')
          .doc(widget.shipmentId)
          .get();

      if (!doc.exists) {
        throw Exception("Pengiriman tidak ditemukan.");
      }

      final data = doc.data()!;
      _noFormController.text = data['no_form'] ?? '';
      _postDateController.text = data['post_date'] ?? '';
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
          'oldQty': detailData['qty'],  // qty lama disimpan di sini
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
          .collection('shipmentReceipts')
          .doc(widget.shipmentId);

      for (var detail in _detailControllers) {
        final oldQty = (detail['oldQty'] ?? 0).toDouble();
        final newQty = double.tryParse(detail['qty']!.text) ?? 0;
        final price = double.tryParse(detail['price']!.text) ?? 0;
        final subtotal = newQty * price;
        grandTotal += subtotal;

        final productRef = FirebaseFirestore.instance.doc(detail['productRef']!.text);

        // Ambil stok produk saat ini
        final productSnap = await productRef.get();
        final currentStock = (productSnap.data()?['stock'] ?? 0).toDouble();

        // Hitung selisih qty baru dengan qty lama
        final qtyDiff = newQty - oldQty; // positif = bertambah, negatif = berkurang

        // Update stok produk, kurangi stok sesuai selisih qty yang bertambah
        // Jadi stok dikurangi qtyDiff
        await productRef.update({
          'stock': currentStock - qtyDiff,
        });

        // Update detail dengan data baru
        await transactionRef.collection('details').doc(detail['id']!.text).update({
          'product_ref': productRef,
          'qty': newQty,
          'price': price,
          'subtotal': subtotal,
          'unit_name': detail['unitName']!.text,
        });

        // Update oldQty di memori supaya tidak salah hitung jika ada edit berikutnya
        detail['oldQty'] = newQty;
      }

      // Update dokumen utama
      await transactionRef.update({
        'no_form': _noFormController.text,
        'post_date': _postDateController.text,
        'grandtotal': grandTotal,
        'item_total': _detailControllers.length,
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
