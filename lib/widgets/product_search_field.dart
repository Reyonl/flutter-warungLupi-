import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../utils/format.dart';

/// Searchable Product/Item Field — menggantikan dropdown statis di form item.
///
/// User mengetik nama item, hasil difilter real-time dari data yang sudah
/// dimuat `ProductProvider` (GET /api/products?is_active=1 — sama seperti
/// website: load semua, filter client-side). Maksimal 10 hasil agar tidak
/// ada scroll panjang. Setelah tap, field otomatis kosong dan siap untuk
/// item berikutnya.
class ProductSearchField extends StatefulWidget {
  /// Dipanggil saat user mengetuk hasil — parent mengisi form item
  /// (nama, harga default, unit) lalu mem-fokus ke field qty.
  final ValueChanged<Product> onSelected;

  /// Dipanggil saat user memilih "+ Input Manual / Item Lain".
  final VoidCallback? onSelectManual;

  /// Dipanggil saat user menekan tombol clear (X) di field pencarian.
  final VoidCallback? onClear;

  /// Nonaktifkan input (misal saat mode edit item / header terkunci).
  final bool enabled;

  const ProductSearchField({
    super.key,
    required this.onSelected,
    this.onSelectManual,
    this.onClear,
    this.enabled = true,
  });

  @override
  State<ProductSearchField> createState() => _ProductSearchFieldState();
}

class _ProductSearchFieldState extends State<ProductSearchField> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && _isOpen) setState(() => _isOpen = false);
      });
    }
  }

  List<Product> _filtered(List<Product> products, String query) {
    final q = query.toLowerCase();
    final list = q.isEmpty
        ? products
        : products
            .where((p) => p.name.toLowerCase().contains(q))
            .toList();
    return list.take(10).toList();
  }

  @override
  Widget build(BuildContext context) {
    final prodProv = context.watch<ProductProvider>();
    final query = _controller.text.trim();
    final filtered = _filtered(prodProv.products, query);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          enabled: widget.enabled,
          decoration: InputDecoration(
            hintText: 'Cari item...',
            prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
            suffixIcon: _controller.text.isNotEmpty && widget.enabled
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _controller.clear();
                      setState(() => _isOpen = true);
                      widget.onClear?.call();
                    },
                  )
                : const Icon(
                    Icons.arrow_drop_down,
                    color: AppColors.textMuted,
                  ),
          ),
          onChanged: (_) => setState(() => _isOpen = true),
          onTap: () => setState(() => _isOpen = true),
          onSubmitted: (_) => setState(() {}),
        ),
        if (_isOpen)
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
            constraints: const BoxConstraints(maxHeight: 280),
            child: prodProv.loading
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
                : prodProv.error != null
                    ? Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          prodProv.error!,
                          style: const TextStyle(
                            color: AppColors.dangerText,
                            fontSize: 13,
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: filtered.length + 1, // +1 = opsi manual
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return InkWell(
                              onTap: () {
                                _controller.clear();
                                setState(() => _isOpen = false);
                                widget.onSelectManual?.call();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: const BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(color: AppColors.gray100),
                                  ),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.add,
                                      size: 16,
                                      color: AppColors.brand600,
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      'Input Manual / Item Lain',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.brand600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                          final item = filtered[index - 1];
                          return InkWell(
                            onTap: () {
                              _controller.clear();
                              setState(() => _isOpen = false);
                              widget.onSelected(item);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                border: index < filtered.length
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
                                    Icons.inventory_2_outlined,
                                    size: 16,
                                    color: AppColors.textMuted,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      item.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color: AppColors.textMain,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${formatRupiah(item.defaultPrice)} / ${item.unit}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.gray600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        if (_isOpen && filtered.isEmpty && query.isNotEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'Tidak ada item ditemukan',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ),
      ],
    );
  }
}