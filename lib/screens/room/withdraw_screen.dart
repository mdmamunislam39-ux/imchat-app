import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:chat_messenger/models/user.dart';
import 'package:chat_messenger/services/gift_economy_service.dart';
import 'package:chat_messenger/components/cached_circle_avatar.dart';
import 'package:chat_messenger/components/dynamic_bean_icon.dart';
import 'package:chat_messenger/config/theme_config.dart';
import 'package:chat_messenger/screens/room/user_withdrawal_history_screen.dart';

class WithdrawPackage {
  final int usdAmount;
  final int beanAmount;

  const WithdrawPackage({
    required this.usdAmount,
    required this.beanAmount,
  });
}

class CoinDealer {
  final String id;
  final String name;
  final String searchId;
  final String photoUrl;

  const CoinDealer({
    required this.id,
    required this.name,
    required this.searchId,
    required this.photoUrl,
  });
}

class WithdrawScreen extends StatefulWidget {
  final User currentUser;

  const WithdrawScreen({
    super.key,
    required this.currentUser,
  });

  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends State<WithdrawScreen> {
  final GiftEconomyService _giftEconomyService = GiftEconomyService.instance;

  late User _currentUser;
  StreamSubscription<DocumentSnapshot>? _userSubscription;
  StreamSubscription<DocumentSnapshot>? _configSubscription;

  // Saved Withdrawal Info (Payment Method)
  String _withdrawalName = '';
  String _withdrawalBkash = '';

  // Diamond Sellers (formerly Coin Dealers)
  List<CoinDealer> _dealers = [];
  CoinDealer _selectedDealer = const CoinDealer(
    id: 'dealer_salim',
    name: 'SaLiM AhMeD',
    searchId: '10908908',
    photoUrl: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150',
  );
  // Dynamic Rate & Packages from Admin Panel (platform_config/gift_conversion)
  int get _beansPerUsd => _giftEconomyService.beansPerUsd;
  int get _minWithdrawUsd => _giftEconomyService.minWithdrawUsd;
  bool get _isWithdrawalEnabled => _giftEconomyService.isWithdrawalEnabled;

  List<WithdrawPackage> get _presetPackages {
    final list = _giftEconomyService.withdrawPackages;
    final rate = _beansPerUsd;
    return list.map((usd) => WithdrawPackage(usdAmount: usd, beanAmount: usd * rate)).toList();
  }

  @override
  void initState() {
    super.initState();
    _currentUser = widget.currentUser;
    _withdrawalName = _currentUser.fullname;
    _withdrawalBkash = _currentUser.number;
    _listenToUserChanges();
    _loadCoinDealers();
    _loadEconomyConfig();
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    _configSubscription?.cancel();
    super.dispose();
  }

  void _listenToUserChanges() {
    _userSubscription?.cancel();
    _userSubscription = FirebaseFirestore.instance
        .collection('Users')
        .doc(widget.currentUser.userId)
        .snapshots()
        .listen((snapshot) {
      if (mounted && snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data()!;
        setState(() {
          _currentUser = User.fromMap(data);
          final wName = data['withdrawalName'] as String?;
          final wBkash = data['withdrawalBkash'] as String? ??
              data['withdrawalNumber'] as String?;
          if (wName != null && wName.isNotEmpty) {
            _withdrawalName = wName;
          } else if (_withdrawalName.isEmpty) {
            _withdrawalName = _currentUser.fullname;
          }
          if (wBkash != null && wBkash.isNotEmpty) {
            _withdrawalBkash = wBkash;
          } else if (_withdrawalBkash.isEmpty) {
            _withdrawalBkash = _currentUser.number;
          }
        });
      }
    });
  }

  void _loadEconomyConfig() {
    _configSubscription?.cancel();
    _configSubscription = FirebaseFirestore.instance
        .collection('platform_config')
        .doc('gift_conversion')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        _giftEconomyService.getConfig();
        setState(() {});
      }
    });
  }

    StreamSubscription<QuerySnapshot>? _dealersSubscription;

  void _loadCoinDealers() {
    try {
      _dealersSubscription?.cancel();
      _dealersSubscription = FirebaseFirestore.instance
          .collection('withdrawal_sellers')
          .where('isActive', isEqualTo: true)
          .snapshots()
          .listen((snapshot) {
        List<CoinDealer> loaded = [];
        for (var doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final uid = (data['userId'] as String?) ?? doc.id;
          final name = (data['name'] as String?) ?? (data['username'] as String?) ?? 'Seller';
          final sId = (data['searchId'] as String?) ?? uid;
          final photo = (data['photoUrl'] as String?) ?? '';
          loaded.add(CoinDealer(
            id: uid,
            name: name,
            searchId: sId,
            photoUrl: photo,
          ));
        }

        if (mounted) {
          setState(() {
            if (loaded.isNotEmpty) {
              _dealers = loaded;
              final existing = loaded.where((d) => d.id == _selectedDealer.id);
              if (existing.isNotEmpty) {
                _selectedDealer = existing.first;
              } else {
                _selectedDealer = loaded.first;
              }
            } else {
              _dealers = [];
            }
          });
        }
      }, onError: (e) {
        debugPrint('Error streaming authorized withdrawal sellers: ' + e.toString());
      });
    } catch (e) {
      debugPrint('Error setting up withdrawal sellers stream: ' + e.toString());
    }
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  String _maskPhoneNumber(String? number) {
    if (number == null || number.isEmpty) {
      return '0184***1874';
    }
    final clean = number.trim();
    if (clean.length > 7) {
      final prefix = clean.substring(0, 4);
      final suffix = clean.substring(clean.length - 4);
      return '$prefix***$suffix';
    }
    return clean;
  }

  // Open "Select a withdrawal method" Bottom Sheet (Screenshot 2)
  void _openWithdrawalMethodSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Center(
                  child: Text(
                    'Select a withdrawal method',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Card with green outline and checked icon
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF00C853),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF8A65), Color(0xFFFFD54F)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.withValues(alpha: 0.25),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFC107),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            child: const Center(
                              child: Text(
                                '\$',
                                style: TextStyle(
                                  color: Color(0xFFD81B60),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Withdraw',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'You are expected to receive it in 7 working days.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.check_circle,
                        color: Color(0xFF00C853),
                        size: 24,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const Divider(height: 1, color: Color(0xFFEEEEEE)),
                const SizedBox(height: 12),
                // "Edit your withdrawal information" row
                InkWell(
                  onTap: () {
                    Navigator.pop(bottomCtx);
                    _openEditWithdrawalInfoScreen();
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 4,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Edit your withdrawal information',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: Colors.grey.shade400,
                          size: 22,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  // Open Edit Withdrawal Information Screen (Screenshot 3)
  Future<void> _openEditWithdrawalInfoScreen() async {
    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(
        builder: (context) => EditWithdrawalInfoScreen(
          initialName: _withdrawalName.isNotEmpty
              ? _withdrawalName
              : _currentUser.fullname,
          initialBkash: _withdrawalBkash.isNotEmpty
              ? _withdrawalBkash
              : _currentUser.number,
          userId: _currentUser.userId,
          onHelpTap: _showHelpDialog,
          onPolicyTap: _showPolicyDialog,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _withdrawalName = result['name'] ?? _withdrawalName;
        _withdrawalBkash = result['bkash'] ?? _withdrawalBkash;
      });
    }
  }

  // Handle preset package tap -> Proceed to Screen 2
  void _onPackageSelected(WithdrawPackage pkg) {
    _proceedToConfirmation(
      usdAmount: pkg.usdAmount.toDouble(),
      beanAmount: pkg.beanAmount,
    );
  }

  // Handle customize button tap -> Open Custom Amount bottom sheet
  void _openCustomizeSheet() {
    final customController = TextEditingController();
    int calculatedBeans = 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomCtx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(bottomCtx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Customize Withdrawal Amount',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.black54),
                        onPressed: () => Navigator.pop(bottomCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Available: ${_formatNumber(_currentUser.beans)} beans',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: customController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    autofocus: true,
                    decoration: InputDecoration(
                      prefixText: '\$ ',
                      prefixStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE91E63),
                      ),
                      labelText: 'Enter USD Amount',
                      hintText: 'e.g. 258',
                      filled: true,
                      fillColor: const Color(0xFFF7F8FA),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: Color(0xFF00C853),
                          width: 2,
                        ),
                      ),
                    ),
                    onChanged: (val) {
                      final parsed = int.tryParse(val.trim()) ?? 0;
                      setSheetState(() {
                        calculatedBeans = parsed * _beansPerUsd;
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  if (calculatedBeans > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F8F0),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF81C784).withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          const DynamicBeanIcon(width: 18, height: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Required Beans: ${_formatNumber(calculatedBeans)}',
                            style: const TextStyle(
                              color: Color(0xFF1B5E20),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        final parsed =
                            int.tryParse(customController.text.trim()) ?? 0;
                        if (parsed <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter a valid amount.'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }
                        if (parsed < _minWithdrawUsd) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Minimum withdrawal amount is ${_minWithdrawUsd} (${_minWithdrawUsd * _beansPerUsd} beans).'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }
                        Navigator.pop(bottomCtx);
                        _proceedToConfirmation(
                          usdAmount: parsed.toDouble(),
                          beanAmount: parsed * _beansPerUsd,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00C853),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Proceed to Withdraw',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Open Diamond Seller Selection Bottom Sheet
  void _openDiamondSellerPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Select Diamond sellers',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _dealers.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final dealer = _dealers[index];
                  final isSelected = dealer.id == _selectedDealer.id;

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    leading: CachedCircleAvatar(
                      radius: 22,
                      iconSize: 24,
                      imageUrl: dealer.photoUrl,
                      borderColor: isSelected
                          ? const Color(0xFF00C853)
                          : Colors.grey.shade300,
                    ),
                    title: Text(
                      dealer.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.black87,
                      ),
                    ),
                    subtitle: Text(
                      'ID:${dealer.searchId}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(
                            Icons.check_circle,
                            color: Color(0xFF00C853),
                          )
                        : null,
                    onTap: () {
                      setState(() {
                        _selectedDealer = dealer;
                      });
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  // ==========================================
  // CONFIRMATION DIALOG
  // ==========================================
  void _proceedToConfirmation({
    required double usdAmount,
    required int beanAmount,
  }) {
    final accountText = _withdrawalBkash.isNotEmpty
        ? _withdrawalBkash
        : _currentUser.number;
    final accountName = _withdrawalName.isNotEmpty
        ? _withdrawalName
        : _currentUser.fullname;

    final formattedUsd = usdAmount % 1 == 0
        ? usdAmount.toInt().toString()
        : usdAmount.toStringAsFixed(2);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.white,
          elevation: 10,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with Title & Close Icon
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(width: 32),
                    const Expanded(
                      child: Text(
                        'Confirm your information.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(dialogCtx),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Field 1: Withdrawal methods
                Text(
                  'Withdrawal methods',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Withdraw',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),

                // Field 2: Select Diamond sellers
                Text(
                  'Select Diamond sellers',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    CachedCircleAvatar(
                      radius: 18,
                      iconSize: 20,
                      imageUrl: _selectedDealer.photoUrl,
                      borderColor: Colors.transparent,
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedDealer.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          'ID:${_selectedDealer.searchId}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Field 3: Withdrawal account (Bkash number + Name)
                Text(
                  'Withdrawal account',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  accountText.isNotEmpty ? accountText : 'Not set',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    letterSpacing: 0.5,
                  ),
                ),
                if (accountName.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Name: $accountName',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // Field 4: Withdrawal amount
                Text(
                  'Withdrawal amount',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '\$ $formattedUsd',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),

                // Field 5: Spend beans
                Text(
                  'Spend beans',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const DynamicBeanIcon(width: 20, height: 20),
                    const SizedBox(width: 6),
                    Text(
                      _formatNumber(beanAmount),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Confirm Button (Green)
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => _executeWithdrawal(
                      dialogCtx: dialogCtx,
                      usdAmount: usdAmount,
                      beanAmount: beanAmount,
                      accountNumber: accountText,
                      accountName: accountName,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00C853),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: const Text(
                      'Confirm',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Execute withdrawal logic
  Future<void> _executeWithdrawal({
    required BuildContext dialogCtx,
    required double usdAmount,
    required int beanAmount,
    required String accountNumber,
    required String accountName,
  }) async {
    // Check if account info is set
    if (accountNumber.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add your Bkash withdrawal information first.'),
          backgroundColor: Colors.orange,
        ),
      );
      _openEditWithdrawalInfoScreen();
      return;
    }

    // Check beans balance
    if (_currentUser.beans < beanAmount) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Insufficient bean balance for this withdrawal.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      // Close confirmation dialog
      Navigator.pop(dialogCtx);

      // Create bean withdrawal request in Firestore
      await _giftEconomyService.createBeanWithdrawalRequest(
        userId: _currentUser.userId,
        username: _currentUser.fullname,
        userSearchId: _currentUser.searchId,
        userType: _currentUser.userType,
        beanAmount: beanAmount,
        usdAmount: usdAmount,
        accountNumber: accountNumber,
        accountName: accountName,
        withdrawalName: accountName,
        withdrawalBkash: accountNumber,
        dealerId: _selectedDealer.id,
        dealerName: _selectedDealer.name,
        dealerSearchId: _selectedDealer.searchId,
      );

      // Show Screen 3 (Success Modal)
      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      debugPrint('Error executing withdrawal: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Withdrawal failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ==========================================
  // SCREEN 3: SUCCESS DIALOG (Screenshot 3)
  // ==========================================
  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (successCtx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.white,
          elevation: 10,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Close button top right
                Align(
                  alignment: Alignment.topRight,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(successCtx),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Large Green Check Circle Icon
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: Color(0xFF00C853),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 38,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Success text
                const Text(
                  'Withdrawn successfully',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 24),

                // Confirm button (Green)
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(successCtx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00C853),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: const Text(
                      'Confirm',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Withdrawal Help',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: const Text(
          '• Withdrawals are processed within 7 working days.\n'
          '• Only Beans balance can be withdrawn.\n'
          '• Ensure your selected coin dealer and withdrawal account are correct.\n'
          '• If you have any inquiries, please contact Official Support in the app.',
          style: TextStyle(fontSize: 14, color: Colors.black87, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'OK',
              style: TextStyle(
                color: Color(0xFF00C853),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPolicyDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Withdrawal Policy',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: const SingleChildScrollView(
          child: Text(
            '1. All bean withdrawal requests are reviewed by the platform and processed within 7 business days.\n\n'
            '2. Bean deductions are performed in real-time upon request submission.\n\n'
            '3. Any suspicious activity, fake account numbers, or violations of platform terms may result in request rejection and account review.\n\n'
            '4. Diamonds cannot be directly withdrawn. Only earned Beans are eligible for withdrawal.\n\n'
            '5. Contact customer service for assistance.',
            style: TextStyle(fontSize: 13, color: Colors.black87, height: 1.5),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Understood',
              style: TextStyle(
                color: Color(0xFF00C853),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showWithdrawalRecords() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserWithdrawalHistoryScreen(
          currentUser: _currentUser,
        ),
      ),
    );
  }

  // ==========================================
  // SCREEN 1: MAIN WITHDRAW SCREEN (Screenshot 1)
  // ==========================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFC),
      appBar: AppBar(
        systemOverlayStyle: getSystemOverlayStyle(false),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Withdraw',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.receipt_long_outlined,
              color: Color(0xFF5A6275),
              size: 22,
            ),
            tooltip: 'Records',
            onPressed: _showWithdrawalRecords,
          ),
          IconButton(
            icon: const Icon(
              Icons.settings_outlined,
              color: Color(0xFF5A6275),
              size: 22,
            ),
            tooltip: 'Settings',
            onPressed: _showPolicyDialog,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Balance Section (Showing Beans Balance)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Balance',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const DynamicBeanIcon(
                        width: 32,
                        height: 32,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _currentUser.beans.toString(),
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // History & Records Fullscreen Link
            GestureDetector(
              onTap: _showWithdrawalRecords,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8E44AD).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.receipt_long_rounded,
                        color: Color(0xFF8E44AD),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Withdrawal Records & Status',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            'View pending, paid & completed history',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.grey,
                      size: 14,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // "Withdraw to" Section
            Text(
              'Withdraw to',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _openWithdrawalMethodSheet,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Gold/Pink coin icon
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF8A65), Color(0xFFFFD54F)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withValues(alpha: 0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFC107),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: const Center(
                            child: Text(
                              '\$',
                              style: TextStyle(
                                color: Color(0xFFD81B60),
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Withdraw',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'You are expected to receive it in 7 working days.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: Colors.grey.shade400,
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // "Select Diamond sellers" Section (formerly Coin dealer)
            Text(
              'Select Diamond sellers',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            // Diamond seller selector box
            GestureDetector(
              onTap: _openDiamondSellerPicker,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _selectedDealer.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: Colors.grey.shade400,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Selected Dealer Info Card
            Row(
              children: [
                CachedCircleAvatar(
                  radius: 20,
                  iconSize: 22,
                  imageUrl: _selectedDealer.photoUrl,
                  borderColor: Colors.transparent,
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedDealer.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      'ID:${_selectedDealer.searchId}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Packages Grid (3 Columns) - Showing Beans
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.95,
              ),
              itemCount: _presetPackages.length,
              itemBuilder: (context, index) {
                final pkg = _presetPackages[index];
                return GestureDetector(
                  onTap: () => _onPackageSelected(pkg),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade100),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'USD',
                          style: TextStyle(
                            color: Color(0xFFE91E63),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          pkg.usdAmount.toString(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const DynamicBeanIcon(
                              width: 14,
                              height: 14,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              pkg.beanAmount.toString(),
                              style: const TextStyle(
                                color: Color(0xFF00B0FF),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 18),

            // "customize" Button (Light Green Rounded Border)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _openCustomizeSheet,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE8F8F0),
                  foregroundColor: const Color(0xFF1B5E20),
                  elevation: 0,
                  side: const BorderSide(
                    color: Color(0xFF81C784),
                    width: 1.2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: const Text(
                  'customize',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF2E7D32),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Footer Links
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _showHelpDialog,
                    child: const Text(
                      'Help',
                      style: TextStyle(
                        color: Color(0xFF0288D1),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: _showPolicyDialog,
                    child: const Text(
                      'Withdrawal Policy',
                      style: TextStyle(
                        color: Color(0xFF0288D1),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'For inquiries, please contact imChat Official Support.',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
}

// ==========================================
// SCREEN 3: EDIT WITHDRAWAL INFORMATION (Screenshot 3)
// ==========================================
class EditWithdrawalInfoScreen extends StatefulWidget {
  final String initialName;
  final String initialBkash;
  final String userId;
  final VoidCallback? onHelpTap;
  final VoidCallback? onPolicyTap;

  const EditWithdrawalInfoScreen({
    super.key,
    required this.initialName,
    required this.initialBkash,
    required this.userId,
    this.onHelpTap,
    this.onPolicyTap,
  });

  @override
  State<EditWithdrawalInfoScreen> createState() =>
      _EditWithdrawalInfoScreenState();
}

class _EditWithdrawalInfoScreenState extends State<EditWithdrawalInfoScreen> {
  late TextEditingController _nameController;
  late TextEditingController _bkashController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _bkashController = TextEditingController(text: widget.initialBkash);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bkashController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final bkash = _bkashController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your Name.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (bkash.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your Bkash number.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance
          .collection('Users')
          .doc(widget.userId)
          .update({
        'withdrawalName': name,
        'withdrawalBkash': bkash,
        'withdrawalNumber': bkash,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Withdrawal information saved successfully.'),
            backgroundColor: Color(0xFF00C853),
          ),
        );
        Navigator.pop(context, {'name': name, 'bkash': bkash});
      }
    } catch (e) {
      debugPrint('Error saving withdrawal info: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        systemOverlayStyle: getSystemOverlayStyle(false),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Withdraw',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        top: false,
        bottom: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name* Label
            RichText(
              text: const TextSpan(
                text: 'Name',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                children: [
                  TextSpan(
                    text: '*',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                hintText: 'Perfect',
                hintStyle: TextStyle(color: Colors.grey, fontSize: 15),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFEEEEEE), width: 1.2),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF00C853), width: 1.8),
                ),
              ),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 24),

            // Bkash number* Label
            RichText(
              text: const TextSpan(
                text: 'Bkash number',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                children: [
                  TextSpan(
                    text: '*',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _bkashController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                hintText: '01878507363',
                hintStyle: TextStyle(color: Colors.grey, fontSize: 15),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFEEEEEE), width: 1.2),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF00C853), width: 1.8),
                ),
              ),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 20),

            // Info Notice
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: const Text(
                'Please make sure all the information filled is correct. '
                'Your salary claiming might be affected if there is any mistake.',
                style: TextStyle(
                  color: Color(0xFF00B0FF),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C853),
                  disabledBackgroundColor:
                      const Color(0xFF00C853).withValues(alpha: 0.6),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Save',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 48),

            // Footer Links
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: widget.onHelpTap,
                    child: const Text(
                      'Help',
                      style: TextStyle(
                        color: Color(0xFF0288D1),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: widget.onPolicyTap,
                    child: const Text(
                      'Withdrawal Policy',
                      style: TextStyle(
                        color: Color(0xFF0288D1),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'For inquiries, please contact imChat Official Support.',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
}
