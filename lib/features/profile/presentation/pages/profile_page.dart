import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';

import '../../data/profile_data.dart';
import '../widgets/personality_style_section.dart';
import '../widgets/favorite_color_section.dart';
import '../widgets/main_style_section.dart';
import '../widgets/occasions_section.dart';
import '../widgets/personal_notes_section.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final ApiClient _apiClient = getIt<ApiClient>();

  bool _isLoading = true;
  Map<String, dynamic>? _profileData;
  Map<String, dynamic>? _loyaltyData;

  // state cho các widget
  final Set<String> _selectedPersonalities = Set.from(
    ProfileMockData.initialSelectedPersonalities,
  );
  final Set<String> _selectedColors = Set.from(
    ProfileMockData.initialSelectedColors,
  );
  String _selectedMainStyle = ProfileMockData.initialMainStyleId;
  final Set<String> _selectedOccasions = Set.from(
    ProfileMockData.initialSelectedOccasions,
  );
  final Map<String, TextEditingController> _noteControllers = {};

  @override
  void initState() {
    super.initState();
    _fetchProfile();

    // khởi tạo Controllers cho phần Personal Notes
    for (var note in ProfileMockData.personalNotes) {
      _noteControllers[note.title] = TextEditingController(
        text: note.content ?? '',
      );
    }
  }

  @override
  void dispose() {
    for (var controller in _noteControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // gọi tạm api trong này

  Future<void> _fetchProfile() async {
    try {
      final results = await Future.wait([
        _apiClient.get('/Profile/customers'),
        _apiClient.get('/Loyalty/me'),
      ]);

      final profileResponse = results[0];
      final loyaltyResponse = results[1];

      if (profileResponse.data != null &&
          profileResponse.data['isSucceeded'] == true) {
        if (mounted) {
          setState(() {
            _profileData = profileResponse.data['data'];
            _loyaltyData = loyaltyResponse.data?['data'];
            _isLoading = false;
          });
        }
      } else {
        throw Exception(
          profileResponse.data?['message'] ?? 'Lỗi không xác định',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Không thể tải thông tin: $e')));
      }
    }
  }

  // trả về bool để xử lý đóng popup
  Future<bool> _updateProfile(
    String firstName,
    String lastName,
    String phone,
    File? imageFile,
  ) async {
    try {
      final formData = FormData.fromMap({
        'FirstName': firstName,
        'LastName': lastName,
        'Phone': phone,
        if (imageFile != null)
          'image': await MultipartFile.fromFile(
            imageFile.path,
            filename: imageFile.path.split('/').last,
          ),
      });

      await _apiClient.put('/Profile', data: formData);
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi cập nhật: $e')));
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Hồ sơ cá nhân',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _profileData == null
          ? const Center(child: Text('Không có dữ liệu khách hàng.'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfileCard(),
                  const SizedBox(height: 24),

                  PersonalityStyleSection(
                    options: ProfileMockData.personalityOptions,
                    selectedIds: _selectedPersonalities,
                    maxSelections: ProfileMockData.maxPersonalitySelections,
                    onToggle: (id) {
                      setState(() {
                        if (_selectedPersonalities.contains(id)) {
                          _selectedPersonalities.remove(id);
                        } else if (_selectedPersonalities.length <
                            ProfileMockData.maxPersonalitySelections) {
                          _selectedPersonalities.add(id);
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 24),

                  FavoriteColorSection(
                    swatches: ProfileMockData.colorSwatches,
                    selectedIds: _selectedColors,
                    onToggle: (id) {
                      setState(() {
                        if (_selectedColors.contains(id)) {
                          _selectedColors.remove(id);
                        } else {
                          _selectedColors.add(id);
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 24),

                  MainStyleSection(
                    options: ProfileMockData.mainStyles,
                    selectedId: _selectedMainStyle,
                    onSelected: (id) {
                      setState(() {
                        _selectedMainStyle = id;
                      });
                    },
                  ),
                  const SizedBox(height: 24),

                  OccasionsSection(
                    options: ProfileMockData.occasions,
                    selectedIds: _selectedOccasions,
                    onToggle: (id) {
                      setState(() {
                        if (_selectedOccasions.contains(id)) {
                          _selectedOccasions.remove(id);
                        } else {
                          _selectedOccasions.add(id);
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 24),

                  PersonalNotesSection(
                    notes: ProfileMockData.personalNotes,
                    controllers: _noteControllers,
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  // thẻ hiển thị thông tin
  Widget _buildProfileCard() {
    final String rawAvatar = _profileData?['avatarUrl']?.toString() ?? '';
    final String avatarUrl = rawAvatar.replaceAll(RegExp(r'\s+'), '');

    final firstName = _profileData?['firstName']?.toString() ?? '';
    final lastName = _profileData?['lastName']?.toString() ?? '';
    final phone = _profileData?['phone']?.toString() ?? 'Chưa cập nhật';
    final status = _profileData?['status']?.toString() ?? 'N/A';
    final loyaltyPoint =
        _loyaltyData?['loyaltyPoint']?.toString() ??
        _profileData?['loyaltyPoint']?.toString() ??
        '0';
    final loyaltyTier =
        (_loyaltyData?['loyaltyTier'] as Map<String, dynamic>?)?['name']
            ?.toString();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.secondary.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.white,
                  backgroundImage: avatarUrl.isNotEmpty
                      ? NetworkImage(avatarUrl)
                      : null,
                  onBackgroundImageError: avatarUrl.isNotEmpty
                      ? (e, s) => debugPrint('Lỗi tải ảnh: $e')
                      : null,
                  child: avatarUrl.isEmpty
                      ? const Icon(Icons.person, size: 40, color: Colors.grey)
                      : null,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$firstName $lastName',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.phone,
                          size: 16,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          phone,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.stars,
                          size: 16,
                          color: Colors.yellowAccent,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$loyaltyPoint điểm',
                          style: const TextStyle(
                            color: Colors.yellowAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    if (loyaltyTier != null && loyaltyTier.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.workspace_premium,
                            size: 16,
                            color: Colors.white70,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Hạng $loyaltyTier',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.white30, height: 1),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Trạng thái: $status',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showUpdatePopup,
                icon: const Icon(
                  Icons.edit,
                  size: 16,
                  color: AppColors.primary,
                ),
                label: const Text(
                  'Cập nhật',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // popup cập nhật profile

  void _showUpdatePopup() {
    final firstNameController = TextEditingController(
      text: _profileData?['firstName']?.toString() ?? '',
    );
    final lastNameController = TextEditingController(
      text: _profileData?['lastName']?.toString() ?? '',
    );
    final phoneController = TextEditingController(
      text: _profileData?['phone']?.toString() ?? '',
    );

    // debug: dọn dẹp chuỗi ảnh
    final String rawAvatar = _profileData?['avatarUrl']?.toString() ?? '';
    final String avatarUrl = rawAvatar.replaceAll(RegExp(r'\s+'), '');

    File? selectedImage;
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            Future<void> pickImage() async {
              final picker = ImagePicker();
              final pickedFile = await picker.pickImage(
                source: ImageSource.gallery,
              );
              if (pickedFile != null) {
                setStateDialog(() => selectedImage = File(pickedFile.path));
              }
            }

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                'Cập nhật hồ sơ',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: pickImage,
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.grey.shade200,
                            backgroundImage: selectedImage != null
                                ? FileImage(selectedImage!) as ImageProvider
                                : avatarUrl.isNotEmpty
                                ? NetworkImage(avatarUrl)
                                : null,
                            onBackgroundImageError: avatarUrl.isNotEmpty
                                ? (e, s) => debugPrint('Lỗi ảnh popup')
                                : null,
                            child: (selectedImage == null && avatarUrl.isEmpty)
                                ? const Icon(
                                    Icons.person,
                                    size: 50,
                                    color: Colors.grey,
                                  )
                                : null,
                          ),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildTextField(
                      firstNameController,
                      'Tên (First Name)',
                      Icons.person_outline,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      lastNameController,
                      'Họ (Last Name)',
                      Icons.badge_outlined,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      phoneController,
                      'Số điện thoại',
                      Icons.phone_outlined,
                      isNumber: true,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text(
                    'Hủy',
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          setStateDialog(() => isSubmitting = true);

                          final success = await _updateProfile(
                            firstNameController.text.trim(),
                            lastNameController.text.trim(),
                            phoneController.text.trim(),
                            selectedImage,
                          );

                          if (success) {
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Cập nhật hồ sơ thành công!'),
                                ),
                              );
                              setState(() => _isLoading = true);
                              _fetchProfile(); // reload Data
                            }
                          } else {
                            if (dialogContext.mounted) {
                              setStateDialog(() => isSubmitting = false);
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Lưu thay đổi',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool isNumber = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.phone : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }
}
