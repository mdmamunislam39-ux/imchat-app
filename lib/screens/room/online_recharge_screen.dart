import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:chat_messenger/models/recharge_models.dart';
import 'package:chat_messenger/services/online_recharge_service.dart';
import 'package:chat_messenger/screens/room/recharge_success_screen.dart';
import 'package:chat_messenger/screens/room/user_recharge_history_screen.dart';
import 'package:chat_messenger/components/dynamic_diamond_icon.dart';

/// Screen matching the provided screenshot for Online Recharge
class OnlineRechargeScreen extends StatefulWidget {
  final User currentUser;
  final num? initialAmount;
  final int? initialDiamonds;
  final int? initialBonusDiamonds;

  const OnlineRechargeScreen({
    super.key,
    required this.currentUser,
    this.initialAmount,
    this.initialDiamonds,
    this.initialBonusDiamonds,
  });

  @override
  State<OnlineRechargeScreen> createState() => _OnlineRechargeScreenState();
}

class _OnlineRechargeScreenState extends State<OnlineRechargeScreen> {
  final OnlineRechargeService _rechargeService = OnlineRechargeService.instance;
  final TextEditingController _trxController = TextEditingController();

  late String _orderId;
  late num _selectedAmount;
  late int _selectedDiamonds;
  late int _selectedBonusDiamonds;
  PaymentMethodModel? _selectedPaymentMethod;
  bool _isBengali = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _orderId = _rechargeService.generateOrderId();
    _selectedAmount = widget.initialAmount ?? 300;
    _selectedDiamonds = widget.initialDiamonds ?? 3000;
    _selectedBonusDiamonds = widget.initialBonusDiamonds ?? 0;
    _rechargeService.seedInitialPackagesIfEmpty();
  }

  @override
  void dispose() {
    _trxController.dispose();
    super.dispose();
  }

  void _copyToClipboard(String text) {
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(_isBengali ? 'নাম্বার কপি করা হয়েছে: $text' : 'Number copied: $text'),
          ],
        ),
        backgroundColor: const Color(0xFF0C6B44),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _submitRecharge() async {
    final trxId = _trxController.text.trim();
    if (trxId.isEmpty) {
      _showErrorSnackBar(
        _isBengali ? 'অনুগ্রহ করে TrxID নাম্বারটি লিখুন।' : 'Please enter the Transaction ID.',
      );
      return;
    }

    if (_selectedPaymentMethod == null) {
      _showErrorSnackBar(
        _isBengali ? 'অনুগ্রহ করে একটি পেমেন্ট চ্যানেল নির্বাচন করুন।' : 'Please select a payment method.',
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final order = await _rechargeService.submitRechargeOrder(
        userId: widget.currentUser.userId,
        userName: widget.currentUser.fullname,
        userPhoto: widget.currentUser.photoUrl,
        searchId: widget.currentUser.searchId,
        userPhone: widget.currentUser.number,
        amount: _selectedAmount,
        diamondAmount: _selectedDiamonds,
        bonusDiamonds: _selectedBonusDiamonds,
        paymentMethod: _selectedPaymentMethod!.name,
        paymentNumber: _selectedPaymentMethod!.number,
        transactionId: trxId,
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => RechargeSuccessScreen(order: order),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      String msg = e.toString().replaceFirst('Exception: ', '');
      if (msg.contains('already been used')) {
        msg = _isBengali
            ? 'এই ট্রানজেকশন আইডিটি (TrxID) ইতিমধ্যে ব্যবহৃত হয়েছে।'
            : 'This transaction ID has already been used.';
      }
      _showErrorSnackBar(msg);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showDetailedInstructionsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isBengali ? 'পেমেন্ট নির্দেশিকা' : 'Payment Instructions',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 12),
              _buildInstructionStep(
                '1',
                _isBengali ? 'নাম্বার কপি করুন' : 'Copy Number',
                _isBengali
                    ? 'প্রদর্শিত ওয়ালেট নম্বরটি কপি বাটনে চাপ দিয়ে কপি করুন।'
                    : 'Click copy button to copy the displayed wallet number.',
              ),
              const SizedBox(height: 12),
              _buildInstructionStep(
                '2',
                _isBengali ? 'সেন্ড মানি করুন' : 'Make Send Money',
                _isBengali
                    ? 'আপনার bKash/Nagad অ্যাপে গিয়ে হুবহু সঠিক অর্ডার অ্যামাউন্টটি সেন্ড মানি করুন।'
                    : 'Open your payment app and Send Money the exact order amount.',
              ),
              const SizedBox(height: 12),
              _buildInstructionStep(
                '3',
                _isBengali ? 'TrxID সাবমিট করুন' : 'Submit TrxID',
                _isBengali
                    ? 'পেমেন্ট সফল হলে এসএমএস বা অ্যাপ থেকে পাওয়া TrxID এই স্ক্রিনে বসিয়ে "জমা দিন" বাটনে চাপুন।'
                    : 'Copy TrxID from SMS/app and submit it on this screen.',
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInstructionStep(String step, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            color: Color(0xFF0C6B44),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              step,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.3),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    const headerGreen = Color(0xFF0C6B44);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: headerGreen,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Wallet',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: _isBengali ? 'হিস্ট্রি' : 'History',
            icon: const Icon(Icons.receipt_long_rounded, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UserRechargeHistoryScreen(userId: widget.currentUser.userId),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Top Green Banner (Exact design from screenshot)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 8, bottom: 28, left: 20, right: 20),
              decoration: const BoxDecoration(
                color: headerGreen,
              ),
              child: Column(
                children: [
                  Text(
                    _isBengali ? 'অর্ডার আইডি: $_orderId' : 'Order ID: $_orderId',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '৳ ${_selectedAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 38,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(35),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const DynamicDiamondIcon(width: 18, height: 18),
                        const SizedBox(width: 6),
                        Text(
                          _selectedBonusDiamonds > 0
                              ? '+${_selectedDiamonds.toString()} Diamonds (+$_selectedBonusDiamonds Bonus)'
                              : '+${_selectedDiamonds.toString()} Diamonds',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // White Card Section (Screenshot style)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(15),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Payment Channel Header + Language Toggle
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _isBengali ? 'পেমেন্ট চ্যানেল' : 'Payment Channel',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() => _isBengali = !_isBengali);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  'বাং',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: _isBengali ? FontWeight.bold : FontWeight.normal,
                                    color: _isBengali ? const Color(0xFF0C6B44) : Colors.grey.shade600,
                                  ),
                                ),
                                Text(
                                  ' | ',
                                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                                ),
                                Text(
                                  'EN',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: !_isBengali ? FontWeight.bold : FontWeight.normal,
                                    color: !_isBengali ? const Color(0xFF0C6B44) : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Payment Method Dynamic Realtime Listener & Steps
                    StreamBuilder<List<PaymentMethodModel>>(
                      stream: _rechargeService.getActivePaymentMethodsStream(),
                      builder: (context, snapshot) {
                        final methods = snapshot.data ?? OnlineRechargeService.defaultPaymentMethods;

                        // Real-time synchronization with selected method
                        PaymentMethodModel? currentMethod;
                        if (_selectedPaymentMethod != null) {
                          currentMethod = methods.cast<PaymentMethodModel?>().firstWhere(
                            (m) => m?.id == _selectedPaymentMethod!.id,
                            orElse: () => null,
                          );
                        }
                        currentMethod ??= methods.isNotEmpty ? methods.first : null;
                        _selectedPaymentMethod = currentMethod;

                        final currentNumber = currentMethod?.number.isNotEmpty == true
                            ? currentMethod!.number
                            : '01609738735';
                        final currentInstructions = currentMethod?.instructions.isNotEmpty == true
                            ? currentMethod!.instructions
                            : (_isBengali ? "'সেন্ড মানি' দিয়ে পরিশোধ করুন" : "Pay with 'Send Money'");
                        final currentMethodName = currentMethod?.name ?? 'পেমেন্ট';

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Payment Method List
                            Column(
                              children: methods.map((method) {
                                final isSelected = currentMethod?.id == method.id;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () {
                                      setState(() {
                                        _selectedPaymentMethod = method;
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSelected ? headerGreen : Colors.grey.shade300,
                                          width: isSelected ? 1.8 : 1,
                                        ),
                                        color: isSelected ? headerGreen.withAlpha(8) : Colors.transparent,
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 20,
                                            height: 20,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: isSelected ? headerGreen : Colors.grey.shade400,
                                                width: 2,
                                              ),
                                            ),
                                            child: isSelected
                                                ? Center(
                                                    child: Container(
                                                      width: 10,
                                                      height: 10,
                                                      decoration: const BoxDecoration(
                                                        color: headerGreen,
                                                        shape: BoxShape.circle,
                                                      ),
                                                    ),
                                                  )
                                                : null,
                                          ),
                                          const SizedBox(width: 14),
                                          _buildPaymentLogo(method),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              method.name,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF1F2937),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 18),

                            // Steps Header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _isBengali ? 'শুধু ২টি ধাপে, পেমেন্ট সম্পন্ন করুন।' : 'Complete payment in just 2 steps.',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1F2937),
                                  ),
                                ),
                                InkWell(
                                  onTap: _showDetailedInstructionsModal,
                                  child: Row(
                                    children: [
                                      Text(
                                        _isBengali ? 'বিস্তারিত ব্যাখ্যা' : 'Details',
                                        style: const TextStyle(
                                          color: Color(0xFFE65100),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFFE65100), size: 10),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Step 1: Wallet Number & Copy (Updates in real time when Admin edits)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade200),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.shade100,
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(color: headerGreen, width: 1.5),
                                        ),
                                        child: const Center(
                                          child: Text(
                                            '1',
                                            style: TextStyle(
                                              color: headerGreen,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _isBengali
                                              ? 'এই $currentMethodName নাম্বার শুধুমাত্র সেন্ড মানি গ্রহণ করা হয়'
                                              : 'Only Send Money is accepted on this $currentMethodName number',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey.shade800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF9FAFB),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.grey.shade300),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.credit_card_rounded, color: Colors.grey, size: 26),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Wallet No*',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade500,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                currentNumber,
                                                style: const TextStyle(
                                                  fontSize: 17,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 0.5,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        ElevatedButton(
                                          onPressed: () => _copyToClipboard(currentNumber),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: headerGreen,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                            minimumSize: Size.zero,
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                          ),
                                          child: Text(
                                            _isBengali ? 'কপি' : 'Copy',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 10),

                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF1F0),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.touch_app_rounded, color: Color(0xFFE53935), size: 18),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            currentInstructions,
                                            style: const TextStyle(
                                              color: Color(0xFFE53935),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Step 2: TrxID input & Submit Button
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade200),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.shade100,
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(color: headerGreen, width: 1.5),
                                        ),
                                        child: const Center(
                                          child: Text(
                                            '2',
                                            style: TextStyle(
                                              color: headerGreen,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _isBengali
                                              ? 'সেন্ড মানির TrxID নাম্বার লিখুন (প্রয়োজন)'
                                              : 'Enter Send Money TrxID number (Required)',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey.shade800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  TextField(
                                    controller: _trxController,
                                    textCapitalization: TextCapitalization.characters,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1.0,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: _isBengali
                                          ? 'TrxID অবশ্যই প্রদান করতে হবে!'
                                          : 'Enter Transaction ID (TrxID)!',
                                      hintStyle: TextStyle(
                                        color: Colors.grey.shade400,
                                        fontSize: 13,
                                        letterSpacing: 0.2,
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      filled: true,
                                      fillColor: Colors.grey.shade50,
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: const BorderSide(color: headerGreen, width: 1.5),
                                      ),
                                    ),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                  const SizedBox(height: 16),

                                  SizedBox(
                                    width: double.infinity,
                                    height: 48,
                                    child: ElevatedButton(
                                      onPressed: _isSubmitting ? null : _submitRecharge,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _trxController.text.trim().isNotEmpty
                                            ? headerGreen
                                            : const Color(0xFFD8D8D8),
                                        foregroundColor: _trxController.text.trim().isNotEmpty
                                            ? Colors.white
                                            : Colors.white70,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                      child: _isSubmitting
                                          ? const SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                color: Colors.white,
                                              ),
                                            )
                                          : Text(
                                              _isBengali ? 'জমা দিন' : 'Submit Recharge',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            _buildDisclaimerText(
                              _isBengali
                                  ? '• পৃষ্ঠায় প্রদর্শিত ওয়ালেট নম্বরটি শুধুমাত্র এই অর্ডারের জন্য বৈধ। বারবার পেমেন্টের জন্য এটি সংরক্ষণ করবেন না।'
                                  : '• The wallet number shown is valid for this order only. Do not save it for recurring payments.',
                            ),
                            const SizedBox(height: 6),
                            _buildDisclaimerText(
                              _isBengali
                                  ? '• বিকাশ বা নগদ আইকনে ক্লিক করুন অ্যাকাউন্টটি পেতে। অনুগ্রহ করে সঠিক অর্ডার অ্যামাউন্টটি নির্বাচিত অ্যাকাউন্টে পরিশোধ করুন।'
                                  : '• Tap payment channel to get number. Please send the exact order amount.',
                            ),
                            const SizedBox(height: 6),
                            _buildDisclaimerText(
                              _isBengali
                                  ? '• একই অ্যাকাউন্টের সাথে একাধিক ওয়ালেট রেজিস্টার থাকতে পারে, অনুগ্রহ করে অন্য কোনো ওয়ালেটে টাকা ট্রান্সফার করবেন না।'
                                  : '• Multiple wallets may exist. Please do not transfer money to any other wallet.',
                            ),
                          ],
                        );
                      },
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisclaimerText(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11.5,
        color: Colors.grey.shade600,
        height: 1.4,
      ),
    );
  }

  Widget _buildPaymentLogo(PaymentMethodModel method, {double size = 32}) {
    final icon = method.iconUrl.trim();
    if (icon.isNotEmpty) {
      // 1. Base64 Data URI (e.g. data:image/png;base64,... or data:image/jpeg;base64,...)
      if (icon.startsWith('data:image/') || icon.startsWith('data:') || icon.contains(';base64,')) {
        try {
          final commaIndex = icon.indexOf(',');
          final rawBase64 = commaIndex != -1 ? icon.substring(commaIndex + 1) : icon;
          final cleanBase64 = rawBase64.replaceAll(RegExp(r'\s+'), '');
          final bytes = base64Decode(cleanBase64);
          return ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: size,
              height: size,
              child: Image.memory(
                bytes,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => _buildBrandedFallbackIcon(method.name, size: size),
              ),
            ),
          );
        } catch (e) {
          debugPrint('Error decoding base64 payment icon: $e');
        }
      }

      // 2. HTTP / HTTPS Network image (e.g. Firebase Storage or web image)
      if (icon.startsWith('http://') || icon.startsWith('https://')) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            width: size,
            height: size,
            child: CachedNetworkImage(
              imageUrl: icon,
              fit: BoxFit.contain,
              placeholder: (_, __) => Container(
                width: size,
                height: size,
                color: Colors.grey.withAlpha(20),
              ),
              errorWidget: (_, __, ___) => _buildBrandedFallbackIcon(method.name, size: size),
            ),
          ),
        );
      }

      // 3. Raw Base64 string without data: header
      if (icon.length > 50 && (!icon.contains('/') || icon.startsWith('/9j/') || icon.startsWith('iVBORw'))) {
        try {
          final cleanBase64 = icon.replaceAll(RegExp(r'\s+'), '');
          final bytes = base64Decode(cleanBase64);
          return ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: size,
              height: size,
              child: Image.memory(
                bytes,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => _buildBrandedFallbackIcon(method.name, size: size),
              ),
            ),
          );
        } catch (_) {}
      }

      // 4. Asset image fallback (e.g. assets/icons/...)
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: size,
          height: size,
          child: Image.asset(
            icon,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _buildBrandedFallbackIcon(method.name, size: size),
          ),
        ),
      );
    }
    return _buildBrandedFallbackIcon(method.name, size: size);
  }

  Widget _buildBrandedFallbackIcon(String name, {double size = 32}) {
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
      bg = const Color(0xFF0C6B44);
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Text(
          symbol,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: size * 0.5,
          ),
        ),
      ),
    );
  }
}
