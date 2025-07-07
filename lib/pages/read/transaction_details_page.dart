import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TransactionDetailsPage extends StatelessWidget {
  final String transactionId;

  TransactionDetailsPage({required this.transactionId});

  @override
  Widget build(BuildContext context) {
    CollectionReference detailsRef = FirebaseFirestore.instance
        .collection('purchaseGoodsReceipts')
        .doc(transactionId)
        .collection('details');

    return Scaffold(
      appBar: AppBar(
        title: Text('Detail Transaksi'),
      ),
      body: StreamBuilder<QuerySnapshot>(
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
              final data = doc.data()! as Map<String, dynamic>;
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
    );
  }
}