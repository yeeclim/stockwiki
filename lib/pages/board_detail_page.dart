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
  bool _isLoading = true;
  String _error = '';
  int _refreshKey = 0;

  @override
  void initState() {
    super.initState();
    _fetchPost();
  }

  Future<void> _fetchPost() async {
    setState(() { _isLoading = true; _error = ''; });
    try {
      final origin = Uri.base.origin;
      final res = await http.get(Uri.parse('$origin/api/board?id=${widget.postId}'))
          .timeout(const Duration(seconds: 10));
      final data = json.decode(res.body);
      if (data['success'] == true) {
        setState(() { _post = data['post']; _refreshKey++; _isLoading = false; });
      } else {
        setState(() { _error = data['error'] ?? '불러오기 실패'; _isLoading = false; });
      }
    } catch (e) {
      setState(() { _error = '오류: $e'; _isLoading = false; });
    }
  }

  String _formatDate(String? isoStr) {
    if (isoStr == null) return '';
    final dt = DateTime.tryParse(isoStr)?.toLocal();
    if (dt == null) return '';
    final y = dt.year;
    final mo = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    return '$y.$mo.$d $h:$mi';
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
                fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
        actions: [
          if (_post != null) ...[
            IconButton(
              icon: Icon(Icons.edit_outlined, color: theme.colorScheme.onSurface),
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
          ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
          : _error.isNotEmpty
              ? Center(child: Text(_error, style: theme.textTheme.bodyMedium))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                      child: Row(
                        children: [
                          Icon(Icons.person_outline, size: 14,
                              color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(_post!['nickname'] ?? '',
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600)),
                          const Spacer(),
                          if (_post!['updated_at'] != null &&
                              _post!['updated_at'] != _post!['created_at']) ...[
                            Text('수정됨',
                                style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontStyle: FontStyle.italic)),
                            const SizedBox(width: 8),
                          ],
                          Icon(Icons.access_time_outlined, size: 13,
                              color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(_formatDate(_post!['created_at'] as String?),
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: theme.dividerColor),
                    Expanded(
                      child: _HtmlContentView(
                        htmlContent: _post!['content'] as String? ?? '',
                        viewId: 'post_${widget.postId}_$_refreshKey',
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
    );
  }

  // iframe pointer-events 토글 (다이얼로그 열릴 때 이벤트 차단 해제)
  void _setIframePointerEvents(bool enabled) {
    final iframes = html.document.querySelectorAll('iframe');
    for (final el in iframes) {
      (el as html.IFrameElement).style.pointerEvents = enabled ? '' : 'none';
    }
  }

  Future<T?> _showDialogDisablingIframe<T>(BuildContext context, Widget Function(BuildContext) builder) {
    _setIframePointerEvents(false);
    return showDialog<T>(context: context, builder: builder)
        .whenComplete(() => _setIframePointerEvents(true));
  }

  // ── 수정 다이얼로그 ──────────────────────────────────────────────────────────
  void _showEditDialog(BuildContext context, ThemeData theme) {
    final contentCtrl = TextEditingController(text: _post!['content'] as String? ?? '');
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
                  controller: contentCtrl,
                  minLines: 6,
                  maxLines: 16,
                  decoration: const InputDecoration(
                    labelText: '내용 (HTML 가능)',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                if (error.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(error,
                      style: TextStyle(color: theme.colorScheme.error, fontSize: 12)),
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
                      setS(() { submitting = true; error = ''; });
                      try {
                        final origin = Uri.base.origin;
                        final res = await http.put(
                          Uri.parse('$origin/api/board?id=${widget.postId}'),
                          headers: {'Content-Type': 'application/json'},
                          body: json.encode({
                            'password': passwordCtrl.text.trim(),
                            'content': contentCtrl.text.trim(),
                          }),
                        ).timeout(const Duration(seconds: 10));
                        final data = json.decode(res.body);
                        if (data['success'] == true) {
                          Navigator.of(ctx).pop();
                          _fetchPost();
                        } else {
                          setS(() { error = data['error'] ?? '수정 실패'; submitting = false; });
                        }
                      } catch (e) {
                        setS(() { error = '오류: $e'; submitting = false; });
                      }
                    },
              child: submitting
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }

  // ── 삭제 다이얼로그 ──────────────────────────────────────────────────────────
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
              Text('삭제하면 복구할 수 없습니다.',
                  style: theme.textTheme.bodyMedium),
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
                    style: TextStyle(color: theme.colorScheme.error, fontSize: 12)),
              ],
            ],
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
                      setS(() { submitting = true; error = ''; });
                      try {
                        final origin = Uri.base.origin;
                        final req = http.Request(
                            'DELETE', Uri.parse('$origin/api/board?id=${widget.postId}'));
                        req.headers['Content-Type'] = 'application/json';
                        req.body = json.encode({'password': passwordCtrl.text.trim()});
                        final streamed = await req.send().timeout(const Duration(seconds: 10));
                        final res = await http.Response.fromStream(streamed);
                        final data = json.decode(res.body);
                        if (data['success'] == true) {
                          Navigator.of(ctx).pop();
                          Navigator.of(context).pop();
                        } else {
                          setS(() { error = data['error'] ?? '삭제 실패'; submitting = false; });
                        }
                      } catch (e) {
                        setS(() { error = '오류: $e'; submitting = false; });
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.error),
              child: submitting
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('삭제', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
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
    final codeBg = widget.isDark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.05)';
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
          ..setAttribute('sandbox', 'allow-popups allow-popups-to-escape-sandbox');
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
