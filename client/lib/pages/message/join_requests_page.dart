import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:threads/state/message.state.dart';

class JoinRequestsPage extends StatefulWidget {
  final int groupId;

  const JoinRequestsPage({
    super.key,
    required this.groupId,
  });

  @override
  State<JoinRequestsPage> createState() => _JoinRequestsPageState();
}

class _JoinRequestsPageState extends State<JoinRequestsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = Provider.of<MessageState>(context, listen: false);
      state.loadJoinRequests(widget.groupId);
    });
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.black,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: const Text(
        'Join Requests',
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildUserAvatar(String? avatarUrl, String fallbackInitial) {
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 22,
        backgroundImage: CachedNetworkImageProvider(avatarUrl),
      );
    }
    return CircleAvatar(
      radius: 22,
      backgroundColor: Colors.grey[800],
      child: Text(
        fallbackInitial.isNotEmpty ? fallbackInitial[0].toUpperCase() : '?',
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
    );
  }

  String _formatDate(String? dateTime) {
    if (dateTime == null || dateTime.isEmpty) return '';
    try {
      final dt = DateTime.parse(dateTime);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateTime;
    }
  }

  Widget _buildRequestItem(Map<String, dynamic> request) {
    final requestId = request['id'] as int? ?? 0;
    final username = request['username'] as String? ?? '';
    final displayName = request['display_name'] as String? ??
        request['displayName'] as String? ??
        username;
    final avatarUrl = request['avatar_url'] as String? ??
        request['avatarUrl'] as String?;
    final createTime = request['create_time'] as String? ??
        request['createTime'] as String?;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildUserAvatar(avatarUrl, displayName),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (username.isNotEmpty)
                  Text(
                    '@$username',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 13,
                    ),
                  ),
                if (createTime != null && createTime.isNotEmpty)
                  Text(
                    'Requested ${_formatDate(createTime)}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Approve button
          GestureDetector(
            onTap: () {
              final state =
                  Provider.of<MessageState>(context, listen: false);
              state.approveJoinRequest(
                groupId: widget.groupId,
                requestId: requestId,
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 7,
              ),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Approve',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Decline button
          GestureDetector(
            onTap: () {
              final state =
                  Provider.of<MessageState>(context, listen: false);
              state.rejectJoinRequest(
                groupId: widget.groupId,
                requestId: requestId,
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 7,
              ),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 46, 46, 46),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Decline',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _buildAppBar(),
      body: Consumer<MessageState>(
        builder: (context, state, _) {
          if (state.isLoadingJoinRequests && state.joinRequests.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.grey,
              ),
            );
          }

          final requests = state.joinRequests;

          if (requests.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_add_outlined,
                      size: 48, color: Colors.grey[700]),
                  const SizedBox(height: 12),
                  const Text(
                    'No pending requests',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: Colors.white,
            backgroundColor: Colors.grey[900],
            onRefresh: () => state.loadJoinRequests(widget.groupId),
            child: ListView.separated(
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              itemCount: requests.length,
              separatorBuilder: (_, __) => Divider(
                height: 0.5,
                color: const Color.fromARGB(255, 46, 46, 46),
                indent: 72,
              ),
              itemBuilder: (context, index) {
                return _buildRequestItem(requests[index]);
              },
            ),
          );
        },
      ),
    );
  }
}
