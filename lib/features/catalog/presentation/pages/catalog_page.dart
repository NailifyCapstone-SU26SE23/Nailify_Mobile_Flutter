import 'package:flutter/material.dart';
import '../../data/models/catalog_mock_data.dart';
import '../widgets/nail_card.dart';
import '../widgets/quiz_banner.dart';
import '../widgets/advanced_filter_bottom_sheet.dart';

class CatalogPage extends StatefulWidget {
  const CatalogPage({super.key});

  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  final TextEditingController _searchController = TextEditingController();

  // Danh sách hiển thị trên UI (sẽ bị thay đổi khi dùng filter)
  List<Map<String, dynamic>> _filteredNails = [];

  // Trạng thái của Dropdown Event
  String? _selectedEvent;

  // Trạng thái của Advanced Filter
  Map<String, Set<String>> _advancedFilters = {
    'styles': <String>{},
    'themes': <String>{},
    'designs': <String>{},
    'variants': <String>{},
    'detailElements': <String>{},
  };

  @override
  void initState() {
    super.initState();
    // Ban đầu hiển thị toàn bộ danh sách
    _filteredNails = List.from(CatalogMockData.nails);

    // Lắng nghe thay đổi từ thanh tìm kiếm
    _searchController.addListener(() {
      _applyFilters();
    });
  }

  // LOGIC LỌC DỮ LIỆU CỐT LÕI
  void _applyFilters() {
    List<Map<String, dynamic>> result = CatalogMockData.nails;

    // 1. Lọc theo Search (Text)
    final query = _searchController.text.toLowerCase().trim();
    if (query.isNotEmpty) {
      result = result.where((nail) {
        return nail['name'].toString().toLowerCase().contains(query);
      }).toList();
    }

    // 2. Lọc theo Event (Dropdown)
    if (_selectedEvent != null && _selectedEvent != 'All Events') {
      result = result.where((nail) {
        List<String> tags = List<String>.from(nail['tags'] ?? []);
        return tags.contains(_selectedEvent);
      }).toList();
    }

    // 3. Lọc theo Advanced Filter (Bottom Sheet)
    if (_advancedFilters.values.any((set) => set.isNotEmpty)) {
      result = result.where((nail) {
        List<String> tags = List<String>.from(nail['tags'] ?? []);
        bool matchesAllActiveCategories = true;

        for (var entry in _advancedFilters.entries) {
          Set<String> selectedOptions = entry.value;
          if (selectedOptions.isNotEmpty) {
            bool hasMatchInThisCategory = selectedOptions.any((option) => tags.contains(option));
            if (!hasMatchInThisCategory) {
              matchesAllActiveCategories = false;
              break;
            }
          }
        }
        return matchesAllActiveCategories;
      }).toList();
    }

    // Cập nhật lại UI
    setState(() {
      _filteredNails = result;
    });
  }

  void _openAdvancedFilter() async {
    final result = await showModalBottomSheet<Map<String, Set<String>>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      // Truyền filter hiện tại vào để UI trong popup không bị reset
      builder: (context) => AdvancedFilterBottomSheet(initialFilters: _advancedFilters),
    );

    // Khi người dùng bấm "Apply Filters", nhận dữ liệu và chạy logic lọc
    if (result != null) {
      setState(() {
        _advancedFilters = result;
      });
      _applyFilters();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 402),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                //Giao diện Search & Nút lọc
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search for designs...',
                            hintStyle: const TextStyle(color: Colors.grey),
                            prefixIcon: const Icon(Icons.search, color: Colors.grey),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 0),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF66C4).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.tune, color: Color(0xFFFF66C4)),
                          onPressed: _openAdvancedFilter,
                        ),
                      ),
                    ],
                  ),
                ),

                // Sub-filter: Dropdown Event và Nút mở Filter
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      // DROPDOWN CHO EVENT
                      Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedEvent,
                            hint: const Text('Event', style: TextStyle(fontSize: 14, color: Colors.black87)),
                            icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.black87),
                            isDense: true,
                            items: ['All Events', ...CatalogMockData.occasions].map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value, style: const TextStyle(fontSize: 14)),
                              );
                            }).toList(),
                            onChanged: (newValue) {
                              setState(() {
                                _selectedEvent = newValue;
                              });
                              _applyFilters();
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Nút Filter nhanh
                      ActionChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Filter '),
                            Icon(
                              Icons.filter_list,
                              size: 16,
                              color: _advancedFilters.values.any((s) => s.isNotEmpty) ? const Color(0xFFFF66C4) : Colors.black87,
                            )
                          ],
                        ),
                        onPressed: _openAdvancedFilter,
                        backgroundColor: Colors.white,
                        side: BorderSide(
                          color: _advancedFilters.values.any((s) => s.isNotEmpty)
                              ? const Color(0xFFFF66C4)
                              : Colors.grey.shade300,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                //  Danh sách
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: _filteredNails.isEmpty
                      ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40.0),
                    child: Center(
                      child: Text(
                        'Không tìm thấy mẫu móng nào phù hợp với bộ lọc.',
                        style: TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                      : GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _filteredNails.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.75,
                    ),
                    itemBuilder: (context, index) {
                      final nail = _filteredNails[index];
                      // Truyền nguyên khối Map dữ liệu vào NailCard
                      return NailCard(
                        nailData: nail,
                      );
                    },
                  ),
                ),

                // Banner Quiz
                const QuizBanner(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}