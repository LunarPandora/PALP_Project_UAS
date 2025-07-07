import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uts_flutter/pages/add/add_warehouse.dart';

class WarehousesPage extends StatelessWidget {
  final DocumentReference storeRef = FirebaseFirestore.instance.doc('stores/2');

  @override
  Widget build(BuildContext context) {  
    return Scaffold(
      appBar: AppBar(
        title: Text('Warehouse Toko'),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            tooltip: "Tambah Warehouse",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AddWarehousePage()),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('warehouses')
            .where('store_ref', isEqualTo: storeRef)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('Tidak ada warehouse untuk stores/2'));
          }

          final warehouses = snapshot.data!.docs;

          return ListView.builder(
            itemCount: warehouses.length,
            itemBuilder: (context, index) {
              final productDoc = warehouses[index];
              final data = productDoc.data() as Map<String, dynamic>;

              return ListTile(
                title: Text(data['name'] ?? 'Tanpa Nama Warehouse'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit, color: Colors.blue),
                      onPressed: () {
                        _showEditDialog(context, productDoc.id, data['name']);
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text('Hapus Warehouse'),
                            content: Text('Yakin ingin menghapus warehouse ini?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: Text('Batal'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: Text('Hapus'),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true) {
                          await FirebaseFirestore.instance
                              .collection('warehouses')
                              .doc(productDoc.id)
                              .delete();
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showEditDialog(BuildContext context, String productId, String currentName) {
    final TextEditingController _editController =
        TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Warehouse'),
        content: TextField(
          controller: _editController,
          decoration: InputDecoration(labelText: 'Nama Warehouse'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal'),
          ),
          TextButton(
            onPressed: () async {
              final newName = _editController.text.trim();
              if (newName.isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('warehouses')
                    .doc(productId)
                    .update({'name': newName});
              }
              Navigator.pop(context);
            },
            child: Text('Simpan'),
          ),
        ],
      ),
    );
  }
}
