import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../nails/data/models/nail_shape_model.dart';
import '../../../nails/data/repositories/nail_variant_repository.dart';
import '../../data/profile_data.dart';

class StyleProfileFormDialog extends StatefulWidget {
  final Set<String> initialPersonalities;
  final Set<String> initialColors;
  final String initialMainStyle;
  final Set<String> initialOccasions;
  final String initialNailCondition;
  final String initialSkinTone;
  final String initialSkinShade;
  final String initialHandShape;
  final String initialOccupation;
  final String initialComplexity;
  final int initialNailShapeId;

  final Future<void> Function({
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
  })
  onSubmit;

  const StyleProfileFormDialog({
    super.key,
    required this.initialPersonalities,
    required this.initialColors,
    required this.initialMainStyle,
    required this.initialOccasions,
    required this.initialNailCondition,
    required this.initialSkinTone,
    required this.initialSkinShade,
    required this.initialHandShape,
    required this.initialOccupation,
    required this.initialComplexity,
    required this.initialNailShapeId,
    required this.onSubmit,
  });

  @override
  State<StyleProfileFormDialog> createState() => _StyleProfileFormDialogState();
}

class _StyleProfileFormDialogState extends State<StyleProfileFormDialog> {
  final _formKey = GlobalKey<FormState>();

  String _skinTone = 'Light';
  String _skinShade = 'Warm';
  String _handShape = 'Slender';
  String _complexity = 'Simple';
  int _nailShapeId = 1;
  String _nailCondition = 'Normal';

  final Set<String> _selectedPersonalities = {};
  final Set<String> _selectedColors = {};
  String _mainStyle = 'kbeauty';
  final Set<String> _selectedOccasions = {};

  final TextEditingController _occupationController = TextEditingController();

  List<NailShapeModel> _nailShapesList = [];
  bool _isLoadingShapes = true;
  bool _isSubmitting = false;

  final List<String> _skinTones = ['Light', 'Medium', 'Dark'];
  final List<String> _skinShades = ['Warm', 'Cool', 'Neutral'];
  final List<String> _handShapes = ['Slender', 'Plump', 'Square'];
  final List<String> _complexities = ['Simple', 'Moderate', 'Complex'];
  final List<String> _nailConditions = ['Normal', 'Dry', 'Brittle', 'Weak'];

  final Map<String, String> _swatchIdToHex = {
    'pink': '#F8BBD0',
    'beige': '#D7CCC8',
    'purple': '#6A1B9A',
    'lavender': '#CE93D8',
    'mint': '#A5D6A7',
    'cream': '#FFF8E1',
    'sky': '#90CAF9',
    'rose': '#F06292',
    'grey': '#E0E0E0',
    'sunset': '#FFB74D',
  };

  final Map<String, String> _personalityIdToTitle = {
    'gentle_cute': 'Gentle & Cute',
    'elegant': 'Elegant & Sophisticated',
    'personality': 'Personality & Strength',
    'creativity': 'Creativity & Art',
    'professional': 'Professional & Courteous',
    'natural': 'Natural & Organic',
    'party': 'Featured & Party',
    'minimal': 'Minimal & Clean',
  };

  final Map<String, String> _mainStyleIdToTitle = {
    'kbeauty': 'K-Beauty / Korean Nail',
    'minimalist': 'Minimalist Chic',
    'maximalist': 'Maximalist / Bold Art',
    'dark': 'Dark & Moody',
    'vintage': 'Vintage / Retro',
  };

  final Map<String, String> _occasionIdToLabel = {
    'work': 'Go to work every day',
    'party': 'Parties & events',
    'wedding': 'Wedding',
    'travel': 'Going out / traveling',
    'photos': 'Take photos / content',
    'graduate': 'Graduate',
    'reward': 'Reward yourself',
    'date': 'Date night',
    'sport': 'Active / Sporty',
    'perform': 'Perform',
  };

  @override
  void initState() {
    super.initState();
    _selectedPersonalities.addAll(widget.initialPersonalities);
    _selectedColors.addAll(widget.initialColors);
    _mainStyle = widget.initialMainStyle;
    _selectedOccasions.addAll(widget.initialOccasions);
    _nailCondition = _nailConditions.contains(widget.initialNailCondition)
        ? widget.initialNailCondition
        : 'Normal';
    _skinTone = widget.initialSkinTone;
    _skinShade = widget.initialSkinShade;
    _handShape = widget.initialHandShape;
    _occupationController.text = widget.initialOccupation;
    _complexity = widget.initialComplexity;
    _nailShapeId = widget.initialNailShapeId;

    _fetchShapes();
  }

  @override
  void dispose() {
    _occupationController.dispose();
    super.dispose();
  }

  Future<void> _fetchShapes() async {
    try {
      final repo = getIt<NailVariantRepository>();
      final list = await repo.getNailShapes();
      if (mounted) {
        setState(() {
          _nailShapesList = list;
          _isLoadingShapes = false;
          if (list.isNotEmpty &&
              !list.any((s) => s.nailShapeId == _nailShapeId)) {
            _nailShapeId = list.first.nailShapeId;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingShapes = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Stack(
        children: [
          Form(
            key: _formKey,
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.psychology_outlined,
                        color: AppColors.primary,
                        size: 28,
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Hồ Sơ Phong Cách',
                        style: TextStyle(
                          fontSize: 20,
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

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('Tông da & Sắc độ da'),
                        Row(
                          children: [
                            Expanded(
                              child: _buildDropdown(
                                label: 'Tông da (Skin Tone)',
                                value: _skinTone,
                                items: _skinTones,
                                onChanged: (val) =>
                                    setState(() => _skinTone = val!),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildDropdown(
                                label: 'Sắc độ da (Skin Shade)',
                                value: _skinShade,
                                items: _skinShades,
                                onChanged: (val) =>
                                    setState(() => _skinShade = val!),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        _buildSectionTitle('Dáng tay & Tình trạng móng'),
                        Row(
                          children: [
                            Expanded(
                              child: _buildDropdown(
                                label: 'Dáng tay (Hand Shape)',
                                value: _handShape,
                                items: _handShapes,
                                onChanged: (val) =>
                                    setState(() => _handShape = val!),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildDropdown(
                                label: 'Tình trạng móng',
                                value: _nailCondition,
                                items: _nailConditions,
                                onChanged: (val) =>
                                    setState(() => _nailCondition = val!),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        _buildSectionTitle('Nghề nghiệp & Độ phức tạp móng'),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _occupationController,
                                decoration: InputDecoration(
                                  labelText: 'Nghề nghiệp (Occupation)',
                                  labelStyle: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 13,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                ),
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildDropdown(
                                label: 'Độ phức tạp (Complexity)',
                                value: _complexity,
                                items: _complexities,
                                onChanged: (val) =>
                                    setState(() => _complexity = val!),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        _buildSectionTitle('Dáng móng yêu thích (từ API)'),
                        _isLoadingShapes
                            ? const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.0),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      'Đang tải dáng móng...',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : DropdownButtonFormField<int>(
                                initialValue: _nailShapeId,
                                decoration: InputDecoration(
                                  labelText: 'Dáng móng (Nail Shape)',
                                  labelStyle: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 13,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                ),
                                items: _nailShapesList.map((shape) {
                                  return DropdownMenuItem<int>(
                                    value: shape.nailShapeId,
                                    child: Text(
                                      shape.name,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) =>
                                    setState(() => _nailShapeId = val!),
                              ),
                        const SizedBox(height: 16),

                        _buildSectionTitle('Tính cách & Phong cách'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: ProfileMockData.personalityOptions.map((
                            opt,
                          ) {
                            final isSelected = _selectedPersonalities.contains(
                              opt.id,
                            );
                            return FilterChip(
                              label: Text(opt.title),
                              selected: isSelected,
                              selectedColor: AppColors.primary.withValues(
                                alpha: 0.15,
                              ),
                              checkmarkColor: AppColors.primary,
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? AppColors.primary
                                    : Colors.grey.shade800,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontSize: 13,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: isSelected
                                      ? AppColors.primary
                                      : Colors.grey.shade300,
                                ),
                              ),
                              onSelected: (val) {
                                setState(() {
                                  if (val) {
                                    _selectedPersonalities.add(opt.id);
                                  } else {
                                    _selectedPersonalities.remove(opt.id);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),

                        _buildSectionTitle('Phong cách chính'),
                        DropdownButtonFormField<String>(
                          initialValue: _mainStyle,
                          decoration: InputDecoration(
                            labelText: 'Phong cách chính',
                            labelStyle: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 13,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                          items: ProfileMockData.mainStyles.map((style) {
                            return DropdownMenuItem<String>(
                              value: style.id,
                              child: Text(
                                style.title,
                                style: const TextStyle(fontSize: 14),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) => setState(() => _mainStyle = val!),
                        ),
                        const SizedBox(height: 16),

                        _buildSectionTitle(
                          'Màu sắc ưa thích (Favorite Colors)',
                        ),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: ProfileMockData.colorSwatches.map((opt) {
                            final isSelected = _selectedColors.contains(opt.id);
                            final color =
                                opt.color ??
                                opt.gradientColors?.first ??
                                Colors.grey;
                            final isWhite =
                                opt.id == 'cream' || color == Colors.white;
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    _selectedColors.remove(opt.id);
                                  } else {
                                    _selectedColors.add(opt.id);
                                  }
                                });
                              },
                              child: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primary
                                        : (isWhite
                                              ? Colors.grey.shade400
                                              : Colors.grey.shade200),
                                    width: isSelected ? 3 : 1,
                                  ),
                                  boxShadow: [
                                    if (isSelected)
                                      BoxShadow(
                                        color: AppColors.primary.withValues(
                                          alpha: 0.3,
                                        ),
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                      ),
                                  ],
                                ),
                                child: isSelected
                                    ? Icon(
                                        Icons.check,
                                        size: 18,
                                        color: isWhite
                                            ? Colors.black
                                            : Colors.white,
                                      )
                                    : null,
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),

                        _buildSectionTitle('Dịp sử dụng'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: ProfileMockData.occasions.map((opt) {
                            final isSelected = _selectedOccasions.contains(
                              opt.id,
                            );
                            return FilterChip(
                              label: Text(opt.label),
                              selected: isSelected,
                              selectedColor: AppColors.primary.withValues(
                                alpha: 0.15,
                              ),
                              checkmarkColor: AppColors.primary,
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? AppColors.primary
                                    : Colors.grey.shade800,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontSize: 13,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: isSelected
                                      ? AppColors.primary
                                      : Colors.grey.shade300,
                                ),
                              ),
                              onSelected: (val) {
                                setState(() {
                                  if (val) {
                                    _selectedOccasions.add(opt.id);
                                  } else {
                                    _selectedOccasions.remove(opt.id);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),

                // Footer Buttons
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16.0),
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
                            'Hủy bỏ',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submitForm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Tạo Cấu Hình',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_isSubmitting)
            Positioned.fill(
              child: Container(
                color: Colors.white.withValues(alpha: 0.8),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
      items: items.map((item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(item, style: const TextStyle(fontSize: 14)),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final preferredColors = _selectedColors
          .map((id) => _swatchIdToHex[id] ?? '#F8BBD0')
          .toList();

      final selectedPersonalityTitles = _selectedPersonalities
          .map((id) => _personalityIdToTitle[id] ?? id)
          .toList();
      final mainStyleTitle = _mainStyleIdToTitle[_mainStyle] ?? _mainStyle;
      final preferredStyles = [...selectedPersonalityTitles, mainStyleTitle];

      final preferredOccasions = _selectedOccasions
          .map((id) => _occasionIdToLabel[id] ?? id)
          .toList();

      final apiBody = {
        'skinTone': _skinTone,
        'skinShade': _skinShade,
        'handShape': _handShape,
        'occupation': _occupationController.text.trim().isEmpty
            ? 'Student'
            : _occupationController.text.trim(),
        'nailCondition': _nailCondition,
        'preferredColors': preferredColors,
        'preferredStyles': preferredStyles,
        'preferredOccasions': preferredOccasions,
        'preferredNailShapeId': _nailShapeId,
        'preferredComplexity': _complexity,
      };

      await widget.onSubmit(
        personalities: _selectedPersonalities,
        colors: _selectedColors,
        mainStyle: _mainStyle,
        occasions: _selectedOccasions,
        nailCondition: _nailCondition,
        skinTone: _skinTone,
        skinShade: _skinShade,
        handShape: _handShape,
        occupation: _occupationController.text,
        complexity: _complexity,
        nailShapeId: _nailShapeId,
        apiBody: apiBody,
      );

      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      // Handled by parent
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
