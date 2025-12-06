import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../core/theme_cicero.dart';
import 'chat_state_notifier.dart'; // To access chatProvider
import 'providers.dart'; // To access selectedStateProvider

class ExamplesScreen extends ConsumerWidget {
  const ExamplesScreen({super.key});

  // Data from your examples.jsx
  static final List<Map<String, dynamic>> categories = [
    {
      'title': 'Contract Review',
      'icon': LucideIcons.fileText,
      'color': CiceroTheme.pastelPurple,
      'textColor': Colors.black87,
      'prompts': [
        'Review this employment contract for red flags',
        'Explain the terms of this lease agreement',
        'What should I look for in a non-compete clause?',
      ],
    },
    {
      'title': 'Legal Research',
      'icon': LucideIcons.search,
      'color': CiceroTheme.pastelBlue,
      'textColor': Colors.black87,
      'prompts': [
        'Find recent cases about tenant rights in [STATE]',
        'What are the statute of limitations for personal injury?',
        'Research state laws on small business formation',
      ],
    },
    {
      'title': 'Document Drafting',
      'icon': LucideIcons.penTool,
      'color': CiceroTheme.pastelRed,
      'textColor': Colors.black87,
      'prompts': [
        'Help me draft a demand letter',
        'Create a simple will template',
        'Draft a partnership agreement',
      ],
    },
    {
      'title': 'State Laws',
      'icon': LucideIcons.mapPin,
      'color': CiceroTheme.pastelOrange,
      'textColor': Colors.black87,
      'prompts': [
        'What are the gun laws in [STATE]?',
        'Explain [STATE] labor laws regarding breaks',
        'How to register a business in [STATE]?',
      ],
    },
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAbbr = ref.watch(selectedStateProvider);
    final stateName = abbrToStateName[stateAbbr] ?? stateAbbr;

    return Scaffold(
      appBar: AppBar(title: const Text('Examples')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            "What can Cicero help you with?",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            "Select a category to get started.",
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[400]
                  : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),

          // The Pastel Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.85, // Taller cards like the design
            ),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index];
              return _CategoryCard(
                title: cat['title'],
                icon: cat['icon'],
                color: cat['color'],
                textColor: cat['textColor'],
                onTap: () {
                  // Show the prompts bottom sheet
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    builder: (ctx) => _PromptsSheet(
                      title: cat['title'],
                      prompts: cat['prompts'],
                      stateName: stateName,
                      onSelect: (prompt) {
                        Navigator.pop(ctx);
                        // Send prompt to chat
                        ref
                            .read(chatProvider.notifier)
                            .sendMessage(
                              prompt.replaceAll('[STATE]', stateName),
                              stateAbbr,
                            );
                        // Navigate to Chat tab so the user can see the result
                        ref.read(tabIndexProvider.notifier).state = 0;
                      },
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(24), // Highly rounded corners
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: textColor, size: 28),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: textColor,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PromptsSheet extends StatelessWidget {
  final String title;
  final List<String> prompts;
  final String stateName;
  final Function(String) onSelect;

  const _PromptsSheet({
    required this.title,
    required this.prompts,
    required this.stateName,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...prompts.map((prompt) {
            final formatted = prompt.replaceAll('[STATE]', stateName);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () => onSelect(formatted),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[800] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    formatted,
                    style: TextStyle(
                      fontSize: 15,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
