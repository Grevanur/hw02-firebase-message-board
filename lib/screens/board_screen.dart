import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/app_user.dart';
import '../models/board_message.dart';
import '../services/auth_service.dart';
import '../services/board_service.dart';
import '../services/firebase_error_message.dart';

class BoardScreen extends StatefulWidget {
  const BoardScreen({
    super.key,
    required this.user,
    required this.authService,
    required this.boardService,
  });

  final User user;
  final AuthService authService;
  final BoardService boardService;

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  final _messageController = TextEditingController();
  final _uuid = const Uuid();
  late final Stream<AppUser> _profileStream;
  late final Stream<List<BoardMessage>> _messageStream;
  bool _isPosting = false;
  String? _pendingRequestId;

  @override
  void initState() {
    super.initState();
    _profileStream = widget.boardService.watchProfile(widget.user.uid);
    _messageStream = widget.boardService.watchMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _post(String authorName) async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _isPosting = true;
      _pendingRequestId ??= _uuid.v4();
    });
    try {
      await widget.boardService.postMessage(
        user: widget.user,
        authorName: authorName,
        text: text,
        requestId: _pendingRequestId!,
      );
      _messageController.clear();
      _pendingRequestId = null;
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(friendlyFirebaseError(error))));
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  Future<void> _edit(BoardMessage message) async {
    final controller = TextEditingController(text: message.text);
    final replacement = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit message'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 500,
          maxLines: 5,
          decoration: const InputDecoration(labelText: 'Message'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(context, value);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    if (replacement == null || replacement == message.text) return;
    try {
      await widget.boardService.editMessage(
        messageId: message.id,
        text: replacement,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(friendlyFirebaseError(error))));
    }
  }

  Future<void> _delete(BoardMessage message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this message?'),
        content: const Text(
          'Only this message will be removed. Other posts are unchanged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.boardService.deleteMessage(message.id);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(friendlyFirebaseError(error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser>(
      stream: _profileStream,
      builder: (context, profileSnapshot) {
        final profile = profileSnapshot.data;
        final authorName = profile?.displayName.isNotEmpty == true
            ? profile!.displayName
            : (widget.user.displayName ?? 'Board member');
        return Scaffold(
          appBar: AppBar(
            title: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VAULT BOARD',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  'LIVE FIRESTORE STREAM',
                  style: TextStyle(fontSize: 10, letterSpacing: 1.5),
                ),
              ],
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Center(
                  child: Text(
                    authorName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Sign out',
                onPressed: widget.authService.signOut,
                icon: const Icon(Icons.logout),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Column(
            children: [
              _Composer(
                controller: _messageController,
                isPosting: _isPosting,
                onPost: () => _post(authorName),
              ),
              Expanded(
                child: StreamBuilder<List<BoardMessage>>(
                  stream: _messageStream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return _BoardError(
                        message: friendlyFirebaseError(snapshot.error!),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final messages = snapshot.data!;
                    if (messages.isEmpty) return const _EmptyBoard();
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
                      itemCount: messages.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        return _MessageCard(
                          message: message,
                          isOwner: message.authorUid == widget.user.uid,
                          onEdit: () => _edit(message),
                          onDelete: () => _delete(message),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.isPosting,
    required this.onPost,
  });
  final TextEditingController controller;
  final bool isPosting;
  final VoidCallback onPost;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 8, 18, 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF17202A),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: !isPosting,
              maxLength: 500,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(color: Color(0xFF17202A)),
              decoration: const InputDecoration(
                hintText: 'Share something with the board…',
                counterText: '',
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filled(
            tooltip: 'Post message',
            onPressed: isPosting ? null : onPost,
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFF2C14E),
              foregroundColor: const Color(0xFF17202A),
            ),
            icon: isPosting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.arrow_upward_rounded),
          ),
        ],
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.message,
    required this.isOwner,
    required this.onEdit,
    required this.onDelete,
  });
  final BoardMessage message;
  final bool isOwner;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final date = message.createdAt == null
        ? 'Sending…'
        : DateFormat('MMM d, h:mm a').format(message.createdAt!.toLocal());
    return Card(
      elevation: 0,
      color: isOwner
          ? const Color(0xFFFFF4D6)
          : Colors.white.withValues(alpha: 0.72),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isOwner ? const Color(0xFFE8C978) : const Color(0xFFD9D0C1),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 10, 15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFF17202A),
                  foregroundColor: const Color(0xFFF2C14E),
                  child: Text(
                    message.authorName.isEmpty
                        ? '?'
                        : message.authorName[0].toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.authorName,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        '$date${message.editedAt == null ? '' : ' · edited'}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (message.hasPendingWrites)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Tooltip(
                      message: 'Queued locally',
                      child: Icon(Icons.cloud_upload_outlined, size: 20),
                    ),
                  ),
                if (isOwner)
                  PopupMenuButton<String>(
                    tooltip: 'Message actions',
                    onSelected: (value) =>
                        value == 'edit' ? onEdit() : onDelete(),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                message.text,
                style: const TextStyle(fontSize: 16, height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyBoard extends StatelessWidget {
  const _EmptyBoard();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.mark_chat_unread_outlined,
              size: 68,
              color: Color(0xFF8A8175),
            ),
            SizedBox(height: 16),
            Text(
              'The board is intentionally empty',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 6),
            Text(
              'Post the first message. Every signed-in member will see it live.',
            ),
          ],
        ),
      ),
    );
  }
}

class _BoardError extends StatelessWidget {
  const _BoardError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 58),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
