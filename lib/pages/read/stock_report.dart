import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class StockReportPage extends StatefulWidget {
  @override
  _StockReportPageState createState() => _StockReportPageState();
}

class _StockReportPageState extends State<StockReportPage> {
  DateTime? _startDate;
  DateTime? _endDate;
  bool _showAll = false;
  DocumentReference? _selectedProductRef;
  List<DocumentSnapshot> _products = [];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    QuerySnapshot snapshot = await FirebaseFirestore.instance.collection('products').get();
    setState(() {
      _products = snapshot.docs;
    });
  }

  Future<List<Map<String, dynamic>>> _fetchStockReports({bool showAll = false}) async {
    if (_selectedProductRef == null) return [];

    String? start;
    String? end;

    if (!showAll && _startDate != null && _endDate != null) {
      start = DateFormat('yyyy-MM-dd').format(_startDate!);
      end = DateFormat('yyyy-MM-dd').format(_endDate!);
    }

    int initialStockIn = 0;
    int initialStockOut = 0;

    if (!showAll && start != null) {
      QuerySnapshot inBeforeSnapshot = await FirebaseFirestore.instance
          .collection('purchaseGoodsReceipts')
          .where('post_date', isLessThan: start)
          .get();

      for (var doc in inBeforeSnapshot.docs) {
        QuerySnapshot detailSnapshot = await doc.reference.collection('details')
            .where('product_ref', isEqualTo: _selectedProductRef)
            .get();
        for (var detail in detailSnapshot.docs) {
          initialStockIn += (detail.get('qty') as num).toInt();
        }
      }

      QuerySnapshot outBeforeSnapshot = await FirebaseFirestore.instance
          .collection('shipmentReceipts')
          .where('post_date', isLessThan: start)
          .get();

      for (var doc in outBeforeSnapshot.docs) {
        QuerySnapshot detailSnapshot = await doc.reference.collection('details')
            .where('product_ref', isEqualTo: _selectedProductRef)
            .get();
        for (var detail in detailSnapshot.docs) {
          initialStockOut += (detail.get('qty') as num).toInt();
        }
      }
    }

    int initialStock = initialStockIn - initialStockOut;
    List<Map<String, dynamic>> reports = [];

    if (!showAll) {
      reports.add({
        'date': '-',
        'no_form': 'Stok Awal',
        'in_qty': 0,
        'out_qty': 0,
        'initial_stock': initialStock,
      });
    }

    Query inQuery = FirebaseFirestore.instance.collection('purchaseGoodsReceipts');
    Query outQuery = FirebaseFirestore.instance.collection('shipmentReceipts');

    if (!showAll && start != null && end != null) {
      inQuery = inQuery.where('post_date', isGreaterThanOrEqualTo: start).where('post_date', isLessThanOrEqualTo: end);
      outQuery = outQuery.where('post_date', isGreaterThanOrEqualTo: start).where('post_date', isLessThanOrEqualTo: end);
    }

    QuerySnapshot inSnapshot = await inQuery.orderBy('post_date').get();
    for (var doc in inSnapshot.docs) {
      int totalQty = 0;
      QuerySnapshot detailSnapshot = await doc.reference.collection('details')
          .where('product_ref', isEqualTo: _selectedProductRef)
          .get();
      for (var detail in detailSnapshot.docs) {
        totalQty += (detail.get('qty') as num).toInt();
      }
      if(totalQty > 0) {
        reports.add({
          'date': doc.get('post_date'),
          'no_form': doc.get('no_form'),
          'in_qty': totalQty,
          'out_qty': 0,
        });
      }
    }

    QuerySnapshot outSnapshot = await outQuery.orderBy('post_date').get();
    for (var doc in outSnapshot.docs) {
      int totalQty = 0;
      QuerySnapshot detailSnapshot = await doc.reference.collection('details')
          .where('product_ref', isEqualTo: _selectedProductRef)
          .get();
      for (var detail in detailSnapshot.docs) {
        totalQty += (detail.get('qty') as num).toInt();
      }
      if(totalQty > 0) {
        reports.add({
          'date': doc.get('post_date'),
          'no_form': doc.get('no_form'),
          'in_qty': 0,
          'out_qty': totalQty,
        });
      }
    }

    reports.sort((a, b) {
      if (a['date'] == '-') return -1;
      if (b['date'] == '-') return 1;
      return a['date'].compareTo(b['date']);
    });

    return reports;
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) setState(() {
      _startDate = picked;
      _showAll = false;
    });
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) setState(() {
      _endDate = picked;
      _showAll = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    String startDateText = _startDate != null ? DateFormat('yyyy-MM-dd').format(_startDate!) : 'Pilih Tanggal Awal';
    String endDateText = _endDate != null ? DateFormat('yyyy-MM-dd').format(_endDate!) : 'Pilih Tanggal Akhir';

    return Scaffold(
      appBar: AppBar(title: Text('Laporan Stok Masuk & Keluar')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            DropdownButton<DocumentReference>(
              hint: Text("Pilih Produk"),
              value: _selectedProductRef,
              items: _products.map((doc) {
                return DropdownMenuItem<DocumentReference>(
                  value: doc.reference,
                  child: Text(doc['name']),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedProductRef = value;
                  _showAll = false;
                });
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton(onPressed: () => _selectStartDate(context), child: Text(startDateText)),
                ElevatedButton(onPressed: () => _selectEndDate(context), child: Text(endDateText)),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _showAll = true;
                      _startDate = null;
                      _endDate = null;
                    });
                  },
                  child: Text('Tampilkan Semua'),
                ),
              ],
            ),
            SizedBox(height: 20),
            Expanded(
              child: (_selectedProductRef == null)
                  ? Center(child: Text('Silakan pilih produk.'))
                  : (_startDate == null || _endDate == null) && !_showAll
                      ? Center(child: Text('Silakan pilih periode tanggal.'))
                      : FutureBuilder<List<Map<String, dynamic>>>(
                          future: _fetchStockReports(showAll: _showAll),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return Center(child: CircularProgressIndicator());
                            }
                            if (!snapshot.hasData || snapshot.data!.isEmpty) {
                              return Center(child: Text('Tidak ada data.'));
                            }

                            final reports = snapshot.data!;
                            int cumulativeStock = 0;

                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.vertical, // Tambahan scroll vertikal di sini
                                child: DataTable(
                                  columns: const [
                                    DataColumn(label: Text('Tanggal')),
                                    DataColumn(label: Text('No Form')),
                                    DataColumn(label: Text('Masuk')),
                                    DataColumn(label: Text('Keluar')),
                                    DataColumn(label: Text('Saldo')),
                                  ],
                                  rows: reports.map((report) {
                                    if (report['no_form'] == 'Stok Awal') {
                                      cumulativeStock = report['initial_stock'];
                                      return DataRow(cells: [
                                        DataCell(Text('')),
                                        DataCell(Text('Stok Awal')),
                                        DataCell(Text('')),
                                        DataCell(Text('')),
                                        DataCell(Text(cumulativeStock.toString())),
                                      ]);
                                    } else {
                                      cumulativeStock += (report['in_qty'] as int) - (report['out_qty'] as int);
                                      return DataRow(cells: [
                                        DataCell(Text(report['date'] ?? '-')),
                                        DataCell(Text(report['no_form'])),
                                        DataCell(Text(report['in_qty'].toString())),
                                        DataCell(Text(report['out_qty'].toString())),
                                        DataCell(Text(cumulativeStock.toString())),
                                      ]);
                                    }
                                  }).toList(),
                                ),
                              ),
                            );
                          }
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
