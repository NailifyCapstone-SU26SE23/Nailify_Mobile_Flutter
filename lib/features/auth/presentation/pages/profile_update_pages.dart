import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../data/models/user_profile.dart';
import '../../data/repositories/auth_repository.dart';

class UpdateProfilePage extends StatefulWidget {
  const UpdateProfilePage({super.key});

  @override
  State<UpdateProfilePage> createState() => _UpdateProfilePageState();
}

class _UpdateProfilePageState extends State<UpdateProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  late final Future<UserProfile> _future;
  final _imagePicker = ImagePicker();
  String? _currentAvatarUrl;
  XFile? _selectedImage;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _future = getIt<AuthRepository>().getCurrentUser();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _fillForm(UserProfile user) {
    if (_emailController.text.isNotEmpty ||
        _firstNameController.text.isNotEmpty ||
        _lastNameController.text.isNotEmpty ||
        _phoneController.text.isNotEmpty) {
      return;
    }

    _emailController.text = user.email;
    _firstNameController.text = user.firstName ?? '';
    _lastNameController.text = user.lastName ?? '';
    _phoneController.text = user.phone ?? '';
    _currentAvatarUrl = user.avatarUrl;
  }

  Future<void> _chooseImage() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (image == null) return;
    setState(() => _selectedImage = image);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      await getIt<AuthRepository>().updateProfile(
        email: _emailController.text.trim(),
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        phone: _phoneController.text.trim(),
        imagePath: _selectedImage?.path,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã cập nhật thông tin')),
      );
      context.go('/profile');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cập nhật thất bại: $error')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserProfile>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _UpdatePageShell(
            title: 'Cập nhật thông tin',
            children: [
              Text(
                snapshot.error.toString(),
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          );
        }

        _fillForm(snapshot.data!);
        return _UpdatePageShell(
          title: 'Cập nhật thông tin',
          children: [
            Center(
              child: CircleAvatar(
                radius: 52,
                backgroundColor: AppColors.primary,
                backgroundImage: _selectedImage != null
                    ? FileImage(File(_selectedImage!.path))
                    : _currentAvatarUrl?.trim().isNotEmpty == true
                        ? NetworkImage(_currentAvatarUrl!.trim())
                        : null,
                child: _selectedImage == null &&
                        (_currentAvatarUrl == null ||
                            _currentAvatarUrl!.trim().isEmpty)
                    ? const Icon(
                        Icons.person,
                        size: 52,
                        color: AppColors.primary,
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _isSubmitting ? null : _chooseImage,
              icon: const Icon(Icons.image_outlined),
              label: const Text('Chọn ảnh đại diện'),
            ),
            const SizedBox(height: 24),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    validator: _requiredValidator,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _firstNameController,
                    decoration: const InputDecoration(labelText: 'Tên'),
                    validator: _requiredValidator,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _lastNameController,
                    decoration: const InputDecoration(labelText: 'Họ'),
                    validator: _requiredValidator,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(labelText: 'Số điện thoại'),
                    keyboardType: TextInputType.phone,
                    validator: _requiredValidator,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      child: Text(_isSubmitting ? 'Đang cập nhật...' : 'Lưu'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập thông tin';
    }
    return null;
  }
}

class UpdatePreferencesPage extends StatefulWidget {
  const UpdatePreferencesPage({super.key});

  @override
  State<UpdatePreferencesPage> createState() => _UpdatePreferencesPageState();
}

class _UpdatePreferencesPageState extends State<UpdatePreferencesPage> {
  final _formKey = GlobalKey<FormState>();
  final _skinToneController = TextEditingController();
  final _occupationController = TextEditingController();
  final _nailConditionController = TextEditingController();
  final _personaIdController = TextEditingController();
  late final Future<UserProfile> _future;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _future = getIt<AuthRepository>().getCustomerProfile();
  }

  @override
  void dispose() {
    _skinToneController.dispose();
    _occupationController.dispose();
    _nailConditionController.dispose();
    _personaIdController.dispose();
    super.dispose();
  }

  void _fillForm(UserProfile user) {
    if (_skinToneController.text.isNotEmpty ||
        _occupationController.text.isNotEmpty ||
        _nailConditionController.text.isNotEmpty ||
        _personaIdController.text.isNotEmpty) {
      return;
    }

    _skinToneController.text = user.skinTone ?? '';
    _occupationController.text = user.occupation ?? '';
    _nailConditionController.text = user.nailCondition ?? '';
    _personaIdController.text = user.personaId ?? '';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      await getIt<AuthRepository>().updateCustomerPreferences(
        skinTone: _skinToneController.text.trim(),
        occupation: _occupationController.text.trim(),
        nailCondition: _nailConditionController.text.trim(),
        personaId: _personaIdController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã cập nhật sở thích')),
      );
      context.go('/profile');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cập nhật thất bại: $error')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserProfile>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _UpdatePageShell(
            title: 'Cập nhật sở thích',
            children: [
              Text(
                snapshot.error.toString(),
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          );
        }

        _fillForm(snapshot.data!);
        return _UpdatePageShell(
          title: 'Cập nhật sở thích',
          children: [
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _skinToneController,
                    decoration: const InputDecoration(labelText: 'Tông da'),
                    validator: _requiredValidator,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _occupationController,
                    decoration: const InputDecoration(labelText: 'Nghề nghiệp'),
                    validator: _requiredValidator,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nailConditionController,
                    decoration:
                        const InputDecoration(labelText: 'Tình trạng móng'),
                    validator: _requiredValidator,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _personaIdController,
                    decoration: const InputDecoration(labelText: 'Persona ID'),
                    validator: _requiredValidator,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      child: Text(_isSubmitting ? 'Đang cập nhật...' : 'Lưu'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập sở thích';
    }
    return null;
  }
}

class _UpdatePageShell extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _UpdatePageShell({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => context.go('/profile'),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Quay lại'),
          ),
        ),

        const SizedBox(height: 16),

        Text(
          title,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 24),
        ...children,
      ],
    );
  }
}
