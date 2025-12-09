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
      'subtitle': 'Summaries, red flags, negotiation angles',
      'icon': LucideIcons.fileText,
      'color': CiceroTheme.pastelPurple,
      'textColor': Colors.black87,
      'prompts': [
        'Summarize the key duties, renewal terms, and payment triggers in this contract.',
        'Flag indemnity, limitation of liability, venue, and governing law clauses that could hurt me.',
        'Draft plain-language bullets for the confidentiality and IP ownership sections.',
        'Compare these terms to market norms and suggest 3 negotiation edits.',
        'Check termination/auto-renew clauses for notice deadlines I should calendar.',
      ],
    },
    {
      'title': 'Legal Research',
      'subtitle': 'Cases, statutes, standards',
      'icon': LucideIcons.search,
      'color': CiceroTheme.pastelBlue,
      'textColor': Colors.black87,
      'prompts': [
        'Find [STATE] cases on probable cause for traffic stops and summarize the rule.',
        'What is the statute of limitations for breach of contract in [STATE]?',
        'Research how enforceable non-compete agreements are in [STATE] for employees vs contractors.',
        'Find federal cases on ADA reasonable accommodation for remote work.',
        'What factors do [STATE] courts use to pierce the corporate veil?',
      ],
    },
    {
      'title': 'Document Drafting',
      'subtitle': 'Letters, agreements, checklists',
      'icon': LucideIcons.penTool,
      'color': CiceroTheme.pastelRed,
      'textColor': Colors.black87,
      'prompts': [
        'Draft a demand letter for unpaid invoices under [STATE] law.',
        'Create a simple LLC operating agreement outline tailored to [STATE].',
        'Draft a cease-and-desist letter for trademark or brand misuse.',
        'Write a settlement proposal email with concessions and next steps.',
        'Make a checklist of exhibits I should collect before filing.',
      ],
    },
    {
      'title': 'State Laws',
      'subtitle': 'Local rules, filings, deadlines',
      'icon': LucideIcons.mapPin,
      'color': CiceroTheme.pastelOrange,
      'textColor': Colors.black87,
      'prompts': [
        'Explain [STATE] landlord entry and notice requirements.',
        'Steps and forms to file small claims in [STATE] for a security deposit.',
        'What wage, overtime, and meal-break rules apply in [STATE]?',
        'Outline [STATE] requirements to register a business name or LLC.',
        'What are [STATE] rules for carrying or transporting a firearm?',
      ],
    },
    {
      'title': 'Court Prep & Strategy',
      'subtitle': 'Timelines, arguments, evidence',
      'icon': LucideIcons.gavel,
      'color': CiceroTheme.pastelGreen,
      'textColor': Colors.black87,
      'prompts': [
        'Build an argument outline with elements and supporting authority in [STATE].',
        'Draft direct- and cross-exam questions for a key witness.',
        'Create a timeline of facts and highlight gaps in proof.',
        'Suggest discovery requests (interrogatories/requests for production) for this dispute.',
        'Explain how to preserve objections and make a record in [STATE] court.',
      ],
    },
    {
      'title': 'Compliance & Policies',
      'subtitle': 'HR, privacy, business ops',
      'icon': LucideIcons.shieldCheck,
      'color': CiceroTheme.pastelTeal,
      'textColor': Colors.black87,
      'prompts': [
        'Draft a privacy policy for an online store serving [STATE] customers.',
        'Create an employee handbook section on PTO, sick leave, and breaks for [STATE].',
        'Checklist for data breach notification obligations in [STATE].',
        'Outline steps to register and maintain a trademark.',
        'Draft a vendor NDA with a short data security addendum.',
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
            "Pick a workflow, tap a prompt, and we’ll tailor it to $stateName.",
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
              childAspectRatio: 0.78, // Taller cards to prevent text overflow
            ),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index];
              return _CategoryCard(
                title: cat['title'],
                subtitle: cat['subtitle'],
                icon: cat['icon'],
                color: cat['color'],
                textColor: cat['textColor'],
                onTap: () {
                  // Show the prompts bottom sheet
                  showModalBottomSheet(
                    isScrollControlled: true,
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
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.title,
    required this.subtitle,
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
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: textColor, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: textColor,
                height: 1.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: textColor.withValues(alpha: 0.8),
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
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
    final maxHeight = MediaQuery.of(context).size.height * 0.7;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: SizedBox(
        height: maxHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "Prompts auto-fill with $stateName. Attach documents first if you want them considered.",
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[400] : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                physics: const BouncingScrollPhysics(),
                itemCount: prompts.length,
                separatorBuilder: (context, _) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final formatted =
                      prompts[index].replaceAll('[STATE]', stateName);
                  return InkWell(
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
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
