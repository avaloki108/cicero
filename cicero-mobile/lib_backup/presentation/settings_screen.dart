import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/viral_growth_service.dart';
import 'providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedStateAbbr = ref.watch(selectedStateProvider);
    final selectedStateName = abbrToStateName[selectedStateAbbr] ?? 'Colorado';

    return Scaffold(
      appBar: AppBar(
        title: const Text('System Configuration'),
        backgroundColor: const Color(0xFF5D5CDE),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Profile Information',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Primary State',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedStateName,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    items: [
                      'California',
                      'Colorado',
                      'New Mexico',
                      'New York',
                      'Texas',
                    ].map((name) => DropdownMenuItem(value: name, child: Text(name))).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        final abbr = stateNameToAbbr[value] ?? 'CO';
                        ref.read(selectedStateProvider.notifier).state = abbr;
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'RAG System Status',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildStatusRow('Vector Database', true),
                  const SizedBox(height: 12),
                  _buildStatusRow('Legal Data Sources', true),
                  const SizedBox(height: 12),
                  _buildStatusRow('Encryption Status', true, detail: 'AES-256'),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Last Index Update', style: TextStyle(fontSize: 14)),
                      Text(
                        '2 hours ago',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Professional Plan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [Colors.green.shade50, Colors.blue.shade50]),
                      border: Border.all(color: Colors.green.shade200),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [Colors.green.shade500, Colors.blue.shade600]),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check, color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Enterprise RAG Active', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade800)),
                              Text('Unlimited queries • Real-time updates', style: TextStyle(fontSize: 12, color: Colors.green.shade700)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _ViralGrowthCard(),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Security & Privacy', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildSecurityRow('End-to-end encryption (AES-256)'),
                  const SizedBox(height: 10),
                  _buildSecurityRow('Zero-knowledge architecture'),
                  const SizedBox(height: 10),
                  _buildSecurityRow('HIPAA-compliant data handling'),
                  const SizedBox(height: 10),
                  _buildSecurityRow('Attorney-client privilege protection'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, bool isConnected, {String? detail}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14)),
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: isConnected ? Colors.green : Colors.red, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(detail ?? (isConnected ? 'Connected' : 'Disconnected'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),
      ],
    );
  }

  Widget _buildSecurityRow(String text) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
      ],
    );
  }
}

class _ViralGrowthCard extends StatefulWidget {
  @override
  State<_ViralGrowthCard> createState() => _ViralGrowthCardState();
}

class _ViralGrowthCardState extends State<_ViralGrowthCard> {
  final ViralGrowthService _viralService = ViralGrowthService();
  String _referralCode = 'Loading...';
  Map<String, int> _stats = {'shares': 0, 'referrals': 0};

  @override
  void initState() {
    super.initState();
    _loadReferralData();
  }

  Future<void> _loadReferralData() async {
    final code = await _viralService.getReferralCode();
    final stats = await _viralService.getReferralStats();
    if (mounted) {
      setState(() {
        _referralCode = code;
        _stats = stats;
      });
    }
  }

  Future<void> _copyReferralCode() async {
    await Clipboard.setData(ClipboardData(text: _referralCode));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Referral code copied to clipboard!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.star, color: Colors.amber.shade600, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Share & Earn',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Referral Code Section
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF5D5CDE).withAlpha(25), Colors.purple.shade50],
                ),
                border: Border.all(color: const Color(0xFF5D5CDE).withAlpha(77)),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your Referral Code',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _referralCode,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                            color: Color(0xFF5D5CDE),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: _copyReferralCode,
                        tooltip: 'Copy code',
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Share: ${_stats['shares']} • Referrals: ${_stats['referrals']}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Reward Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.card_giftcard, color: Colors.green.shade700, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Earn 7 days Pro for each friend who joins!',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final localContext = context;
                      await _viralService.shareApp();
                      if (mounted) {
                        _viralService.showShareSuccessDialog(localContext);
                        _loadReferralData();
                      }
                    },
                    icon: const Icon(Icons.share),
                    label: const Text('Share App'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5D5CDE),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _viralService.requestReview(force: true);
                    },
                    icon: const Icon(Icons.star_rate),
                    label: const Text('Rate Us'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF5D5CDE),
                      side: const BorderSide(color: Color(0xFF5D5CDE)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Social Media Share Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSocialButton(
                  icon: Icons.chat,
                  label: 'Twitter',
                  onTap: () => _viralService.shareOnSocialMedia('twitter'),
                ),
                _buildSocialButton(
                  icon: Icons.facebook,
                  label: 'Facebook',
                  onTap: () => _viralService.shareOnSocialMedia('facebook'),
                ),
                _buildSocialButton(
                  icon: Icons.business,
                  label: 'LinkedIn',
                  onTap: () => _viralService.shareOnSocialMedia('linkedin'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }
}
