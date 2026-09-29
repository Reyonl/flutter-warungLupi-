import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';

/// Kategori — meniru `pages/products/CategoryList.jsx`.
/// Search client-side, tambah/edit inline form, hapus (disabled jika ada item),
/// jumlah kategori + total item.
class CategoryListScreen extends StatefulWidget {
  const CategoryListScreen({super.key});

  @override
  State<CategoryListScreen> createState() => _CategoryListScreenState();
}

class _CategoryListScreenState extends State<CategoryListScreen> {
  final _searchCtrl = TextEditingController();
  String _search = '';
  bool _showAddForm = false;
  int? _editingId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<CategoryProvider>().load();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Category> get _filtered {
    final cats = context.read<CategoryProvider>().categories;
    if (_search.trim().isEmpty) return cats;
    return cats
        .where(
          (c) => c.name.toLowerCase().contains(_search.trim().toLowerCase()),
        )
        .toList();
  }

  Future<void> _handleAdd(String name) async {
    try {
      await context.read<CategoryProvider>().add(name);
      if (mounted) {
        setState(() => _showAddForm = false);
        showToast(context, 'Kategori berhasil ditambahkan!');
      }
    } catch (e) {
      if (mounted)
        showToast(context, 'Gagal menambahkan kategori.', error: true);
    }
  }

  Future<void> _handleUpdate(int id, String name) async {
    try {
      await context.read<CategoryProvider>().update(id, name);
      if (mounted) {
        setState(() => _editingId = null);
        showToast(context, 'Kategori berhasil diperbarui!');
      }
    } catch (e) {
      if (mounted)
        showToast(context, 'Gagal memperbarui kategori.', error: true);
    }
  }

  Future<void> _confirmDelete(Category c) async {
    if ((c.productsCount ?? 0) > 0) {
      showToast(
        context,
        'Tidak bisa dihapus — masih ada item dalam kategori ini.',
        error: true,
      );
      return;
    }
    final ok = await showConfirmDialog(
      context,
      title: 'Hapus Kategori?',
      message:
          'Kategori "${c.name}" akan dihapus secara permanen. Tindakan ini tidak bisa dibatalkan.',
    );
    if (ok == true && mounted) {
      final msg = await context.read<CategoryProvider>().delete(c);
      if (mounted) showToast(context, msg ?? 'Kategori berhasil dihapus.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<CategoryProvider>();
    final cats = _filtered;
    final totalItems = prov.categories.fold<int>(
      0,
      (sum, c) => sum + (c.productsCount ?? 0),
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: PageHeader(
            title: 'Kategori',
            subtitle:
                '${prov.categories.length} kategori · $totalItems total item',
            actions: [
              DarkButton(
                label: 'Tambah Kategori',
                icon: Icons.add,
                onPressed: () {
                  setState(() {
                    _showAddForm = true;
                    _editingId = null;
                  });
                },
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _search = v),
            decoration: const InputDecoration(
              hintText: 'Cari nama kategori...',
              prefixIcon: Icon(Icons.search, size: 20),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: prov.loading && prov.categories.isEmpty
              ? const LoadingState()
              : prov.error != null && prov.categories.isEmpty
              ? InlineMessage(prov.error!)
              : RefreshIndicator(
                  onRefresh: prov.load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    children: [
                      if (_showAddForm)
                        _InlineCategoryForm(
                          initialName: '',
                          submitLabel: 'Simpan',
                          onSubmit: _handleAdd,
                          onCancel: () => setState(() => _showAddForm = false),
                        ),
                      const SizedBox(height: 8),
                      if (cats.isEmpty && !_showAddForm)
                        const EmptyState(
                          title: 'Belum ada kategori.',
                          subtitle: 'Tambahkan kategori baru untuk mulai mengelompokkan item.',
                        )
                      else
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: cats.map((c) {
                              final isEditing = _editingId == c.id;
                              return Container(
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: AppColors.border,
                                      width: c == cats.last ? 0 : 1,
                                    ),
                                  ),
                                ),
                                child: isEditing
                                    ? Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: _InlineCategoryForm(
                                          initialName: c.name,
                                          submitLabel: 'Simpan',
                                          onSubmit: (name) =>
                                              _handleUpdate(c.id, name),
                                          onCancel: () =>
                                              setState(() => _editingId = null),
                                        ),
                                      )
                                    : _CategoryRow(
                                        category: c,
                                        onEdit: () => setState(() {
                                          _showAddForm = false;
                                          _editingId = c.id;
                                        }),
                                        onDelete: () => _confirmDelete(c),
                                      ),
                              );
                            }).toList(),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final Category category;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CategoryRow({
    required this.category,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final count = category.productsCount ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              category.name,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textMain,
              ),
            ),
          ),
          Text(
            '$count item',
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: onEdit,
            style: TextButton.styleFrom(foregroundColor: AppColors.gray600),
            child: const Text('Edit', style: TextStyle(fontSize: 13)),
          ),
          TextButton(
            onPressed: count > 0 ? null : onDelete,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.gray600,
              disabledForegroundColor: AppColors.gray300,
            ),
            child: const Text('Hapus', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _InlineCategoryForm extends StatefulWidget {
  final String initialName;
  final String submitLabel;
  final ValueChanged<String> onSubmit;
  final VoidCallback onCancel;

  const _InlineCategoryForm({
    required this.initialName,
    required this.submitLabel,
    required this.onSubmit,
    required this.onCancel,
  });

  @override
  State<_InlineCategoryForm> createState() => _InlineCategoryFormState();
}

class _InlineCategoryFormState extends State<_InlineCategoryForm> {
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.initialName,
  );
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _ctrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Nama kategori wajib diisi');
      return;
    }
    setState(() => _saving = true);
    widget.onSubmit(name);
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.gray100,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              onChanged: (_) => setState(() => _error = null),
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: 'Nama kategori...',
                isDense: true,
                errorText: _error,
              ),
            ),
          ),
          const SizedBox(width: 8),
          DarkButton(
            label: widget.submitLabel,
            loading: _saving,
            onPressed: _submit,
            height: 44,
          ),
          const SizedBox(width: 8),
          OutlineButton(label: 'Batal', onPressed: widget.onCancel),
        ],
      ),
    );
  }
}
