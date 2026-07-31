import 'package:chat_messenger/config/theme_config.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:chat_messenger/services/wallet_service.dart';
import 'package:flutter/material.dart';

class EarningsScreen extends StatefulWidget {
  final User currentUser;
  
  const EarningsScreen({
    super.key, 
    required this.currentUser,
  });

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> with TickerProviderStateMixin {
  final WalletService _walletService = WalletService();
  
  // State variables
  User? _currentUser;
  bool _isLoading = true;
  String _errorMessage = '';
  late TabController _tabController;
  
  // Earnings data
  List<EarningItem> _dailyEarnings = [];
  List<EarningItem> _weeklyEarnings = [];
  List<EarningItem> _monthlyEarnings = [];
  
  // Task data
  List<TaskItem> _availableTasks = [];
  List<TaskItem> _completedTasks = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUserData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Load user data and earnings
  Future<void> _loadUserData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      debugPrint('💰 Loading user earnings data...');
      
      // Get user data
      final userData = await _walletService.getUserWallet(widget.currentUser.userId);
      if (userData != null) {
        setState(() {
          _currentUser = userData;
        });
      } else {
        setState(() {
          _currentUser = widget.currentUser;
        });
      }
      
      // Load earnings and tasks
      await _loadEarningsData();
      await _loadTasksData();
      
      setState(() {
        _isLoading = false;
      });
      
      debugPrint('💰 User earnings data loaded successfully');
    } catch (e) {
      debugPrint('❌ Error loading user earnings data: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load earnings data: $e';
      });
    }
  }

  // Load earnings data
  Future<void> _loadEarningsData() async {
    try {
      // TODO: Implement actual earnings data loading from Firebase
      // For now, create sample data
      _createSampleEarningsData();
    } catch (e) {
      debugPrint('❌ Error loading earnings data: $e');
      _createSampleEarningsData();
    }
  }

  // Load tasks data
  Future<void> _loadTasksData() async {
    try {
      // TODO: Implement actual tasks data loading from Firebase
      // For now, create sample data
      _createSampleTasksData();
    } catch (e) {
      debugPrint('❌ Error loading tasks data: $e');
      _createSampleTasksData();
    }
  }

  // Create sample earnings data
  void _createSampleEarningsData() {
    _dailyEarnings = [
      EarningItem(
        id: '1',
        title: 'Daily Login',
        description: 'Login to the app',
        amount: 100,
        currency: 'diamonds',
        completedAt: DateTime.now().subtract(const Duration(hours: 2)),
        isCompleted: true,
      ),
      EarningItem(
        id: '2',
        title: 'Send 5 Messages',
        description: 'Send 5 messages to friends',
        amount: 50,
        currency: 'diamonds',
        completedAt: DateTime.now().subtract(const Duration(hours: 1)),
        isCompleted: true,
      ),
      EarningItem(
        id: '3',
        title: 'Join Voice Room',
        description: 'Join a voice room for 10 minutes',
        amount: 200,
        currency: 'diamonds',
        completedAt: null,
        isCompleted: false,
      ),
    ];
    
    _weeklyEarnings = [
      EarningItem(
        id: '4',
        title: 'Weekly Active User',
        description: 'Be active for 7 days',
        amount: 1000,
        currency: 'diamonds',
        completedAt: DateTime.now().subtract(const Duration(days: 1)),
        isCompleted: true,
      ),
      EarningItem(
        id: '5',
        title: 'Invite 3 Friends',
        description: 'Invite 3 friends to join',
        amount: 500,
        currency: 'diamonds',
        completedAt: null,
        isCompleted: false,
      ),
    ];
    
    _monthlyEarnings = [
      EarningItem(
        id: '6',
        title: 'Monthly VIP',
        description: 'Maintain VIP status for 30 days',
        amount: 5000,
        currency: 'diamonds',
        completedAt: DateTime.now().subtract(const Duration(days: 5)),
        isCompleted: true,
      ),
    ];
  }

  // Create sample tasks data
  void _createSampleTasksData() {
    _availableTasks = [
      TaskItem(
        id: '1',
        title: 'Daily Check-in',
        description: 'Check in daily to earn rewards',
        reward: 100,
        currency: 'diamonds',
        type: 'daily',
        isCompleted: false,
        progress: 0,
        maxProgress: 1,
      ),
      TaskItem(
        id: '2',
        title: 'Send Messages',
        description: 'Send 10 messages to earn diamonds',
        reward: 200,
        currency: 'diamonds',
        type: 'daily',
        isCompleted: false,
        progress: 7,
        maxProgress: 10,
      ),
      TaskItem(
        id: '3',
        title: 'Join Voice Rooms',
        description: 'Join voice rooms for 30 minutes',
        reward: 300,
        currency: 'diamonds',
        type: 'daily',
        isCompleted: false,
        progress: 15,
        maxProgress: 30,
      ),
    ];
    
    _completedTasks = [
      TaskItem(
        id: '4',
        title: 'First Message',
        description: 'Send your first message',
        reward: 50,
        currency: 'diamonds',
        type: 'one_time',
        isCompleted: true,
        progress: 1,
        maxProgress: 1,
        completedAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      TaskItem(
        id: '5',
        title: 'Profile Setup',
        description: 'Complete your profile',
        reward: 100,
        currency: 'diamonds',
        type: 'one_time',
        isCompleted: true,
        progress: 1,
        maxProgress: 1,
        completedAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ];
  }

  // Complete task
  Future<void> _completeTask(TaskItem task) async {
    try {
      debugPrint('✅ Completing task: ${task.title}');
      
      // TODO: Implement actual task completion logic
      // For now, just update local state
      setState(() {
        final completedTask = TaskItem(
          id: task.id,
          title: task.title,
          description: task.description,
          reward: task.reward,
          currency: task.currency,
          type: task.type,
          isCompleted: true,
          progress: task.maxProgress,
          maxProgress: task.maxProgress,
          completedAt: DateTime.now(),
        );
        
        _completedTasks.add(completedTask);
        _availableTasks.removeWhere((t) => t.id == task.id);
        
        // Add reward to user balance
        if (_currentUser != null) {
          if (task.currency == 'diamonds') {
            _currentUser!.diamonds += task.reward;
          } else if (task.currency == 'beans') {
            _currentUser!.beans += task.reward;
          }
        }
      });
      
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Task completed! Earned ${task.reward} ${task.currency}'),
            backgroundColor: Colors.green,
          ),
        );
    } catch (e) {
      debugPrint('❌ Error completing task: $e');
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Failed to complete task: $e'),
            backgroundColor: Colors.red,
          ),
        );
    }
  }

  // Refresh data
  Future<void> _refreshData() async {
    await _loadUserData();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white.withValues(alpha: 0.9),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        backgroundColor: Colors.white.withValues(alpha: 0.9),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _errorMessage,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _refreshData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white.withValues(alpha: 0.9),
      appBar: AppBar(
        title: const Text('Task Earnings'),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        titleTextStyle: const TextStyle(
          color: Colors.black, 
          fontSize: 18, 
          fontWeight: FontWeight.bold
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: primaryColor,
          tabs: const [
            Tab(text: 'Tasks'),
            Tab(text: 'Earnings'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildTasksTab(),
            _buildEarningsTab(),
            _buildHistoryTab(),
          ],
        ),
      ),
    );
  }

  // Tasks Tab
  Widget _buildTasksTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Available Tasks
          _buildSectionTitle('Available Tasks'),
          const SizedBox(height: 16),
          _buildTasksList(_availableTasks),
          const SizedBox(height: 24),
          
          // Completed Tasks
          _buildSectionTitle('Completed Tasks'),
          const SizedBox(height: 16),
          _buildTasksList(_completedTasks, isCompleted: true),
        ],
      ),
    );
  }

  // Earnings Tab
  Widget _buildEarningsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Daily Earnings
          _buildSectionTitle('Daily Earnings'),
          const SizedBox(height: 16),
          _buildEarningsList(_dailyEarnings),
          const SizedBox(height: 24),
          
          // Weekly Earnings
          _buildSectionTitle('Weekly Earnings'),
          const SizedBox(height: 16),
          _buildEarningsList(_weeklyEarnings),
          const SizedBox(height: 24),
          
          // Monthly Earnings
          _buildSectionTitle('Monthly Earnings'),
          const SizedBox(height: 16),
          _buildEarningsList(_monthlyEarnings),
        ],
      ),
    );
  }

  // History Tab
  Widget _buildHistoryTab() {
    final allEarnings = [..._dailyEarnings, ..._weeklyEarnings, ..._monthlyEarnings]
        .where((earning) => earning.isCompleted)
        .toList()
      ..sort((a, b) => b.completedAt!.compareTo(a.completedAt!));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Earnings History'),
          const SizedBox(height: 16),
          if (allEarnings.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text(
                  'No earnings history yet',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            _buildEarningsList(allEarnings),
        ],
      ),
    );
  }

  // Section Title
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  // Tasks List
  Widget _buildTasksList(List<TaskItem> tasks, {bool isCompleted = false}) {
    if (tasks.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            isCompleted ? 'No completed tasks yet' : 'No available tasks',
            style: const TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Column(
      children: tasks.map((task) => _buildTaskItem(task, isCompleted)).toList(),
    );
  }

  // Task Item
  Widget _buildTaskItem(TaskItem task, bool isCompleted) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCompleted ? Colors.green.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCompleted ? Colors.green.shade300 : Colors.grey.shade300,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      task.description,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: task.currency == 'diamonds' ? Colors.pink : Colors.orange,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      task.currency == 'diamonds' ? Icons.diamond : Icons.monetization_on,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${task.reward}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!isCompleted) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: task.progress / task.maxProgress,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${task.progress}/${task.maxProgress}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                if (task.progress >= task.maxProgress)
                  ElevatedButton(
                    onPressed: () => _completeTask(task),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      minimumSize: const Size(80, 32),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Claim',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // Earnings List
  Widget _buildEarningsList(List<EarningItem> earnings) {
    if (earnings.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text(
            'No earnings available',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Column(
      children: earnings.map((earning) => _buildEarningItem(earning)).toList(),
    );
  }

  // Earning Item
  Widget _buildEarningItem(EarningItem earning) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: earning.isCompleted ? Colors.green.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: earning.isCompleted ? Colors.green.shade300 : Colors.grey.shade300,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            earning.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
            color: earning.isCompleted ? Colors.green : Colors.grey,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  earning.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  earning.description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                if (earning.completedAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Completed: ${_formatDate(earning.completedAt!)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: earning.currency == 'diamonds' ? Colors.pink : Colors.orange,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  earning.currency == 'diamonds' ? Icons.diamond : Icons.monetization_on,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  '${earning.amount}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Format date
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }
}

// Earning Item model
class EarningItem {
  final String id;
  final String title;
  final String description;
  final int amount;
  final String currency;
  final DateTime? completedAt;
  final bool isCompleted;

  EarningItem({
    required this.id,
    required this.title,
    required this.description,
    required this.amount,
    required this.currency,
    this.completedAt,
    required this.isCompleted,
  });
}

// Task Item model
class TaskItem {
  final String id;
  final String title;
  final String description;
  final int reward;
  final String currency;
  final String type;
  final bool isCompleted;
  final int progress;
  final int maxProgress;
  DateTime? completedAt;

  TaskItem({
    required this.id,
    required this.title,
    required this.description,
    required this.reward,
    required this.currency,
    required this.type,
    required this.isCompleted,
    required this.progress,
    required this.maxProgress,
    this.completedAt,
  });
}
