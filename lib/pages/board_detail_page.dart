// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class BoardDetailPage extends StatefulWidget {
  final String postId;
  const BoardDetailPage({super.key, required this.postId});

  @override
  State<BoardDetailPage> createState() => _BoardDetailPageState();
}

class _BoardDetailPageState extends State<BoardDetailPage> {
  Map<String, dynamic>? _post;
  List<Map<String, dynamic>> _comments = [];
  bool _isLoading = true;
  bool _commentsLoading = false;
  String _error = '';
  int _refreshKey = 0;

  @override
  void initState() {
    super.initState();
    _fetchPost();
  }

  Future<void> _fetchPost() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final origin = Uri.base.origin;
      final res = await http
          .get(Uri.parse('$origin/api/board?id=${widget.postId}'))
          .timeout(const Duration(seconds: 10));
      final data = json.decode(res.body);
      if (data['success'] == true) {
        setState(() {
          _post = data['post'];
          _refreshKey++;
          _isLoading = false;
        });
        _fetchComments();
      } else {
        setState(() {
          _error = data['error'] ?? '불러오기 실패';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = '오류: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchComments() async {
    setState(() => _commentsLoading = true);
    try {
      final origin = Uri.base.origin;
      final res = await http
          .get(Uri.parse('$origin/api/board_comments?post_id=${widget.postId}'))
          .timeout(const Duration(seconds: 10));
      final data = json.decode(res.body);
      if (data['success'] == true && mounted) {
        setState(() {
          _comments = List<Map<String, dynamic>>.from(data['comments'] ?? []);
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _commentsLoading = false);
  }

  String _formatDate(String? isoStr) {
    if (isoStr == null) return '';
    final dt = DateTime.tryParse(isoStr)?.toLocal();
    if (dt == null) return '';
    return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _relTime(String? isoStr) {
    if (isoStr == null) return '';
    final dt = DateTime.tryParse(isoStr)?.toLocal();
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }

  // iframe pointer-events 토글 (다이얼로그 열릴 때 이벤트 차단)
  void _setIframePointerEvents(bool enabled) {
    final iframes = html.document.querySelectorAll('iframe');
    for (final el in iframes) {
      (el as html.IFrameElement).style.pointerEvents = enabled ? '' : 'none';
    }
  }

  Future<T?> _showDialogDisablingIframe<T>(
      BuildContext context, Widget Function(BuildContext) builder) {
    _setIframePointerEvents(false);
    return showDialog<T>(context: context, builder: builder)
        .whenComplete(() => _setIframePointerEvents(true));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('게시글',
            style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface)),
        actions: [
          if (_post != null) ...[
            IconButton(
              icon:
                  Icon(Icons.edit_outlined, color: theme.colorScheme.onSurface),
              onPressed: () => _showEditDialog(context, theme),
              tooltip: '수정',
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
              onPressed: () => _showDeleteDialog(context, theme),
              tooltip: '삭제',
            ),
          ],
        ],
      ),
      body: _isLoading
          ? Center(
              child:
                  CircularProgressIndicator(color: theme.colorScheme.primary))
          : _error.isNotEmpty
              ? Center(child: Text(_error, style: theme.textTheme.bodyMedium))
              : Column(
                  children: [
                    // ── 게시글 본문 ───────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if ((_post!['title'] as String? ?? '').isNotEmpty)
                            Text(
                              _post!['title'] as String,
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.person_outline,
                                  size: 14,
                                  color: theme.colorScheme.onSurfaceVariant),
                              const SizedBox(width: 4),
                              Text(_post!['nickname'] ?? '',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w600)),
                              const Spacer(),
                              if (_post!['updated_at'] != null &&
                                  _post!['updated_at'] !=
                                      _post!['created_at']) ...[
                                Text('수정됨',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                        fontStyle: FontStyle.italic)),
                                const SizedBox(width: 8),
                              ],
                              Icon(Icons.access_time_outlined,
                                  size: 13,
                                  color: theme.colorScheme.onSurfaceVariant),
                              const SizedBox(width: 4),
                              Text(_formatDate(_post!['created_at'] as String?),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      color:
                                          theme.colorScheme.onSurfaceVariant)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Divider(
                        height: 16, thickness: 1, color: theme.dividerColor),
                    // HTML 본문
                    Expanded(
                      child: _HtmlContentView(
                        htmlContent: _post!['content'] as String? ?? '',
                        viewId: 'post_${widget.postId}_$_refreshKey',
                        isDark: isDark,
                      ),
                    ),
                    // ── 댓글 섹션 ─────────────────────────────────────────
                    _CommentSection(
                      postId: widget.postId,
                      comments: _comments,
                      isLoading: _commentsLoading,
                      relTime: _relTime,
                      onCommentAdded: _fetchComments,
                      onCommentDeleted: _fetchComments,
                      showDeleteDialog: (commentId) =>
                          _showCommentDeleteDialog(context, theme, commentId),
                    ),
                  ],
                ),
    );
  }

  // ── 게시글 수정 ──────────────────────────────────────────────────────────────
  void _showEditDialog(BuildContext context, ThemeData theme) {
    final titleCtrl =
        TextEditingController(text: _post!['title'] as String? ?? '');
    final contentCtrl =
        TextEditingController(text: _post!['content'] as String? ?? '');
    final passwordCtrl = TextEditingController();
    bool submitting = false;
    String error = '';

    _showDialogDisablingIframe(
      context,
      (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('게시글 수정'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: passwordCtrl,
                  obscureText: true,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: '비밀번호',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleCtrl,
                  maxLength: 100,
                  decoration: const InputDecoration(
                    labelText: '제목',
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contentCtrl,
                  minLines: 6,
                  maxLines: 16,
                  decoration: const InputDecoration(
                    labelText: '내용',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                if (error.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(error,
                      style: TextStyle(
                          color: theme.colorScheme.error, fontSize: 12)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.of(ctx).pop(),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: submitting
                  ? null
                  : () async {
                      setS(() {
                        submitting = true;
                        error = '';
                      });
                      try {
                        final origin = Uri.base.origin;
                        final res = await http
                            .put(
                              Uri.parse(
                                  '$origin/api/board?id=${widget.postId}'),
                              headers: {'Content-Type': 'application/json'},
                              body: json.encode({
                                'title': titleCtrl.text.trim(),
                                'password': passwordCtrl.text.trim(),
                                'content': contentCtrl.text.trim(),
                              }),
                            )
                            .timeout(const Duration(seconds: 10));
                        final data = json.decode(res.body);
                        if (data['success'] == true) {
                          if (ctx.mounted) Navigator.of(ctx).pop();
                          _fetchPost();
                        } else {
                          setS(() {
                            error = data['error'] ?? '수정 실패';
                            submitting = false;
                          });
                        }
                      } catch (e) {
                        setS(() {
                          error = '오류: $e';
                          submitting = false;
                        });
                      }
                    },
              child: submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }

  // ── 게시글 삭제 ──────────────────────────────────────────────────────────────
  void _showDeleteDialog(BuildContext context, ThemeData theme) {
    final passwordCtrl = TextEditingController();
    bool submitting = false;
    String error = '';

    _showDialogDisablingIframe(
      context,
      (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('게시글 삭제'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('삭제하면 복구할 수 없습니다.', style: theme.textTheme.bodyMedium),
              const SizedBox(height: 12),
              TextField(
                controller: passwordCtrl,
                obscureText: true,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '비밀번호 확인',
                  border: OutlineInputBorder(),
                ),
              ),
              if (error.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(error,
                    style: TextStyle(
                        color: theme.colorScheme.error, fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.of(ctx).pop(),
              child: const Text('취소'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.error),
              onPressed: submitting
                  ? null
                  : () async {
                      setS(() {
                        submitting = true;
                        error = '';
                      });
                      try {
                        final origin = Uri.base.origin;
                        final req = http.Request('DELETE',
                            Uri.parse('$origin/api/board?id=${widget.postId}'));
                        req.headers['Content-Type'] = 'application/json';
                        req.body =
                            json.encode({'password': passwordCtrl.text.trim()});
                        final streamed = await req
                            .send()
                            .timeout(const Duration(seconds: 10));
                        final res = await http.Response.fromStream(streamed);
                        final data = json.decode(res.body);
                        if (data['success'] == true) {
                          if (ctx.mounted) Navigator.of(ctx).pop();
                          if (context.mounted) Navigator.of(context).pop();
                        } else {
                          setS(() {
                            error = data['error'] ?? '삭제 실패';
                            submitting = false;
                          });
                        }
                      } catch (e) {
                        setS(() {
                          error = '오류: $e';
                          submitting = false;
                        });
                      }
                    },
              child: submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('삭제', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ── 댓글 삭제 ────────────────────────────────────────────────────────────────
  void _showCommentDeleteDialog(
      BuildContext context, ThemeData theme, String commentId) {
    final passwordCtrl = TextEditingController();
    bool submitting = false;
    String error = '';

    _showDialogDisablingIframe(
      context,
      (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('댓글 삭제'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: passwordCtrl,
                obscureText: true,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '비밀번호',
                  border: OutlineInputBorder(),
                ),
              ),
              if (error.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(error,
                    style: TextStyle(
                        color: theme.colorScheme.error, fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.of(ctx).pop(),
              child: const Text('취소'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.error),
              onPressed: submitting
                  ? null
                  : () async {
                      setS(() {
                        submitting = true;
                        error = '';
                      });
                      try {
                        final origin = Uri.base.origin;
                        final req = http.Request(
                            'DELETE',
                            Uri.parse(
                                '$origin/api/board_comments?id=$commentId'));
                        req.headers['Content-Type'] = 'application/json';
                        req.body =
                            json.encode({'password': passwordCtrl.text.trim()});
                        final streamed = await req
                            .send()
                            .timeout(const Duration(seconds: 10));
                        final res = await http.Response.fromStream(streamed);
                        final data = json.decode(res.body);
                        if (data['success'] == true) {
                          if (ctx.mounted) Navigator.of(ctx).pop();
                          _fetchComments();
                        } else {
                          setS(() {
                            error = data['error'] ?? '삭제 실패';
                            submitting = false;
                          });
                        }
                      } catch (e) {
                        setS(() {
                          error = '오류: $e';
                          submitting = false;
                        });
                      }
                    },
              child: submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('삭제', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 댓글 섹션 ─────────────────────────────────────────────────────────────────
class _CommentSection extends StatefulWidget {
  final String postId;
  final List<Map<String, dynamic>> comments;
  final bool isLoading;
  final String Function(String?) relTime;
  final VoidCallback onCommentAdded;
  final VoidCallback onCommentDeleted;
  final void Function(String) showDeleteDialog;

  const _CommentSection({
    required this.postId,
    required this.comments,
    required this.isLoading,
    required this.relTime,
    required this.onCommentAdded,
    required this.onCommentDeleted,
    required this.showDeleteDialog,
  });

  @override
  State<_CommentSection> createState() => _CommentSectionState();
}

class _CommentSectionState extends State<_CommentSection> {
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
    setState(() {
      _submitting = true;
      _error = '';
    });
    try {
      final origin = Uri.base.origin;
      final res = await http
          .post(
            Uri.parse('$origin/api/board_comments'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'post_id': widget.postId,
              'nickname': _nicknameCtrl.text.trim(),
              'password': _passwordCtrl.text.trim(),
              'content': _contentCtrl.text.trim(),
            }),
          )
          .timeout(const Duration(seconds: 10));
      final data = json.decode(res.body);
      if (data['success'] == true) {
        _contentCtrl.clear();
        widget.onCommentAdded();
      } else {
        setState(() => _error = data['error'] ?? '등록 실패');
      }
    } catch (e) {
      setState(() => _error = '오류: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(maxHeight: 380),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 댓글 헤더
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.chat_bubble_outline,
                    size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Text(
                  '댓글 ${widget.comments.length}',
                  style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: theme.dividerColor),
          // 댓글 목록
          Flexible(
            child: widget.isLoading
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : widget.comments.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          '첫 댓글을 남겨보세요',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: widget.comments.length,
                        separatorBuilder: (_, __) =>
                            Divider(height: 1, color: theme.dividerColor),
                        itemBuilder: (ctx, i) {
                          final c = widget.comments[i];
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.person_outline,
                                        size: 13,
                                        color:
                                            theme.colorScheme.onSurfaceVariant),
                                    const SizedBox(width: 4),
                                    Text(c['nickname'] ?? '',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                                color: theme.colorScheme
                                                    .onSurfaceVariant)),
                                    const SizedBox(width: 8),
                                    Text(
                                        widget.relTime(
                                            c['created_at'] as String?),
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                                color: theme.colorScheme
                                                    .onSurfaceVariant)),
                                    const Spacer(),
                                    GestureDetector(
                                      onTap: () => widget
                                          .showDeleteDialog(c['id'].toString()),
                                      child: Icon(Icons.close,
                                          size: 16,
                                          color: theme
                                              .colorScheme.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(c['content'] ?? '',
                                    style: theme.textTheme.bodyMedium),
                              ],
                            ),
                          );
                        },
                      ),
          ),
          Divider(height: 1, color: theme.dividerColor),
          // 댓글 입력
          Padding(
            padding: EdgeInsets.fromLTRB(
                12, 8, 12, 8 + MediaQuery.of(context).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _SmallField(
                        controller: _nicknameCtrl,
                        hint: '닉네임',
                        theme: theme,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _SmallField(
                        controller: _passwordCtrl,
                        hint: '비밀번호',
                        theme: theme,
                        obscure: !_pwVisible,
                        suffix: IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            _pwVisible
                                ? Icons.visibility_off
                                : Icons.visibility,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          onPressed: () =>
                              setState(() => _pwVisible = !_pwVisible),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _contentCtrl,
                        minLines: 1,
                        maxLines: 4,
                        style: theme.textTheme.bodySmall,
                        decoration: InputDecoration(
                          hintText: '댓글을 입력하세요',
                          hintStyle: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant),
                          filled: true,
                          fillColor:
                              theme.colorScheme.surfaceVariant.withOpacity(0.3),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                  color: theme.colorScheme.primary,
                                  width: 1.5)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      height: 38,
                      child: ElevatedButton(
                        onPressed: _submitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: _submitting
                            ? SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: theme.colorScheme.onPrimary))
                            : const Text('등록', style: TextStyle(fontSize: 13)),
                      ),
                    ),
                  ],
                ),
                if (_error.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(_error,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.error)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ThemeData theme;
  final bool obscure;
  final Widget? suffix;
  const _SmallField({
    required this.controller,
    required this.hint,
    required this.theme,
    this.obscure = false,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: theme.textTheme.bodySmall,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        filled: true,
        fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
                BorderSide(color: theme.colorScheme.primary, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        suffixIcon: suffix,
        isDense: true,
      ),
    );
  }
}

// ── HTML 콘텐츠 뷰어 (iframe + srcdoc) ───────────────────────────────────────
class _HtmlContentView extends StatefulWidget {
  final String htmlContent;
  final String viewId;
  final bool isDark;
  const _HtmlContentView({
    required this.htmlContent,
    required this.viewId,
    required this.isDark,
  });

  @override
  State<_HtmlContentView> createState() => _HtmlContentViewState();
}

class _HtmlContentViewState extends State<_HtmlContentView> {
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType = 'html_board_${widget.viewId}';
    final bg = widget.isDark ? '#1A1A1A' : '#FFFFFF';
    final fg = widget.isDark ? '#E0E0E0' : '#212121';
    final link = widget.isDark ? '#90CAF9' : '#1565C0';
    final codeBg =
        widget.isDark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.05)';
    final srcdoc = '''<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
  *{box-sizing:border-box}
  body{
    margin:0;padding:16px;
    font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;
    font-size:14px;line-height:1.75;
    background:$bg;color:$fg;
    word-break:break-word;
  }
  img{max-width:100%;max-height:400px;object-fit:contain;display:block;margin:8px 0}
  a{color:$link;text-decoration:none}
  a:hover{text-decoration:underline}
  pre{background:$codeBg;padding:12px;border-radius:6px;overflow-x:auto;font-size:13px;margin:12px 0}
  code{background:$codeBg;padding:1px 5px;border-radius:3px;font-size:13px}
  blockquote{border-left:3px solid rgba(128,128,128,0.5);margin:12px 0;padding:8px 16px;opacity:0.85}
  hr{border:none;border-top:1px solid rgba(128,128,128,0.3);margin:16px 0}
  table{border-collapse:collapse;width:100%;margin:12px 0}
  th,td{border:1px solid rgba(128,128,128,0.3);padding:8px 12px;text-align:left}
  th{background:$codeBg;font-weight:600}
  h1{font-size:22px;margin:20px 0 10px}
  h2{font-size:18px;margin:18px 0 8px}
  h3{font-size:16px;margin:14px 0 6px}
  ul,ol{padding-left:24px;margin:8px 0}
  li{margin:4px 0}
</style>
</head>
<body>${widget.htmlContent}</body>
</html>''';
    try {
      ui_web.platformViewRegistry.registerViewFactory(_viewType, (int id) {
        return html.IFrameElement()
          ..srcdoc = srcdoc
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.border = 'none'
          ..tabIndex = -1
          ..setAttribute('sandbox', '');
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
