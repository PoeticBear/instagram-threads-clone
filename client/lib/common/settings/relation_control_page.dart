import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:threads/l10n/generated/app_localizations.dart';
import 'package:threads/services/user_service.dart';
import 'package:threads/common/locator.dart';

class RelationControlPage extends StatefulWidget {
  const RelationControlPage({super.key});

  @override
  State<RelationControlPage> createState() => _RelationControlPageState();
}

class _RelationControlPageState extends State<RelationControlPage> {
  int _selectedType = 1; // 1=Muted, 2=Restricted, 3=Blocked
  List<RelationControlledUser> _users = [];
  bool _isLoading = true;
  late UserService _userService;

  @override
  void initState() {
    super.initState();
    _userService = UserService(apiClient: getIt());
    _loadList();
  }

  Future<void> _loadList() async {
    setState(() => _isLoading = true);
    try {
      final users = await _userService.getRelationControlList(controlType: _selectedType);
      if (mounted) {
        setState(() {
          _users = users;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _actionLabel() {
    switch (_selectedType) {
      case 1:
        return 'Unmute';
      case 2:
        return 'Unrestrict';
      case 3:
        return 'Unblock';
      default:
        return 'Remove';
    }
  }

  Future<void> _removeUser(RelationControlledUser user) async {
    try {
      await _userService.removeRelationControl(user.userId);
      _loadList();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to remove. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Muted / Restricted / Blocked',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        children: [
          // Segmented control
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: SizedBox(
              width: double.infinity,
              child: CupertinoSlidingSegmentedControl<int>(
                groupValue: _selectedType,
                thumbColor: const Color(0xff333333),
                backgroundColor: const Color(0xff1a1a1a),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                onValueChanged: (value) {
                  if (value != null && value != _selectedType) {
                    setState(() => _selectedType = value);
                    _loadList();
                  }
                },
                children: {
                  1: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Text(
                      'Muted',
                      style: TextStyle(
                        color: _selectedType == 1 ? Colors.white : const Color(0xff888888),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  2: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Text(
                      'Restricted',
                      style: TextStyle(
                        color: _selectedType == 2 ? Colors.white : const Color(0xff888888),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  3: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Text(
                      'Blocked',
                      style: TextStyle(
                        color: _selectedType == 3 ? Colors.white : const Color(0xff888888),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                },
              ),
            ),
          ),
          const Divider(
            color: Color(0xff333333),
            height: 0.5,
            thickness: 0.5,
          ),
          // User list
          Expanded(
            child: _isLoading
                ? const Center(child: CupertinoActivityIndicator())
                : _users.isEmpty
                    ? Center(
                        child: Text(
                          'No users found',
                          style: TextStyle(
                            color: const Color(0xff888888),
                            fontSize: 16,
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        backgroundColor: const Color(0xff222222),
                        color: Colors.white,
                        onRefresh: _loadList,
                        child: ListView.separated(
                          itemCount: _users.length,
                          separatorBuilder: (_, __) => const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20),
                            child: Divider(
                              color: Color(0xff333333),
                              height: 0.5,
                              thickness: 0.5,
                            ),
                          ),
                          itemBuilder: (context, index) {
                            final user = _users[index];
                            return _buildUserTile(user);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTile(RelationControlledUser user) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xff333333),
            backgroundImage:
                user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                    ? NetworkImage(user.avatarUrl!)
                    : null,
            child: user.avatarUrl == null || user.avatarUrl!.isEmpty
                ? Text(
                    user.username.isNotEmpty ? user.username[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.username,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (user.displayName != null && user.displayName!.isNotEmpty)
                  Text(
                    user.displayName!,
                    style: const TextStyle(
                      color: Color(0xff888888),
                      fontSize: 14,
                    ),
                  ),
                if (user.reason != null && user.reason!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Reason: ${user.reason}',
                      style: const TextStyle(
                        color: Color(0xff666666),
                        fontSize: 13,
                      ),
                    ),
                  ),
                if (user.createTime != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      user.createTime!,
                      style: const TextStyle(
                        color: Color(0xff555555),
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Action button
          GestureDetector(
            onTap: () => _removeUser(user),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xff1a1a1a),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xff444444)),
              ),
              child: Text(
                _actionLabel(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
