import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class CustomerTransactionPage extends StatefulWidget {
  const CustomerTransactionPage({Key? key}) : super(key: key);

  @override
  State<CustomerTransactionPage> createState() => _CustomerTransactionPageState();
}

class _CustomerTransactionPageState extends State<CustomerTransactionPage> {
  String? _selectedCustomerId;
  String? _selectedCustomerName;
  List<QueryDocumentSnapshot> _payments = [];
  List<QueryDocumentSnapshot> _sales = [];
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        title: const Text('Customer Transaction'),
        elevation: 0,
        backgroundColor: theme.primaryColor,
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          // Customer Selection
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('customers').orderBy('name').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(child: Text('No customers found'));
                }

                return DropdownButtonFormField<String>(
                  value: _selectedCustomerId,
                  decoration: InputDecoration(
                    labelText: 'Select Customer',
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return DropdownMenuItem<String>(
                      value: doc.id,
                      child: Text(data['name'] ?? 'Unknown'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedCustomerId = value;
                        final selectedDoc = docs.firstWhere((doc) => doc.id == value);
                        final data = selectedDoc.data() as Map<String, dynamic>;
                        _selectedCustomerName = data['name'];
                      });
                      _loadCustomerTransactions(value);
                    }
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          if (_selectedCustomerId != null) ...[
            // Transaction Summary
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 5,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Transaction Summary for $_selectedCustomerName',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSummaryRow('Total Purchase', _calculateTotalSales(), Colors.blue),
                  _buildSummaryRow('Total Payments', _calculateTotalPaid(), Colors.green),
                  _buildSummaryRow('Remaining Amount', _calculateRemaining(), Colors.red, isBold: true),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Transaction Details
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildTransactionDetails(),
            ),
          ] else ...[
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person_search,
                      size: 80,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Select a customer to view transactions',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount, Color color, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            'Rs. ${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionDetails() {
    return Column(
      children: [
        // Take Payment Button
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _selectedCustomerId != null ? _showTakePaymentDialog : null,
            icon: const Icon(Icons.payments),
            label: const Text('Take Payment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Payments List
        Expanded(
          child: _buildPaymentsList(),
        ),
      ],
    );
  }

  Widget _buildPaymentsList() {
    print('Building payments list. Count: ${_payments.length}');
    
    if (_payments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.payments, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text('No payments found'),
            const SizedBox(height: 8),
            Text(
              'Selected Customer ID: ${_selectedCustomerId ?? "None"}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Try creating a test payment to see data',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _payments.length,
      itemBuilder: (context, index) {
        final payment = _payments[index];
        final data = payment.data() as Map<String, dynamic>;
        final date = (data['receivedAt'] as Timestamp?)?.toDate();
        final amount = data['amount'] ?? 0;

        print('Payment $index: ID=${payment.id}, Amount=$amount, Date=$date');

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.green.shade100,
              child: Icon(Icons.payments, color: Colors.green.shade700),
            ),
            title: Text('Rs. ${amount.toStringAsFixed(2)}'),
            subtitle: Text(
              'Payment received\n${date != null ? DateFormat('dd/MM/yyyy HH:mm').format(date) : 'No date'}',
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red, size: 20),
              onPressed: () => _deletePayment(payment.id, amount),
            ),
          ),
        );
      },
    );
  }

  Future<void> _loadCustomerTransactions(String customerId) async {
    setState(() {
      _isLoading = true;
    });

    try {
      print('Loading transactions for customer: $customerId');
      
      // Load sales
      final salesSnapshot = await FirebaseFirestore.instance
          .collection('sales')
          .where('customerId', isEqualTo: customerId)
          .orderBy('createdAt', descending: true)
          .get();

      print('Found ${salesSnapshot.docs.length} sales');
      
      // Load payments
      final paymentsSnapshot = await FirebaseFirestore.instance
          .collection('payments')
          .where('customerId', isEqualTo: customerId)
          .orderBy('receivedAt', descending: true)
          .get();

      print('Found ${paymentsSnapshot.docs.length} payments');
      
      setState(() {
        _sales = salesSnapshot.docs;
        _payments = paymentsSnapshot.docs;
        _isLoading = false;
      });
      
      print('Sales loaded: ${_sales.length}, Payments loaded: ${_payments.length}');
      
    } catch (e) {
      print('Error loading transactions: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading transactions: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  double _calculateTotalSales() {
    double total = 0;
    for (final sale in _sales) {
      final data = sale.data() as Map<String, dynamic>;
      final liters = data['liters'] ?? 0;
      final price = data['price'] ?? 0;
      total += liters * price;
    }
    return total;
  }

  double _calculateTotalPaid() {
    double total = 0;
    for (final payment in _payments) {
      final data = payment.data() as Map<String, dynamic>;
      total += data['amount'] ?? 0;
    }
    return total;
  }

  double _calculateRemaining() {
    return _calculateTotalSales() - _calculateTotalPaid();
  }

  Future<void> _showTakePaymentDialog() async {
    final amountController = TextEditingController();
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Take Payment from $_selectedCustomerName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Total Purchase: Rs. ${_calculateTotalSales().toStringAsFixed(2)}'),
            Text('Total Paid: Rs. ${_calculateTotalPaid().toStringAsFixed(2)}'),
            Text('Remaining Amount: Rs. ${_calculateRemaining().toStringAsFixed(2)}'),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Payment Amount',
                prefixIcon: Icon(Icons.currency_rupee),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = double.tryParse(amountController.text.trim());
              if (value != null && value > 0) {
                Navigator.pop(context, value);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid amount'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
            child: const Text('Take Payment'),
          ),
        ],
      ),
    );

    if (result != null && result > 0) {
      await _takePayment(result);
    }
  }

  Future<void> _takePayment(double amount) async {
    try {
      await FirebaseFirestore.instance.collection('payments').add({
        'customerId': _selectedCustomerId,
        'customerName': _selectedCustomerName,
        'amount': amount,
        'receivedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment of Rs. ${amount.toStringAsFixed(2)} received!'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Reload transactions
      if (_selectedCustomerId != null) {
        _loadCustomerTransactions(_selectedCustomerId!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error taking payment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deletePayment(String paymentId, double amount) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Payment'),
        content: Text('Are you sure you want to delete this payment of Rs. ${amount.toStringAsFixed(2)}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('payments')
          .doc(paymentId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Reload transactions
      if (_selectedCustomerId != null) {
        _loadCustomerTransactions(_selectedCustomerId!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting payment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


} 