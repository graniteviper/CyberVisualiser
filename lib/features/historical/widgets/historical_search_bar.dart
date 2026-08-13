import 'package:flutter/material.dart';

/// A search bar widget specifically optimized for live filtering of historical attacks.
class HistoricalSearchBar extends StatefulWidget {
  final ValueChanged<String> onChanged;
  final String initialQuery;

  const HistoricalSearchBar({
    super.key,
    required this.onChanged,
    required this.initialQuery,
  });

  @override
  State<HistoricalSearchBar> createState() => _HistoricalSearchBarState();
}

class _HistoricalSearchBarState extends State<HistoricalSearchBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
  }

  @override
  void didUpdateWidget(covariant HistoricalSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync external query changes, e.g. when filters are cleared
    if (widget.initialQuery != oldWidget.initialQuery &&
        widget.initialQuery != _controller.text) {
      _controller.text = widget.initialQuery;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: TextField(
        controller: _controller,
        onChanged: widget.onChanged,
        decoration: InputDecoration(
          hintText: 'Search title, victim, attacker, summary, tags...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _controller.clear();
                    widget.onChanged('');
                  },
                )
              : null,
          filled: true,
          fillColor: isDark ? const Color(0xFF161925) : Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: isDark
                ? BorderSide(color: Colors.blueGrey.shade800.withOpacity(0.5))
                : BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: isDark
                ? BorderSide(color: Colors.blueGrey.shade800.withOpacity(0.5))
                : BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 1.5,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 14,
            horizontal: 16,
          ),
        ),
      ),
    );
  }
}
