import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'providers.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  Map<String, dynamic>? _subscriptionStatus;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSubscriptionStatus();
  }

  Future<void> _loadSubscriptionStatus() async {
    try {
      final authService = ref.read(authServiceProvider);
      final token = await authService.getIdToken();
      final apiBaseUrl = ref.read(apiBaseUrlProvider);

      if (token == null) {
        setState(() {
          _error = 'Not authenticated';
          _isLoading = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse('$apiBaseUrl/subscription/status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        setState(() {
          _subscriptionStatus = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load subscription status';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _createCheckout() async {
    try {
      final authService = ref.read(authServiceProvider);
      final token = await authService.getIdToken();
      final apiBaseUrl = ref.read(apiBaseUrlProvider);

      if (token == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not authenticated')),
        );
        return;
      }

      final response = await http.post(
        Uri.parse('$apiBaseUrl/subscription/create-checkout'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final checkoutUrl = data['checkout_url'];
        // In a real app, you'd open this URL in a browser or WebView
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Checkout URL: $checkoutUrl'),
            duration: const Duration(seconds: 5),
          ),
        );
        // TODO: Open URL in browser or WebView
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create checkout session')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : const Color(0xFFF2F2F7);
    final sectionColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Subscription'),
        backgroundColor: bgColor,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.alertCircle, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(_error!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadSubscriptionStatus,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadSubscriptionStatus,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Current Plan Card
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: sectionColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _subscriptionStatus?['tier'] == 'PREMIUM'
                                      ? LucideIcons.crown
                                      : LucideIcons.user,
                                  size: 32,
                                  color: Theme.of(context).primaryColor,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  _subscriptionStatus?['tier'] == 'PREMIUM'
                                      ? 'Premium'
                                      : 'Free',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (_subscriptionStatus?['tier'] == 'FREE') ...[
                              Text(
                                '${_subscriptionStatus?['queries_today'] ?? 0} / ${_subscriptionStatus?['queries_limit'] ?? 5} queries used today',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                value: (_subscriptionStatus?['queries_today'] ?? 0) /
                                    (_subscriptionStatus?['queries_limit'] ?? 5),
                              ),
                            ] else ...[
                              const Text(
                                'Unlimited queries',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Upgrade Button (if Free)
                      if (_subscriptionStatus?['tier'] == 'FREE')
                        ElevatedButton(
                          onPressed: _createCheckout,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('Upgrade to Premium'),
                        ),
                      const SizedBox(height: 24),
                      // Features
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: sectionColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Features',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _FeatureItem(
                              icon: LucideIcons.messageSquare,
                              title: 'Unlimited Queries',
                              available: _subscriptionStatus?['tier'] == 'PREMIUM',
                            ),
                            const SizedBox(height: 12),
                            _FeatureItem(
                              icon: LucideIcons.zap,
                              title: 'Priority Support',
                              available: _subscriptionStatus?['tier'] == 'PREMIUM',
                            ),
                            const SizedBox(height: 12),
                            _FeatureItem(
                              icon: LucideIcons.fileText,
                              title: 'Export Conversations',
                              available: _subscriptionStatus?['tier'] == 'PREMIUM',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool available;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.available,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: available ? Colors.green : Colors.grey,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              color: available ? null : Colors.grey,
            ),
          ),
        ),
        if (available)
          Icon(
            LucideIcons.check,
            size: 20,
            color: Colors.green,
          ),
      ],
    );
  }
}

