import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../services/sync_service.dart';

class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  List<dynamic> _members = [];
  List<dynamic> _groups = [];
  bool _isLoading = true;
  StreamSubscription? _syncSubscription;

  @override
  void initState() {
    super.initState();
    _fetchMembers();
    _syncSubscription = SyncService.instance.stream.listen((event) {
      if (event['type'] == 'family.update') {
        _fetchMembers();
      }
    });
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchMembers({bool forceRefresh = false}) async {
    final results = await Future.wait([
      ApiService.getFamilyMembers(forceRefresh: forceRefresh),
      ApiService.getFamilyGroups(forceRefresh: forceRefresh),
    ]);
    if (mounted) {
      setState(() {
        _members = results[0];
        _groups = results[1];
        _isLoading = false;
      });
    }
  }

  void _showFamilyCodeDialog(String code, String groupName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.vpn_key_rounded, color: Color(0xFF14B8A6)),
            SizedBox(width: 8),
            Text('Family Join Code', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Share this code with family members so they can join "$groupName":',
                textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF64748B))),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF14B8A6).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF14B8A6), width: 1.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(code,
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4,
                          color: Color(0xFF14B8A6))),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, color: Color(0xFF14B8A6)),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Code copied to clipboard!'), backgroundColor: Color(0xFF14B8A6)),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF14B8A6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddMemberDialog({String initialMode = ''}) async {
    // Show a loading indicator first or fetch immediately
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFF14B8A6))),
    );

    final groups = await ApiService.getFamilyGroups();
    
    if (mounted) {
      Navigator.pop(context); // Dismiss loading spinner
    } else {
      return;
    }

    final emailController = TextEditingController();
    final codeController = TextEditingController();
    final nameController = TextEditingController();
    final descController = TextEditingController();
    String label = 'OTHER';
    String mode = initialMode.isNotEmpty 
        ? initialMode 
        : (groups.isEmpty ? 'create' : 'invite');
    bool dialogSaving = false;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          final dialogDark = Theme.of(context).brightness == Brightness.dark;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              mode == 'invite' 
                  ? 'Invite Family Member' 
                  : (mode == 'join' ? 'Join Family Group' : 'Create Family Circle'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2.0),
                          child: ChoiceChip(
                            label: const Text('Invite', style: TextStyle(fontSize: 12)),
                            selected: mode == 'invite',
                            selectedColor: const Color(0xFF14B8A6).withValues(alpha: 0.2),
                            onSelected: (val) {
                              if (val) setStateDialog(() => mode = 'invite');
                            },
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2.0),
                          child: ChoiceChip(
                            label: const Text('Join', style: TextStyle(fontSize: 12)),
                            selected: mode == 'join',
                            selectedColor: const Color(0xFF14B8A6).withValues(alpha: 0.2),
                            onSelected: (val) {
                              if (val) setStateDialog(() => mode = 'join');
                            },
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2.0),
                          child: ChoiceChip(
                            label: const Text('Create', style: TextStyle(fontSize: 12)),
                            selected: mode == 'create',
                            selectedColor: const Color(0xFF14B8A6).withValues(alpha: 0.2),
                            onSelected: (val) {
                              if (val) setStateDialog(() => mode = 'create');
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (mode == 'invite') ...[
                    if (groups.isEmpty)
                      const Text(
                        'You do not manage any family groups. Please create a family group first using the Create tab above.',
                        style: TextStyle(color: Colors.red, fontSize: 13),
                        textAlign: TextAlign.center,
                      )
                    else ...[
                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(color: dialogDark ? Colors.white : const Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          labelText: 'Invitee Email',
                          prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF14B8A6)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: label,
                        decoration: InputDecoration(
                          labelText: 'Relationship Label',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        dropdownColor: dialogDark ? const Color(0xFF1E293B) : Colors.white,
                        items: const [
                          DropdownMenuItem(value: 'PARENT', child: Text('Parent')),
                          DropdownMenuItem(value: 'CHILD', child: Text('Child')),
                          DropdownMenuItem(value: 'ELDER', child: Text('Elderly Member')),
                          DropdownMenuItem(value: 'SPOUSE', child: Text('Spouse')),
                          DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                        ],
                        onChanged: (val) => setStateDialog(() => label = val!),
                      ),
                    ]
                  ] else if (mode == 'join') ...[
                    TextField(
                      controller: codeController,
                      style: TextStyle(color: dialogDark ? Colors.white : const Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        labelText: 'Family Group Code',
                        prefixIcon: const Icon(Icons.vpn_key_outlined, color: Color(0xFF14B8A6)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: label,
                      decoration: InputDecoration(
                        labelText: 'Your Role Label',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      dropdownColor: dialogDark ? const Color(0xFF1E293B) : Colors.white,
                      items: const [
                        DropdownMenuItem(value: 'PARENT', child: Text('Parent')),
                        DropdownMenuItem(value: 'CHILD', child: Text('Child')),
                        DropdownMenuItem(value: 'ELDER', child: Text('Elderly Member')),
                        DropdownMenuItem(value: 'SPOUSE', child: Text('Spouse')),
                        DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                      ],
                      onChanged: (val) => setStateDialog(() => label = val!),
                    ),
                  ] else ...[
                    TextField(
                      controller: nameController,
                      style: TextStyle(color: dialogDark ? Colors.white : const Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        labelText: 'Circle Name',
                        prefixIcon: const Icon(Icons.people_outline, color: Color(0xFF14B8A6)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descController,
                      style: TextStyle(color: dialogDark ? Colors.white : const Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        labelText: 'Description (Optional)',
                        prefixIcon: const Icon(Icons.description_outlined, color: Color(0xFF14B8A6)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
              ),
              if (mode != 'invite' || groups.isNotEmpty)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF14B8A6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: dialogSaving
                      ? null
                      : () async {
                          setStateDialog(() => dialogSaving = true);
                          bool success = false;
                          String msg = '';

                          if (mode == 'invite') {
                            final email = emailController.text.trim();
                            if (email.isEmpty) {
                              setStateDialog(() => dialogSaving = false);
                              return;
                            }
                            if (groups.isEmpty) {
                              setStateDialog(() => dialogSaving = false);
                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('You must create a Family Circle first before inviting members.'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                              }
                              return;
                            }
                            final groupId = groups[0]['id'] as int;
                            final res = await ApiService.inviteFamilyMember(groupId, email, label);
                            success = res['success'] == true;
                            msg = success
                                ? (res['message'] ?? 'Invitation sent to $email!')
                                : (res['error'] ?? 'Failed to send invitation.');
                          } else if (mode == 'join') {
                            final code = codeController.text.trim();
                            if (code.isEmpty) {
                              setStateDialog(() => dialogSaving = false);
                              return;
                            }
                            final res = await ApiService.joinFamilyByCode(code, label);
                            success = res['success'] == true;
                            msg = success
                                ? (res['message'] ?? 'Request to join group submitted!')
                                : (res['error'] ?? 'Failed to join group.');
                          } else {
                            final name = nameController.text.trim();
                            if (name.isEmpty) {
                              setStateDialog(() => dialogSaving = false);
                              return;
                            }
                            final desc = descController.text.trim();
                            final res = await ApiService.createFamilyGroup(name, desc);
                            success = res['success'] == true;
                            if (success) {
                              final code = res['family_code']?.toString() ?? '';
                              msg = 'Family Circle "$name" created!';
                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(msg), backgroundColor: Colors.green),
                                );
                                setState(() => _isLoading = true);
                                _fetchMembers(forceRefresh: true);
                                if (code.isNotEmpty) {
                                  Future.delayed(const Duration(milliseconds: 300), () {
                                    _showFamilyCodeDialog(code, name);
                                  });
                                }
                              }
                              return;
                            }
                            msg = res['error']?.toString() ?? 'Failed to create Family Circle.';
                          }

                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(msg),
                                backgroundColor: success ? Colors.green : Colors.red,
                              ),
                            );
                            if (success) {
                              setState(() => _isLoading = true);
                              _fetchMembers(forceRefresh: true);
                            }
                          }
                        },
                  child: dialogSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(
                          mode == 'invite' 
                              ? 'Send Invite' 
                              : (mode == 'join' ? 'Join Group' : 'Create Circle'), 
                          style: const TextStyle(color: Colors.white),
                        ),
                ),
            ],
          );
        },
      ),
    );
  }


  String _getRoleDisplay(String label) {
    switch (label.toUpperCase()) {
      case 'HEAD':
        return 'Family Head';
      case 'PARENT':
        return 'Parent';
      case 'CHILD':
        return 'Child';
      case 'ELDER':
      case 'ELDERLY':
        return 'Elderly Member';
      case 'SPOUSE':
        return 'Spouse';
      case 'OTHER':
        return 'Other';
      default:
        return label;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Family Directory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF14B8A6)),
            onPressed: () {
              setState(() => _isLoading = true);
              _fetchMembers(forceRefresh: true);
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_add_rounded, color: Color(0xFF14B8A6)),
            onPressed: _showAddMemberDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF14B8A6)))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // All safe banner
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF14B8A6), Color(0xFF0D9488)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Colors.white, size: 28),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('All Family Members Safe',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                          Text('${_members.length} members tracked',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),

                // My Family Group Code Banner
                if (_groups.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      final code = _groups[0]['family_code']?.toString() ?? '';
                      final name = _groups[0]['name']?.toString() ?? 'My Group';
                      if (code.isNotEmpty) _showFamilyCodeDialog(code, name);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.vpn_key_rounded, color: Color(0xFF3B82F6), size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Your Group Join Code',
                                    style: TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.bold, fontSize: 13)),
                                Text(
                                  _groups[0]['family_code']?.toString() ?? '',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 3),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.copy_rounded, color: Color(0xFF3B82F6), size: 18),
                        ],
                      ),
                    ),
                  ),

                if (_members.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    margin: const EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFF14B8A6).withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.diversity_3_rounded, size: 56, color: Color(0xFF14B8A6)),
                        const SizedBox(height: 12),
                        Text(
                          'No Family Circle Connected',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Create a new circle as Family Head or join an existing circle using an invitation code.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF14B8A6),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                                label: const Text('Create Circle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                onPressed: () => _showAddMemberDialog(initialMode: 'create'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Color(0xFF14B8A6)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                icon: const Icon(Icons.vpn_key_outlined, color: Color(0xFF14B8A6), size: 18),
                                label: const Text('Join Circle', style: TextStyle(color: Color(0xFF14B8A6), fontWeight: FontWeight.bold)),
                                onPressed: () => _showAddMemberDialog(initialMode: 'join'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                else
                  ..._members.map((member) {
                    final userDetails = member['user_details'] as Map<String, dynamic>?;
                    final username = userDetails != null ? (userDetails['username'] ?? '') : (member['name'] ?? 'Unknown');
                    final email = userDetails != null ? (userDetails['email'] ?? '') : '';
                    final phone = userDetails != null ? (userDetails['phone_number'] ?? '') : '';
                    final labelStr = _getRoleDisplay((member['label'] ?? 'Member').toString());
                    final statusStr = (member['is_approved'] == true ? 'Active' : 'Pending').toString();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: const Color(0xFF14B8A6).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(
                              username.toString().substring(0, 1).toUpperCase(),
                              style: const TextStyle(
                                color: Color(0xFF14B8A6),
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          username.toString(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(labelStr, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.circle,
                                  size: 10,
                                  color: member['is_approved'] == true ? const Color(0xFF14B8A6) : Colors.amber,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  statusStr,
                                  style: TextStyle(
                                    color: member['is_approved'] == true ? const Color(0xFF14B8A6) : Colors.amber,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.call_rounded, color: Color(0xFF14B8A6), size: 22),
                              onPressed: () async {
                                if (phone.toString().isNotEmpty) {
                                  final url = Uri.parse('tel:${phone.toString().replaceAll(' ', '')}');
                                  if (await canLaunchUrl(url)) {
                                    await launchUrl(url);
                                  } else {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Could not open phone dialer.')),
                                      );
                                    }
                                  }
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('No phone number registered for this member.')),
                                  );
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.message_rounded, color: Color(0xFF6366F1), size: 22),
                              onPressed: () async {
                                if (phone.toString().isNotEmpty) {
                                  final url = Uri.parse('sms:${phone.toString().replaceAll(' ', '')}');
                                  if (await canLaunchUrl(url)) {
                                    await launchUrl(url);
                                  } else {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Could not open SMS app.')),
                                      );
                                    }
                                  }
                                } else if (email.toString().isNotEmpty) {
                                  final url = Uri.parse('mailto:${email.toString()}');
                                  if (await canLaunchUrl(url)) {
                                    await launchUrl(url);
                                  } else {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Could not open mail app.')),
                                      );
                                    }
                                  }
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('No contact information registered for this member.')),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 80),
              ],
            ),
    );
  }
}
