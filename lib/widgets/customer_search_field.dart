import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/providers.dart';
import '../../core/theme/app_theme.dart';

/// Searchable Customer Field — menggantikan dropdown statis di Form Bon.
/// Memungkinkan user mengetik nama pelanggan secara real-time, menampilkan list ber-filter (maks 10),
/// memilih dengan tap, serta menghapus/mengganti dengan tombol [X].
class CustomerSearchField extends StatefulWidget {
  final int? initialCustomerId;
  final String? initialCustomerName;
  final ValueChanged<int?> onSelected;
  final VoidCallback? onClear;

  /// Nonaktifkan input — dipakai saat header sudah tersimpan (pelanggan
  /// terkunci, sama seperti website: ganti pelanggan lewat layar Detail).
  final bool enabled;

  const CustomerSearchField({
    super.key,
    this.initialCustomerId,
    this.initialCustomerName,
    required this.onSelected,
    this.onClear,
    this.enabled = true,
  });

  @override
  State<CustomerSearchField> createState() => _CustomerSearchFieldState();
}

class _CustomerSearchFieldState extends State<CustomerSearchField> {
  late TextEditingController _controller;
  bool _isDropdownOpen = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialCustomerName ?? '');
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant CustomerSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialCustomerName != oldWidget.initialCustomerName &&
        widget.initialCustomerName != null) {
      if (_controller.text != widget.initialCustomerName) {
        _controller.text = widget.initialCustomerName!;
      }
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    // Jika kehilangan fokus, beri sedikit jeda agar tap pada item list sempat tereksekusi
    if (!_focusNode.hasFocus) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && _isDropdownOpen) {
          setState(() => _isDropdownOpen = false);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final customerProvider = context.watch<CustomerProvider>();
    final query = _controller.text.trim().toLowerCase();

    // Filter real-time dari list customer yang sudah dimuat provider (prefix / contains match)
    final filtered = customerProvider.customers
        .where((c) {
          if (!c.isActive && c.id != widget.initialCustomerId) return false;
          if (query.isEmpty) return true;
          return c.name.toLowerCase().contains(query) ||
              (c.phone != null && c.phone!.contains(query));
        })
        .take(10)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          enabled: widget.enabled,
          decoration: InputDecoration(
            hintText: 'Cari pelanggan (ketik nama/hp)...',
            prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_controller.text.isNotEmpty && widget.enabled)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _controller.clear();
                      setState(() {
                        _isDropdownOpen = false;
                      });
                      widget.onSelected(null);
                      widget.onClear?.call();
                    },
                  ),
                const Icon(Icons.arrow_drop_down, color: AppColors.textMuted),
                const SizedBox(width: 8),
              ],
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(
                color: AppColors.brand600,
                width: 1.5,
              ),
            ),
          ),
          onChanged: (val) {
            setState(() {
              _isDropdownOpen = true;
            });
          },
          onTap: () {
            setState(() {
              _isDropdownOpen = true;
            });
          },
        ),
        if (_isDropdownOpen)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            constraints: const BoxConstraints(maxHeight: 240),
            child: customerProvider.loading
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : customerProvider.error != null
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      customerProvider.error!,
                      style: const TextStyle(
                        color: AppColors.dangerText,
                        fontSize: 13,
                      ),
                    ),
                  )
                : filtered.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: Text(
                        'Tidak ada pelanggan ditemukan',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final cust = filtered[index];
                      return InkWell(
                        onTap: () {
                          _controller.text = cust.name;
                          setState(() {
                            _isDropdownOpen = false;
                          });
                          widget.onSelected(cust.id);
                          _focusNode.unfocus();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            border: index < filtered.length - 1
                                ? const Border(
                                    bottom: BorderSide(
                                      color: AppColors.gray100,
                                    ),
                                  )
                                : null,
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.person_outline,
                                size: 16,
                                color: AppColors.textMuted,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      cust.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color: AppColors.textMain,
                                      ),
                                    ),
                                    if (cust.phone != null &&
                                        cust.phone!.isNotEmpty)
                                      Text(
                                        cust.phone!,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
      ],
    );
  }
}
