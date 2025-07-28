import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AddSalesPage extends StatefulWidget {
  const AddSalesPage({Key? key}) : super(key: key);

  @override
  State<AddSalesPage> createState() => _AddSalesPageState();
}

class _AddSalesPageState extends State<AddSalesPage> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedCustomerId;
  String? _selectedCustomerName;
  Map<String, dynamic>? _selectedCustomerData;
  final TextEditingController _litersController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  bool _isSubmitting = false;
  double _totalPrice = 0.0;
  String _globalMilkPrice = '';

  void _updateTotalPrice() {
    final liters = double.tryParse(_litersController.text.trim()) ?? 0.0;
    final pricePerLiter = double.tryParse(_priceController.text.trim()) ?? 0.0;
    setState(() {
      _totalPrice = liters * pricePerLiter;
    });
  }

  Future<void> _loadGlobalMilkPrice() async {
    final prefs = await SharedPreferences.getInstance();
    final price = prefs.getString('globalMilkPrice');
    print('DEBUG: Loading global milk price in AddSalesPage: $price');
    
    setState(() {
      if (price != null && price.isNotEmpty && price != '0') {
        print('DEBUG: Setting global milk price in AddSalesPage: $price');
        _globalMilkPrice = price;
        // Set the price controller to the global price if it's empty
        if (_priceController.text.isEmpty) {
          _priceController.text = price;
        }
      } else {
        print('DEBUG: No valid global milk price found in AddSalesPage');
        _globalMilkPrice = '';
      }
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
    _loadGlobalMilkPrice();
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
        title: const Text('Add Sales'),
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
                                // Set the price field to the customer's milk price if available, otherwise use global price
                                final milkPrice = data['milkPrice'];
                                if (milkPrice != null && milkPrice.toString().isNotEmpty && milkPrice.toString() != '0') {
                                  _priceController.text = milkPrice.toString();
                                } else if (_globalMilkPrice.isNotEmpty && _globalMilkPrice != '0') {
                                  _priceController.text = _globalMilkPrice;
                                } else {
                                  _priceController.clear();
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
                      if (_globalMilkPrice.isNotEmpty && _globalMilkPrice != '0')
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            'Global price: ₹$_globalMilkPrice',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green.shade700,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
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
          ],
        ),
      ),
    );
  }
}