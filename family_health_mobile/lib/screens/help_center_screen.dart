import 'package:flutter/material.dart';

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  String _category = 'General Support';
  bool _isSubmitting = false;

  final List<Map<String, String>> _faqs = [
    {
      'q': 'How do I add my family members?',
      'a': 'Go to the Family tab in the bottom navigation menu. Tap on the "+" add member icon in the top right corner. You can invite them via email or share your family group code so they can join.'
    },
    {
      'q': 'How is my medical data secured?',
      'a': 'Your health data is stored securely using industry-standard AES encryption. Privacy controls under settings let you configure whether health records are visible to family members or kept fully private.'
    },
    {
      'q': 'Can I connect physical wearables?',
      'a': 'Yes, the ecosystem is IoT-ready! You can sync your smartwatch, blood pressure monitor, and smart scale. Check out the Wearables Integration option in the web dashboard for automated Bluetooth pairings.'
    },
    {
      'q': 'How does the emergency SOS alert work?',
      'a': 'When you tap "Send SOS" on the emergency tab or dashboard, a priority alert containing your current GPS location is instantly broad-casted to all of your family members through push notifications and SMS.'
    },
    {
      'q': 'How do I set up medicine reminders?',
      'a': 'You can configure daily health habits and medicine intakes inside the Health tab. Toggles under notification preferences ensure you are notified immediately when a medication window is near.'
    },
  ];

  Future<void> _submitFeedback() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    // Mock network latency
    await Future.delayed(const Duration(milliseconds: 1200));

    setState(() {
      _isSubmitting = false;
      _messageController.clear();
    });

    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.green),
              SizedBox(width: 8),
              Text('Request Submitted', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'Thank you for contacting Family Health Connect support! Our team will review your inquiry and respond to your registered email shortly.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK', style: TextStyle(color: Color(0xFF14B8A6), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Help Center'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('Frequently Asked Questions'),
          ..._faqs.map((faq) => Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 8),
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ExpansionTile(
                  title: Text(faq['q']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  textColor: const Color(0xFF14B8A6),
                  iconColor: const Color(0xFF14B8A6),
                  childrenPadding: const EdgeInsets.all(16),
                  expandedAlignment: Alignment.topLeft,
                  children: [
                    Text(faq['a']!, style: const TextStyle(fontSize: 13, height: 1.4)),
                  ],
                ),
              )),
          const SizedBox(height: 20),

          _buildSectionHeader('Contact Support'),
          Card(
            elevation: 0,
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Send us a message', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _category,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      items: const [
                        DropdownMenuItem(value: 'General Support', child: Text('General Support')),
                        DropdownMenuItem(value: 'Report a Bug', child: Text('Report a Bug')),
                        DropdownMenuItem(value: 'Billing & Account', child: Text('Billing & Account')),
                        DropdownMenuItem(value: 'IoT Hardware Pairing', child: Text('IoT Hardware Pairing')),
                      ],
                      onChanged: (val) => setState(() => _category = val!),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _messageController,
                      maxLines: 4,
                      validator: (val) => val == null || val.trim().isEmpty ? 'Please describe your request' : null,
                      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        hintText: 'Describe your issue or feedback in detail...',
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF14B8A6), width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF14B8A6),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        onPressed: _isSubmitting ? null : _submitFeedback,
                        child: _isSubmitting
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('Submit Request', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12, top: 12),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF64748B),
          fontWeight: FontWeight.bold,
          fontSize: 12,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}
