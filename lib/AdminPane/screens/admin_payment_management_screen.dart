import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:chat_messenger/models/recharge_models.dart';
import 'package:chat_messenger/services/online_recharge_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Admin Panel screen for managing dynamic payment methods (bKash, Nagad, etc.) and recharge packages
class AdminPaymentManagementScreen extends StatefulWidget {
  const AdminPaymentManagementScreen({super.key});

  @override
  State<AdminPaymentManagementScreen> createState() => _AdminPaymentManagementScreenState();
}

class _AdminPaymentManagementScreenState extends State<AdminPaymentManagementScreen>
    with SingleTickerProviderStateMixin {
  final OnlineRechargeService _rechargeService = OnlineRechargeService.instance;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ============================================================
  // PAYMENT METHOD MODALS
  // ============================================================

  void _showAddEditPaymentMethodDialog([PaymentMethodModel? existing]) {
    final isEdit = existing != null;
    final nameController = TextEditingController(text: existing?.name ?? '');
    final numberController = TextEditingController(text: existing?.number ?? '');
    final iconController = TextEditingController(text: existing?.iconUrl ?? '');
    final instructionController = TextEditingController(
      text: existing?.instructions ?? "'সেন্ড মানি' দিয়ে পরিশোধ করুন",
    );
    bool isStatusOn = existing != null ? existing.isActive : true;
    File? pickedImageFile;
    bool isUploading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E142B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                isEdit ? 'Edit Payment Method' : 'Add Payment Method',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Payment Name (e.g. bKash, Nagad, Rocket)',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.purpleAccent)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: numberController,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Payment Number (e.g. 01609738735)',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.purpleAccent)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: instructionController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Payment Note / Instructions',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.purpleAccent)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Logo / Picture Selector (File Picker + URL)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(10),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withAlpha(25)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Payment Logo / Picture:',
                            style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              // Preview box
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: Colors.black26,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.purpleAccent.withAlpha(100)),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: pickedImageFile != null
                                      ? Image.file(pickedImageFile!, fit: BoxFit.contain)
                                      : (iconController.text.trim().isNotEmpty
                                          ? _buildPaymentImageWidget(iconController.text.trim(), 'Payment', size: 52)
                                          : const Icon(Icons.image, color: Colors.white38, size: 28)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.purple.shade700,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  icon: const Icon(Icons.photo_library, size: 18),
                                  label: Text(pickedImageFile != null ? 'CHANGE PHOTO' : 'PICK PHOTO'),
                                  onPressed: () async {
                                    try {
                                      final picker = ImagePicker();
                                      final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                                      if (picked != null) {
                                        setDialogState(() {
                                          pickedImageFile = File(picked.path);
                                        });
                                      }
                                    } catch (e) {
                                      debugPrint('Error picking image: $e');
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: iconController,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                            onChanged: (_) => setDialogState(() {}),
                            decoration: const InputDecoration(
                              labelText: 'Or Paste Image URL / Asset Path',
                              labelStyle: TextStyle(color: Colors.white54, fontSize: 12),
                              isDense: true,
                              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.purpleAccent)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Status (Active / Live):', style: TextStyle(color: Colors.white70)),
                        Switch(
                          value: isStatusOn,
                          activeThumbColor: const Color(0xFF00B074),
                          onChanged: (val) {
                            setDialogState(() => isStatusOn = val);
                          },
                        ),
                      ],
                    ),
                    if (isUploading) ...[
                      const SizedBox(height: 14),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.purpleAccent)),
                          SizedBox(width: 10),
                          Text('Uploading logo...', style: TextStyle(color: Colors.purpleAccent, fontSize: 12)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isUploading ? null : () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purpleAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: isUploading
                      ? null
                      : () async {
                          final name = nameController.text.trim();
                          final number = numberController.text.trim();
                          final messenger = ScaffoldMessenger.of(context);
                          if (name.isEmpty || number.isEmpty) {
                            messenger.showSnackBar(
                              const SnackBar(content: Text('Please fill name and number.')),
                            );
                            return;
                          }

                          final navigator = Navigator.of(context);
                          setDialogState(() => isUploading = true);

                          try {
                            String finalIconUrl = iconController.text.trim();

                            // If a new local image file was picked, upload to Firebase Storage
                            if (pickedImageFile != null) {
                              final storageRef = FirebaseStorage.instance
                                  .ref()
                                  .child('payment_method_logos/${const Uuid().v4()}.png');
                              await storageRef.putFile(pickedImageFile!);
                              finalIconUrl = await storageRef.getDownloadURL();
                            }

                            if (isEdit) {
                              await _rechargeService.updatePaymentMethod(
                                paymentId: existing.id,
                                name: name,
                                number: number,
                                iconUrl: finalIconUrl,
                                status: isStatusOn ? 'ON' : 'OFF',
                                instructions: instructionController.text.trim(),
                              );
                            } else {
                              await _rechargeService.addPaymentMethod(
                                name: name,
                                number: number,
                                iconUrl: finalIconUrl,
                                status: isStatusOn ? 'ON' : 'OFF',
                                instructions: instructionController.text.trim(),
                              );
                            }
                            navigator.pop();
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(isEdit ? 'Payment method updated successfully!' : 'Payment method added successfully!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e) {
                            setDialogState(() => isUploading = false);
                            messenger.showSnackBar(
                              SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                            );
                          }
                        },
                  child: Text(isEdit ? 'SAVE CHANGES' : 'ADD METHOD'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeletePaymentMethod(PaymentMethodModel method) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E142B),
        title: const Text('Delete Payment Method', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete ${method.name} (${method.number})?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(context);
              await _rechargeService.deletePaymentMethod(method.id);
              messenger.showSnackBar(
                const SnackBar(content: Text('Payment method deleted.')),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DIAMOND PACKAGE MODAL
  // ============================================================

  void _showAddEditPackageDialog([RechargePackageModel? existing]) {
    final isEdit = existing != null;
    final amountController = TextEditingController(text: existing?.amount.toString() ?? '');
    final diamondsController = TextEditingController(text: existing?.diamondAmount.toString() ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E142B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isEdit ? 'Edit Diamond Package' : 'Add Diamond Package',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Amount (BDT ৳)',
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.purpleAccent)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: diamondsController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Diamond Amount',
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.purpleAccent)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
            onPressed: () async {
              final amount = num.tryParse(amountController.text.trim()) ?? 0;
              final diamonds = int.tryParse(diamondsController.text.trim()) ?? 0;
              final messenger = ScaffoldMessenger.of(context);
              if (amount <= 0 || diamonds <= 0) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Please enter valid amount and diamonds.')),
                );
                return;
              }

              Navigator.pop(context);

              try {
                final id = existing?.id ?? 'pkg_${amount.toInt()}';
                await FirebaseFirestore.instance
                    .collection('rechargePackages')
                    .doc(id)
                    .set({
                  'id': id,
                  'amount': amount,
                  'diamondAmount': diamonds,
                  'status': 'active',
                  'updatedAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));

                messenger.showSnackBar(
                  const SnackBar(content: Text('Package saved!'), backgroundColor: Colors.green),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('SAVE PACKAGE'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0B18),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E142B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Payment Management',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.purpleAccent,
          labelColor: Colors.purpleAccent,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'Payment Methods', icon: Icon(Icons.account_balance_wallet_outlined, size: 20)),
            Tab(text: 'Diamond Packages', icon: Icon(Icons.diamond_outlined, size: 20)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.purpleAccent,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          _tabController.index == 0 ? 'Add Payment Method' : 'Add Diamond Package',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        onPressed: () {
          if (_tabController.index == 0) {
            _showAddEditPaymentMethodDialog();
          } else {
            _showAddEditPackageDialog();
          }
        },
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 1. PAYMENT METHODS TAB
          StreamBuilder<List<PaymentMethodModel>>(
            stream: _rechargeService.getAllPaymentMethodsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Colors.purpleAccent));
              }

              final methods = snapshot.data ?? [];
              if (methods.isEmpty) {
                return const Center(
                  child: Text('No payment methods found. Tap + to add one.', style: TextStyle(color: Colors.white54)),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                itemCount: methods.length,
                itemBuilder: (context, index) {
                  final method = methods[index];
                  return _buildPaymentMethodCard(method);
                },
              );
            },
          ),

          // 2. DIAMOND PACKAGES TAB
          StreamBuilder<List<RechargePackageModel>>(
            stream: _rechargeService.getRechargePackagesStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Colors.purpleAccent));
              }

              final packages = snapshot.data ?? [];
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                itemCount: packages.length,
                itemBuilder: (context, index) {
                  final pkg = packages[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E142B),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withAlpha(20)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.diamond, color: Colors.amberAccent, size: 24),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '৳${pkg.amount.toStringAsFixed(0)} BDT',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '+${pkg.diamondAmount} Diamonds',
                                  style: const TextStyle(color: Colors.amberAccent, fontSize: 13),
                                ),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.purpleAccent, size: 20),
                          onPressed: () => _showAddEditPackageDialog(pkg),
                        ),
                      ],
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

  Widget _buildPaymentMethodCard(PaymentMethodModel method) {
    final isOn = method.isActive;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E142B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOn ? const Color(0xFF00B074).withAlpha(80) : Colors.white.withAlpha(15),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Logo
              _buildPaymentImageWidget(method.iconUrl, method.name, size: 36),
              const SizedBox(width: 12),

              // Title & Status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      method.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isOn ? const Color(0xFF00B074) : Colors.red,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isOn ? 'STATUS: ACTIVE (LIVE)' : 'STATUS: OFF (HIDDEN)',
                          style: TextStyle(
                            color: isOn ? const Color(0xFF00B074) : Colors.redAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Switch ON/OFF
              Switch(
                value: isOn,
                activeThumbColor: const Color(0xFF00B074),
                onChanged: (val) {
                  _rechargeService.togglePaymentMethodStatus(method.id, isOn);
                },
              ),
            ],
          ),
          const Divider(color: Colors.white12, height: 20),

          // Number
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Payment Number:', style: TextStyle(color: Colors.white60, fontSize: 13)),
              SelectableText(
                method.number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Note
          if (method.instructions.isNotEmpty) ...[
            Text(
              'Note: ${method.instructions}',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
            const SizedBox(height: 10),
          ],

          // Actions: [Edit] [Delete]
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.edit, size: 16, color: Colors.purpleAccent),
                label: const Text('EDIT', style: TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold)),
                onPressed: () => _showAddEditPaymentMethodDialog(method),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                label: const Text('DELETE', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                onPressed: () => _confirmDeletePaymentMethod(method),
              ),
            ],
          ),
        ],
      ),
    );
  }

  
  Widget _buildPaymentImageWidget(String iconUrl, String name, {double size = 36}) {
    final icon = iconUrl.trim();
    if (icon.isNotEmpty) {
      if (icon.startsWith('data:image/') || icon.startsWith('data:') || icon.contains(';base64,')) {
        try {
          final commaIndex = icon.indexOf(',');
          final rawBase64 = commaIndex != -1 ? icon.substring(commaIndex + 1) : icon;
          final cleanBase64 = rawBase64.replaceAll(RegExp(r'\s+'), '');
          final bytes = base64Decode(cleanBase64);
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: size,
              height: size,
              child: Image.memory(
                bytes,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => _buildFallbackLogo(name),
              ),
            ),
          );
        } catch (e) {
          debugPrint('Error decoding base64 icon: $e');
        }
      }

      if (icon.startsWith('http://') || icon.startsWith('https://')) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: size,
            height: size,
            child: CachedNetworkImage(
              imageUrl: icon,
              fit: BoxFit.contain,
              errorWidget: (_, __, ___) => _buildFallbackLogo(name),
            ),
          ),
        );
      }

      if (icon.length > 50 && (!icon.contains('/') || icon.startsWith('/9j/') || icon.startsWith('iVBORw'))) {
        try {
          final cleanBase64 = icon.replaceAll(RegExp(r'\s+'), '');
          final bytes = base64Decode(cleanBase64);
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: size,
              height: size,
              child: Image.memory(
                bytes,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => _buildFallbackLogo(name),
              ),
            ),
          );
        } catch (_) {}
      }

      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: size,
          height: size,
          child: Image.asset(
            icon,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _buildFallbackLogo(name),
          ),
        ),
      );
    }
    return _buildFallbackLogo(name);
  }

  Widget _buildFallbackLogo(String name) {
    final lower = name.toLowerCase();
    Color bg = Colors.pink;
    String symbol = '৳';

    if (lower.contains('bkash')) {
      bg = const Color(0xFFE2136E);
      symbol = 'b';
    } else if (lower.contains('nagad')) {
      bg = const Color(0xFFF7941D);
      symbol = 'ন';
    } else if (lower.contains('rocket')) {
      bg = const Color(0xFF8C3494);
      symbol = 'R';
    } else {
      bg = Colors.purple;
    }

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Center(
        child: Text(
          symbol,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
    );
  }
}
