import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ShipmentDetailsPage extends StatelessWidget {
  final String shipmentId;

  const ShipmentDetailsPage({super.key, required this.shipmentId});

  @override
  Widget build(BuildContext context) {
    final DocumentReference shipmentRef = FirebaseFirestore.instance
        .collection('shipmentReceipts')
        .doc(shipmentId);

    final CollectionReference detailsRef = shipmentRef.collection('details');

    return Scaffold(
      appBar: AppBar(title: Text('Detail Pengiriman')),
      body: FutureBuilder<DocumentSnapshot>(
        future: shipmentRef.get(),
        builder: (context, shipmentSnapshot) {
          if (shipmentSnapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!shipmentSnapshot.hasData || !shipmentSnapshot.data!.exists) {
            return Center(child: Text('Data tidak ditemukan.'));
          }

          // final shipmentData = shipmentSnapshot.data!.data() as Map<String, dynamic>;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Text('No Form: ${shipmentData['no_form'] ?? '-'}'),
                    // Text('Tanggal Posting: ${shipmentData['post_date'] ?? '-'}'),
                    // Text('Grand Total: ${shipmentData['grandtotal'] ?? '-'}'),
                    // Text('Jumlah Item: ${shipmentData['item_total'] ?? '-'}'),
                    // SizedBox(height: 16),
                    Text('Detail Barang:', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: detailsRef.snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(child: Text("Tidak ada detail."));
                    }

                    return ListView(
                      children: snapshot.data!.docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return FutureBuilder<DocumentSnapshot>(
                          future: (data['product_ref'] as DocumentReference).get(),
                          builder: (context, productSnapshot) {
                            String productName = 'Memuat...';
                            if (productSnapshot.connectionState == ConnectionState.done) {
                              if (productSnapshot.hasData && productSnapshot.data!.exists) {
                                final productData = productSnapshot.data!.data() as Map<String, dynamic>;
                                productName = productData['name'] ?? 'Tidak diketahui';
                              } else {
                                productName = 'Produk tidak ditemukan';
                              }
                            }

                            return ListTile(
                              title: Text(productName),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Qty: ${data['qty']}"),
                                  Text("Price: ${data['price']}"),
                                  Text("Subtotal: ${data['subtotal']}"),
                                  Text("Unit: ${data['unit_name']}"),
                                ],
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
        },
      ),
    );
  }
}
