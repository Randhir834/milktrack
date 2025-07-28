import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'milk_production_page.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ProductionListPage extends StatefulWidget {
  const ProductionListPage({super.key});

  @override
  State<ProductionListPage> createState() => _ProductionListPageState();
}

class _ProductionListPageState extends State<ProductionListPage> {
  String? _userType;
  bool _isAdmin = false;
  bool _isLoading = true;
  String? _errorMessage;
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  Set<String> _selectedRecordIds = {};
  bool _selectAll = false;
  String? _selectedCowId;
  List<String> _availableCowIds = [];
  TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadUserType();
    _fetchAvailableCowIds();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserType() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final userDoc = await _firestore
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
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchAvailableCowIds() async {
    final user = _auth.currentUser;
    if (user == null) return;
    Query query = _firestore.collection('productions');
    if (!_isAdmin) {
      query = query.where('userId', isEqualTo: user.uid);
    }
    final snapshot = await query.get();
    final cowIds = <String>{};
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['cowId'] != null && data['cowId'].toString().isNotEmpty) {
        cowIds.add(data['cowId'].toString());
      }
    }
    setState(() {
      _availableCowIds = cowIds.toList();
    });
  }

  Stream<QuerySnapshot> _getProductionsStream() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();
    Query query = _firestore.collection('productions');
    if (_isAdmin) {
      // Admins can see all records
    } else {
      // Staff can only see their own records
      query = query.where('userId', isEqualTo: user.uid);
    }
    if (_selectedCowId != null && _selectedCowId!.isNotEmpty) {
      query = query.where('cowId', isEqualTo: _selectedCowId);
    }
    return query.orderBy('productionDate', descending: true).snapshots();
  }

  Future<void> _checkDuplicateEntry(String cowId, DateTime date, String session) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final snapshot = await _firestore
          .collection('productions')
          .where('userId', isEqualTo: user.uid)
          .where('cowId', isEqualTo: cowId)
          .where('productionDate', isEqualTo: Timestamp.fromDate(date))
          .where('session', isEqualTo: session)
          .get();

      if (snapshot.docs.isNotEmpty) {
        throw Exception('A record already exists for this cow, date, and session');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Renamed for clarity and slight style adjustment for the screenshot
  Widget _buildSummarySection(QuerySnapshot snapshot) {
    if (snapshot.docs.isEmpty) return const SizedBox.shrink();

    double totalQuantity = 0;
    int morningCount = 0;
    int eveningCount = 0;

    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      totalQuantity += (data['quantityInLiters'] as num).toDouble();
      if (data['session'] == 'Morning') {
        morningCount++;
      } else { // Assuming 'Evening' or other
        eveningCount++;
      }
    }

    return Container( // Using Container for background and padding
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor, // Use card color for consistency
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2), // changes position of shadow
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Summary',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12), // Adjusted spacing
          Text('Total Records: ${snapshot.docs.length}', style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 4),
          Text('Morning Records: $morningCount', style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 4),
          Text('Evening Records: $eveningCount', style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 12), // Adjusted spacing
          Text(
            'Total Quantity: ${totalQuantity.toStringAsFixed(2)} L',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Future<bool> _canModifyRecord(String recordUserId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    // If user is admin, they can modify any record
    if (_isAdmin) return true;

    // Staff can only modify their own records
    return user.uid == recordUserId;
  }

  Future<void> _deleteRecord(String docId, String cowName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Record'),
        content: const Text('Are you sure you want to delete this record?'),
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
      await _firestore
          .collection('productions')
          .doc(docId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Record deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting record: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    await _loadUserType();
  }

  void _toggleSelectAll(List<QueryDocumentSnapshot> docs) {
    setState(() {
      if (_selectAll) {
        _selectedRecordIds.clear();
        _selectAll = false;
      } else {
        _selectedRecordIds = docs.map((doc) => doc.id).toSet();
        _selectAll = true;
      }
    });
  }

  void _toggleSelectRecord(String docId) {
    setState(() {
      if (_selectedRecordIds.contains(docId)) {
        _selectedRecordIds.remove(docId);
      } else {
        _selectedRecordIds.add(docId);
      }
    });
  }

  Future<void> _downloadSelectedAsPdf(List<QueryDocumentSnapshot> docs) async {
    final selectedDocs = docs.where((doc) => _selectedRecordIds.contains(doc.id)).toList();
    if (selectedDocs.isEmpty) return;

    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text('Production Records', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 16),
          pw.Table.fromTextArray(
            headers: ['Date', 'Session', 'Cow Name', 'Cow ID', 'Quantity (L)', 'Notes', 'Added By'],
            data: selectedDocs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final date = (data['productionDate'] as Timestamp).toDate();
              return [
                DateFormat('dd/MM/yyyy').format(date),
                data['session'] ?? '',
                data['cowName'] ?? '',
                data['cowId'] ?? '',
                data['quantityInLiters']?.toString() ?? '',
                data['notes'] ?? '',
                data['username'] ?? '',
              ];
            }).toList(),
          ),
        ],
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
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

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Error'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Error: $_errorMessage',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _refreshData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isAdmin ? 'All Production Records' : 'My Production Records'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _refreshData();
              _fetchAvailableCowIds();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 16), // Add gap between AppBar and search bar
          // Search bar for cow ID
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search by Cow ID',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                            _searchController.clear();
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getProductionsStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 60,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading records:  {snapshot.error}', // Corrected interpolation
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _refreshData,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final docs = snapshot.data?.docs ?? [];
                return Column(
                  children: [
                    if (!_isAdmin && snapshot.hasData)
                      _buildSummarySection(snapshot.data!),
                    if (_isAdmin && docs.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Row(
                          children: [
                            Checkbox(
                              value: _selectAll,
                              onChanged: (val) => _toggleSelectAll(docs),
                            ),
                            const Text('Select All'),
                            const Spacer(),
                            IconButton(
                              icon: Icon(
                                Icons.download,
                                size: 32,
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                              tooltip: 'Download Selected as PDF',
                              onPressed: _selectedRecordIds.isEmpty ? null : () async {
                                await _downloadSelectedAsPdf(docs);
                              },
                            ),
                          ],
                        ),
                      ),
                    if (docs.isEmpty)
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.note_alt_outlined,
                                size: 60,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _isAdmin 
                                  ? 'No production records found'
                                  : 'You haven\'t added any records yet',
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.builder(
                          itemCount: docs.where((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final cowId = data['cowId']?.toString() ?? '';
                            return cowId.toLowerCase().contains(_searchQuery.toLowerCase());
                          }).length,
                          itemBuilder: (context, index) {
                            final filteredDocs = docs.where((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final cowId = data['cowId']?.toString() ?? '';
                              return cowId.toLowerCase().contains(_searchQuery.toLowerCase());
                            }).toList();
                            final doc = filteredDocs[index];
                            final data = doc.data() as Map<String, dynamic>;
                            final date = (data['productionDate'] as Timestamp).toDate();
                            final quantity = data['quantityInLiters']?.toString() ?? '0';
                            final cowName = data['cowName'] ?? 'Unknown Cow';
                            final cowId = data['cowId'] ?? 'Unknown ID';
                            final session = data['session'] ?? 'Unknown Session';
                            final recordUserId = data['userId'] ?? '';
                            final username = data['username'] ?? 'Unknown User';
                            final notes = data['notes'] as String?;
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              elevation: 2, // Ensure consistency with summary
                              shape: RoundedRectangleBorder( // Ensure consistency with summary
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  if (_isAdmin)
                                    Checkbox(
                                      value: _selectedRecordIds.contains(doc.id),
                                      onChanged: (val) => _toggleSelectRecord(doc.id),
                                    ),
                                  Expanded(
                                    child: ListTile(
                                      title: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              '${DateFormat('dd/MM/yyyy').format(date)} - $session',
                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context).primaryColor.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              '$quantity L',
                                              style: TextStyle(
                                                color: Theme.of(context).primaryColor,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 4),
                                          // Only show cow name if it is not 'Unknown Cow'
                                          if (cowName != 'Unknown Cow')
                                            Text('Cow: $cowName (ID: $cowId)'),
                                          if (notes?.isNotEmpty == true) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              'Notes: $notes',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ],
                                          if (_isAdmin && username.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              'Added by: $username',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      isThreeLine: true,
                                      trailing: FutureBuilder<bool>(
                                        future: _canModifyRecord(recordUserId),
                                        builder: (context, snapshot) {
                                          final canModify = snapshot.data ?? false;
                                          if (!canModify) {
                                            return const SizedBox.shrink();
                                          }
                                          return Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.edit),
                                                onPressed: () async {
                                                  final result = await Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) => MilkProductionPage(
                                                        existingProduction: data,
                                                        documentId: doc.id,
                                                      ),
                                                    ),
                                                  );
                                                  if (result == true) {
                                                    _refreshData();
                                                  }
                                                },
                                                tooltip: 'Edit',
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete, color: Colors.red),
                                                onPressed: () => _deleteRecord(doc.id, cowName),
                                                tooltip: 'Delete',
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}