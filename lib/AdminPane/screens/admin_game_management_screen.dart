import 'package:flutter/material.dart';
import '../models/game_model.dart';
import '../services/game_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AdminGameManagementScreen extends StatefulWidget {
  const AdminGameManagementScreen({super.key});

  @override
  State<AdminGameManagementScreen> createState() =>
      _AdminGameManagementScreenState();
}

class _AdminGameManagementScreenState extends State<AdminGameManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _thumbnailUrlController = TextEditingController();
  final _gameUrlController = TextEditingController();
  final _winRatioController = TextEditingController();

  bool _isEditing = false;
  String? _editingGameId;

  @override
  void dispose() {
    _nameController.dispose();
    _thumbnailUrlController.dispose();
    _gameUrlController.dispose();
    _winRatioController.dispose();
    super.dispose();
  }

  void _resetForm() {
    setState(() {
      _isEditing = false;
      _editingGameId = null;
      _nameController.clear();
      _thumbnailUrlController.clear();
      _gameUrlController.clear();
      _winRatioController.text = '0.5';
    });
  }

  void _editGame(GameModel game) {
    setState(() {
      _isEditing = true;
      _editingGameId = game.id;
      _nameController.text = game.name;
      _thumbnailUrlController.text = game.thumbnailUrl;
      _gameUrlController.text = game.gameUrl;
      _winRatioController.text = game.winRatio.toString();
    });
    _showGameFormDialog(context);
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final double winRatio = double.tryParse(_winRatioController.text) ?? 0.5;

      final game = GameModel(
        id: _editingGameId ?? '',
        name: _nameController.text,
        thumbnailUrl: _thumbnailUrlController.text,
        gameUrl: _gameUrlController.text,
        winRatio: winRatio,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (_isEditing) {
        await GameService.updateGame(game);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Game updated successfully')));
        }
      } else {
        await GameService.createGame(game);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Game created successfully')));
        }
      }

      if (mounted) {
        Navigator.pop(context);
        _resetForm();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  void _showGameFormDialog(BuildContext context) {
    if (!_isEditing && _winRatioController.text.isEmpty) {
      _winRatioController.text = '0.5';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF22223B),
        title: Text(
          _isEditing ? 'Edit Game' : 'Add New Game',
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Game Name',
                    labelStyle: TextStyle(color: Colors.grey),
                    enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey)),
                  ),
                  validator: (value) =>
                      value!.isEmpty ? 'Please enter a name' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _thumbnailUrlController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Thumbnail URL',
                    labelStyle: TextStyle(color: Colors.grey),
                    enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey)),
                  ),
                  validator: (value) =>
                      value!.isEmpty ? 'Please enter thumbnail URL' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _gameUrlController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Game URL / WebView Link',
                    labelStyle: TextStyle(color: Colors.grey),
                    enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey)),
                  ),
                  validator: (value) =>
                      value!.isEmpty ? 'Please enter game URL' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _winRatioController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Win Ratio (0.0 to 1.0)',
                    labelStyle: TextStyle(color: Colors.grey),
                    enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey)),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty)
                      return 'Please enter win ratio';
                    final num = double.tryParse(value);
                    if (num == null || num < 0 || num > 1) {
                      return 'Must be between 0.0 and 1.0';
                    }
                    return null;
                  },
                ),
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
          ElevatedButton(
            onPressed: _submitForm,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: Text(_isEditing ? 'Update' : 'Create'),
          ),
        ],
      ),
    ).then((_) {
      if (!_isEditing) _resetForm();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Game Management',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _resetForm();
          _showGameFormDialog(context);
        },
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Text('Webview Games List',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: StreamBuilder<List<GameModel>>(
              stream: GameService.getGamesStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                      child: Text('Error: ${snapshot.error}',
                          style: const TextStyle(color: Colors.red)));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: Colors.blue));
                }

                final games = snapshot.data ?? [];

                if (games.isEmpty) {
                  return const Center(
                    child: Text('No games found. Add one!',
                        style: TextStyle(color: Colors.grey)),
                  );
                }

                return ListView.builder(
                  itemCount: games.length,
                  itemBuilder: (context, index) {
                    final game = games[index];
                    return Card(
                      color: const Color(0xFF22223B),
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: game.thumbnailUrl,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                                color: Colors.grey[800],
                                child: const Icon(Icons.gamepad,
                                    color: Colors.white24)),
                            errorWidget: (context, url, error) => Container(
                                color: Colors.grey[800],
                                child: const Icon(Icons.gamepad,
                                    color: Colors.white24)),
                          ),
                        ),
                        title: Text(
                          game.name,
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text('URL: ${game.gameUrl}',
                                style: TextStyle(color: Colors.blue[300]),
                                overflow: TextOverflow.ellipsis),
                            Text('Win Ratio: ${game.winRatio}',
                                style: const TextStyle(color: Colors.grey)),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(
                              value: game.isActive,
                              onChanged: (value) {
                                GameService.toggleGameStatus(game.id, value);
                              },
                              activeThumbColor: Colors.blue,
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _editGame(game),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    backgroundColor: const Color(0xFF22223B),
                                    title: const Text('Delete Game',
                                        style: TextStyle(color: Colors.white)),
                                    content: const Text(
                                        'Are you sure you want to delete this game?',
                                        style: TextStyle(color: Colors.grey)),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Cancel'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () {
                                          GameService.deleteGame(game.id);
                                          Navigator.pop(context);
                                        },
                                        style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
