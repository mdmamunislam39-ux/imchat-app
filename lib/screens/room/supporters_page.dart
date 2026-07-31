import 'package:flutter/material.dart';


class SupportersPage extends StatelessWidget {
  final String userID;
  final String userName;
  final List<Map<String, dynamic>> supporters;

  const SupportersPage({
    super.key,
    required this.userID,
    required this.userName,
    required this.supporters,
  });

  String _formatDiamondCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  Widget _buildTopSupporter(Map<String, dynamic>? supporter, int rank) {
    if (supporter == null) return const SizedBox(width: 80);

    final String url = supporter['photoUrl'] ?? '';
    final String name = supporter['name'] ?? 'User';
    final String id = supporter['searchId']?.toString().isNotEmpty == true ? supporter['searchId'] : (supporter['id'] ?? '');
    final int value = supporter['totalValue'] ?? 0;

    double avatarRadius = rank == 1 ? 40 : 32;
    Color crownColor = rank == 1 ? Colors.amber : (rank == 2 ? Colors.grey.shade300 : Colors.orange.shade300);
    IconData crownIcon = Icons.military_tech; 
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: crownColor, width: 2),
              ),
              child: CircleAvatar(
                radius: avatarRadius,
                backgroundImage: NetworkImage(url),
              ),
            ),
            Positioned(
              top: -10,
              right: -10,
              child: Icon(crownIcon, color: crownColor, size: 30),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 80,
          child: Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          'ID:$id',
          style: const TextStyle(color: Colors.grey, fontSize: 11),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.diamond_outlined, color: Colors.orange, size: 14),
            const SizedBox(width: 2),
            Text(
              _formatDiamondCount(value),
              style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic>? first, second, third;
    if (supporters.isNotEmpty) first = supporters[0];
    if (supporters.length > 1) second = supporters[1];
    if (supporters.length > 2) third = supporters[2];

    return Scaffold(
      appBar: AppBar(
        title: Text('Supporter (${supporters.length})'),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF38E09D), Color(0xFF26BFA6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {},
          )
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: _buildTopSupporter(second, 2)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: _buildTopSupporter(first, 1),
                ),
              ),
              Expanded(child: _buildTopSupporter(third, 3)),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(thickness: 1, color: Colors.black12),
          Expanded(
            child: ListView.builder(
              itemCount: supporters.length > 3 ? supporters.length - 3 : 0,
              itemBuilder: (context, index) {
                final supporter = supporters[index + 3];
                final String url = supporter['photoUrl'] ?? '';
                final String name = supporter['name'] ?? 'User';
                final String id = supporter['searchId']?.toString().isNotEmpty == true ? supporter['searchId'] : (supporter['id'] ?? '');
                final int value = supporter['totalValue'] ?? 0;
                final int rank = index + 4;

                return ListTile(
                  leading: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 30,
                        child: Text(
                          '$rank',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        radius: 22,
                        backgroundImage: NetworkImage(url),
                      ),
                    ],
                  ),
                  title: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text('ID:$id', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.diamond_outlined, color: Colors.orange, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        _formatDiamondCount(value),
                        style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
