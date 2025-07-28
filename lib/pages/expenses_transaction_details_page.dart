import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ExpensesTransactionDetailsPage extends StatefulWidget {
  const ExpensesTransactionDetailsPage({Key? key}) : super(key: key);

  @override
  State<ExpensesTransactionDetailsPage> createState() => _ExpensesTransactionDetailsPageState();
}

class _ExpensesTransactionDetailsPageState extends State<ExpensesTransactionDetailsPage> {
  String? _selectedVendorName;
  List<QueryDocumentSnapshot> _expenses = [];
  List<QueryDocumentSnapshot> _payments = [];
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        title: const Text('Expenses Transaction'),
        elevation: 0,
        backgroundColor: theme.primaryColor,
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          // Vendor Selection
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('expenses').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(child: Text('No expenses found'));
                }

                // Extract unique vendor names
                final vendorNames = docs
                    .map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return data['vendorName']?.toString() ?? '';
                    })
                    .where((name) => name.isNotEmpty)
                    .toSet()
                    .toList()
                  ..sort();

                return DropdownButtonFormField<String>(
                  value: _selectedVendorName,
                  decoration: InputDecoration(
                    labelText: 'Select Vendor',
                    prefixIcon: const Icon(Icons.business),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: vendorNames.map((vendorName) {
                    return DropdownMenuItem<String>(
                      value: vendorName,
                      child: Text(vendorName),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedVendorName = value;
                      });
                      _loadVendorTransactions(value);
                    }
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          if (_selectedVendorName != null) ...[
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
                    'Transaction Summary for $_selectedVendorName',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSummaryRow('Total Expenses', _calculateTotalExpenses(), Colors.red),
                  _buildSummaryRow('Payments Done', _calculateTotalPayments(), Colors.green),
                  _buildSummaryRow('Remaining Amount', _calculateRemaining(), Colors.orange, isBold: true),
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
                      Icons.business,
                      size: 80,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Select a vendor to view transactions',
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
            label.contains('Number') || label.contains('Average') 
                ? amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2)
                : '₹${amount.toStringAsFixed(2)}',
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
        // Make Payment Button
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _selectedVendorName != null ? _showMakePaymentDialog : null,
            icon: const Icon(Icons.payments),
            label: const Text('Make Payment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Transactions List
        Expanded(
          child: _buildTransactionsList(),
        ),
      ],
    );
  }

  Widget _buildTransactionsList() {
    if (_expenses.isEmpty && _payments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No transactions found for $_selectedVendorName',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    // Combine and sort all transactions
    List<Map<String, dynamic>> allTransactions = [];
    
    // Add expenses
    for (var doc in _expenses) {
      final data = doc.data() as Map<String, dynamic>;
      allTransactions.add({
        ...data,
        'id': doc.id,
        'type': 'expense',
        'timestamp': data['date'] as Timestamp?,
      });
    }
    
    // Add payments
    for (var doc in _payments) {
      final data = doc.data() as Map<String, dynamic>;
      allTransactions.add({
        ...data,
        'id': doc.id,
        'type': 'payment',
        'timestamp': data['paymentDate'] as Timestamp?,
      });
    }
    
    // Sort by timestamp (newest first)
    allTransactions.sort((a, b) {
      final aTime = a['timestamp'] as Timestamp?;
      final bTime = b['timestamp'] as Timestamp?;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: allTransactions.length,
      itemBuilder: (context, index) {
        final transaction = allTransactions[index];
        final isExpense = transaction['type'] == 'expense';
        final amount = transaction['amount']?.toString() ?? '0';
        final timestamp = transaction['timestamp'] as Timestamp?;
        final date = timestamp?.toDate();
        final createdAt = (transaction['createdAt'] as Timestamp?)?.toDate();

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isExpense ? Colors.red.shade50 : Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isExpense ? Icons.currency_rupee : Icons.payments,
                color: isExpense ? Colors.red.shade700 : Colors.green.shade700,
                size: 24,
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    '${isExpense ? '-' : '+'}₹$amount',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: isExpense ? Colors.red.shade700 : Colors.green.shade700,
                    ),
                  ),
                ),
                if (date != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      DateFormat('dd/MM/yyyy').format(date),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  isExpense 
                      ? 'Expense: ${transaction['reason']?.toString() ?? 'No reason'}'
                      : 'Payment',
                  style: const TextStyle(fontSize: 14),
                ),
                if (createdAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Added: ${DateFormat('dd/MM/yyyy HH:mm').format(createdAt)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _loadVendorTransactions(String vendorName) {
    setState(() => _isLoading = true);
    
    // Load expenses
    FirebaseFirestore.instance
        .collection('expenses')
        .where('vendorName', isEqualTo: vendorName)
        .orderBy('date', descending: true)
        .get()
        .then((expensesSnapshot) {
          // Load payments
          FirebaseFirestore.instance
              .collection('payments')
              .where('vendorName', isEqualTo: vendorName)
              .orderBy('paymentDate', descending: true)
              .get()
              .then((paymentsSnapshot) {
                setState(() {
                  _expenses = expensesSnapshot.docs;
                  _payments = paymentsSnapshot.docs;
                  _isLoading = false;
                });
              })
              .catchError((error) {
                setState(() {
                  _expenses = expensesSnapshot.docs;
                  _payments = [];
                  _isLoading = false;
                });
                print('Error loading payments: $error');
              });
        })
        .catchError((error) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error loading transactions: $error'),
              backgroundColor: Colors.red,
            ),
          );
        });
  }

  double _calculateTotalExpenses() {
    return _expenses.fold(0.0, (sum, doc) {
      final data = doc.data() as Map<String, dynamic>;
      return sum + ((data['amount'] as num?)?.toDouble() ?? 0.0);
    });
  }

  double _calculateTotalPayments() {
    return _payments.fold(0.0, (sum, doc) {
      final data = doc.data() as Map<String, dynamic>;
      return sum + ((data['amount'] as num?)?.toDouble() ?? 0.0);
    });
  }

  double _calculateRemaining() {
    return _calculateTotalExpenses() - _calculateTotalPayments();
  }

  void _showAddExpenseDialog() {
    // Navigate to Add Expenses page
    Navigator.pop(context);
  }

  void _showMakePaymentDialog() {
    final amountController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Make Payment'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixText: '₹',
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('Payment Date'),
                  subtitle: Text(DateFormat('dd/MM/yyyy').format(selectedDate)),
                  trailing: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        selectedDate = date;
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text);
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid amount')),
                  );
                  return;
                }

                try {
                  await FirebaseFirestore.instance.collection('payments').add({
                    'vendorName': _selectedVendorName,
                    'amount': amount,
                    'paymentDate': Timestamp.fromDate(selectedDate),
                    'createdAt': FieldValue.serverTimestamp(),
                  });

                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Payment recorded successfully')),
                  );
                  
                  // Refresh the data
                  if (_selectedVendorName != null) {
                    _loadVendorTransactions(_selectedVendorName!);
                  }
                } catch (e) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error recording payment: $e')),
                  );
                }
              },
              child: const Text('Save Payment'),
            ),
          ],
        );
      },
    );
  }
} 