import 'package:flutter/material.dart';

import '../../design/app_tokens.dart';
import '../../design/reference_assets.dart';
import 'reference_menu_button.dart';

/// Browse/list header — matches mobile `HeaderBox` (bg1, slice, search pill).
class PageHeaderBox extends StatefulWidget {
  const PageHeaderBox({
    super.key,
    required this.title,
    required this.categoryLabel,
    required this.bookLabel,
    this.searchHint,
    this.onSearchChanged,
    this.initialQuery = '',
  });

  final String title;
  final String categoryLabel;
  final String bookLabel;
  final String? searchHint;
  final ValueChanged<String>? onSearchChanged;
  final String initialQuery;

  @override
  State<PageHeaderBox> createState() => _PageHeaderBoxState();
}

class _PageHeaderBoxState extends State<PageHeaderBox> {
  late final TextEditingController _searchController;
  bool _searchFocused = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hint = widget.searchHint ?? 'Search...';

    return SizedBox(
      height: 250,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: 250,
            width: double.infinity,
            padding: const EdgeInsets.only(top: 35),
            decoration: const BoxDecoration(
              image: DecorationImage(
                opacity: 0.5,
                image: AssetImage(ReferenceAssets.bgPattern),
                fit: BoxFit.cover,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.category_outlined,
                      size: 15,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.categoryLabel,
                      style: const TextStyle(fontSize: 15, color: Colors.black),
                    ),
                    const SizedBox(width: 10),
                    const Icon(
                      Icons.library_books_outlined,
                      size: 15,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.bookLabel,
                      style: const TextStyle(fontSize: 15, color: Colors.black),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Positioned(
          //   top: -50,
          //   right: 0,
          //   child: Container(
          //     width: 200,
          //     height: 250,
          //     decoration: const BoxDecoration(
          //       image: DecorationImage(
          //         image: AssetImage(ReferenceAssets.headerSlice),
          //         fit: BoxFit.contain,
          //       ),
          //     ),
          //   ),
          // ),
          Positioned(
            top: ReferenceMenuLayout.top(context),
            left: ReferenceMenuLayout.left,
            child: const ReferenceMenuButton(),
          ),
          if (widget.onSearchChanged != null)
            Positioned(
              left: 30,
              right: 30,
              bottom: 10,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _searchController,
                  builder: (context, value, _) {
                    return TextField(
                      controller: _searchController,
                      onChanged: widget.onSearchChanged,
                      onTap: () => setState(() => _searchFocused = true),
                      onSubmitted: (_) =>
                          setState(() => _searchFocused = false),
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                      decoration: InputDecoration(
                        hintText: hint,
                        hintStyle: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 16,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: _searchFocused
                              ? AppColors.referencePrimary
                              : Colors.grey[400],
                          size: 24,
                        ),
                        suffixIcon: value.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.clear,
                                  color: Colors.grey[400],
                                  size: 20,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  widget.onSearchChanged?.call('');
                                  setState(() => _searchFocused = false);
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: const BorderSide(
                            color: AppColors.referencePrimary,
                            width: 2,
                          ),
                        ),
                        filled: false,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 0),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
