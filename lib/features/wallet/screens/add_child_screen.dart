// Add Child screen — lets a logged-in parent register their own
// student, using their own id from AuthProvider (never typed by hand).

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/wallet_provider.dart';

class AddChildScreen extends StatefulWidget {
  const AddChildScreen({super.key});

  @override
  State<AddChildScreen> createState() => _AddChildScreenState();
}

class _AddChildScreenState extends State<AddChildScreen> {
  final _nameController = TextEditingController();
  final _schoolIdController = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _schoolIdController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final name = _nameController.text.trim();
    final schoolIdText = _schoolIdController.text.trim();

    if (name.isEmpty) {
      setState(() => _error = "Enter your child's name.");
      return;
    }

    final schoolId = int.tryParse(schoolIdText);
    if (schoolId == null) {
      setState(() => _error = 'Enter a valid School ID number.');
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final parentId = authProvider.currentUser?.id;

    if (parentId == null) {
      setState(() => _error = 'You must be logged in to add a child.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final walletProvider = context.read<WalletProvider>();
    final success = await walletProvider.createStudent(
      name: name,
      schoolId: schoolId,
      parentId: parentId,
    );

    if (!mounted) return;

    setState(() => _isSubmitting = false);

    if (success) {
      context.pop();
    } else {
      setState(() {
        _error = walletProvider.errorMessage ?? 'Failed to add child.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Add a Child')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.marginMobile),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Register your child to create their wallet.",
              style: AppTheme.bodyMd
                  .copyWith(color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: AppTheme.spaceLg),

            Text("Child's Name",
                style:
                    AppTheme.bodySm.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: AppTheme.spaceSm),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(hintText: 'e.g. Amara Namukasa'),
            ),
            const SizedBox(height: AppTheme.spaceLg),

            Text('School ID',
                style:
                    AppTheme.bodySm.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: AppTheme.spaceSm),
            TextField(
              controller: _schoolIdController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: 'e.g. 1'),
            ),
            const SizedBox(height: AppTheme.spaceXs),
            Text(
              'Ask your school administrator for this if you don\'t know it.',
              style: AppTheme.bodySm.copyWith(color: AppColors.onSurfaceVariant),
            ),

            if (_error != null) ...[
              const SizedBox(height: AppTheme.spaceMd),
              Text(_error!, style: AppTheme.bodySm.copyWith(color: AppColors.error)),
            ],

            const SizedBox(height: AppTheme.spaceXl),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _handleSubmit,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Add Child'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}