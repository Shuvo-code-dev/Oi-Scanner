import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/history_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/language_provider.dart';
import '../models/scan_history_model.dart';
import '../theme/app_theme.dart';
import '../widgets/scan_result_sheet.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _searchQuery = '';
  bool _showOnlyFavorites = false;
  String _selectedCategory = 'All';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(context),
        _buildFilterBar(),
        Expanded(
          child: Consumer<HistoryProvider>(
            builder: (context, provider, child) {
              if (provider.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              final filteredHistory = provider.history.where((scan) {
                final matchesSearch = scan.content.toLowerCase().contains(_searchQuery.toLowerCase());
                final matchesFavorite = !_showOnlyFavorites || scan.isFavorite;
                final matchesCategory = _selectedCategory == 'All' || scan.category == _selectedCategory;
                return matchesSearch && matchesFavorite && matchesCategory;
              }).toList();

              if (filteredHistory.isEmpty) {
                return _buildEmptyState(context);
              }

              return AnimationLimiter(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: StaggeredGrid.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    children: List.generate(filteredHistory.length, (index) {
                      final scan = filteredHistory[index];
                      // Favorites take 2 columns, others take 1
                      final int crossAxisCellCount = scan.isFavorite ? 2 : 1;
                      
                      return StaggeredGridTile.fit(
                        crossAxisCellCount: crossAxisCellCount,
                        child: AnimationConfiguration.staggeredGrid(
                          position: index,
                          duration: const Duration(milliseconds: 500),
                          columnCount: 2,
                          child: ScaleAnimation(
                            child: FadeInAnimation(
                              child: _buildBentoItem(context, provider, scan),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final provider = context.read<HistoryProvider>();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search history...',
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            icon: const Icon(Icons.download, color: AppTheme.accent),
            tooltip: 'Export History',
            onSelected: (val) async {
              final p = context.read<HistoryProvider>();
              final messenger = ScaffoldMessenger.of(context);
              
              try {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => const AlertDialog(
                    content: Row(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(width: 16),
                        Text('Exporting...'),
                      ],
                    ),
                  ),
                );

                String? path;
                if (val == 'csv') {
                  path = await p.exportToCSV();
                } else {
                  path = await p.exportToPDF();
                }
                
                if (context.mounted) Navigator.pop(context);

                if (context.mounted && path != null) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('History exported to: $path')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  messenger.showSnackBar(
                    SnackBar(content: Text('Export failed: ${e.toString().replaceAll('Exception: ', '')}')),
                  );
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'csv', child: Text('Export as CSV')),
              const PopupMenuItem(value: 'pdf', child: Text('Export as PDF')),
            ],
          ),
          IconButton(
            onPressed: () => _showClearConfirmation(context, provider),
            icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
            tooltip: 'Clear All History',
          ),
        ],
      ),
    );
  }

  void _showClearConfirmation(BuildContext context, HistoryProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All History'),
        content: const Text('Are you sure you want to delete all scan history? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              provider.clearHistory();
              Navigator.pop(context);
            },
            child: const Text('CLEAR ALL', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          FilterChip(
            label: const Text('Favorites'),
            selected: _showOnlyFavorites,
            onSelected: (val) => setState(() => _showOnlyFavorites = val),
            selectedColor: AppTheme.accent.withValues(alpha: 0.2),
            checkmarkColor: AppTheme.accent,
          ),
          const SizedBox(width: 8),
          ...['All', 'Web', 'Contact', 'Work', 'Network', 'Other'].map((cat) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(cat),
              selected: _selectedCategory == cat,
              onSelected: (val) {
                HapticFeedback.selectionClick();
                setState(() => _selectedCategory = cat);
              },
              selectedColor: AppTheme.accent.withValues(alpha: 0.2),
              checkmarkColor: AppTheme.accent,
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildBentoItem(BuildContext context, HistoryProvider provider, ScanHistory scan) {
    final isWide = scan.isFavorite;
    
    return RepaintBoundary(
      child: Dismissible(
        key: Key(scan.id.toString()),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.redAccent.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Icon(Icons.delete, color: Colors.redAccent),
        ),
        onDismissed: (_) => provider.deleteScan(scan.id!),
        child: GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => ScanResultSheet(
                content: scan.content,
                type: scan.type,
                resultType: scan.resultType,
              ),
            );
          },
          child: Container(
            constraints: BoxConstraints(minHeight: isWide ? 100 : 150),
            decoration: BoxDecoration(
              color: AppTheme.surface.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: scan.isFavorite ? AppTheme.accent.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.05),
                width: 1.5,
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, // Use min size to avoid forced expansion
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(_getCategoryIcon(scan.category), color: AppTheme.accent, size: 18),
                    ),
                    IconButton(
                      icon: Icon(
                        scan.isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                        color: scan.isFavorite ? Colors.amber : Colors.white24,
                        size: 20,
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        provider.toggleFavorite(scan);
                      },
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: Text(
                    scan.content.trim(),
                    maxLines: isWide ? 2 : 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                      fontSize: isWide ? 16 : 14,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('MMM dd, yyyy').format(scan.scannedAt),
                      style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        scan.category.toUpperCase(),
                        style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Web': return Icons.language;
      case 'Contact': return Icons.person;
      case 'Work': return Icons.business_center;
      case 'Network': return Icons.wifi;
      default: return Icons.description;
    }
  }

  Widget _buildEmptyState(BuildContext context) {
    final langProvider = context.watch<LanguageProvider>();
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_outlined,
            size: 80,
            color: AppTheme.textSecondary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            langProvider.getText('no_history'),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              context.read<NavigationProvider>().setIndex(0);
            },
            icon: const Icon(Icons.qr_code_scanner),
            label: Text(langProvider.getText('scan_now')),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
          )
        ],
      ),
    );
  }
}
