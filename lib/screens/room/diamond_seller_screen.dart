import 'dart:async';
import 'package:chat_messenger/components/cached_circle_avatar.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:chat_messenger/api/official_team_api.dart';
import 'package:chat_messenger/services/svip_service.dart';
import 'package:chat_messenger/screens/room/seller_history_screen.dart';

class DiamondSellerScreen extends StatefulWidget {
  final User currentUser;
  const DiamondSellerScreen({super.key, required this.currentUser});

  @override
  State<DiamondSellerScreen> createState() => _DiamondSellerScreenState();
}

class _DiamondSellerScreenState extends State<DiamondSellerScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  bool _isLoadingSeller = true;
  bool _isSearching = false;
  bool _isSending = false;

  // Seller data
  Map<String, dynamic>? _sellerData;
  String? _sellerDocId;

  // Found user data
  User? _foundUser;
  String? _searchError;
  StreamSubscription<QuerySnapshot>? _sellerSubscription;

  @override
  void initState() {
    super.initState();
    _listenToSellerData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _amountController.dispose();
    _sellerSubscription?.cancel();
    super.dispose();
  }

  void _listenToSellerData() {
    setState(() => _isLoadingSeller = true);
    _sellerSubscription?.cancel();
    _sellerSubscription = _firestore
        .collection('sellers')
        .where('userId', isEqualTo: widget.currentUser.userId)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        if (snapshot.docs.isNotEmpty) {
          setState(() {
            _sellerDocId = snapshot.docs.first.id;
            _sellerData = snapshot.docs.first.data();
            _isLoadingSeller = false;
          });
        } else {
          setState(() {
            _sellerDocId = null;
            _sellerData = null;
            _isLoadingSeller = false;
          });
        }
      }
    }, onError: (e) {
      debugPrint('Error listening to seller data: $e');
      if (mounted) {
        setState(() => _isLoadingSeller = false);
      }
    });
  }

  Future<void> _searchUser() async {
    final searchId = _searchController.text.trim();
    if (searchId.isEmpty) return;

    setState(() {
      _isSearching = true;
      _foundUser = null;
      _searchError = null;
    });

    try {
      final snapshot = await _firestore
          .collection('Users')
          .where('searchId', isEqualTo: searchId)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        setState(() {
          _foundUser = User.fromMap(snapshot.docs.first.data());
        });
      } else {
        setState(() => _searchError = 'No user found with ID: $searchId');
      }
    } catch (e) {
      setState(() => _searchError = 'Search failed: $e');
    } finally {
      setState(() => _isSearching = false);
    }
  }

  Future<void> _sendDiamonds() async {
    if (_foundUser == null || _sellerDocId == null) return;

    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      _showSnackBar('Please enter an amount', Colors.orange);
      return;
    }

    final amount = int.tryParse(amountText);
    if (amount == null || amount <= 0) {
      _showSnackBar('Please enter a valid amount', Colors.orange);
      return;
    }

    final sellerBalance = _sellerData?['accountBalance'] ?? 0;
    if (sellerBalance < amount) {
      _showSnackBar('Insufficient account balance', Colors.red);
      return;
    }

    // Confirm dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Recharge'),
        content: Text(
          'Send $amount diamonds to ${_foundUser!.fullname} (ID: ${_foundUser!.searchId})?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.pink),
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSending = true);

    try {
      final sellerRef = _firestore.collection('sellers').doc(_sellerDocId);
      final userRef =
          _firestore.collection('Users').doc(_foundUser!.userId);
      final txnRef = _firestore.collection('seller_transactions').doc();

      // Fetch SVIP levels outside transaction
      final svipLevelsSnap = await _firestore.collection('config').doc('svip_levels').collection('levels').get();
      final svipLevels = svipLevelsSnap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();

      await _firestore.runTransaction((transaction) async {
        // Re-read seller to verify balance
        final sellerSnap = await transaction.get(sellerRef);
        final currentBalance = sellerSnap.data()?['accountBalance'] ?? 0;

        if (currentBalance < amount) {
          throw Exception('Insufficient account balance');
        }

        // Re-read user to check monthly reset
        final userSnap = await transaction.get(userRef);
        final userData = userSnap.data() ?? {};
        final lastMonth = userData['lastRechargeMonth'] as String? ?? '';
        final now = DateTime.now();
        final currentMonth = "${now.year}-${now.month.toString().padLeft(2, '0')}";
        
        // int currentRecharge = (userData['monthlyRechargeAmount'] as num?)?.toInt() ?? 0;

        if (currentBalance < amount) {
          throw Exception('Insufficient account balance');
        }

        // Deduct seller balance
        transaction.update(sellerRef, {
          'accountBalance': FieldValue.increment(-amount),
          'totalSales': FieldValue.increment(amount),
          'totalUsersRecharged': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Increment user diamonds & monthly recharge tracking atomically
        int previousMonthlyRecharge = (userData['monthlyRechargeAmount'] as num?)?.toInt() ?? 0;
        int newMonthlyRecharge = amount;

        if (lastMonth != currentMonth) {
          transaction.update(userRef, {
            'diamonds': FieldValue.increment(amount),
            'totalDiamonds': FieldValue.increment(amount),
            'monthlyRechargeAmount': amount,
            'lastRechargeMonth': currentMonth,
          });
        } else {
          newMonthlyRecharge = previousMonthlyRecharge + amount;
          transaction.update(userRef, {
            'diamonds': FieldValue.increment(amount),
            'totalDiamonds': FieldValue.increment(amount),
            'monthlyRechargeAmount': FieldValue.increment(amount),
            'lastRechargeMonth': currentMonth,
          });
        }

        // Auto upgrade SVIP
        await SvipService.checkAndAutoUpgradeSvip(
          userId: _foundUser!.userId,
          newRechargeAmount: newMonthlyRecharge,
          currentMonth: currentMonth,
          transaction: transaction,
          userRef: userRef,
          userData: userData,
          svipLevels: svipLevels,
        );

        // Record transaction
        transaction.set(txnRef, {
          'sellerId': widget.currentUser.userId,
          'userId': _foundUser!.userId,
          'amount': amount,
          'type': 'recharge',
          'description':
              'Seller recharge: $amount diamonds to ${_foundUser!.fullname}',
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

      // Update local seller balance
      setState(() {
        _sellerData?['accountBalance'] =
            (_sellerData?['accountBalance'] ?? 0) - amount;
        _sellerData?['totalSales'] =
            (_sellerData?['totalSales'] ?? 0) + amount;
      });
      
      // Send official system notification
      OfficialTeamApi.sendDiamondSellerRechargeMessage(_foundUser!, widget.currentUser, amount);

      _showSnackBar(
          'Successfully sent $amount diamonds to ${_foundUser!.fullname}!',
          Colors.green);

      // Clear form
      _amountController.clear();
      setState(() {
        _foundUser = null;
        _searchController.clear();
      });
    } catch (e) {
      _showSnackBar('Failed: $e', Colors.red);
    } finally {
      setState(() => _isSending = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), backgroundColor: color),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diamond Seller'),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        titleTextStyle: const TextStyle(
          color: Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        actions: [
          if (_sellerData != null && _sellerData!['isActive'] == true)
            IconButton(
              icon: const Icon(Icons.history),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SellerHistoryScreen(currentUser: widget.currentUser),
                  ),
                );
              },
            ),
        ],
      ),
      backgroundColor: Colors.grey.shade100,
      body: _isLoadingSeller
          ? const Center(child: CircularProgressIndicator())
          : _sellerData == null || _sellerData!['isActive'] != true
              ? _buildNotSellerView()
              : _buildSellerView(),
    );
  }

  Widget _buildNotSellerView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.store_outlined, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'You are not a registered seller',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Contact admin to register as a diamond seller.',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSellerView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSellerInfoCard(),
          const SizedBox(height: 16),
          _buildSearchSection(),
          if (_foundUser != null) ...[
            const SizedBox(height: 16),
            _buildFoundUserCard(),
            const SizedBox(height: 16),
            _buildAmountSection(),
          ],
          if (_searchError != null) ...[
            const SizedBox(height: 12),
            Text(
              _searchError!,
              style: const TextStyle(color: Colors.red, fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSellerInfoCard() {
    final balance = _sellerData?['accountBalance'] ?? 0;
    final sellerName = _sellerData?['sellerName'] ?? 'Seller';
    final totalSales = _sellerData?['totalSales'] ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFC381F4), Color(0xFF8E44AD)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sellerName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Account Balance',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    balance.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Total Sales',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    totalSales.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Search User',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Enter user Search ID',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                  keyboardType: TextInputType.text,
                  onSubmitted: (_) => _searchUser(),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _isSearching ? null : _searchUser,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pink,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: _isSearching
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Search',
                        style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFoundUserCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          CachedCircleAvatar(
            radius: 25,
            iconSize: 30,
            imageUrl: _foundUser!.photoUrl,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _foundUser!.fullname,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'ID: ${_foundUser!.searchId}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.check_circle, color: Colors.green),
        ],
      ),
    );
  }

  Widget _buildAmountSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recharge Amount',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            decoration: InputDecoration(
              hintText: 'Enter diamond amount',
              prefixIcon: const Icon(Icons.diamond, color: Colors.pink),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isSending ? null : _sendDiamonds,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pink,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: _isSending
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Send Diamonds',
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
