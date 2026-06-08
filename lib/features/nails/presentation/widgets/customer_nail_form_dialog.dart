import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/di/injection.dart';
import '../../data/models/customer_nail_models.dart';
import '../../data/repositories/nail_repository.dart';

class CustomerNailFormDialog extends StatefulWidget {
  final CustomerNailModel? nail;

  const CustomerNailFormDialog({
    super.key,
    this.nail,
  });

  @override
  State<CustomerNailFormDialog> createState() => _CustomerNailFormDialogState();
}

class _CustomerNailFormDialogState extends State<CustomerNailFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _picker = ImagePicker();

  bool _isFavorite = false;
  bool _isPublic = false;
  XFile? _imageFile;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final nail = widget.nail;
    _nameController.text = nail?.name ?? '';
    _isFavorite = nail?.isFavorite ?? false;
    _isPublic = nail?.isPublic ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (image != null) {
      setState(() => _imageFile = image);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final repository = getIt<NailRepository>();

    try {
      if (widget.nail == null) {
        // CREATE
        await repository.createCustomerNail(
          name: _nameController.text.trim(),
          isFavorite: _isFavorite,
          isPublic: _isPublic,
          imagePath: _imageFile?.path,
        );
      } else {
        // UPDATE
        await repository.updateCustomerNail(
          customerNailId: widget.nail!.customerNailId,
          name: _nameController.text.trim(),
          isFavorite: _isFavorite,
          isPublic: _isPublic,
          imagePath: _imageFile?.path,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.nail == null ? 'Tạo mẫu móng mới' : 'Sửa mẫu móng'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Tên mẫu móng *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                  value?.trim().isEmpty == true ? 'Vui lòng nhập tên' : null,
                ),
                const SizedBox(height: 12),

                // Image picker with preview
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.photo_library),
                      label: Text(_imageFile != null ? 'Đổi ảnh' : 'Chọn ảnh móng'),
                    ),
                    const SizedBox(height: 12),

                    // Image Preview Section
                    if (_imageFile != null) ...[
                      Container(
                        height: 180,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.grey.shade50,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(_imageFile!.path),
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: 180,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Ảnh mới',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ] else if (widget.nail?.imageUrl != null && widget.nail!.imageUrl.isNotEmpty) ...[
                      Container(
                        height: 180,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.grey.shade50,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            widget.nail!.imageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: 180,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey.shade200,
                                child: const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.broken_image, size: 50, color: Colors.grey),
                                      SizedBox(height: 8),
                                      Text(
                                        'Không thể tải ảnh',
                                        style: TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Ảnh hiện tại',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),

                // Switches
                SwitchListTile(
                  title: const Text('Yêu thích'),
                  value: _isFavorite,
                  onChanged: (value) => setState(() => _isFavorite = value),
                  contentPadding: EdgeInsets.zero,
                ),
                SwitchListTile(
                  title: const Text('Công khai'),
                  subtitle: const Text('Mọi người có thể nhìn thấy mẫu này'),
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