import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/palette.dart';
import 'providers.dart';

class PromptsScreen extends ConsumerStatefulWidget {
  const PromptsScreen({super.key});

  @override
  ConsumerState<PromptsScreen> createState() => _PromptsScreenState();
}

class _PromptsScreenState extends ConsumerState<PromptsScreen> {
  Map<String, dynamic>? _selectedCategory;

  static const List<Map<String, dynamic>> _legalCategories = [
    {
      'id': 'contract-review',
      'title': 'Contract Review',
      'icon': Icons.description_outlined,
      'color': 0xFFE7D8FF,
      'examples': [
        'Review this employment contract for red flags',
        'Explain the terms of this lease agreement',
        'What should I look for in a non-compete clause?',
      ],
    },
    {
      'id': 'legal-research',
      'title': 'Legal Research',
      'icon': Icons.search,
      'color': 0xFFCDECF8,
      'examples': [
        'Find recent cases about tenant rights in California',
        'What are the statute of limitations for personal injury?',
        'Research state laws on small business formation',
      ],
    },
    {
      'id': 'document-drafting',
      'title': 'Document Drafting',
      'icon': Icons.create_outlined,
      'color': 0xFFFBD1D4,
      'examples': [
        'Help me draft a demand letter',
        'Create a simple will template',
        'Draft a partnership agreement',
      ],
    },
    {
      'id': 'state-laws',
      'title': 'State Laws',
      'icon': Icons.map_outlined,
      'color': 0xFFE7D8FF,
      'examples': [
        'What are the employment laws in my state?',
        'Explain state-specific landlord-tenant laws',
        'What are the requirements for forming an LLC in Texas?',
      ],
    },
    {
      'id': 'court-cases',
      'title': 'Court Cases',
      'icon': Icons.gavel_outlined,
      'color': 0xFFCDECF8,
      'examples': [
        'Find similar cases to mine',
        'What was the outcome of this case citation?',
        'Search for precedents in contract disputes',
      ],
    },
    {
      'id': 'business-law',
      'title': 'Business Law',
      'icon': Icons.business_center_outlined,
      'color': 0xFFFBD1D4,
      'examples': [
        'What permits do I need to start a food business?',
        'Explain intellectual property protection',
        'How do I trademark my business name?',
      ],
    },
  ];

  void _selectCategory(Map<String, dynamic> category) {
    setState(() => _selectedCategory = category);
  }

  void _goBackToCategories() => setState(() => _selectedCategory = null);

  void _handleExampleTap(String example) {
    ref.read(promptSelectedProvider.notifier).selectPrompt(example);
  }

  @override
  Widget build(BuildContext context) {
    final colors = PocketPalette.of(Theme.of(context).brightness);
    final stateAbbr = ref.watch(selectedStateProvider);
    final stateName = abbrToStateName[stateAbbr] ?? 'Colorado';

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            _ExamplesHeader(colors: colors, stateName: stateName),
            Expanded(
              child: _selectedCategory == null
                  ? _CategoryGrid(
                      colors: colors,
                      onSelect: _selectCategory,
                      categories: _legalCategories,
                    )
                  : _CategoryDetail(
                      colors: colors,
                      category: _selectedCategory!,
                      onBack: _goBackToCategories,
                      onExampleTap: _handleExampleTap,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExamplesHeader extends StatelessWidget {
  const _ExamplesHeader({required this.colors, required this.stateName});

  final PocketColors colors;
  final String stateName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Examples',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: colors.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Get started with common legal questions',
            style: TextStyle(
              fontSize: 15,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({
    required this.colors,
    required this.onSelect,
    required this.categories,
  });

  final PocketColors colors;
  final ValueChanged<Map<String, dynamic>> onSelect;
  final List<Map<String, dynamic>> categories;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.95,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        final color = Color(category['color'] as int);

        return GestureDetector(
          onTap: () => onSelect(category),
          child: Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(77),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    category['icon'] as IconData,
                    size: 24,
                    color: colors.text,
                  ),
                ),
                const Spacer(),
                Text(
                  category['title'] as String,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colors.text,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CategoryDetail extends StatelessWidget {
  const _CategoryDetail({
    required this.colors,
    required this.category,
    required this.onBack,
    required this.onExampleTap,
  });

  final PocketColors colors;
  final Map<String, dynamic> category;
  final VoidCallback onBack;
  final ValueChanged<String> onExampleTap;

  @override
  Widget build(BuildContext context) {
    final examples = (category['examples'] as List).cast<String>();
    final color = Color(category['color'] as int);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back, color: colors.text),
                onPressed: onBack,
              ),
              const SizedBox(width: 4),
              Text(
                'Back to Categories',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: colors.text,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(77),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Icon(
                    category['icon'] as IconData,
                    size: 32,
                    color: colors.text,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  category['title'] as String,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: colors.text,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Try these examples:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colors.text,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: examples.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final example = examples[index];

              return GestureDetector(
                onTap: () => onExampleTap(example),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.surfaceElevated,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.border),
                  ),
                  child: Text(
                    example,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: colors.text,
                    ),
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
