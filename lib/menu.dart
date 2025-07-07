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

import 'package:intl/intl.dart';

final rupiahFormat = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp',
  decimalDigits: 0,
);

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  String? _name;
  String? _code;
  String? _storeRef;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      _name = prefs.getString('name');
      _code = prefs.getString('code');
      _storeRef = prefs.getString('store_ref');
    });
  }

  Future<void> deleteTransaction(String id) async {
    final transactionRef = FirebaseFirestore.instance.collection('purchaseGoodsReceipts').doc(id);
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

  // @override
  Widget _buildPenerimaanBarangPage() {
    final ref = FirebaseFirestore.instance.collection('stores').doc(_storeRef);
    final receipts = FirebaseFirestore.instance.collection(
      'purchaseGoodsReceipts',
    ).where('store_ref', isEqualTo: ref);

    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: receipts.snapshots(),
        builder: (context, snapshot) {

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text("Belum ada catatan."));
          }
          
          final docs = snapshot.data!.docs;

          return LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTableTheme(
                    data: DataTableThemeData(
                      headingRowColor: WidgetStateProperty.resolveWith<Color?>(
                        (states) => Colors.blue.shade700
                      ),
                      headingTextStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold
                      )
                    ),
                    child:
                    DataTable(
                      columns: const [
                        DataColumn(label: Text('No. Form')),
                        DataColumn(label: Text('Tanggal')),
                        DataColumn(label: Text('Total')),
                        DataColumn(label: Text('Jumlah Item')),
                        DataColumn(label: Text('Action'))
                      ],
                      rows: docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return DataRow(cells: [
                          DataCell(Text(data['no_form'] ?? '-')),
                          DataCell(Text(data['created_at'] != null
                              ? (data['created_at'] as Timestamp).toDate().toString().split(' ')[0]
                              : '-')),
                          DataCell(Text(data['grandtotal']?.toString() ?? '-')),
                          DataCell(Text(data['item_total']?.toString() ?? '-')),
                          DataCell(
                            Row(
                              children: [
                                ElevatedButton(
                                  onPressed: () { 
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => EditTransactionPage(transactionId: doc.id))
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    padding: EdgeInsets.all(10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8), // Set your desired radius here
                                    ),
                                    backgroundColor: Colors.yellow.shade800,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit, color: Colors.white),
                                      SizedBox(width: 5),
                                      Text('Edit')
                                    ],
                                  ),
                                ),
                                SizedBox(width: 5),
                                ElevatedButton(
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
                                  style: ElevatedButton.styleFrom(
                                    padding: EdgeInsets.all(10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8), // Set your desired radius here
                                    ),
                                    backgroundColor: Colors.red.shade800,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete, color: Colors.white),
                                      SizedBox(width: 5),
                                      Text('Delete')
                                    ],
                                  ),
                                )
                              ],
                            )
                          ),
                        ]);
                      }).toList(),
                    )
                  )
                )
              );
            }
          );
        },
      ),
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
              child: Icon(Icons.add, color: Colors.white, size: 30),
              backgroundColor: Colors.blue.shade700,
              tooltip: "Tambah Transaksi",
            )
          : null,
    );
  }
}
