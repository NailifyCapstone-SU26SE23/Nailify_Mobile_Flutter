import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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
      _priceController.text = component.price > 0
          ? component.price.toString()
          : '';
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
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
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
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.component == null ? 'Tạo thành phần mới' : 'Sửa thành phần',
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Tên thành phần *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value?.trim().isEmpty == true
                      ? 'Vui lòng nhập tên'
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _componentType,
                  decoration: const InputDecoration(
                    labelText: 'Loại thành phần *',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('💎 Gem')),
                    DropdownMenuItem(value: 1, child: Text('📝 Sticker')),
                    DropdownMenuItem(value: 2, child: Text('🔗 Charm')),
                    DropdownMenuItem(value: 3, child: Text('🎨 Art')),
                  ],
                  onChanged: (value) =>
                      setState(() => _componentType = value ?? 0),
                ),
                const SizedBox(height: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.photo_library),
                      label: Text(_imageFile != null ? 'Đổi ảnh' : 'Chọn ảnh'),
                    ),
                    const SizedBox(height: 12),
                    if (_imageFile != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(_imageFile!.path),
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Ảnh mới',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ] else if (widget.component?.imageUrl != null &&
                        widget.component!.imageUrl.isNotEmpty) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          widget.component!.imageUrl,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Ảnh hiện tại',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Công khai'),
                  subtitle: const Text(
                    'Mọi người có thể sử dụng thành phần này',
                  ),
                  value: _isPublic,
                  onChanged: (value) => setState(() => _isPublic = value),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _save,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Lưu'),
        ),
      ],
    );
  }
}
