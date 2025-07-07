import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:uts_flutter/pages/add/add_transaction_page.dart';
import 'package:uts_flutter/pages/edit/edit_transaction_page.dart';
import 'package:uts_flutter/pages/read/transaction_details_page.dart';
import 'package:uts_flutter/pages/read/products.dart';
import 'package:uts_flutter/pages/read/suppliers.dart';
import 'package:uts_flutter/pages/read/warehouses.dart';
import 'package:uts_flutter/pages/read/stock_report.dart';
import 'pages/read/shipment_home_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  String? _code;
  String? _name;

  final CollectionReference notes = FirebaseFirestore.instance.collection('purchaseGoodsReceipts');

  @override
  void initState() {
    super.initState();
    _loadStoreInfo();
  }

  Future<void> _loadStoreInfo() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _code = prefs.getString('code');
      _name = prefs.getString('name');
    });
  }

  Future<String> _getNameFromReference(DocumentReference? ref) async {
    if (ref == null) return '-';
    try {
      final doc = await ref.get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return data['name'] ?? '-';
      }
    } catch (_) {}
    return '-';
  }

  Future<Map<String, String>> _getNames(Map<String, dynamic> data) async {
    final storeRef = data['store_ref'] as DocumentReference?;
    final supplierRef = data['supplier_ref'] as DocumentReference?;
    final warehouseRef = data['warehouse_ref'] as DocumentReference?;

    return {
      'store': await _getNameFromReference(storeRef),
      'supplier': await _getNameFromReference(supplierRef),
      'warehouse': await _getNameFromReference(warehouseRef),
    };
  }

  Future<void> deleteTransaction(String id) async {
    final transactionRef = notes.doc(id);
    final detailSnapshot = await transactionRef.collection('details').get();

    for (var doc in detailSnapshot.docs) {
      final data = doc.data();
      final productRef = data['product_ref'] as DocumentReference?;
      final qty = data['qty'] ?? 0;

      if (productRef != null) {
        final productDoc = await productRef.get();
        if (productDoc.exists) {
          final stock = (productDoc.data() as Map<String, dynamic>)['stock'] ?? 0;
          await productRef.update({'stock': stock - qty});
        }
      }

      await doc.reference.delete();
    }

    await transactionRef.delete();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Transaksi dihapus')));
  }

  Widget _buildPenerimaanBarangPage() {
    return Column(
      children: [
        if (_code != null && _name != null)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text('Toko: $_name (Code: $_code)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: notes.orderBy('created_at', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(child: Text("Belum ada transaksi."));
              }
              return ListView(
                children: snapshot.data!.docs
                    .where((doc) => (doc.data()! as Map<String, dynamic>)['store_code'] == '22100036')
                    .map((doc) {
                  final data = doc.data()! as Map<String, dynamic>;
                  return FutureBuilder<Map<String, String>>(
                    future: _getNames(data),
                    builder: (context, snapshotRef) {
                      if (!snapshotRef.hasData) return ListTile(title: Text('Memuat...'));
                      final names = snapshotRef.data!;
                      return Card(
                        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ListTile(
                          title: Text(data['no_form'] ?? '-'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Tanggal: ${data['created_at'] != null ? (data['created_at'] as Timestamp).toDate() : '-'}'),
                              Text('Total: ${data['grandtotal'] ?? '-'}'),
                              Text('Jumlah Item: ${data['item_total'] ?? '-'}'),
                              Text('Tanggal Posting: ${data['post_date'] ?? '-'}'),
                              Text('Store: ${names['store']}'),
                              Text('Supplier: ${names['supplier']}'),
                              Text('Warehouse: ${names['warehouse']}'),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.edit, color: Colors.blue),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => EditTransactionPage(transactionId: doc.id),
                                    ),
                                  );
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.delete, color: Colors.red),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Text("Konfirmasi"),
                                      content: Text("Yakin ingin menghapus transaksi ini?"),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(context, false), child: Text("Batal")),
                                        ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text("Hapus")),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) await deleteTransaction(doc.id);
                                },
                              ),
                              data['synced'] == true
                                  ? Icon(Icons.cloud_done, color: Colors.green)
                                  : Icon(Icons.cloud_off, color: Colors.grey),
                            ],
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TransactionDetailsPage(transactionId: doc.id),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }).toList(),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildPenerimaanBarangPage(),
      ShipmentHomePage(),
      ProductsPage(),
      SuppliersPage(),
      WarehousesPage(),
      StockReportPage(),
    ];

    final titles = [
      'Penerimaan Barang',
      'Pengiriman',
      'Produk',
      'Supplier',
      'Warehouse',
      'Stock Report',
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_selectedIndex]),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Text('Toko Daniel', style: TextStyle(color: Colors.white, fontSize: 24)),
            ),
            ListTile(
              leading: Icon(Icons.inventory),
              title: Text('Penerimaan Barang'),
              selected: _selectedIndex == 0,
              onTap: () {
                setState(() => _selectedIndex = 0);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.local_shipping),
              title: Text('Pengiriman'),
              selected: _selectedIndex == 1,
              onTap: () {
                setState(() => _selectedIndex = 1);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.shopping_bag),
              title: Text('Produk'),
              selected: _selectedIndex == 2,
              onTap: () {
                setState(() => _selectedIndex = 2);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.store),
              title: Text('Supplier'),
              selected: _selectedIndex == 3,
              onTap: () {
                setState(() => _selectedIndex = 3);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.warehouse),
              title: Text('Warehouse'),
              selected: _selectedIndex == 4,
              onTap: () {
                setState(() => _selectedIndex = 4);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.assignment),
              title: Text('Stock Report'),
              selected: _selectedIndex == 5,
              onTap: () {
                setState(() => _selectedIndex = 5);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
      body: IndexedStack(index: _selectedIndex, children: pages),
      floatingActionButton: _selectedIndex == 0 // HANYA di Penerimaan Barang
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AddTransactionPage()),
                );
              },
              child: Icon(Icons.add),
              tooltip: "Tambah Transaksi",
            )
          : null,
    );
  }
}
