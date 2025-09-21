// lib/screens/tourist_id_registration_screen.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/blockchain_provider.dart';
import '../models/tourist_record.dart';

class TouristIDRegistrationScreen extends StatefulWidget {
  const TouristIDRegistrationScreen({super.key});

  @override
  State<TouristIDRegistrationScreen> createState() =>
      _TouristIDRegistrationScreenState();
}

class _TouristIDRegistrationScreenState
    extends State<TouristIDRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();

  // Form controllers
  final _nameController = TextEditingController();
  final _passportController = TextEditingController();
  final _aadhaarController = TextEditingController();
  final _nationalityController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emergencyContactController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();

  DateTime? _dateOfBirth;
  DateTime? _validUntil;
  final List<String> _itinerary = [];
  final String _profileImageCID = '';
  int _currentPage = 0;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _passportController.dispose();
    _aadhaarController.dispose();
    _nationalityController.dispose();
    _phoneController.dispose();
    _emergencyContactController.dispose();
    _emergencyPhoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Tourist ID'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_currentPage + 1) / 4,
            backgroundColor: Colors.grey.shade300,
          ),
        ),
      ),
      body: Consumer<BlockchainProvider>(
        builder: (context, blockchainProvider, child) {
          if (_isSubmitting) {
            return _buildSubmittingState(blockchainProvider);
          }

          return PageView(
            controller: _pageController,
            onPageChanged: (page) {
              setState(() {
                _currentPage = page;
              });
            },
            children: [
              _buildPersonalInfoPage(),
              _buildDocumentInfoPage(),
              _buildTravelInfoPage(),
              _buildReviewPage(),
            ],
          );
        },
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  Widget _buildSubmittingState(BlockchainProvider blockchainProvider) {
    String statusText = 'Preparing data...';
    double progress = 0.25;

    if (blockchainProvider.status == BlockchainStatus.transactionPending) {
      statusText = 'Creating Tourist ID on blockchain...';
      progress = 0.75;
    } else if (blockchainProvider.isLoading) {
      statusText = 'Uploading metadata to IPFS...';
      progress = 0.5;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(value: progress),
            const SizedBox(height: 24),
            Text(
              statusText,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (blockchainProvider.transactionHash.isNotEmpty) ...[
              Text(
                'Transaction: ${blockchainProvider.transactionHash.substring(0, 10)}...',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontFamily: 'monospace',
                    ),
              ),
            ],
            const SizedBox(height: 24),
            Text(
              'Please wait while we create your secure digital Tourist ID. This may take a few minutes.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalInfoPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Personal Information',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please provide your basic personal information.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                hintText: 'Enter your full name as per passport',
                prefixIcon: Icon(Icons.person),
              ),
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return 'Please enter your full name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nationalityController,
              decoration: const InputDecoration(
                labelText: 'Nationality',
                hintText: 'e.g., Indian, American',
                prefixIcon: Icon(Icons.flag),
              ),
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return 'Please enter your nationality';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _selectDateOfBirth,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date of Birth',
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(
                  _dateOfBirth != null
                      ? _formatDate(_dateOfBirth!)
                      : 'Select your date of birth',
                  style: _dateOfBirth != null
                      ? null
                      : TextStyle(color: Colors.grey.shade600),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                hintText: 'Enter your mobile number',
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return 'Please enter your phone number';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentInfoPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Document Information',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Provide your identification documents.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _passportController,
            decoration: const InputDecoration(
              labelText: 'Passport Number',
              hintText: 'Enter your passport number',
              prefixIcon: Icon(Icons.card_membership),
            ),
            validator: (value) {
              if (value?.isEmpty ?? true) {
                return 'Please enter your passport number';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _aadhaarController,
            decoration: const InputDecoration(
              labelText: 'Aadhaar Number (Optional)',
              hintText: 'For Indian citizens only',
              prefixIcon: Icon(Icons.credit_card),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              border: Border.all(color: Colors.blue.shade200),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info, color: Colors.blue.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Your document numbers are hashed for security and privacy.',
                    style: TextStyle(color: Colors.blue.shade600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTravelInfoPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Travel Information',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Emergency contacts and travel validity.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _emergencyContactController,
            decoration: const InputDecoration(
              labelText: 'Emergency Contact Name',
              hintText: 'Name of person to contact in emergency',
              prefixIcon: Icon(Icons.contact_emergency),
            ),
            validator: (value) {
              if (value?.isEmpty ?? true) {
                return 'Please enter emergency contact name';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emergencyPhoneController,
            decoration: const InputDecoration(
              labelText: 'Emergency Contact Phone',
              hintText: 'Phone number of emergency contact',
              prefixIcon: Icon(Icons.phone_in_talk),
            ),
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (value?.isEmpty ?? true) {
                return 'Please enter emergency contact phone';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: _selectValidUntil,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Valid Until',
                prefixIcon: Icon(Icons.event),
              ),
              child: Text(
                _validUntil != null
                    ? _formatDate(_validUntil!)
                    : 'Select validity end date',
                style: _validUntil != null
                    ? null
                    : TextStyle(color: Colors.grey.shade600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review Information',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please review your information before submitting.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 24),
          _buildReviewSection('Personal Information', [
            'Name: ${_nameController.text}',
            'Nationality: ${_nationalityController.text}',
            'Date of Birth: ${_dateOfBirth != null ? _formatDate(_dateOfBirth!) : 'Not set'}',
            'Phone: ${_phoneController.text}',
          ]),
          const SizedBox(height: 16),
          _buildReviewSection('Documents', [
            'Passport: ${_passportController.text}',
            if (_aadhaarController.text.isNotEmpty)
              'Aadhaar: ${_aadhaarController.text}',
          ]),
          const SizedBox(height: 16),
          _buildReviewSection('Emergency & Travel', [
            'Emergency Contact: ${_emergencyContactController.text}',
            'Emergency Phone: ${_emergencyPhoneController.text}',
            'Valid Until: ${_validUntil != null ? _formatDate(_validUntil!) : 'Not set'}',
          ]),
        ],
      ),
    );
  }

  Widget _buildReviewSection(String title, List<String> items) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(item),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            offset: const Offset(0, -1),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentPage > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousPage,
                child: const Text('Previous'),
              ),
            ),
          if (_currentPage > 0) const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _currentPage == 3 ? _submitForm : _nextPage,
              child: Text(_currentPage == 3 ? 'Create Tourist ID' : 'Next'),
            ),
          ),
        ],
      ),
    );
  }

  void _nextPage() {
    if (_currentPage < 3) {
      if (_validateCurrentPage()) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  bool _validateCurrentPage() {
    switch (_currentPage) {
      case 0:
        if (!(_formKey.currentState?.validate() ?? false)) return false;
        if (_dateOfBirth == null) {
          _showSnackBar('Please select your date of birth');
          return false;
        }
        return true;
      case 1:
        if (_passportController.text.isEmpty) {
          _showSnackBar('Please enter your passport number');
          return false;
        }
        return true;
      case 2:
        if (_emergencyContactController.text.isEmpty ||
            _emergencyPhoneController.text.isEmpty) {
          _showSnackBar('Please fill in emergency contact information');
          return false;
        }
        if (_validUntil == null) {
          _showSnackBar('Please select validity end date');
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  Future<void> _submitForm() async {
    if (!_validateCurrentPage()) return;

    setState(() {
      _isSubmitting = true;
    });

    final blockchainProvider =
        Provider.of<BlockchainProvider>(context, listen: false);

    // Create metadata object
    final metadata = TouristMetadata(
      name: _nameController.text.trim(),
      passportNumber: _passportController.text.trim(),
      aadhaarHash: _aadhaarController.text.trim(),
      nationality: _nationalityController.text.trim(),
      dateOfBirth: _dateOfBirth!,
      phoneNumber: _phoneController.text.trim(),
      emergencyContact: _emergencyContactController.text.trim(),
      emergencyPhone: _emergencyPhoneController.text.trim(),
      itinerary: _itinerary,
      profileImageCID: _profileImageCID,
      issuedAt: DateTime.now(),
    );

    // Use the primary identity document (passport in this case)
    final identityDocument = _passportController.text.trim();

    final success = await blockchainProvider.mintTouristID(
      metadata: metadata,
      validUntil: _validUntil!,
      identityDocument: identityDocument,
    );

    setState(() {
      _isSubmitting = false;
    });

    if (!mounted) return;

    if (success) {
      _showSuccessDialog();
    } else {
      _showSnackBar(
          'Failed to create Tourist ID: ${blockchainProvider.errorMessage}');
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Success!'),
        content: const Text(
          'Your Tourist ID has been created successfully on the blockchain.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushReplacementNamed('/home');
            },
            child: const Text('Go to Home'),
          ),
        ],
      ),
    );
  }

  void _selectDateOfBirth() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 25)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
    );
    if (date != null) {
      setState(() {
        _dateOfBirth = date;
      });
    }
  }

  void _selectValidUntil() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (date != null) {
      setState(() {
        _validUntil = date;
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
