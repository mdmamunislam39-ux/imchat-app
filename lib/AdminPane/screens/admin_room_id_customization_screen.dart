import 'package:flutter/material.dart';
import '../models/custom_room_id_model.dart';
import '../models/custom_room_id_history_model.dart';
import '../services/room_customization_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AdminRoomIdCustomizationScreen extends StatefulWidget {
  const AdminRoomIdCustomizationScreen({super.key});

  @override
  State<AdminRoomIdCustomizationScreen> createState() => _AdminRoomIdCustomizationScreenState();
}

class _AdminRoomIdCustomizationScreenState extends State<AdminRoomIdCustomizationScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _searchController = TextEditingController();
  final _customIdController = TextEditingController();
  final _durationController = TextEditingController();
  late TabController _tabController;

  Map<String, dynamic>? _selectedRoom;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _customIdController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  void _resetForm() {
    setState(() {
      _searchController.clear();
      _customIdController.clear();
      _durationController.text = '30'; // Default 30 days
      _selectedRoom = null;
    });
  }

  Future<void> _searchRoom() async {
    final searchId = _searchController.text.trim();
    if (searchId.isEmpty) return;

    setState(() => _isSearching = true);
    
    try {
      final room = await RoomCustomizationService.searchRoomByOriginalId(searchId);
      setState(() {
        _selectedRoom = room;
        _isSearching = false;
      });
      
      if (room == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Room not found! Ensure the ID is correct.'))
        );
      }
    } catch (e) {
      setState(() => _isSearching = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search error: $e'))
        );
      }
    }
  }

  Future<void> _assignCustomId() async {
    if (!_formKey.currentState!.validate() || _selectedRoom == null) return;

    try {
      final days = int.tryParse(_durationController.text) ?? 30;
      final customIdModel = CustomRoomIdModel(
        id: '',
        roomId: _selectedRoom!['id'],
        originalRoomId: _selectedRoom!['roomId'],
        customRoomId: _customIdController.text.trim(),
        roomName: _selectedRoom!['name'],
        roomImageUrl: _selectedRoom!['imageUrl'],
        assignedAt: DateTime.now(),
        expiresAt: DateTime.now().add(Duration(days: days)),
      );

      await RoomCustomizationService.assignCustomRoomId(customIdModel);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Custom Room ID assigned successfully')));
        Navigator.pop(context);
        _resetForm();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Assignment error: $e')));
      }
    }
  }

  void _showAssignDialog(BuildContext context) {
    _resetForm();
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF22223B),
            title: const Text('Assign Custom Room ID', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _searchController,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'Original Room ID',
                              labelStyle: TextStyle(color: Colors.grey),
                              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _isSearching ? null : () async {
                            setDialogState(() => _isSearching = true);
                            await _searchRoom();
                            setDialogState(() => _isSearching = false);
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                          child: _isSearching
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('Search', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_selectedRoom != null) ...[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: CachedNetworkImage(
                                imageUrl: _selectedRoom!['imageUrl'] ?? '',
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(color: Colors.grey[800], child: const Icon(Icons.room, color: Colors.white24)),
                                errorWidget: (context, url, error) => Container(color: Colors.grey[800], child: const Icon(Icons.room, color: Colors.white24)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _selectedRoom!['name'] ?? 'Unknown Room',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _customIdController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Desired Custom ID (1-6 Digits)',
                          labelStyle: TextStyle(color: Colors.grey),
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return 'Please enter desired Custom ID';
                          final len = value.trim().length;
                          if (len < 1 || len > 6) return 'Must be between 1 and 6 characters';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _durationController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Duration in Days',
                          labelStyle: TextStyle(color: Colors.grey),
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Please enter duration';
                          if (int.tryParse(value) == null) return 'Must be a valid integer';
                          return null;
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _resetForm();
                },
                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
              if (_selectedRoom != null)
                ElevatedButton(
                  onPressed: _assignCustomId,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  child: const Text('Assign', style: TextStyle(color: Colors.white)),
                ),
            ],
          );
        }
      ),
    );
  }

  void _showEditDialog(BuildContext context, CustomRoomIdModel assignment) {
    final editIdController = TextEditingController(text: assignment.customRoomId);
    DateTime selectedDate = assignment.expiresAt;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF22223B),
            title: const Text('Edit Custom Room ID', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: editIdController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Custom ID',
                      labelStyle: TextStyle(color: Colors.grey),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Please enter Custom ID';
                      final len = value.trim().length;
                      if (len < 1 || len > 6) return 'Must be between 1 and 6 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Expires At:', style: TextStyle(color: Colors.grey)),
                      TextButton(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime.now().subtract(const Duration(days: 30)),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (date != null) {
                            setDialogState(() {
                              selectedDate = DateTime(date.year, date.month, date.day, 23, 59, 59);
                            });
                          }
                        },
                        child: Text(selectedDate.toString().split(' ')[0], style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    try {
                      await RoomCustomizationService.updateCustomRoomId(
                        assignment.id,
                        selectedDate,
                        assignment.isActive,
                        newCustomId: editIdController.text,
                      );
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Updated successfully!')));
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    }
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                child: const Text('Save', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        }
      ),
    );
  }

  Widget _getStyleIndicator(String customId) {
    final length = customId.length;
    Color bgColor;
    Color textColor = Colors.white;
    String label;
    IconData? icon;

    if (length == 1) {
      bgColor = Colors.black;
      textColor = Colors.amber;
      label = 'Premium Black';
      icon = Icons.star;
    } else if (length == 2) {
      bgColor = Colors.amber[700]!;
      label = 'Golden';
      icon = Icons.stars;
    } else if (length >= 3 && length <= 4) {
      bgColor = Colors.purple;
      label = 'Purple';
    } else if (length >= 5 && length <= 6) {
      bgColor = Colors.cyan;
      label = 'Aqua RGB';
    } else {
      bgColor = Colors.grey[700]!;
      label = 'Default';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: length == 1 ? Border.all(color: Colors.amber, width: 2) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: textColor, size: 14),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(color: textColor, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveAssignments() {
    return StreamBuilder<List<CustomRoomIdModel>>(
      stream: RoomCustomizationService.getCustomRoomIdsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.blue));
        }

        final assignments = snapshot.data ?? [];

        if (assignments.isEmpty) {
          return const Center(
            child: Text('No custom room IDs assigned yet.', style: TextStyle(color: Colors.grey)),
          );
        }

        return ListView.builder(
          itemCount: assignments.length,
          itemBuilder: (context, index) {
            final assignment = assignments[index];
            final isExpired = assignment.isExpired;

            return Card(
              color: const Color(0xFF22223B),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: CachedNetworkImage(
                            imageUrl: assignment.roomImageUrl,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(color: Colors.grey[800], child: const Icon(Icons.room, color: Colors.white24)),
                            errorWidget: (context, url, error) => Container(color: Colors.grey[800], child: const Icon(Icons.room, color: Colors.white24)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(assignment.roomName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              Text('Original ID: ${assignment.originalRoomId}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              assignment.customRoomId,
                              style: const TextStyle(color: Colors.amber, fontSize: 24, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            _getStyleIndicator(assignment.customRoomId),
                          ],
                        ),
                      ],
                    ),
                    const Divider(color: Colors.grey),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Status: ${!assignment.isActive ? "Deactivated" : (isExpired ? "Expired" : "Active")}',
                              style: TextStyle(color: !assignment.isActive ? Colors.grey : (isExpired ? Colors.red : Colors.green)),
                            ),
                            Text(
                              'Expires: ${assignment.expiresAt.toLocal().toString().split(' ')[0]}',
                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Switch(
                              value: assignment.isActive && !isExpired,
                              onChanged: (value) {
                                if (isExpired && value) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot activate expired ID. Please delete and assign a new one.')));
                                  return;
                                }
                                RoomCustomizationService.updateCustomRoomId(assignment.id, assignment.expiresAt, value);
                              },
                              activeThumbColor: Colors.blue,
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () {
                                _showEditDialog(context, assignment);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    backgroundColor: const Color(0xFF22223B),
                                    title: const Text('Remove Assignment', style: TextStyle(color: Colors.white)),
                                    content: const Text('Are you sure you want to remove this Custom ID and restore the original ID?', style: TextStyle(color: Colors.grey)),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                                      ElevatedButton(
                                        onPressed: () {
                                          RoomCustomizationService.deleteCustomRoomId(assignment.id);
                                          Navigator.pop(context);
                                        },
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                        child: const Text('Remove'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHistoryTab() {
    return StreamBuilder<List<dynamic>>(
      stream: RoomCustomizationService.getCustomRoomIdHistoryStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.blue));
        }

        final historyLogs = snapshot.data ?? [];

        if (historyLogs.isEmpty) {
          return const Center(
            child: Text('No history found.', style: TextStyle(color: Colors.grey)),
          );
        }

        return ListView.builder(
          itemCount: historyLogs.length,
          itemBuilder: (context, index) {
            final log = historyLogs[index];
            IconData actionIcon;
            Color actionColor;

            switch (log.action) {
              case RoomIdHistoryAction.assign:
                actionIcon = Icons.add_circle;
                actionColor = Colors.green;
                break;
              case RoomIdHistoryAction.update:
                actionIcon = Icons.edit;
                actionColor = Colors.orange;
                break;
              case RoomIdHistoryAction.remove:
                actionIcon = Icons.delete;
                actionColor = Colors.red;
                break;
              default:
                actionIcon = Icons.info;
                actionColor = Colors.blue;
            }

            return ListTile(
              leading: Icon(actionIcon, color: actionColor),
              title: Text('Room ID: ${log.roomId} - Custom ID: ${log.customRoomId}', style: const TextStyle(color: Colors.white)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(log.notes ?? '', style: const TextStyle(color: Colors.grey)),
                  Text('Admin: ${log.actionByAdminId}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
              trailing: Text(
                log.timestamp.toLocal().toString().substring(0, 16),
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Custom Room IDs', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.blue,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'Active Assignments'),
            Tab(text: 'History'),
          ],
        ),
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton(
              onPressed: () {
                _resetForm();
                _showAssignDialog(context);
              },
              backgroundColor: Colors.blue,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildActiveAssignments(),
          _buildHistoryTab(),
        ],
      ),
    );
  }
}
