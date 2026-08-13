import 'package:flutter/material.dart';

/// A widget displaying horizontal filter chips for filtering historical cyber attacks.
class HistoricalFilterBar extends StatelessWidget {
  final List<String> countries;
  final List<String> categories;
  final List<String> sectors;
  final List<int> years;

  final String? selectedCountry;
  final String? selectedCategory;
  final String? selectedSector;
  final int? selectedYear;

  final ValueChanged<String?> onCountryChanged;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String?> onSectorChanged;
  final ValueChanged<int?> onYearChanged;
  final VoidCallback onClearAll;

  const HistoricalFilterBar({
    super.key,
    required this.countries,
    required this.categories,
    required this.sectors,
    required this.years,
    required this.selectedCountry,
    required this.selectedCategory,
    required this.selectedSector,
    required this.selectedYear,
    required this.onCountryChanged,
    required this.onCategoryChanged,
    required this.onSectorChanged,
    required this.onYearChanged,
    required this.onClearAll,
  });

  bool get hasActiveFilters =>
      selectedCountry != null ||
      selectedCategory != null ||
      selectedSector != null ||
      selectedYear != null;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: Row(
            children: [
              // Country Chip
              _buildFilterChip(
                context: context,
                label: selectedCountry ?? 'Country',
                isSelected: selectedCountry != null,
                onTap: () => _showSelector(
                  context: context,
                  title: 'Select Country',
                  options: countries,
                  selectedValue: selectedCountry,
                  onSelected: onCountryChanged,
                ),
                onClear: () => onCountryChanged(null),
              ),
              const SizedBox(width: 8),

              // Category Chip
              _buildFilterChip(
                context: context,
                label: selectedCategory ?? 'Category',
                isSelected: selectedCategory != null,
                onTap: () => _showSelector(
                  context: context,
                  title: 'Select Category',
                  options: categories,
                  selectedValue: selectedCategory,
                  onSelected: onCategoryChanged,
                ),
                onClear: () => onCategoryChanged(null),
              ),
              const SizedBox(width: 8),

              // Sector Chip
              _buildFilterChip(
                context: context,
                label: selectedSector ?? 'Sector',
                isSelected: selectedSector != null,
                onTap: () => _showSelector(
                  context: context,
                  title: 'Select Sector',
                  options: sectors,
                  selectedValue: selectedSector,
                  onSelected: onSectorChanged,
                ),
                onClear: () => onSectorChanged(null),
              ),
              const SizedBox(width: 8),

              // Year Chip
              _buildFilterChip(
                context: context,
                label: selectedYear != null ? selectedYear.toString() : 'Year',
                isSelected: selectedYear != null,
                onTap: () => _showSelector<int>(
                  context: context,
                  title: 'Select Year',
                  options: years,
                  selectedValue: selectedYear,
                  onSelected: onYearChanged,
                ),
                onClear: () => onYearChanged(null),
              ),

              if (hasActiveFilters) ...[
                const SizedBox(width: 12),
                TextButton.icon(
                  onPressed: onClearAll,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.clear_all, size: 16),
                  label: const Text(
                    'Clear All',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip({
    required BuildContext context,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InputChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (!isSelected) ...[
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 16),
          ],
        ],
      ),
      selected: isSelected,
      onPressed: onTap,
      onDeleted: isSelected ? onClear : null,
      deleteIcon: isSelected ? const Icon(Icons.cancel, size: 16) : null,
      deleteButtonTooltipMessage: 'Clear filter',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: BorderSide(
        color: isSelected
            ? Theme.of(context).colorScheme.primary
            : (isDark ? Colors.blueGrey.shade800 : Colors.grey.shade300),
      ),
      selectedColor: Theme.of(context).colorScheme.primaryContainer,
      labelStyle: TextStyle(
        color: isSelected
            ? Theme.of(context).colorScheme.onPrimaryContainer
            : (isDark ? Colors.grey.shade300 : Colors.black87),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
    );
  }

  void _showSelector<T>({
    required BuildContext context,
    required String title,
    required List<T> options,
    required T? selectedValue,
    required ValueChanged<T?> onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        List<T> filteredOptions = List.from(options);

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                top: 8,
              ),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Pull handler
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Sheet Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        if (selectedValue != null)
                          TextButton(
                            onPressed: () {
                              onSelected(null);
                              Navigator.pop(context);
                            },
                            child: const Text('Clear Filter'),
                          ),
                      ],
                    ),
                  ),
                  const Divider(),

                  // Option Search Field for lists with many entries
                  if (options.length > 8)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      child: TextField(
                        autofocus: false,
                        decoration: InputDecoration(
                          hintText: 'Search options...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 8,
                          ),
                        ),
                        onChanged: (val) {
                          setModalState(() {
                            filteredOptions = options
                                .where(
                                  (opt) => opt
                                      .toString()
                                      .toLowerCase()
                                      .contains(val.toLowerCase()),
                                )
                                .toList();
                          });
                        },
                      ),
                    ),

                  // Option List
                  Expanded(
                    child: filteredOptions.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Text(
                                'No matching options',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: Colors.grey),
                              ),
                            ),
                          )
                        : ListView.builder(
                            physics: const ClampingScrollPhysics(),
                            itemCount: filteredOptions.length,
                            itemBuilder: (context, index) {
                              final item = filteredOptions[index];
                              final isSelected = item == selectedValue;
                              return ListTile(
                                title: Text(
                                  item.toString(),
                                  style: TextStyle(
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.primary
                                        : null,
                                  ),
                                ),
                                trailing: isSelected
                                    ? Icon(
                                        Icons.check_circle_rounded,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      )
                                    : null,
                                selected: isSelected,
                                onTap: () {
                                  onSelected(item);
                                  Navigator.pop(context);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
