import 'package:flutter/material.dart';
import 'elder_database_service.dart'; // Fixed path to the database logic file

class RegisterElderScreen extends StatefulWidget {
  const RegisterElderScreen({super.key});

  @override
  State<RegisterElderScreen> createState() => _RegisterElderScreenState();
}

class _RegisterElderScreenState extends State<RegisterElderScreen> {
  // Initialize our database service
  final ElderDatabaseService _dbService = ElderDatabaseService();

  // Controllers to "grab" the text you type in the boxes
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _conditionController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    // Clean up controllers when the widget is disposed to prevent memory leaks
    _nameController.dispose();
    _ageController.dispose();
    _phoneController.dispose();
    _conditionController.dispose();
    super.dispose();
  }

  void _saveToFirebase() async {
    if (_nameController.text.isEmpty || _phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and Phone are required!')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Create a unique ID for this entry
      String elderId = 'elder_${DateTime.now().millisecondsSinceEpoch}';

      // 1. Save the main profile
      await _dbService.createUserProfile(
        uid: elderId,
        fullName: _nameController.text,
        role: 'elderly',
        age: int.tryParse(_ageController.text) ?? 0,
        phone: _phoneController.text,
      );

      // 2. Add the medical condition if they typed one
      if (_conditionController.text.isNotEmpty) {
        await _dbService.addHealthCondition(
          elderlyUid: elderId,
          conditionName: _conditionController.text,
          severity: 'Chronic',
          diagnosedDate: '2026-05-16',
        );
      }

      // --- ASYNC GAP GUARD ---
      // If the user left the screen while Firebase was saving, stop here and don't call context.
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Success! Check your Firebase Console.')),
      );

      // Clear the form
      _nameController.clear();
      _ageController.clear();
      _phoneController.clear();
      _conditionController.clear();
    } catch (e) {
      // --- ASYNC GAP GUARD FOR ERROR ---
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      // --- ASYNC GAP GUARD FOR LOADING STATE ---
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Elder Registration')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Full Name'),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _ageController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Age'),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone Number'),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _conditionController,
                decoration: const InputDecoration(labelText: 'Health Condition (Dementia, etc.)'),
              ),
              const SizedBox(height: 30),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _saveToFirebase,
                      child: const Text('Save to Firebase Database'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}