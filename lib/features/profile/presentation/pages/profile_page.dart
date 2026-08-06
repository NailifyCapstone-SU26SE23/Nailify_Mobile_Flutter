import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/localization/locale_service.dart';
import '../../../../core/network/api_client.dart';
import '../../../../generated/l10n.dart';

import '../../data/profile_data.dart';
import '../widgets/personal_notes_section.dart';
import '../widgets/style_profile_form_dialog.dart';
import '../../../quiz/data/datasources/quiz_repository.dart';
import 'dart:convert';

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
  Map<String, dynamic>? _styleCompositionResult;
  final QuizRepository _quizRepo = QuizRepository(getIt<ApiClient>());

  String _skinTone = 'Light';
  String _skinShade = 'Warm';
  String _handShape = 'Slender';
  String _occupation = 'Student';
  String _complexity = 'Simple';
  int _nailShapeId = 1;

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
    _loadStyleComposition();

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

  Future<void> _logout() async {
    await getIt<SharedPreferences>().remove(AppConstants.authTokenKey);
    await getIt<SharedPreferences>().remove('has_completed_quiz');
    if (mounted) {
      setState(() {
        _profileData = null;
        _loyaltyData = null;
        _isLoading = true;
      });
      context.go('/'); // Đưa người dùng về trang chủ
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(S.of(context).logoutSuccess)));
    }
  }

  // gọi tạm api trong này

  Future<void> _loadStyleComposition() async {
    final prefs = getIt<SharedPreferences>();
    final jsonStr = prefs.getString('profile_style_composition');
    if (jsonStr != null) {
      try {
        setState(() {
          _styleCompositionResult = Map<String, dynamic>.from(
            jsonDecode(jsonStr),
          );
        });
      } catch (_) {}
    }

    _skinTone = prefs.getString('profile_skinTone') ?? 'Light';
    _skinShade = prefs.getString('profile_skinShade') ?? 'Warm';
    _handShape = prefs.getString('profile_handShape') ?? 'Slender';
    _occupation = prefs.getString('profile_occupation') ?? 'Student';
    _complexity = prefs.getString('profile_complexity') ?? 'Simple';
    _nailShapeId = prefs.getInt('profile_nailShapeId') ?? 1;

    final pList = prefs.getStringList('profile_selectedPersonalities');
    if (pList != null) {
      _selectedPersonalities.clear();
      _selectedPersonalities.addAll(pList);
    }
    final cList = prefs.getStringList('profile_selectedColors');
    if (cList != null) {
      _selectedColors.clear();
      _selectedColors.addAll(cList);
    }
    _selectedMainStyle =
        prefs.getString('profile_selectedMainStyle') ??
        ProfileMockData.initialMainStyleId;
    final oList = prefs.getStringList('profile_selectedOccasions');
    if (oList != null) {
      _selectedOccasions.clear();
      _selectedOccasions.addAll(oList);
    }
    final nailCond = prefs.getString('profile_nailCondition');
    if (nailCond != null) {
      _noteControllers['NAIL CONDITION']?.text = nailCond;
    }
    setState(() {});
  }

  Future<void> _handleStyleProfileSubmit({
    required Set<String> personalities,
    required Set<String> colors,
    required String mainStyle,
    required Set<String> occasions,
    required String nailCondition,
    required String skinTone,
    required String skinShade,
    required String handShape,
    required String occupation,
    required String complexity,
    required int nailShapeId,
    required Map<String, dynamic> apiBody,
  }) async {
    try {
      final res = await _quizRepo.getNailComposition(apiBody);
      final jsonStr = jsonEncode(res);
      final prefs = getIt<SharedPreferences>();

      await prefs.setString('profile_style_composition', jsonStr);
      await prefs.setString('profile_skinTone', skinTone);
      await prefs.setString('profile_skinShade', skinShade);
      await prefs.setString('profile_handShape', handShape);
      await prefs.setString('profile_occupation', occupation);
      await prefs.setString('profile_complexity', complexity);
      await prefs.setInt('profile_nailShapeId', nailShapeId);
      await prefs.setStringList(
        'profile_selectedPersonalities',
        personalities.toList(),
      );
      await prefs.setStringList('profile_selectedColors', colors.toList());
      await prefs.setString('profile_selectedMainStyle', mainStyle);
      await prefs.setStringList(
        'profile_selectedOccasions',
        occasions.toList(),
      );
      await prefs.setString('profile_nailCondition', nailCondition);

      setState(() {
        _styleCompositionResult = res;
        _skinTone = skinTone;
        _skinShade = skinShade;
        _handShape = handShape;
        _occupation = occupation;
        _complexity = complexity;
        _nailShapeId = nailShapeId;

        _selectedPersonalities.clear();
        _selectedPersonalities.addAll(personalities);
        _selectedColors.clear();
        _selectedColors.addAll(colors);
        _selectedMainStyle = mainStyle;
        _selectedOccasions.clear();
        _selectedOccasions.addAll(occasions);
        _noteControllers['NAIL CONDITION']?.text = nailCondition;
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(S.of(context).updateSuccess)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(S.of(context).updateFailure(e))));
      }
      rethrow;
    }
  }

  Future<void> _fetchProfile() async {
    final token = getIt<SharedPreferences>().getString(
      AppConstants.authTokenKey,
    );
    if (token == null || token.isEmpty) {
      if (mounted) {
        setState(() {
          _profileData = null;
          _isLoading = false;
        });
      }
      return;
    }

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
        ).showSnackBar(SnackBar(content: Text(S.of(context).loadFailure(e))));
      }
    }
  }

  // trả về bool để xử lý đóng popup
  Future<bool> _updateProfile(
    String email,
    String firstName,
    String lastName,
    String phone,
    File? imageFile,
  ) async {
    try {
      final formData = FormData.fromMap({
        'Email': email,
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).updateProfileError(e))),
        );
      }
      return false;
    }
  }

  Future<bool> _updatePassword({
    required String oldPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      final response = await _apiClient.put(
        '/Profile/password',
        data: {
          'oldPassword': oldPassword,
          'newPassword': newPassword,
          'confirmPassword': confirmPassword,
        },
      );

      final responseData = response.data;
      if (responseData is Map && responseData['isSucceeded'] == false) {
        throw Exception(
          responseData['message']?.toString() ?? 'Password update failed',
        );
      }

      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Password update failed: $e')));
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          S.of(context).profileTitle,
          style: const TextStyle(
            color: AppColors.primaryDark,
            fontWeight: FontWeight.w800,
            fontFamily: 'Georgia',
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
          ? Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 40.0,
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Elegant Icon
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.account_circle_outlined,
                        size: 80,
                        color: AppColors.primary.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Prompt Message
                    Text(
                      S.of(context).pleaseLoginToViewProfile,
                      style: const TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    // Action Buttons (Login & Register)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => context.push('/login'),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: AppColors.primary,
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text(
                              S.of(context).login,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => context.push('/register'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text(
                              S.of(context).register,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 48),
                    const Divider(thickness: 1, color: Color(0xFFF5F5F5)),
                    const SizedBox(height: 24),
                    // --- Language Toggle widget ---
                    Consumer<LocaleService>(
                      builder: (ctx, localeService, _) {
                        final isVi =
                            localeService.currentLocale.languageCode == 'vi';
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade100),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.language_rounded,
                                  color: AppColors.primary,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Ngôn ngữ / Language',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      isVi ? 'Tiếng Việt' : 'English',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: () async {
                                  await localeService.toggleLocale();
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  width: 72,
                                  height: 34,
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    gradient: LinearGradient(
                                      colors: isVi
                                          ? [
                                              AppColors.primary,
                                              AppColors.secondary,
                                            ]
                                          : [
                                              Colors.grey.shade300,
                                              Colors.grey.shade400,
                                            ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              left: 6,
                                            ),
                                            child: Text(
                                              'VI',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: isVi
                                                    ? Colors.white
                                                    : Colors.white60,
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              right: 6,
                                            ),
                                            child: Text(
                                              'EN',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: !isVi
                                                    ? Colors.white
                                                    : Colors.white60,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      AnimatedAlign(
                                        duration: const Duration(
                                          milliseconds: 250,
                                        ),
                                        curve: Curves.easeInOut,
                                        alignment: isVi
                                            ? Alignment.centerLeft
                                            : Alignment.centerRight,
                                        child: Container(
                                          width: 28,
                                          height: 28,
                                          decoration: const BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black12,
                                                blurRadius: 4,
                                                offset: Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfileCard(),
                  const SizedBox(height: 16),

                  // Nút Thiết lập phong cách cá nhân
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => StyleProfileFormDialog(
                            initialPersonalities: _selectedPersonalities,
                            initialColors: _selectedColors,
                            initialMainStyle: _selectedMainStyle,
                            initialOccasions: _selectedOccasions,
                            initialNailCondition:
                                _noteControllers['NAIL CONDITION']?.text ?? '',
                            initialSkinTone: _skinTone,
                            initialSkinShade: _skinShade,
                            initialHandShape: _handShape,
                            initialOccupation: _occupation,
                            initialComplexity: _complexity,
                            initialNailShapeId: _nailShapeId,
                            onSubmit: _handleStyleProfileSubmit,
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.psychology,
                        size: 20,
                        color: Colors.white,
                      ),
                      label: Text(
                        S.of(context).styleProfileSetup,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Banner gợi ý mẫu nail phù hợp nếu có kết quả
                  if (_styleCompositionResult != null) ...[
                    _BlinkingBanner(
                      onViewPressed: () => _showNailCompositionResultDialog(
                        _styleCompositionResult!,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // --- Language Toggle ---
                  Consumer<LocaleService>(
                    builder: (ctx, localeService, _) {
                      final isVi =
                          localeService.currentLocale.languageCode == 'vi';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade100),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.language_rounded,
                                color: AppColors.primary,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Ngôn ngữ / Language',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    isVi ? 'Tiếng Việt' : 'English',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Toggle switch VI <-> EN
                            GestureDetector(
                              onTap: () async {
                                await localeService.toggleLocale();
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                width: 72,
                                height: 34,
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  gradient: LinearGradient(
                                    colors: isVi
                                        ? [
                                            AppColors.primary,
                                            AppColors.secondary,
                                          ]
                                        : [
                                            Colors.grey.shade300,
                                            Colors.grey.shade400,
                                          ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            left: 6,
                                          ),
                                          child: Text(
                                            'VI',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: isVi
                                                  ? Colors.white
                                                  : Colors.white60,
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            right: 6,
                                          ),
                                          child: Text(
                                            'EN',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: !isVi
                                                  ? Colors.white
                                                  : Colors.white60,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    AnimatedAlign(
                                      duration: const Duration(
                                        milliseconds: 250,
                                      ),
                                      curve: Curves.easeInOut,
                                      alignment: isVi
                                          ? Alignment.centerLeft
                                          : Alignment.centerRight,
                                      child: Container(
                                        width: 28,
                                        height: 28,
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black12,
                                              blurRadius: 4,
                                              offset: Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildProfileNavButton(
                          icon: Icons.receipt_long_rounded,
                          label: 'Giao dịch',
                          onTap: () => context.push('/profile/transactions'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildProfileNavButton(
                          icon: Icons.favorite_rounded,
                          label: 'Yêu thích',
                          onTap: () =>
                              context.push('/profile/favorite-nails-list'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 100),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(
                        Icons.logout,
                        size: 20,
                        color: Colors.redAccent,
                      ),
                      label: Text(
                        S.of(context).logout,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                          color: Colors.redAccent,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  PersonalNotesSection(
                    notes: ProfileMockData.personalNotes,
                    controllers: _noteControllers,
                    readOnly: _styleCompositionResult != null,
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  // thẻ hiển thị thông tin
  Widget _buildProfileNavButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade100),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
                        Flexible(
                          child: Text(
                            '$loyaltyPoint ${S.of(context).pointsLabel}',
                            style: const TextStyle(
                              color: Colors.yellowAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
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
                          Flexible(
                            child: Text(
                              '${S.of(context).tierLabel} $loyaltyTier',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
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
                  '${S.of(context).statusLabel}: $status',
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
                label: Text(
                  S.of(context).updateProfile,
                  style: const TextStyle(
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
    final emailController = TextEditingController(
      text: _profileData?['email']?.toString() ?? '',
    );
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
                      emailController,
                      'Email',
                      Icons.email_outlined,
                    ),
                    const SizedBox(height: 16),
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
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: isSubmitting
                          ? null
                          : () {
                              Navigator.pop(dialogContext);
                              _showUpdatePasswordPopup();
                            },
                      icon: const Icon(Icons.lock_reset),
                      label: const Text('Đổi mật khẩu'),
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
                            emailController.text.trim(),
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

  void _showUpdatePasswordPopup() {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            Future<void> submit() async {
              final messenger = ScaffoldMessenger.of(context);
              final oldPassword = oldPasswordController.text;
              final newPassword = newPasswordController.text;
              final confirmPassword = confirmPasswordController.text;

              if (oldPassword.isEmpty ||
                  newPassword.isEmpty ||
                  confirmPassword.isEmpty) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Please fill in all password fields'),
                  ),
                );
                return;
              }

              if (newPassword != confirmPassword) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Password confirmation does not match'),
                  ),
                );
                return;
              }

              setStateDialog(() => isSubmitting = true);

              final success = await _updatePassword(
                oldPassword: oldPassword,
                newPassword: newPassword,
                confirmPassword: confirmPassword,
              );

              if (success) {
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
                if (mounted) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Cập nhật mật khẩu thành công!'),
                    ),
                  );
                }
              } else if (dialogContext.mounted) {
                setStateDialog(() => isSubmitting = false);
              }
            }

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                'Đổi mật khẩu',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTextField(
                      oldPasswordController,
                      'Mật khẩu cũ',
                      Icons.lock_outline,
                      isPassword: true,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      newPasswordController,
                      'Mật khẩu mới',
                      Icons.lock_reset,
                      isPassword: true,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      confirmPasswordController,
                      'Xác nhận mật khẩu',
                      Icons.verified_user_outlined,
                      isPassword: true,
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
                  onPressed: isSubmitting ? null : submit,
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
                          'Cập nhật',
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

  void _showNailCompositionResultDialog(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) {
        final shapeName = data['nailShape']?['name']?.toString() ?? 'Almond';
        final shapeImageUrl = data['nailShape']?['imageUrl']?.toString() ?? '';
        final surfaceName =
            data['nailSurface']?['name']?.toString() ?? 'Glossy';
        final colorsList = List<String>.from(data['colors'] ?? []);
        final componentsList = List<dynamic>.from(data['components'] ?? []);
        final reason =
            data['reason']?.toString() ??
            'Cấu hình móng thiết kế riêng phù hợp với các nét cá tính và tông da của bạn.';

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      color: AppColors.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Mẫu Nail Phù Hợp',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Layers List
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // TẦNG 1
                      _buildLayerCard(
                        layerNumber: 'TẦNG 1',
                        title: 'Dáng Móng Đề Xuất (Nail Shape)',
                        icon: Icons.design_services_outlined,
                        color: const Color(0xFFE8F5E9),
                        iconColor: Colors.green.shade700,
                        child: Row(
                          children: [
                            Text(
                              shapeName,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const Spacer(),
                            if (shapeImageUrl.isNotEmpty)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  shapeImageUrl,
                                  width: 44,
                                  height: 44,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const SizedBox(),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // TẦNG 2
                      _buildLayerCard(
                        layerNumber: 'TẦNG 2',
                        title: 'Màu Sắc Chủ Đạo (Base Colors)',
                        icon: Icons.palette_outlined,
                        color: const Color(0xFFE3F2FD),
                        iconColor: Colors.blue.shade700,
                        child: colorsList.isEmpty
                            ? const Text('Màu sắc hài hòa')
                            : Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: colorsList.map((hex) {
                                  Color colorVal;
                                  try {
                                    colorVal = Color(
                                      int.parse(hex.replaceAll('#', '0xFF')),
                                    );
                                  } catch (_) {
                                    colorVal = Colors.grey;
                                  }
                                  return Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          color: colorVal,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.grey.shade300,
                                            width: 1.2,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        hex,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                      ),
                      const SizedBox(height: 12),

                      // TẦNG 3
                      _buildLayerCard(
                        layerNumber: 'TẦNG 3',
                        title: 'Bề Mặt Móng (Nail Surface)',
                        icon: Icons.brush_outlined,
                        color: const Color(0xFFFFF3E0),
                        iconColor: Colors.orange.shade700,
                        child: Text(
                          surfaceName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // TẦNG 4
                      _buildLayerCard(
                        layerNumber: 'TẦNG 4',
                        title: 'Họa Tiết & Phụ Kiện (Components)',
                        icon: Icons.diamond_outlined,
                        color: const Color(0xFFF3E5F5),
                        iconColor: Colors.purple.shade700,
                        child: componentsList.isEmpty
                            ? const Text(
                                'Không đính phụ kiện (Trơn tối giản)',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                ),
                              )
                            : Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: componentsList.map((comp) {
                                  final name = comp['name']?.toString() ?? '';
                                  final url =
                                      comp['imageUrl']?.toString() ?? '';
                                  final type =
                                      comp['componentType']?.toString() ?? '';
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFAF9F6),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFFEDEBE7),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (url.isNotEmpty) ...[
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            child: Image.network(
                                              url,
                                              width: 22,
                                              height: 22,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                        ],
                                        Text(
                                          '$name ($type)',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                      ),
                      const SizedBox(height: 12),

                      // TẦNG 5
                      _buildLayerCard(
                        layerNumber: 'TẦNG 5',
                        title: 'Lý Do Đề Xuất (Vibe & Concept)',
                        icon: Icons.lightbulb_outline_rounded,
                        color: const Color(0xFFFFFDE7),
                        iconColor: Colors.amber.shade900,
                        child: Text(
                          reason,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textPrimary,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),

              // Actions
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        child: Text(
                          'Đóng',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          context.push('/try-on', extra: data);
                        },
                        icon: const Icon(Icons.camera_alt_outlined, size: 18),
                        label: const Text(
                          'Thử Móng Ngay 💅',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLayerCard({
    required String layerNumber,
    required String title,
    required IconData icon,
    required Color color,
    required Color iconColor,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDEBE7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      layerNumber,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: iconColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Icon(
                      Icons.arrow_right_alt_rounded,
                      size: 16,
                      color: Colors.grey,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool isNumber = false,
    bool isPassword = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.phone : TextInputType.text,
      obscureText: isPassword,
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

class _BlinkingBanner extends StatefulWidget {
  final VoidCallback onViewPressed;

  const _BlinkingBanner({required this.onViewPressed});

  @override
  State<_BlinkingBanner> createState() => _BlinkingBannerState();
}

class _BlinkingBannerState extends State<_BlinkingBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.5, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.purple.shade700.withValues(alpha: _animation.value),
                Colors.pink.shade500.withValues(alpha: _animation.value),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.purple.withValues(alpha: 0.3 * _animation.value),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(
                Icons.star_purple500_rounded,
                color: Colors.yellowAccent,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Gợi Ý Hoàn Hảo Cho Bạn! 🌟',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Thiết kế móng tối ưu theo tông da, phong cách & sở thích của riêng bạn.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: widget.onViewPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.purple.shade900,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'XEM NGAY',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
