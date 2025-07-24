import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
// No need for 'dart:math' as we are not generating random IDs

class AddCustomerPage extends StatefulWidget {
  const AddCustomerPage({Key? key}) : super(key: key);

  @override
  State<AddCustomerPage> createState() => _AddCustomerPageState();
}

class _AddCustomerPageState extends State<AddCustomerPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _milkPriceController = TextEditingController();
  final TextEditingController _userIdController = TextEditingController(); // Keep this for manual input
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadMilkPrice();
    // Removed _generateUserId() call here
  }

  Future<void> _loadMilkPrice() async {
    final prefs = await SharedPreferences.getInstance();
    final price = prefs.getString('milkPrice') ?? '';
    _milkPriceController.text = price;
  }

  Future<void> _saveMilkPrice(String price) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('milkPrice', price);
  }

  // Removed the _generateUserId function entirely

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _milkPriceController.dispose();
    _userIdController.dispose();
    super.dispose();
  }

  Future<void> _saveCustomer() async {
    if (!_formKey.currentState!.validate()) return; // Validate form fields first
    
    setState(() => _isSubmitting = true);

    final enteredUserId = _userIdController.text.trim();

    try {
      // --- Start Uniqueness Check ---
      final querySnapshot = await FirebaseFirestore.instance
          .collection('customers')
          .where('userId', isEqualTo: enteredUserId)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        // If documents are found, it means the userId already exists
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User ID already exists. Please enter a unique ID.'),
            backgroundColor: Colors.red,
          ),
        );
        return; // Stop the save process
      }
      // --- End Uniqueness Check ---

      await _saveMilkPrice(_milkPriceController.text.trim());
      await FirebaseFirestore.instance.collection('customers').add({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'milkPrice': _milkPriceController.text.trim(),
        'userId': enteredUserId, // Use the manually entered and validated ID
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer added successfully'), backgroundColor: Colors.green),
      );
      // Clear form for a new entry, keeping milk price
      _formKey.currentState?.reset();
      _nameController.clear();
      _phoneController.clear();
      _addressController.clear();
      _userIdController.clear(); // Clear User ID for the next manual entry
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
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
        title: const Text('Add Customer'),
        elevation: 0,
        backgroundColor: theme.primaryColor,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
        child: Column(
          children: [
            Card(
              elevation: 6,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Customer Details',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.primaryColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Name',
                          prefixIcon: const Icon(Icons.person, color: Colors.teal),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        validator: (value) => value == null || value.trim().isEmpty ? 'Please enter name' : null,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _phoneController,
                        decoration: InputDecoration(
                          labelText: 'Phone Number',
                          prefixIcon: const Icon(Icons.phone, color: Colors.teal),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        keyboardType: TextInputType.phone,
                        validator: (value) => value == null || value.trim().isEmpty ? 'Please enter phone number' : null,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _addressController,
                        decoration: InputDecoration(
                          labelText: 'Address',
                          prefixIcon: const Icon(Icons.home, color: Colors.teal),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        validator: (value) => value == null || value.trim().isEmpty ? 'Please enter address' : null,
                        textInputAction: TextInputAction.done,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _milkPriceController,
                        decoration: InputDecoration(
                          labelText: 'Milk Price',
                          prefixIcon: const Icon(Icons.currency_rupee, color: Colors.teal),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        validator: (value) => value == null || value.trim().isEmpty ? 'Please enter milk price' : null,
                        onChanged: (value) {
                          _saveMilkPrice(value);
                        },
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _userIdController,
                        decoration: InputDecoration(
                          labelText: 'User ID',
                          prefixIcon: const Icon(Icons.confirmation_number, color: Colors.teal),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        validator: (value) => value == null || value.trim().isEmpty ? 'Please enter User ID' : null,
                        keyboardType: TextInputType.text, // Allow any text for ID, not just numbers
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 22),
                      ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : _saveCustomer,
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
                        label: const Text('Save Customer', style: TextStyle(fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                const Icon(Icons.people, color: Colors.teal),
                const SizedBox(width: 8),
                Text(
                  'Customer List',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('customers').orderBy('createdAt', descending: true).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Center(child: Text('No customers found.'));
                  }
                  return ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (context, i) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final data = docs[i].data() as Map<String, dynamic>;
                      return Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.teal.shade100,
                            child: const Icon(Icons.person, color: Colors.teal),
                          ),
                          title: Text(
                            data['name'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(Icons.phone, size: 16, color: Colors.teal),
                                  const SizedBox(width: 4),
                                  Text(data['phone'] ?? ''),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(Icons.home, size: 16, color: Colors.teal),
                                  const SizedBox(width: 4),
                                  Expanded(child: Text(data['address'] ?? '')),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(Icons.currency_rupee, size: 16, color: Colors.teal),
                                  const SizedBox(width: 4),
                                  Text('Milk Price: ₹' + (data['milkPrice'] ?? '')),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(Icons.confirmation_number, size: 16, color: Colors.teal),
                                  const SizedBox(width: 4),
                                  Text('User ID: ' + (data['userId'] ?? '')), // Display the manually entered User ID
                                ],
                              ),
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