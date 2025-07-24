import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ExpensesPage extends StatefulWidget {
  const ExpensesPage({Key? key}) : super(key: key);

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isSubmitting = false;
  String? _selectedReasonFilter = 'All';
  List<String> _reasonOptions = ['All'];

  @override
  void initState() {
    super.initState();
    _fetchReasons();
  }

  Future<void> _fetchReasons() async {
    final snapshot = await FirebaseFirestore.instance.collection('expenses').get();
    final reasons = snapshot.docs.map((doc) => (doc.data() as Map<String, dynamic>)['reason']?.toString() ?? '').where((r) => r.isNotEmpty).toSet().toList();
    setState(() {
      _reasonOptions = ['All', ...reasons];
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      await FirebaseFirestore.instance.collection('expenses').add({
        'amount': double.parse(_amountController.text.trim()),
        'reason': _reasonController.text.trim(),
        'date': Timestamp.fromDate(_selectedDate),
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expense saved!'), backgroundColor: Colors.green),
      );
      // Clear the form for next entry
      _amountController.clear();
      _reasonController.clear();
      setState(() { _selectedDate = DateTime.now(); });
      await _fetchReasons();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Expense'),
        backgroundColor: theme.primaryColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          children: [
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Add Reason box above Amount
                  TextFormField(
                    controller: _reasonController,
                    decoration: const InputDecoration(
                      labelText: 'Reason',
                      prefixIcon: Icon(Icons.info_outline),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.text,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Enter reason';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _amountController,
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      prefixIcon: Icon(Icons.currency_rupee),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Enter amount';
                      final d = double.tryParse(value);
                      if (d == null || d <= 0) return 'Enter valid amount';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Date: ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.calendar_today),
                        label: const Text('Pick Date'),
                        onPressed: _pickDate,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _saveExpense,
                    icon: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.save),
                    label: const Text('Save Expense', style: TextStyle(fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 3,
                    ),
                  ),
                  // Filter dropdown below save button
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedReasonFilter,
                    items: _reasonOptions.map((reason) => DropdownMenuItem(
                      value: reason,
                      child: Text(reason),
                    )).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedReasonFilter = val;
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: 'Filter by Reason',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.filter_alt),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('expenses')
                    .orderBy('date', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error:  ${snapshot.error}'));
                  }
                  final docs = snapshot.data?.docs ?? [];
                  // Filter docs by selected reason
                  final filteredDocs = _selectedReasonFilter == 'All'
                      ? docs
                      : docs.where((doc) => (doc.data() as Map<String, dynamic>)['reason'] == _selectedReasonFilter).toList();
                  if (filteredDocs.isEmpty) {
                    return const Center(child: Text('No expenses found.'));
                  }
                  return ListView.separated(
                    itemCount: filteredDocs.length,
                    separatorBuilder: (context, i) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final data = filteredDocs[i].data() as Map<String, dynamic>;
                      final date = (data['date'] as Timestamp?)?.toDate();
                      return Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        child: ListTile(
                          leading: const Icon(Icons.currency_rupee, color: Colors.teal),
                          title: Text('₹ ${data['amount'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if ((data['reason'] ?? '').toString().isNotEmpty)
                                Text('Reason: ${data['reason']}'),
                              if (date != null)
                                Text('Date: ${date.day}/${date.month}/${date.year}'),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
} 