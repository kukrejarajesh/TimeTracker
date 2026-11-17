// CategoriesScreen
// List of categories with expand/collapse to see subcategories.
// Add / edit / delete categories; add / edit / delete or archive subcategories.
//
// Delete rules (enforced in repositories):
//   - Category: only deletable when it has zero subcategories.
//   - Subcategory: hard-delete only if zero time entries; archive otherwise.

import 'package:flutter/material.dart';

import '../constants/colors.dart';
import '../constants/strings.dart';
import '../db/category_repository.dart';
import '../db/subcategory_repository.dart';
import '../models/category.dart';
import '../models/subcategory.dart';

// ---------------------------------------------------------------------------
// Data holder
// ---------------------------------------------------------------------------

class _CatData {
  final Category category;
  final List<Subcategory> subcategories;
  _CatData({required this.category, required this.subcategories});
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final _categoryRepo = CategoryRepository();
  final _subcategoryRepo = SubcategoryRepository();

  List<_CatData> _data = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ── data ──────────────────────────────────────────────────────────────────

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final cats = await _categoryRepo.getAllCategories();
    final result = <_CatData>[];
    for (final cat in cats) {
      final subs =
          await _subcategoryRepo.getActiveSubcategories(categoryId: cat.id);
      result.add(_CatData(category: cat, subcategories: subs));
    }
    if (mounted) setState(() { _data = result; _isLoading = false; });
  }

  // ── category actions ──────────────────────────────────────────────────────

  void _addCategory() => _showCategoryDialog(null);

  void _editCategory(Category cat) => _showCategoryDialog(cat);

  Future<void> _deleteCategory(Category cat) async {
    final canDelete = await _categoryRepo.canDeleteCategory(cat.id);
    if (!mounted) return;

    if (!canDelete) {
      _showSnack('Remove all subcategories before deleting this category.');
      return;
    }

    final confirmed = await _confirmDialog(
      title: AppStrings.deleteCategory,
      message: 'Delete "${cat.name}"? This cannot be undone.',
      destructive: true,
    );
    if (confirmed != true || !mounted) return;

    await _categoryRepo.deleteCategory(cat.id);
    _load();
  }

  void _showCategoryDialog(Category? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _CategoryDialog(
        existing: existing,
        onSave: (name, colorHex) async {
          if (existing == null) {
            await _categoryRepo.createCategory(name: name, color: colorHex);
          } else {
            await _categoryRepo.updateCategory(
                id: existing.id, name: name, color: colorHex);
          }
          if (ctx.mounted) Navigator.pop(ctx);
          _load();
        },
      ),
    );
  }

  // ── subcategory actions ───────────────────────────────────────────────────

  void _addSubcategory(Category cat) => _showSubcategoryDialog(cat, null);

  void _editSubcategory(Category cat, Subcategory sub) =>
      _showSubcategoryDialog(cat, sub);

  Future<void> _deleteOrArchiveSubcategory(Subcategory sub) async {
    final canDelete = await _subcategoryRepo.canDeleteSubcategory(sub.id);
    if (!mounted) return;

    if (canDelete) {
      final confirmed = await _confirmDialog(
        title: AppStrings.deleteSubcategory,
        message: 'Delete "${sub.name}"? This cannot be undone.',
        destructive: true,
      );
      if (confirmed != true || !mounted) return;
      await _subcategoryRepo.deleteSubcategory(sub.id);
    } else {
      final confirmed = await _confirmDialog(
        title: AppStrings.archiveSubcategory,
        message:
            '"${sub.name}" has existing time entries and cannot be deleted.\n\n'
            'Archive it instead? It will no longer appear in the entry form.',
        destructive: false,
        confirmLabel: 'Archive',
      );
      if (confirmed != true || !mounted) return;
      await _subcategoryRepo.archiveSubcategory(sub.id);
    }

    _load();
  }

  Future<void> _mergeSubcategory(Subcategory source) async {
    // Candidate targets: every other active subcategory, labelled with its category.
    final catName = {for (final d in _data) d.category.id: d.category.name};
    final targets = [
      for (final d in _data)
        for (final s in d.subcategories)
          if (s.id != source.id) s,
    ];
    if (targets.isEmpty) {
      _showSnack('No other subcategory to merge into.');
      return;
    }

    final target = await showDialog<Subcategory>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Merge "${source.name}" into…'),
        children: [
          SizedBox(
            width: double.maxFinite,
            height: 360,
            child: ListView(
              children: [
                for (final t in targets)
                  ListTile(
                    dense: true,
                    title: Text(t.name),
                    subtitle: Text(catName[t.categoryId] ?? ''),
                    onTap: () => Navigator.pop(ctx, t),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (target == null || !mounted) return;

    final confirmed = await _confirmDialog(
      title: AppStrings.mergeTitle,
      message: 'Move all entries from "${source.name}" to "${target.name}" '
          'and remove "${source.name}"?\n\nThis cannot be undone.',
      destructive: true,
      confirmLabel: 'Merge',
    );
    if (confirmed != true || !mounted) return;

    final moved = await _subcategoryRepo.mergeSubcategory(
        fromId: source.id, toId: target.id);
    if (!mounted) return;
    _showSnack('Moved $moved ${moved == 1 ? 'entry' : 'entries'} '
        'to "${target.name}".');
    _load();
  }

  void _showSubcategoryDialog(Category cat, Subcategory? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _SubcategoryDialog(
        categoryName: cat.name,
        categoryColor: cat.color,
        existing: existing,
        onSave: (name) async {
          final similar = await _subcategoryRepo.findSimilarByName(name,
              excludeId: existing?.id);
          if (similar.isNotEmpty && mounted) {
            final names = similar.map((s) => '"${s.name}"').join(', ');
            final proceed = await _confirmDialog(
              title: AppStrings.duplicateTitle,
              message: '$names already exists. Use it instead of creating '
                  'a duplicate?',
              destructive: false,
              confirmLabel: existing == null
                  ? AppStrings.createAnyway
                  : AppStrings.save,
            );
            if (proceed != true) return;
          }
          if (existing == null) {
            await _subcategoryRepo.createSubcategory(
                categoryId: cat.id, name: name);
          } else {
            await _subcategoryRepo.updateSubcategory(
                id: existing.id, categoryId: cat.id, name: name);
          }
          if (ctx.mounted) Navigator.pop(ctx);
          _load();
        },
      ),
    );
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool?> _confirmDialog({
    required String title,
    required String message,
    required bool destructive,
    String confirmLabel = 'Delete',
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(AppStrings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              confirmLabel,
              style: TextStyle(
                color: destructive ? colorScheme.error : colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        title: const Text(AppStrings.categories),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addCategory,
        tooltip: AppStrings.addCategory,
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _data.isEmpty
              ? _EmptyState(onAdd: _addCategory)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
                  itemCount: _data.length,
                  itemBuilder: (_, i) => _CategoryTile(
                    data: _data[i],
                    onEditCategory: () => _editCategory(_data[i].category),
                    onDeleteCategory: () => _deleteCategory(_data[i].category),
                    onAddSubcategory: () => _addSubcategory(_data[i].category),
                    onEditSubcategory: (sub) =>
                        _editSubcategory(_data[i].category, sub),
                    onDeleteSubcategory: _deleteOrArchiveSubcategory,
                    onMergeSubcategory: _mergeSubcategory,
                  ),
                ),
    );
  }
}

// ---------------------------------------------------------------------------
// _CategoryTile
// ---------------------------------------------------------------------------

class _CategoryTile extends StatelessWidget {
  final _CatData data;
  final VoidCallback onEditCategory;
  final VoidCallback onDeleteCategory;
  final VoidCallback onAddSubcategory;
  final void Function(Subcategory) onEditSubcategory;
  final void Function(Subcategory) onDeleteSubcategory;
  final void Function(Subcategory) onMergeSubcategory;

  const _CategoryTile({
    required this.data,
    required this.onEditCategory,
    required this.onDeleteCategory,
    required this.onAddSubcategory,
    required this.onEditSubcategory,
    required this.onDeleteSubcategory,
    required this.onMergeSubcategory,
  });

  @override
  Widget build(BuildContext context) {
    final cat = data.category;
    final subs = data.subcategories;
    final color = AppColors.hexToColor(cat.color);
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        title: Text(
          cat.name,
          style: TextStyle(fontWeight: FontWeight.w600, color: color),
        ),
        subtitle: Text(
          '${subs.length} ${subs.length == 1 ? 'subcategory' : 'subcategories'}',
          style:
              TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              tooltip: 'Edit category',
              onPressed: onEditCategory,
            ),
            IconButton(
              icon: Icon(Icons.delete_outline,
                  size: 20, color: colorScheme.error),
              tooltip: 'Delete category',
              onPressed: onDeleteCategory,
            ),
            // Default expansion chevron space
            const SizedBox(width: 4),
          ],
        ),
        children: [
          const Divider(height: 1),
          // Subcategory list
          if (subs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                AppStrings.noSubcategories,
                style: TextStyle(
                    fontSize: 13, color: colorScheme.onSurfaceVariant),
              ),
            )
          else
            for (final sub in subs)
              ListTile(
                contentPadding:
                    const EdgeInsets.only(left: 40, right: 8),
                title: Text(sub.name, style: const TextStyle(fontSize: 14)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.merge_type, size: 18),
                      tooltip: AppStrings.mergeSubcategory,
                      onPressed: () => onMergeSubcategory(sub),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      tooltip: 'Edit subcategory',
                      onPressed: () => onEditSubcategory(sub),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline,
                          size: 18, color: colorScheme.error),
                      tooltip: 'Delete / archive subcategory',
                      onPressed: () => onDeleteSubcategory(sub),
                    ),
                  ],
                ),
              ),
          // Add subcategory button
          Padding(
            padding: const EdgeInsets.fromLTRB(40, 4, 16, 12),
            child: TextButton.icon(
              onPressed: onAddSubcategory,
              icon: Icon(Icons.add, size: 16, color: color),
              label: Text(AppStrings.addSubcategory,
                  style: TextStyle(fontSize: 13, color: color)),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _CategoryDialog  (add / edit)
// ---------------------------------------------------------------------------

class _CategoryDialog extends StatefulWidget {
  final Category? existing;
  final Future<void> Function(String name, String colorHex) onSave;

  const _CategoryDialog({this.existing, required this.onSave});

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  late final TextEditingController _nameCtrl;
  late String _selectedHex;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameCtrl =
        TextEditingController(text: widget.existing?.name ?? '');
    _selectedHex =
        widget.existing?.color ?? AppColors.palette.first;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name cannot be empty');
      return;
    }
    setState(() { _saving = true; _error = null; });
    await widget.onSave(name, _selectedHex);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isEdit = widget.existing != null;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            isEdit ? AppStrings.editCategory : AppStrings.addCategory,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_error!,
                  style: TextStyle(color: colorScheme.error)),
            ),
          TextField(
            controller: _nameCtrl,
            autofocus: true,
            decoration: InputDecoration(
              labelText: AppStrings.categoryName,
              border: const OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 16),
          Text(AppStrings.colorLabel,
              style: TextStyle(
                  fontSize: 13, color: colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final hex in AppColors.palette)
                GestureDetector(
                  onTap: () => setState(() => _selectedHex = hex),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.hexToColor(hex),
                      shape: BoxShape.circle,
                      border: _selectedHex == hex
                          ? Border.all(
                              color: colorScheme.onSurface, width: 2.5)
                          : null,
                    ),
                    child: _selectedHex == hex
                        ? Icon(Icons.check,
                            size: 18, color: colorScheme.surface)
                        : null,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text(AppStrings.save),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _SubcategoryDialog  (add / edit)
// ---------------------------------------------------------------------------

class _SubcategoryDialog extends StatefulWidget {
  final String categoryName;
  final String categoryColor;
  final Subcategory? existing;
  final Future<void> Function(String name) onSave;

  const _SubcategoryDialog({
    required this.categoryName,
    required this.categoryColor,
    this.existing,
    required this.onSave,
  });

  @override
  State<_SubcategoryDialog> createState() => _SubcategoryDialogState();
}

class _SubcategoryDialogState extends State<_SubcategoryDialog> {
  late final TextEditingController _nameCtrl;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameCtrl =
        TextEditingController(text: widget.existing?.name ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name cannot be empty');
      return;
    }
    setState(() { _saving = true; _error = null; });
    await widget.onSave(name);
    // onSave may return without closing the sheet (e.g. duplicate declined).
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final catColor = AppColors.hexToColor(widget.categoryColor);
    final isEdit = widget.existing != null;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                    color: catColor, shape: BoxShape.circle),
              ),
              Text(
                widget.categoryName,
                style: TextStyle(
                    fontSize: 12,
                    color: catColor,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isEdit ? AppStrings.editSubcategory : AppStrings.addSubcategory,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_error!,
                  style: TextStyle(color: colorScheme.error)),
            ),
          TextField(
            controller: _nameCtrl,
            autofocus: true,
            decoration: InputDecoration(
              labelText: AppStrings.subcategoryName,
              border: const OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text(AppStrings.save),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _EmptyState
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.label_off_outlined,
              size: 56, color: colorScheme.outlineVariant),
          const SizedBox(height: 12),
          Text('No categories yet',
              style: TextStyle(
                  fontSize: 15, color: colorScheme.onSurfaceVariant)),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: onAdd,
            child: const Text(AppStrings.addCategory),
          ),
        ],
      ),
    );
  }
}
