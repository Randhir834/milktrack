import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SalesPage extends StatefulWidget {
  const SalesPage({Key? key}) : super(key: key);

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedCustomerId;
  String? _selectedCustomerName;
  Map<String, dynamic>? _selectedCustomerData;
  final TextEditingController _litersController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  bool _isSubmitting = false;
  double _totalPrice = 0.0;

  void _updateTotalPrice() {
    final liters = double.tryParse(_litersController.text.trim()) ?? 0.0;
    final pricePerLiter = double.tryParse(_priceController.text.trim()) ?? 0.0;
    setState(() {
      _totalPrice = liters * pricePerLiter;
    });
  }

  @override
  void dispose() {
    _litersController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _litersController.addListener(_updateTotalPrice);
    _priceController.addListener(_updateTotalPrice);
  }

  Future<void> _saveSale() async {
    if (!_formKey.currentState!.validate() || _selectedCustomerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields and select a customer.'), backgroundColor: Colors.orange),
      );
      return;
    }
    
    setState(() => _isSubmitting = true);

    try {
      // --- THIS IS THE CRUCIAL DEBUGGING CODE ---
      // It checks what the app thinks the user's status is.
      final user = FirebaseAuth.instance.currentUser;
      print('--- DEBUGGING USER PERMISSIONS ---');
      print('Current user UID: ' + (user?.uid ?? 'null'));
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          print('User document data: ' + userDoc.data().toString());
          print('User type from document: ' + (userDoc.data()?['type']?.toString() ?? 'null'));
        } else {
          print('User document does NOT exist in Firestore for this UID.');
        }
      }
      print('--- END DEBUGGING ---');
      // --- END OF DEBUGGING CODE ---

      await FirebaseFirestore.instance.collection('sales').add({
        'customerId': _selectedCustomerId,
        'customerName': _selectedCustomerName,
        'liters': double.parse(_litersController.text.trim()),
        'price': double.parse(_priceController.text.trim()),
        'createdAt': FieldValue.serverTimestamp(),
        'recordedByUid': user?.uid, // Optional: track who recorded the sale
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sale recorded successfully'), backgroundColor: Colors.green),
      );
      
      _formKey.currentState?.reset();
      _litersController.clear();
      // Removed: _priceController.clear(); // This line was removed
      // We keep the customer selected to allow for multiple entries.

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving sale: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        title: const Text('Record Sale'),
        backgroundColor: Colors.teal.shade700,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Sale Details',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.teal.shade800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('customers').orderBy('userId').snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (snapshot.hasError) {
                            return Center(child: Text('Error loading customers: ${snapshot.error}'));
                          }
                          final docs = snapshot.data?.docs ?? [];
                          if (docs.isEmpty) {
                            return const Text('No customers found. Please add a customer first.', textAlign: TextAlign.center);
                          }
                          return DropdownButtonFormField<String>(
                            value: _selectedCustomerId,
                            decoration: InputDecoration(
                              labelText: 'Select User ID',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              prefixIcon: const Icon(Icons.confirmation_number, color: Colors.teal),
                            ),
                            items: docs.map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              return DropdownMenuItem<String>(
                                value: doc.id,
                                child: Text(data['userId'] ?? 'No ID'),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() {
                                _selectedCustomerId = value;
                                final selectedDoc = docs.firstWhere((doc) => doc.id == value);
                                final data = selectedDoc.data() as Map<String, dynamic>;
                                _selectedCustomerName = data['name'];
                                _selectedCustomerData = data;
                                // Set the price field to the customer's milk price if available
                                final milkPrice = data['milkPrice'];
                                if (milkPrice != null && milkPrice.toString().isNotEmpty) {
                                  _priceController.text = milkPrice.toString();
                                } else {
                                  _priceController.clear(); // Price is cleared ONLY when customer changes
                                }
                              });
                            },
                            validator: (value) => value == null ? 'Please select a customer' : null,
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'Customer Name',
                          prefixIcon: const Icon(Icons.person, color: Colors.teal),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        controller: TextEditingController(text: _selectedCustomerName ?? ''),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _litersController,
                        decoration: InputDecoration(
                          labelText: 'Liters of Milk',
                          prefixIcon: const Icon(Icons.local_drink_outlined, color: Colors.teal),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return 'Please enter liters';
                          final d = double.tryParse(value);
                          if (d == null || d <= 0) return 'Enter a valid number';
                          return null;
                        },
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _priceController,
                        decoration: InputDecoration(
                          labelText: 'Price (per liter)',
                          prefixIcon: const Icon(Icons.currency_rupee, color: Colors.teal),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return 'Please enter price';
                          final d = double.tryParse(value);
                          if (d == null || d < 0) return 'Enter a valid price';
                          return null;
                        },
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _saveSale(),
                      ),
                     const SizedBox(height: 12),
                     Container(
                       padding: const EdgeInsets.symmetric(vertical: 8),
                       alignment: Alignment.centerLeft,
                       child: Text(
                         'Total: ₹${_totalPrice.toStringAsFixed(2)}',
                         style: theme.textTheme.titleMedium?.copyWith(
                           color: Colors.teal.shade800,
                           fontWeight: FontWeight.bold,
                         ),
                       ),
                     ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : _saveSale,
                        icon: _isSubmitting
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                            : const Icon(Icons.save_alt_outlined),
                        label: const Text('Save Sale', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal.shade600,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (_selectedCustomerId != null)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: Text('History for $_selectedCustomerName', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    ),
                    const Divider(height: 20),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('sales')
                            .where('customerId', isEqualTo: _selectedCustomerId)
                            .orderBy('createdAt', descending: true)
                            .snapshots(),
                        builder: (context, salesSnapshot) {
                          if (salesSnapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (salesSnapshot.hasError) {
                            return Center(child: Text('Error: ${salesSnapshot.error}', style: const TextStyle(color: Colors.red)));
                          }
                          final salesDocs = salesSnapshot.data?.docs ?? [];
                          if (salesDocs.isEmpty) {
                            return const Center(child: Text('No sales found for this customer.'));
                          }
                          // This part onwards is for displaying sales, payments, and balance.
                          // It will only render if the above stream is successful.
                          return _buildSalesAndPaymentsView(salesDocs);
                        },
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Helper widget to avoid deep nesting in the main build method
  Widget _buildSalesAndPaymentsView(List<QueryDocumentSnapshot> salesDocs) {
    double totalAmount = 0;
    for (final doc in salesDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final price = data['price'];
      final liters = data['liters'];
      double priceNum = 0;
      double litersNum = 0;
      if (price is num) priceNum = price.toDouble();
      else if (price is String) priceNum = double.tryParse(price) ?? 0;
      if (liters is num) litersNum = liters.toDouble();
      else if (liters is String) litersNum = double.tryParse(liters) ?? 0;
      totalAmount += priceNum * litersNum;
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('payments')
          .where('customerId', isEqualTo: _selectedCustomerId)
          .snapshots(),
      builder: (context, paymentsSnapshot) {
        if (paymentsSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (paymentsSnapshot.hasError) {
          return Center(child: Text('Error loading payments: ${paymentsSnapshot.error}', style: const TextStyle(color: Colors.red)));
        }

        final paymentDocs = paymentsSnapshot.data?.docs ?? [];
        double totalPaid = 0;
        for (final doc in paymentDocs) {
          final data = doc.data() as Map<String, dynamic>;
          final amount = data['amount'];
          if (amount is num) totalPaid += amount;
        }

        final remaining = totalAmount - totalPaid;

        return ListView.builder( // Changed Column to ListView.builder
          itemCount: salesDocs.length + 3, // Add 3 for the summary rows
          itemBuilder: (context, i) {
            if (i < salesDocs.length) {
              final data = salesDocs[i].data() as Map<String, dynamic>;
              final date = (data['createdAt'] as Timestamp?)?.toDate();
              return Card(
                elevation: 1,
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: Colors.teal.withOpacity(0.1), child: const Icon(Icons.receipt_long, color: Colors.teal)),
                  title: Text('₹ ${data['price'] ?? '0.0'} for ${data['liters'] ?? '0'} L'),
                  subtitle: date != null ? Text('${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}') : null,
                ),
              );
            } else if (i == salesDocs.length) {
              return const SizedBox(height: 10); // Space before the button
            } else if (i == salesDocs.length + 1) {
              return SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('Receive Payment'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _showReceivePaymentDialog(),
                ),
              );
            } else { // i == salesDocs.length + 2
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildBalanceRow('Total Sale:', '₹ ${totalAmount.toStringAsFixed(2)}', Colors.teal),
                        _buildBalanceRow('Total Paid:', '₹ ${totalPaid.toStringAsFixed(2)}', Colors.green.shade700),
                        _buildBalanceRow('Remaining:', '₹ ${remaining.toStringAsFixed(2)}', Colors.red, isBold: true),
                      ],
                    ),
                  ),
                ],
              );
            }
          },
        );
      },
    );
  }

  // Helper for displaying balance rows
  Widget _buildBalanceRow(String label, String value, Color color, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 16, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(fontSize: 16, color: color, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  // Helper for showing the payment dialog
  Future<void> _showReceivePaymentDialog() async {
    final amountController = TextEditingController();
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Receive Payment'),
        content: TextField(
          controller: amountController,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Amount Received', prefixIcon: Icon(Icons.currency_rupee)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            child: const Text('Save'),
            onPressed: () {
              final value = double.tryParse(amountController.text.trim());
              if (value != null && value > 0) {
                Navigator.pop(context, value);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid amount.'), backgroundColor: Colors.orange));
              }
            },
          ),
        ],
      ),
    );

    if (result != null && result > 0) {
      try {
        await FirebaseFirestore.instance.collection('payments').add({
          'customerId': _selectedCustomerId,
          'customerName': _selectedCustomerName,
          'amount': result,
          'receivedAt': FieldValue.serverTimestamp(),
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Payment of ₹${result.toStringAsFixed(2)} received!'), backgroundColor: Colors.green),
          );
        }
        // After payment, check if remaining is zero and delete all bills if so
        await _deleteBillsIfRemainingZero();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving payment: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  Future<void> _deleteBillsIfRemainingZero() async {
    // Calculate total sale and total paid
    final salesSnapshot = await FirebaseFirestore.instance
        .collection('sales')
        .where('customerId', isEqualTo: _selectedCustomerId)
        .get();
    double totalSale = 0;
    for (final doc in salesSnapshot.docs) {
      final data = doc.data();
      final price = data['price'];
      final liters = data['liters'];
      double priceNum = 0;
      double litersNum = 0;
      if (price is num) priceNum = price.toDouble();
      else if (price is String) priceNum = double.tryParse(price) ?? 0;
      if (liters is num) litersNum = liters.toDouble();
      else if (liters is String) litersNum = double.tryParse(liters) ?? 0;
      totalSale += priceNum * litersNum;
    }
    final paymentsSnapshot = await FirebaseFirestore.instance
        .collection('payments')
        .where('customerId', isEqualTo: _selectedCustomerId)
        .get();
    double totalPaid = 0;
    for (final doc in paymentsSnapshot.docs) {
      final data = doc.data();
      final amount = data['amount'];
      if (amount is num) totalPaid += amount;
      else if (amount is String) totalPaid += double.tryParse(amount) ?? 0;
    }
    final remaining = totalSale - totalPaid;
    if (remaining.abs() < 0.01) { // allow for floating point error
      // Delete all sales
      for (final doc in salesSnapshot.docs) {
        await doc.reference.delete();
      }
      // Delete all payments
      for (final doc in paymentsSnapshot.docs) {
        await doc.reference.delete();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All bills cleared and deleted for this customer!'), backgroundColor: Colors.green),
        );
      }
    }
  }
}