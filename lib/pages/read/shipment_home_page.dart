import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'shipment_details_page.dart';
import '../add/add_shipment_page.dart';
import '../edit/edit_shipment_page.dart';

class ShipmentHomePage extends StatefulWidget {
  @override
  _ShipmentHomePageState createState() => _ShipmentHomePageState();
}

class _ShipmentHomePageState extends State<ShipmentHomePage> {
  final CollectionReference shipments =
      FirebaseFirestore.instance.collection('shipmentReceipts');

  String? _code;
  String? _name;

  @override
  void initState() {
    super.initState();
    _loadStoreInfo();
  }

  Future<String> _getNameFromReference(DocumentReference? ref) async {
    if (ref == null) return '-';
    try {
      final doc = await ref.get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return data['name'] ?? '-';
      }
    } catch (e) {
      print('Error getting name from reference: $e');
    }
    return '-';
  }

  Future<Map<String, String>> _getNames(Map<String, dynamic> data) async {
    final storeRef = data['store_ref'] as DocumentReference?;
    final warehouseRef = data['warehouse_ref'] as DocumentReference?;

    final storeName = await _getNameFromReference(storeRef);
    final warehouseName = await _getNameFromReference(warehouseRef);

    return {
      'store': storeName,
      'warehouse': warehouseName,
    };
  }

  Future<void> _loadStoreInfo() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _code = prefs.getString('code');
      _name = prefs.getString('name');
    });
  }

  Future<void> deleteShipment(String shipmentId) async {
    try {
      final shipmentRef = FirebaseFirestore.instance
          .collection('shipmentReceipts') // <- sesuai koleksi utama shipment
          .doc(shipmentId);

      final detailsSnapshot = await shipmentRef.collection('details').get();

      // Loop: kembalikan stok produk
      for (var doc in detailsSnapshot.docs) {
        final detailData = doc.data();
        final productRef = detailData['product_ref'] as DocumentReference?;
        final qty = detailData['qty'] as num? ?? 0;

        if (productRef != null) {
          final productDoc = await productRef.get();
          if (productDoc.exists) {
            final productData = productDoc.data() as Map<String, dynamic>;
            final currentStock = productData['stock'] as num? ?? 0;
            final newStock = currentStock + qty;

            await productRef.update({'stock': newStock});
          }
        }

        // Hapus detail
        await doc.reference.delete();
      }

      // Hapus dokumen utama shipment
      await shipmentRef.delete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pengiriman berhasil dihapus dan stok dikembalikan')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menghapus pengiriman: $e')),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Pengiriman Barang"),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            tooltip: "Tambah Pengiriman",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AddShipmentPage()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_code != null && _name != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'Toko: $_name (Code: $_code)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: shipments
                  .orderBy('created_at', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text("Belum ada pengiriman."));
                }

                return ListView(
                  children: snapshot.data!.docs
                      .where((doc) => (doc.data()! as Map<String, dynamic>)['store_code'] == _code)
                      .map((DocumentSnapshot document) {
                    final data = document.data()! as Map<String, dynamic>;

                    return FutureBuilder<Map<String, String>>(
                      future: _getNames(data),
                      builder: (context, snapshotRef) {
                        if (!snapshotRef.hasData) {
                          return ListTile(title: Text('Memuat...'));
                        }

                        final names = snapshotRef.data!;

                        return Card(
                          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: ListTile(
                            title: Text(data['no_form'] ?? '-'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Tanggal: ${data['created_at'] != null ? (data['created_at'] as Timestamp).toDate().toString() : '-'}'),
                                Text('Total: ${data['grandtotal']?.toString() ?? '-'}'),
                                Text('Jumlah Item: ${data['item_total']?.toString() ?? '-'}'),
                                Text('Tanggal Posting: ${data['post_date'] ?? '-'}'),
                                Text('Store: ${names['store'] ?? '-'}'),
                                Text('Warehouse: ${names['warehouse'] ?? '-'}'),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.edit, color: Colors.blue),
                                  tooltip: 'Edit Pengiriman',
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => EditShipmentPage(shipmentId: document.id),
                                      ),
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete, color: Colors.red),
                                  tooltip: 'Hapus Pengiriman',
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: Text("Konfirmasi"),
                                        content: Text("Yakin ingin menghapus pengiriman ini beserta detailnya?"),
                                        actions: [
                                          TextButton(
                                            child: Text("Batal"),
                                            onPressed: () => Navigator.pop(context, false),
                                          ),
                                          ElevatedButton(
                                            child: Text("Hapus"),
                                            onPressed: () => Navigator.pop(context, true),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirm == true) {
                                      await deleteShipment(document.id);
                                    }
                                  },
                                ),
                                data['synced'] == true
                                    ? Icon(Icons.cloud_done, color: Colors.green)
                                    : Icon(Icons.cloud_off, color: Colors.grey),
                              ],
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ShipmentDetailsPage(shipmentId: document.id),
                                ),
                              );
                            },
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
      ),
    );
  }
}
