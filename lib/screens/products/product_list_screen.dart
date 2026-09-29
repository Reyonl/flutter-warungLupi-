import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../utils/format.dart';
import '../../widgets/widgets.dart';

/// Daftar Item — meniru `pages/products/ProductList.jsx`.
/// Search (debounce), filter kategori & status, tambah/edit modal,
/// toggle aktif, hapus confirm, toasts.
class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final _searchDebounce = Debouncer(400, () {});

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<ProductProvider>();
      p.loadCategories();
      p.load();
    });
  }

  @override
  void dispose() {
    _searchDebounce.dispose();
    super.dispose();
  }

  void _openForm({Product? product}) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => ProductFormScreen(product: product),
          ),
        )
        .then((saved) {
          if (saved != null && mounted) {
            showToast(
              context,
              product == null
                  ? 'Item berhasil ditambahkan!'
                  : 'Item berhasil diperbarui!',
            );
          }
        });
  }

  Future<void> _confirmDelete(Product p) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Hapus Item?',
      message:
          'Item "${p.name}" akan dihapus secara permanen. Tindakan ini tidak bisa dibatalkan.',
    );
    if (ok == true && mounted) {
      final msg = await context.read<ProductProvider>().delete(p);
      if (msg != null && mounted) showToast(context, msg);
    }
  }

  Future<void> _toggleActive(Product p) async {
    final msg = await context.read<ProductProvider>().toggleActive(p);
    if (msg != null && mounted) showToast(context, msg);
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ProductProvider>();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: PageHeader(
            title: 'Daftar Item',
            actions: [
              DarkButton(
                label: 'Tambah Item',
                icon: Icons.add,
                onPressed: () => _openForm(),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              TextField(
                onChanged: (v) {
                  _searchDebounce.run(() {
                    context.read<ProductProvider>().setSearch(v);
                    context.read<ProductProvider>().load();
                  });
                },
                decoration: const InputDecoration(
                  hintText: 'Cari nama item...',
                  prefixIcon: Icon(Icons.search, size: 20),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _FilterDropdown<String>(
                      value: prov.filterCategory?.toString() ?? '',
                      items: {
                        '': 'Semua Kategori',
                        ...{
                          for (final c in prov.categories)
                            c.id.toString(): c.name,
                        },
                      },
                      onChanged: (v) {
                        context.read<ProductProvider>().setFilterCategory(
                          v == null || v.isEmpty ? null : int.parse(v),
                        );
                        context.read<ProductProvider>().load();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _FilterDropdown<String>(
                      value: prov.filterActive == null
                          ? ''
                          : (prov.filterActive! ? '1' : '0'),
                      items: const {
                        '': 'Semua Status',
                        '1': 'Aktif',
                        '0': 'Nonaktif',
                      },
                      onChanged: (v) {
                        context.read<ProductProvider>().setFilterActive(
                          v == null || v.isEmpty ? null : v == '1',
                        );
                        context.read<ProductProvider>().load();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(child: _buildBody(prov)),
      ],
    );
  }

  Widget _buildBody(ProductProvider prov) {
    if (prov.loading && prov.products.isEmpty) {
      return const LoadingState(text: 'Memuat data...');
    }
    if (prov.error != null && prov.products.isEmpty) {
      return InlineMessage(prov.error!);
    }
    if (prov.products.isEmpty) {
      return const EmptyState(title: 'Tidak ada item ditemukan.', subtitle: '');
    }
    return RefreshIndicator(
      onRefresh: () => prov.load(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: prov.products.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, idx) {
          final p = prov.products[idx];
          final cat = prov.categories
              .where((c) => c.id == p.categoryId)
              .firstOrNull;
          return _ProductCard(
            product: p,
            categoryName: cat?.name,
            onEdit: () => _openForm(product: p),
            onToggle: () => _toggleActive(p),
            onDelete: () => _confirmDelete(p),
          );
        },
      ),
    );
  }
}

class _FilterDropdown<T> extends StatelessWidget {
  final T value;
  final Map<T, String> items;
  final ValueChanged<T?> onChanged;

  const _FilterDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isDense: true,
      decoration: const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      items: items.entries
          .map(
            (e) => DropdownMenuItem<T>(
              value: e.key,
              child: Text(e.value, style: const TextStyle(fontSize: 13)),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final String? categoryName;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _ProductCard({
    required this.product,
    this.categoryName,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMain,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      categoryName ?? '—',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onToggle,
                child: StatusBadge.product(product.isActive),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  formatRupiah(product.defaultPrice),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMain,
                  ),
                ),
              ),
              Text(
                product.unit,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onEdit,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.gray600,
                    side: const BorderSide(color: AppColors.borderStrong),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: const Text('Edit', style: TextStyle(fontSize: 13)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: onDelete,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.dangerText,
                    side: const BorderSide(color: AppColors.borderStrong),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: const Text('Hapus', style: TextStyle(fontSize: 13)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Form tambah/edit item dalam halaman penuh (padanan modal ProductFormModal).
class ProductFormScreen extends StatefulWidget {
  final Product? product;
  const ProductFormScreen({super.key, this.product});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _price;
  late final TextEditingController _unit;
  String? _categoryId;
  bool _isActive = true;
  bool _saving = false;
  String? _globalError;

  bool get _isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _name = TextEditingController(text: p?.name ?? '');
    _price = TextEditingController(text: p?.defaultPrice.toString() ?? '');
    _unit = TextEditingController(text: p?.unit ?? 'pcs');
    _categoryId = p?.categoryId?.toString();
    _isActive = p?.isActive ?? true;
    // Load categories untuk dropdown
    Future.microtask(() {
      final prov = context.read<ProductProvider>();
      if (prov.categories.isEmpty) prov.loadCategories();
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _unit.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final catId = int.tryParse(_categoryId ?? '');
    if (catId == null) {
      setState(() => _globalError = 'Kategori wajib dipilih.');
      return;
    }
    setState(() {
      _saving = true;
      _globalError = null;
    });
    try {
      await context.read<ProductProvider>().save(
        id: widget.product?.id,
        categoryId: catId,
        name: _name.text,
        defaultPrice:
            int.tryParse(_price.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
        unit: _unit.text,
        isActive: _isActive,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _globalError = 'Terjadi kesalahan. Coba lagi.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ProductProvider>();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(_isEdit ? 'Edit Item' : 'Tambah Item Baru')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_globalError != null) InlineMessage(_globalError!),
                    AppFormField(
                      label: 'Kategori',
                      required: true,
                      child: DropdownButtonFormField<String>(
                        initialValue: _categoryId,
                        isDense: true,
                        decoration: const InputDecoration(
                          hintText: '-- Pilih Kategori --',
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: '',
                            child: Text('-- Pilih Kategori --'),
                          ),
                          ...prov.categories.map(
                            (c) => DropdownMenuItem(
                              value: c.id.toString(),
                              child: Text(c.name),
                            ),
                          ),
                        ],
                        onChanged: (v) => setState(() => _categoryId = v),
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Kategori wajib dipilih'
                            : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    AppFormField(
                      label: 'Nama Item',
                      required: true,
                      child: TextFormField(
                        controller: _name,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Nama item wajib diisi'
                            : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: AppFormField(
                            label: 'Harga Default',
                            required: true,
                            child: TextFormField(
                              controller: _price,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.right,
                              validator: (v) {
                                final n = int.tryParse(
                                  (v ?? '').replaceAll(RegExp(r'[^0-9]'), ''),
                                );
                                return (n == null || n < 0)
                                    ? 'Harga tidak valid (min 0)'
                                    : null;
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppFormField(
                            label: 'Satuan',
                            required: true,
                            child: TextFormField(
                              controller: _unit,
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Satuan wajib diisi'
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      value: _isActive,
                      onChanged: (v) => setState(() => _isActive = v ?? true),
                      title: const Text(
                        'Status Aktif',
                        style: TextStyle(fontSize: 14),
                      ),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlineButton(
                          label: 'Batal',
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: 12),
                        DarkButton(
                          label: _isEdit ? 'Simpan Perubahan' : 'Tambah Item',
                          loading: _saving,
                          onPressed: _submit,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
