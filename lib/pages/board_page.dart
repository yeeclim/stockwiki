import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'board_detail_page.dart';

class BoardPage extends StatefulWidget {
  const BoardPage({super.key});

  @override
  State<BoardPage> createState() => _BoardPageState();
}

class _BoardPageState extends State<BoardPage> {
  List<Map<String, dynamic>> _posts = [];
  bool _isLoading = true;
  int _page = 1;
  int _total = 0;
  static const int _limit = 20;
  bool _loadingMore = false;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchPosts();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200 && !_loadingMore && _posts.length < _total) {
      _loadMore();
    }
  }

  Future<void> _fetchPosts({bool reset = false}) async {
    if (reset) setState(() { _page = 1; _posts = []; _isLoading = true; });
    try {
      final origin = Uri.base.origin;
      final res = await http.get(Uri.parse('$origin/api/board?page=$_page&limit=$_limit'))
          .timeout(const Duration(seconds: 10));
      final data = json.decode(res.body);
      if (data['success'] == true) {
        final incoming = List<Map<String, dynamic>>.from(data['posts'] ?? []);
        setState(() {
          _posts = [..._posts, ...incoming];
          _total = data['total'] ?? 0;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    setState(() { _loadingMore = true; _page++; });
    await _fetchPosts();
    setState(() => _loadingMore = false);
  }

  String _relativeTime(String? isoStr) {
    if (isoStr == null) return '';
    final dt = DateTime.tryParse(isoStr)?.toLocal();
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        title: Text('자유게시판',
            style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.close, color: theme.colorScheme.onSurface),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
          : RefreshIndicator(
              onRefresh: () => _fetchPosts(reset: true),
              child: _posts.isEmpty
                  ? _buildEmpty(theme)
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                      itemCount: _posts.length + (_loadingMore ? 1 : 0),
                      itemBuilder: (ctx, i) {
                        if (i == _posts.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final post = _posts[i];
                        return _PostCard(
                          post: post,
                          relTime: _relativeTime(post['created_at'] as String?),
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => BoardDetailPage(postId: post['id'].toString()),
                              ),
                            );
                            _fetchPosts(reset: true);
                          },
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showWriteSheet(context, theme),
        icon: const Icon(Icons.edit_outlined),
        label: const Text('글쓰기'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
    );
  }

  Widget _buildEmpty(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.forum_outlined, size: 56,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4)),
          const SizedBox(height: 16),
          Text('아직 게시글이 없습니다', style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Text('첫 번째 글을 작성해보세요!', style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  void _showWriteSheet(BuildContext context, ThemeData theme) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _WriteSheet(
        onSubmitted: () {
          Navigator.of(ctx).pop();
          _fetchPosts(reset: true);
        },
      ),
    );
  }
}

// ── 게시글 카드 ────────────────────────────────────────────────────────────────
class _PostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final String relTime;
  final VoidCallback onTap;
  const _PostCard({required this.post, required this.relTime, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = post['preview'] as String? ?? '';
    final nickname = post['nickname'] as String? ?? '익명';
    final isUpdated = post['updated_at'] != null && post['updated_at'] != post['created_at'];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        elevation: 0,
        color: theme.cardTheme.color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (preview.isNotEmpty)
                  Text(preview,
                      style: theme.textTheme.bodyMedium,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.person_outline, size: 13,
                        color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(nickname,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600)),
                    const Spacer(),
                    if (isUpdated) ...[
                      Text('수정됨',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontStyle: FontStyle.italic)),
                      const SizedBox(width: 8),
                    ],
                    Icon(Icons.access_time_outlined, size: 12,
                        color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(relTime,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── 글쓰기 바텀시트 ────────────────────────────────────────────────────────────
class _WriteSheet extends StatefulWidget {
  final VoidCallback onSubmitted;
  const _WriteSheet({required this.onSubmitted});

  @override
  State<_WriteSheet> createState() => _WriteSheetState();
}

class _WriteSheetState extends State<_WriteSheet> {
  final _nicknameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  bool _submitting = false;
  bool _pwVisible = false;
  String _error = '';

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    _passwordCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() { _submitting = true; _error = ''; });
    try {
      final origin = Uri.base.origin;
      final res = await http.post(
        Uri.parse('$origin/api/board'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'nickname': _nicknameCtrl.text.trim(),
          'password': _passwordCtrl.text.trim(),
          'content': _contentCtrl.text.trim(),
        }),
      ).timeout(const Duration(seconds: 10));
      final data = json.decode(res.body);
      if (data['success'] == true) {
        widget.onSubmitted();
      } else {
        setState(() { _error = data['error'] ?? '등록 실패'; _submitting = false; });
      }
    } catch (e) {
      setState(() { _error = '오류: $e'; _submitting = false; });
    }
  }

  InputDecoration _deco(ThemeData theme, String hint) => InputDecoration(
        hintText: hint,
        hintStyle: theme.textTheme.bodyMedium
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        filled: true,
        fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text('새 게시글 작성',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nicknameCtrl,
                  maxLength: 30,
                  style: theme.textTheme.bodyMedium,
                  decoration: _deco(theme, '닉네임').copyWith(counterText: ''),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _passwordCtrl,
                  obscureText: !_pwVisible,
                  style: theme.textTheme.bodyMedium,
                  decoration: _deco(theme, '비밀번호 (수정·삭제용)').copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(
                        _pwVisible ? Icons.visibility_off : Icons.visibility,
                        size: 18, color: theme.colorScheme.onSurfaceVariant,
                      ),
                      onPressed: () => setState(() => _pwVisible = !_pwVisible),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _contentCtrl,
            minLines: 5,
            maxLines: 12,
            style: theme.textTheme.bodyMedium,
            decoration: _deco(theme, '내용 (HTML 사용 가능)'),
          ),
          if (_error.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(_error,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _submitting
                  ? SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: theme.colorScheme.onPrimary))
                  : const Text('등록'),
            ),
          ),
        ],
      ),
    );
  }
}
