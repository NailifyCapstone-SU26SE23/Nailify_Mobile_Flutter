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
      _componentType = _componentTypeValue(component.componentType);
    }
  }

  int _componentTypeValue(String value) {
    final normalized = value.trim().toLowerCase();
    final parsed = int.tryParse(normalized);
    if (parsed != null) return parsed;
    switch (normalized) {
      case 'gem':
        return 0;
      case 'sticker':
        return 1;
      case 'charm':
        return 2;
      case 'art':
        return 3;
      default:
        return 0;
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
          imagePath: _imageFile?.path,
        );
      } else {
        await repository.updateCustomerComponent(
          customerComponentId: widget.component!.customerComponentId,
          name: _nameController.text.trim(),
          componentType: _componentType,
          price: double.tryParse(_priceController.text.trim()),
          customDataJson: _customDataController.text.trim(),
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
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      clipBehavior: Clip.antiAlias,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
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
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Tên thành phần
                TextFormField(
                  controller: _nameController,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Tên thành phần *',
                    labelStyle: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF5F5F7),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  validator: (value) => value?.trim().isEmpty == true
                      ? 'Vui lòng nhập tên'
                      : null,
                ),
                const SizedBox(height: 16),

                // Giá tiền
                TextFormField(
                  controller: _priceController,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Giá tiền (VND)',
                    labelStyle: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF5F5F7),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),

                // Loại thành phần (Dropdown)
                DropdownButtonFormField<int>(
                  initialValue: _componentType,
                  isExpanded: true,
                  dropdownColor: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  decoration: InputDecoration(
                    labelText: 'Loại thành phần *',
                    labelStyle: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF5F5F7),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary,
                    size: 22,
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 0,
                      child: Text('💎 Gem', style: TextStyle(fontSize: 14)),
                    ),
                    DropdownMenuItem(
                      value: 1,
                      child: Text('📝 Sticker', style: TextStyle(fontSize: 14)),
                    ),
                    DropdownMenuItem(
                      value: 2,
                      child: Text('🔗 Charm', style: TextStyle(fontSize: 14)),
                    ),
                    DropdownMenuItem(
                      value: 3,
                      child: Text('🎨 Art', style: TextStyle(fontSize: 14)),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _componentType = value ?? 0),
                ),
                const SizedBox(height: 16),

                // Bộ chọn ảnh trực quan tích hợp
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    height: 130,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F7),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        width: 1.5,
                      ),
                    ),
                    child: _imageFile != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Stack(
                              children: [
                                Image.file(
                                  File(_imageFile!.path),
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                                Container(
                                  color: Colors.black38,
                                  child: const Center(
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.photo_library_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Đổi ảnh mới',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : (widget.component?.imageUrl != null &&
                              widget.component!.imageUrl.isNotEmpty)
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Stack(
                              children: [
                                Image.network(
                                  widget.component!.imageUrl,
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                                Container(
                                  color: Colors.black38,
                                  child: const Center(
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.photo_library_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Đổi ảnh mới',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_photo_alternate_rounded,
                                  size: 32,
                                  color: AppColors.primary,
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'Chọn ảnh thành phần',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 28),

                // Nút hành động
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          side: const BorderSide(
                            color: Color(0xFFE0E0E0),
                            width: 1.2,
                          ),
                        ),
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.of(context).pop(false),
                        child: const Text(
                          'Hủy',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        onPressed: _isLoading ? null : _save,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Lưu',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
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
