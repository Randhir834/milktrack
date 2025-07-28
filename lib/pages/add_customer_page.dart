import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AddCustomerPage extends StatefulWidget {
  final Map<String, dynamic>? existingCustomer;
  final String? documentId;
  
  const AddCustomerPage({
    Key? key, 
    this.existingCustomer,
    this.documentId,
  }) : super(key: key);

  @override
  State<AddCustomerPage> createState() => _AddCustomerPageState();
}

class _AddCustomerPageState extends State<AddCustomerPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _userIdController = TextEditingController();
  final TextEditingController _globalPriceController = TextEditingController();
  bool _isSubmitting = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.existingCustomer != null;
    _loadMilkPrice();
    if (_isEditing) {
      _initializeWithExistingData();
    }
  }

  void _initializeWithExistingData() {
    final customer = widget.existingCustomer!;
    _nameController.text = customer['name'] ?? '';
    _phoneController.text = customer['phone'] ?? '';
    _addressController.text = customer['address'] ?? '';
    _userIdController.text = customer['userId'] ?? '';
  }

  Future<void> _loadMilkPrice() async {
    final prefs = await SharedPreferences.getInstance();
    final price = prefs.getString('globalMilkPrice');
    print('DEBUG: Loading global milk price in AddCustomerPage: $price');
    
    // Always update the controller, even if price is null or empty
    if (price != null && price.isNotEmpty && price != '0') {
      print('DEBUG: Setting global price controller to: $price');
      setState(() {
        _globalPriceController.text = price;
      });
    } else {
      print('DEBUG: No valid global price found in AddCustomerPage, clearing controller');
      setState(() {
        _globalPriceController.clear();
      });
    }
  }

  Future<void> _saveGlobalMilkPrice(String price) async {
    final prefs = await SharedPreferences.getInstance();
    print('DEBUG: Attempting to save global milk price: $price');
    // Only save if price is not empty
    if (price.isNotEmpty && price != '0') {
      await prefs.setString('globalMilkPrice', price);
      print('DEBUG: Global milk price saved successfully: $price');
      
      // Verify the save by reading it back
      final savedPrice = prefs.getString('globalMilkPrice');
      print('DEBUG: Verification - Read back global milk price: $savedPrice');
    } else {
      print('DEBUG: Not saving global milk price - invalid value: $price');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _userIdController.dispose();
    _globalPriceController.dispose();
    super.dispose();
  }

  Future<void> _saveCustomer() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSubmitting = true);

    final enteredUserId = _userIdController.text.trim();

    try {
      // Check uniqueness only for new customers or if userId changed
      if (!_isEditing || (widget.existingCustomer?['userId'] != enteredUserId)) {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('customers')
            .where('userId', isEqualTo: enteredUserId)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User ID already exists. Please enter a unique ID.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      await _saveGlobalMilkPrice(_globalPriceController.text.trim());
      
      final customerData = {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'userId': enteredUserId,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_isEditing) {
        // Update existing customer
        await FirebaseFirestore.instance
            .collection('customers')
            .doc(widget.documentId)
            .update(customerData);
      } else {
        // Add new customer
        customerData['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance
            .collection('customers')
            .add(customerData);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing ? 'Customer updated successfully' : 'Customer added successfully'), 
          backgroundColor: Colors.green
        ),
      );
      
      if (!_isEditing) {
        // Clear form for new entry, keeping global price
        _formKey.currentState?.reset();
        _nameController.clear();
        _phoneController.clear();
        _addressController.clear();
        _userIdController.clear();
      } else {
        // Go back to previous screen after editing
        Navigator.pop(context, true);
      }
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
        title: Text(_isEditing ? 'Edit Customer' : 'Add Customer'),
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
                        _isEditing ? 'Edit Customer Details' : 'Customer Details',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.primaryColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 18),
                      // Global Price Setting
                      TextFormField(
                        controller: _globalPriceController,
                        decoration: InputDecoration(
                          labelText: 'Global Milk Price (₹)',
                          prefixIcon: const Icon(Icons.settings, color: Colors.orange),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: Colors.orange.shade50,
                          hintText: 'Set default price for all customers',
                        ),
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        textInputAction: TextInputAction.done,
                      ),
                      const SizedBox(height: 12),
                      // Separate Save Global Price Button
                      ElevatedButton.icon(
                        onPressed: () async {
                          final price = _globalPriceController.text.trim();
                          if (price.isEmpty || price == '0') {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter a valid price'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                            return;
                          }
                          await _saveGlobalMilkPrice(price);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Global milk price saved successfully'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.save),
                        label: const Text('Save Global Price', style: TextStyle(fontSize: 14)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade600,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Divider
                      Container(
                        height: 1,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 20),
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
                        textInputAction: TextInputAction.next,
                        maxLines: 2,
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
                        keyboardType: TextInputType.text,
                        textInputAction: TextInputAction.done,
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
                            : Icon(_isEditing ? Icons.update : Icons.save),
                        label: Text(_isEditing ? 'Update Customer' : 'Save Customer', style: const TextStyle(fontSize: 16)),
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
          ],
        ),
      ),
    );
  }
}