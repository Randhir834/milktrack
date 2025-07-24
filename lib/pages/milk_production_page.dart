import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MilkProductionPage extends StatefulWidget {
  final Map<String, dynamic>? existingProduction;
  final String? documentId;
  
  const MilkProductionPage({
    super.key, 
    this.existingProduction,
    this.documentId,
  });

  @override
  State<MilkProductionPage> createState() => _MilkProductionPageState();
}

class _MilkProductionPageState extends State<MilkProductionPage> {
  final _formKey = GlobalKey<FormState>();
  final _cowIdController = TextEditingController();
  final _quantityController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String _selectedSession = 'Morning';
  bool _isLoading = false;
  bool _isSubmitting = false;
  late bool _isEditing;
  String? _userType;
  bool _isAdmin = false;
  String _username = 'User';

  @override
  void initState() {
    super.initState();
    _isEditing = widget.existingProduction != null;
    _loadUserData();
    if (_isEditing) {
      _checkEditPermissionAndInitialize();
    }
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final prefs = await SharedPreferences.getInstance();
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (!userDoc.exists) {
        throw Exception('User profile not found');
      }

      if (mounted) {
        setState(() {
          _userType = userDoc.data()?['type'] as String? ?? 'staff';
          _isAdmin = _userType == 'admin';
          _username = prefs.getString('username') ?? 'User';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading user data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _checkEditPermissionAndInitialize() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final production = widget.existingProduction!;
      final recordUserId = production['userId'];

      // Only allow editing if admin or if staff owns the record
      if (!_isAdmin && recordUserId != user.uid) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You do not have permission to edit this record'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      _initializeWithExistingData();
    } catch (e) {
      _showErrorDialog('Error loading record', e.toString());
    }
  }

  void _initializeWithExistingData() {
    try {
      final production = widget.existingProduction!;
      _cowIdController.text = production['cowId'] ?? '';
      _selectedDate = (production['productionDate'] as Timestamp).toDate();
      _selectedSession = production['session'] ?? 'Morning';
      _quantityController.text = production['quantityInLiters']?.toString() ?? '';
      _notesController.text = production['notes'] ?? '';
    } catch (e) {
      _showErrorDialog('Error loading production data', e.toString());
    }
  }

  void _showErrorDialog(String title, String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _cowIdController.dispose();
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<bool> _checkDuplicateEntry() async {
    if (_isEditing) return false;

    try {
      final startOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('productions')
          .where('cowId', isEqualTo: _cowIdController.text)
          .where('productionDate', isEqualTo: Timestamp.fromDate(startOfDay))
          .where('session', isEqualTo: _selectedSession)
          .where('userId', isEqualTo: user.uid)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      _showErrorDialog('Error checking for duplicates', e.toString());
      return true; // Prevent save on error
    }
  }

  Future<void> _saveMilkProduction() async {
    if (_isSubmitting) return; // Prevent double submission
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Check for duplicate entry
      final isDuplicate = await _checkDuplicateEntry();
      if (isDuplicate) {
        throw Exception('A record already exists for this cow, date, and session');
      }

      // Prepare production data
      final productionData = {
        'cowId': _cowIdController.text.trim(),
        'productionDate': Timestamp.fromDate(_selectedDate),
        'session': _selectedSession,
        'quantityInLiters': double.parse(_quantityController.text),
        'notes': _notesController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
        'userId': user.uid,
        'userEmail': user.email ?? 'Unknown User',
        'lastModified': FieldValue.serverTimestamp(),
        'username': _username,
      };

      // Save to Firestore
      if (_isEditing && widget.documentId != null) {
        await FirebaseFirestore.instance
            .collection('productions')
            .doc(widget.documentId)
            .update(productionData);
      } else {
        await FirebaseFirestore.instance
            .collection('productions')
            .add(productionData);
      }

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing ? 'Record updated successfully' : 'Record saved successfully'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true); // Return true to indicate success

    } catch (e) {
      _showErrorDialog(
        'Error saving record',
        e.toString().replaceAll('Exception:', '').trim()
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Milk Production' : 'Record Milk Production'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Cow ID Input
              TextFormField(
                controller: _cowIdController,
                decoration: const InputDecoration(
                  labelText: 'Cow ID *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.tag),
                ),
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter cow ID';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Cow Name Input REMOVED

              // Date Selection
              ListTile(
                title: Text('Date: ${DateFormat('dd/MM/yyyy').format(_selectedDate)}'),
                trailing: const Icon(Icons.calendar_today),
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(8),
                ),
                onTap: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() => _selectedDate = picked);
                  }
                },
              ),
              const SizedBox(height: 16),

              // Session Selection
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 16, top: 8),
                      child: Text(
                        'Session *',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('Morning'),
                            value: 'Morning',
                            groupValue: _selectedSession,
                            onChanged: (String? value) {
                              setState(() => _selectedSession = value!);
                            },
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('Evening'),
                            value: 'Evening',
                            groupValue: _selectedSession,
                            onChanged: (String? value) {
                              setState(() => _selectedSession = value!);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Quantity Input
              TextFormField(
                controller: _quantityController,
                decoration: const InputDecoration(
                  labelText: 'Quantity (Liters) *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.water_drop),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter quantity';
                  }
                  final double? quantity = double.tryParse(value);
                  if (quantity == null) {
                    return 'Please enter a valid number';
                  }
                  if (quantity <= 0) {
                    return 'Quantity must be greater than 0';
                  }
                  if (quantity > 100) {
                    return 'Quantity seems too high. Please verify';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Notes Input
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note),
                ),
                maxLines: 3,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 24),

              // Submit Button
              ElevatedButton(
                onPressed: _isSubmitting ? null : _saveMilkProduction,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Theme.of(context).primaryColor,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        _isEditing ? 'Update Record' : 'Save Record',
                        style: const TextStyle(fontSize: 16),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 