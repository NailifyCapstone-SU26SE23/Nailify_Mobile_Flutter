import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../nails/data/models/customer_nail_models.dart';
import '../../../nails/data/repositories/customer_component_repository.dart';

class CustomerComponentFormDialog extends StatefulWidget {
  final CustomerComponentModel? component;

  const CustomerComponentFormDialog({super.key, this.component});

  @override
  State<CustomerComponentFormDialog> createState() =>
      _CustomerComponentFormDialogState();
}

class _CustomerComponentFormDialogState
    extends State<CustomerComponentFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _customDataController = TextEditingController();
  final _picker = ImagePicker();

  int _componentType = 0;
  bool _isPublic = true;
  XFile? _imageFile;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final component = widget.component;
    if (component != null) {
      _nameController.text = component.name;
      _priceController.text = component.price > 0 ? component.price.toString() : '';
      _customDataController.text = component.customDataJson;
      _componentType = int.tryParse(component.componentType) ?? 0;
      _isPublic = component.isPublic;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _customDataController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (image != null) setState(() => _imageFile = image);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final repository = getIt<CustomerComponentRepository>();
    try {
      if (widget.component == null) {
        await repository.createCustomerComponent(
          name: _nameController.text.trim(),
          componentType: _componentType,
          price: double.tryParse(_priceController.text.trim()),
          customDataJson: _customDataController.text.trim(),
          isPublic: _isPublic,
          imagePath: _imageFile?.path,
        );
      } else {
        await repository.updateCustomerComponent(
          customerComponentId: widget.component!.customerComponentId,
          name: _nameController.text.trim(),
          componentType: _componentType,
          price: double.tryParse(_priceController.text.trim()),
          customDataJson: _customDataController.text.trim(),
          isPublic: _isPublic,
          imagePath: _imageFile?.path,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.component == null
                      ? 'Tạo thành phần mới'
                      : 'Sửa thành phần',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Tên thành phần *',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.borderLight),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                  validator: (value) =>
                      value?.trim().isEmpty == true ? 'Vui lòng nhập tên' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _priceController,
                  decoration: InputDecoration(
                    labelText: 'Giá tiền (VND)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: _componentType,
                  decoration: InputDecoration(
                    labelText: 'Loại thành phần *',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('💎 Gem')),
                    DropdownMenuItem(value: 1, child: Text('📝 Sticker')),
                    DropdownMenuItem(value: 2, child: Text('🔗 Charm')),
                    DropdownMenuItem(value: 3, child: Text('🎨 Art')),
                  ],
                  onChanged: (value) => setState(() => _componentType = value ?? 0),
                ),
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      onPressed: _pickImage,
                      icon: const Icon(Icons.photo_library_outlined, size: 20),
                      label: Text(_imageFile != null ? 'Đổi ảnh' : 'Chọn ảnh'),
                    ),
                    const SizedBox(height: 12),
                    if (_imageFile != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(File(_imageFile!.path), height: 180, width: double.infinity, fit: BoxFit.cover),
                      ),
                      const SizedBox(height: 4),
                      Text('Ảnh mới', style: TextStyle(fontSize: 11, color: Colors.grey.shade600), textAlign: TextAlign.center),
                    ] else if (widget.component?.imageUrl != null && widget.component!.imageUrl.isNotEmpty) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(widget.component!.imageUrl, height: 180, width: double.infinity, fit: BoxFit.cover),
                      ),
                      const SizedBox(height: 4),
                      Text('Ảnh hiện tại', style: TextStyle(fontSize: 11, color: Colors.grey.shade600), textAlign: TextAlign.center),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: SwitchListTile(
                    title: const Text('Công khai', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Mọi người có thể sử dụng', style: TextStyle(fontSize: 12)),
                    value: _isPublic,
                    activeThumbColor: AppColors.primary,
                    onChanged: (value) => setState(() => _isPublic = value),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
                        child: const Text('Hủy', style: TextStyle(color: AppColors.textSecondary)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _isLoading ? null : _save,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Lưu', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
