import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chat_messenger/config/theme_config.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:chat_messenger/services/agency_service.dart';
import 'package:flutter/material.dart';
import 'package:chat_messenger/api/user_api.dart';
import 'package:chat_messenger/api/official_team_api.dart';

class AgencyApplicationScreen extends StatefulWidget {
  final User currentUser;
  
  const AgencyApplicationScreen({
    super.key, 
    required this.currentUser,
  });

  @override
  State<AgencyApplicationScreen> createState() => _AgencyApplicationScreenState();
}

class _AgencyApplicationScreenState extends State<AgencyApplicationScreen> {
  final AgencyService _agencyService = AgencyService();
  final _formKey = GlobalKey<FormState>();
  
  // Form controllers
  final _agencyNameController = TextEditingController();
  final _agencyIdNumberController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _ownerPhoneController = TextEditingController();
  final _ownerEmailController = TextEditingController();
  final _ownerAddressController = TextEditingController();
  final _dateOfBirthController = TextEditingController();
  
  // State variables
  bool _isLoading = false;
  final String _selectedLogoUrl = '';
  DateTime? _selectedDateOfBirth;
  
  @override
  void initState() {
    super.initState();
    // Pre-fill with user data
    _ownerNameController.text = widget.currentUser.fullname;
    _ownerPhoneController.text = widget.currentUser.number;
    _ownerEmailController.text = widget.currentUser.email;
  }

  @override
  void dispose() {
    _agencyNameController.dispose();
    _agencyIdNumberController.dispose();
    _ownerNameController.dispose();
    _ownerPhoneController.dispose();
    _ownerEmailController.dispose();
    _ownerAddressController.dispose();
    _dateOfBirthController.dispose();
    super.dispose();
  }

  // Submit application
  Future<void> _submitApplication() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedDateOfBirth == null) {
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Please select your date of birth'),
            backgroundColor: Colors.red,
          ),
        );
      return;
    }

    try {
      setState(() {
        _isLoading = true;
      });

      debugPrint('🏢 Submitting agency application...');

      // Create agency owner
      final owner = AgencyOwner(
        userId: widget.currentUser.userId,
        name: _ownerNameController.text.trim(),
        phone: _ownerPhoneController.text.trim(),
        email: _ownerEmailController.text.trim(),
        profileImageUrl: widget.currentUser.photoUrl,
        dateOfBirth: _selectedDateOfBirth!,
        address: _ownerAddressController.text.trim(),
      );

      // Create agency
      final agencyId = await _agencyService.createAgency(
        agencyName: _agencyNameController.text.trim(),
        logoUrl: _selectedLogoUrl,
        agencyIdNumber: _agencyIdNumberController.text.trim(),
        owner: owner,
      );

      // Update user to be agency owner
      await FirebaseFirestore.instance
          .collection('Users')
          .doc(widget.currentUser.userId)
          .update({
        'isAgency': true,
        'agencyId': agencyId,
        'agencyName': _agencyNameController.text.trim(),
        'userType': 'agency_owner',
        'roles': FieldValue.arrayUnion(['agency']),
      });

      // Trigger official team Agency Congratulation notification
      try {
        final receiver = await UserApi.getUser(widget.currentUser.userId);
        if (receiver != null) {
          await OfficialTeamApi.sendAgencyCongratulation(receiver);
        }
      } catch (ex) {
        debugPrint('Error sending official agency congratulation notification: $ex');
      }

      if (mounted) {
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('Agency application submitted successfully! Agency ID: $agencyId'),
              backgroundColor: Colors.green,
            ),
          );
        
        // Navigate back
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('❌ Error submitting agency application: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('Failed to submit application: $e'),
              backgroundColor: Colors.red,
            ),
          );
      }
    }
  }

  // Select date of birth
  Future<void> _selectDateOfBirth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateOfBirth ?? DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 100)),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
    );
    
    if (picked != null && picked != _selectedDateOfBirth) {
      setState(() {
        _selectedDateOfBirth = picked;
        _dateOfBirthController.text = '${picked.day}/${picked.month}/${picked.year}';
      });
    }
  }

  // Select logo
  void _selectLogo() {
    // TODO: Implement image picker
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Logo selection coming soon!')),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white.withValues(alpha: 0.9),
      appBar: AppBar(
        title: const Text('Apply for Agency'),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        titleTextStyle: const TextStyle(
          color: Colors.black, 
          fontSize: 18, 
          fontWeight: FontWeight.bold
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(),
              const SizedBox(height: 24),
              
              // Agency Information
              _buildSectionTitle('Agency Information'),
              const SizedBox(height: 16),
              _buildAgencyInfoForm(),
              const SizedBox(height: 24),
              
              // Owner Information
              _buildSectionTitle('Owner Information'),
              const SizedBox(height: 16),
              _buildOwnerInfoForm(),
              const SizedBox(height: 32),
              
              // Submit Button
              _buildSubmitButton(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // Header
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor.withValues(alpha: 0.1), primaryColor.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.business, color: primaryColor, size: 28),
              const SizedBox(width: 12),
              const Text(
                'Agency Application',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Create your agency and start managing hosts',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  // Section Title
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  // Agency Information Form
  Widget _buildAgencyInfoForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Agency Name
          TextFormField(
            controller: _agencyNameController,
            decoration: const InputDecoration(
              labelText: 'Agency Name',
              hintText: 'Enter your agency name',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.business),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter agency name';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          // Agency ID Number
          TextFormField(
            controller: _agencyIdNumberController,
            decoration: const InputDecoration(
              labelText: 'Agency ID Number',
              hintText: 'Enter your agency ID number',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.credit_card),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter agency ID number';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          // Logo Selection
          GestureDetector(
            onTap: _selectLogo,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.image, color: Colors.grey.shade600),
                  const SizedBox(width: 12),
                  const Text('Select Agency Logo'),
                  const Spacer(),
                  Icon(Icons.arrow_forward_ios, color: Colors.grey.shade600, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Owner Information Form
  Widget _buildOwnerInfoForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Owner Name
          TextFormField(
            controller: _ownerNameController,
            decoration: const InputDecoration(
              labelText: 'Owner Name',
              hintText: 'Enter your full name',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter owner name';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          // Phone Number
          TextFormField(
            controller: _ownerPhoneController,
            decoration: const InputDecoration(
              labelText: 'Phone Number',
              hintText: 'Enter your phone number',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.phone),
            ),
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter phone number';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          // Email
          TextFormField(
            controller: _ownerEmailController,
            decoration: const InputDecoration(
              labelText: 'Email Address',
              hintText: 'Enter your email address',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.email),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter email address';
              }
              if (!value.contains('@')) {
                return 'Please enter a valid email address';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          // Date of Birth
          TextFormField(
            controller: _dateOfBirthController,
            decoration: const InputDecoration(
              labelText: 'Date of Birth',
              hintText: 'Select your date of birth',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.calendar_today),
            ),
            readOnly: true,
            onTap: _selectDateOfBirth,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please select date of birth';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          // Address
          TextFormField(
            controller: _ownerAddressController,
            decoration: const InputDecoration(
              labelText: 'Address',
              hintText: 'Enter your address',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.location_on),
            ),
            maxLines: 2,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter address';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  // Submit Button
  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitApplication,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'Submit Application',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
      ),
    );
  }
}
