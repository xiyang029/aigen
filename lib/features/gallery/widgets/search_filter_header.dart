import 'package:flutter/material.dart';

import '../../../models/image_task.dart';
import '../../../shared/app_ui.dart';

const _allModeFilter = 'all';
const _generateModeFilter = 'generate';
const _editModeFilter = 'edit';

class SearchFilterHeader extends StatelessWidget {
  const SearchFilterHeader({
    super.key,
    required this.searchController,
    required this.onSearchChanged,
    required this.onUnfocus,
    required this.modeFilter,
    required this.onModeChanged,
    this.extraFilters,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onUnfocus;
  final ImageMode? modeFilter;
  final ValueChanged<ImageMode?> onModeChanged;
  final Widget? extraFilters;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ShadInput(
          controller: searchController,
          placeholder: const Text('搜索提示词'),
          leading: const Icon(LucideIcons.search, size: 18),
          onChanged: onSearchChanged,
        ),
        if (extraFilters != null) ...[
          const SizedBox(height: 10),
          extraFilters!,
        ],
        const SizedBox(height: 10),
        ShadTabs<String>(
          value: switch (modeFilter) {
            ImageMode.generate => _generateModeFilter,
            ImageMode.edit => _editModeFilter,
            null => _allModeFilter,
          },
          onChanged: (value) => onModeChanged(switch (value) {
            _generateModeFilter => ImageMode.generate,
            _editModeFilter => ImageMode.edit,
            _ => null,
          }),
          tabBarConstraints: const BoxConstraints(maxWidth: double.infinity),
          tabs: const [
            ShadTab(
              value: _allModeFilter,
              content: SizedBox.shrink(),
              child: AppTabLabel(icon: LucideIcons.grid2x2, label: '全部模式'),
            ),
            ShadTab(
              value: _generateModeFilter,
              content: SizedBox.shrink(),
              child: AppTabLabel(
                icon: LucideIcons.textCursorInput,
                label: '文生图',
              ),
            ),
            ShadTab(
              value: _editModeFilter,
              content: SizedBox.shrink(),
              child: AppTabLabel(icon: LucideIcons.image, label: '图生图'),
            ),
          ],
        ),
      ],
    );
  }
}
