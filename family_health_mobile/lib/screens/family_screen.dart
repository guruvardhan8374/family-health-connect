import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../services/sync_service.dart';
import '../services/location_service.dart';
import 'chat_screen.dart';

class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  List<dynamic> _members = [];
  List<dynamic> _groups = [];
  int _selectedGroupIndex = 0;
  bool _isLoading = true;
  StreamSubscription? _syncSubscription;

  @override
  void initState() {
    super.initState();
    _fetchMembers(forceRefresh: true);
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

  void _showDeleteCircleDialog() {
    if (_groups.isEmpty) return;
    int? selectedGroupId = _groups[_selectedGroupIndex.clamp(0, _groups.length - 1)]['id'];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Row(
                children: [
                  Icon(Icons.delete_forever_rounded, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Select Circle to Delete', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select which family circle you want to delete:',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          children: _groups.map((group) {
                            final gId = group['id'];
                            final gName = group['name'] ?? 'Family Circle';
                            final isSelected = selectedGroupId == gId;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.red.withOpacity(0.08) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected ? Colors.red : const Color(0xFFE2E8F0),
                                  width: isSelected ? 1.5 : 1.0,
                                ),
                              ),
                              child: RadioListTile<int>(
                                value: gId,
                                groupValue: selectedGroupId,
                                activeColor: Colors.red,
                                title: Text(
                                  gName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? Colors.red : const Color(0xFF0F172A),
                                  ),
                                ),
                                subtitle: Text(
                                  group['description'] ?? 'Family Group',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                ),
                                onChanged: (val) {
                                  setModalState(() => selectedGroupId = val);
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.delete_forever_rounded, color: Colors.white, size: 18),
                  label: const Text('Delete Selected Circle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  onPressed: selectedGroupId == null
                      ? null
                      : () async {
                          Navigator.pop(ctx);
                          final targetGroup = _groups.firstWhere((g) => g['id'] == selectedGroupId, orElse: () => null);
                          final gName = targetGroup != null ? (targetGroup['name'] ?? 'Circle') : 'Circle';
                          setState(() => _isLoading = true);
                          final ok = await ApiService.deleteFamilyGroup(selectedGroupId!);
                          if (ok) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Family circle "$gName" deleted successfully.')),
                              );
                              _selectedGroupIndex = 0;
                              _fetchMembers(forceRefresh: true);
                            }
                          } else {
                            if (mounted) {
                              setState(() => _isLoading = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Failed to delete circle. Only the Circle Head/Admin can delete it.')),
                              );
                            }
                          }
                        },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddMemberDialog({String initialMode = 'create'}) async {
    final codeController = TextEditingController();
    final nameController = TextEditingController();
    final descController = TextEditingController();
    String label = 'OTHER';
    String mode = (initialMode == 'join' || initialMode == 'create') ? initialMode : 'create';
    bool dialogSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          final dialogDark = Theme.of(context).brightness == Brightness.dark;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              mode == 'join' ? 'Join Family Group' : 'Create Family Circle',
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
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: ChoiceChip(
                            label: const Text('Create Circle', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            selected: mode == 'create',
                            selectedColor: const Color(0xFF14B8A6).withValues(alpha: 0.2),
                            onSelected: (val) {
                              if (val) setStateDialog(() => mode = 'create');
                            },
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: ChoiceChip(
                            label: const Text('Join Circle', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            selected: mode == 'join',
                            selectedColor: const Color(0xFF14B8A6).withValues(alpha: 0.2),
                            onSelected: (val) {
                              if (val) setStateDialog(() => mode = 'join');
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (mode == 'join') ...[
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

                        if (mode == 'join') {
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
                          msg = res['error'] ?? 'Failed to create group.';
                        }

                        if (success) {
                          LocationService.startPeriodicTracking();
                          LocationService.getCurrentPosition().then((pos) {
                            if (pos != null) {
                              ApiService.updateLocation(lat: pos.latitude, lng: pos.longitude);
                            }
                          });
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
                        mode == 'join' ? 'Join Group' : 'Create Circle', 
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
    final activeIndex = _selectedGroupIndex.clamp(0, _groups.isEmpty ? 0 : _groups.length - 1);
    final activeGroup = _groups.isNotEmpty ? _groups[activeIndex] : null;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Family Directory'),
        actions: [
          if (_groups.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF14B8A6)),
              onSelected: (val) {
                if (val == 'delete_circle') {
                  _showDeleteCircleDialog();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'delete_circle',
                  child: Row(
                    children: [
                      Icon(Icons.delete_forever_rounded, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Text('Delete Circle', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
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
                  // Active Circle Switcher (if user is in multiple groups)
                  if (_groups.length > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF14B8A6).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF14B8A6).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.people_alt_rounded, color: Color(0xFF14B8A6), size: 20),
                          const SizedBox(width: 8),
                          const Text('Active Circle:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: activeIndex,
                                isExpanded: true,
                                icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF14B8A6)),
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 14),
                                onChanged: (newIdx) {
                                  if (newIdx != null) {
                                    setState(() => _selectedGroupIndex = newIdx);
                                  }
                                },
                                items: List.generate(_groups.length, (i) {
                                  return DropdownMenuItem<int>(
                                    value: i,
                                    child: Text(_groups[i]['name'] ?? 'Circle ${i + 1}'),
                                  );
                                }),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

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

                  // Active Family Group Code Banner
                  if (activeGroup != null)
                    GestureDetector(
                      onTap: () {
                        final code = activeGroup['family_code']?.toString() ?? '';
                        final name = activeGroup['name']?.toString() ?? 'My Group';
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
                                  Text('${activeGroup['name'] ?? 'Group'} Join Code',
                                      style: const TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.bold, fontSize: 13)),
                                  Text(
                                    activeGroup['family_code']?.toString() ?? '',
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

                  if (activeGroup != null) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.forum_rounded, color: Colors.white, size: 20),
                        label: Text(
                          'Open "${activeGroup['name'] ?? 'Family Circle'}" Group Chat',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                initialFamilyGroupId: activeGroup['id'],
                                initialFamilyGroupName: activeGroup['name'],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],

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
                        trailing: IconButton(
                          icon: const Icon(Icons.message_rounded, color: Color(0xFF6366F1), size: 22),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  targetUserId: member['user'],
                                  targetUsername: username,
                                ),
                              ),
                            );
                          },
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
