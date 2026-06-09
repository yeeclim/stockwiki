import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _adminEmail = 'eklim4254@gmail.com';

class AdminScreeningPage extends StatefulWidget {
  const AdminScreeningPage({super.key});

  @override
  State<AdminScreeningPage> createState() => _AdminScreeningPageState();
}

class _AdminScreeningPageState extends State<AdminScreeningPage>
    with SingleTickerProviderStateMixin {
  final _sb = Supabase.instance.client;
  late final TabController _tab;

  List<Map<String, dynamic>> _pending  = [];
  List<Map<String, dynamic>> _approved = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final pending = await _sb
          .from('screening_candidates')
          .select()
          .eq('status', 'ai_pending')
          .order('sector')
          .order('stock_name');

      final approved = await _sb
          .from('screening_candidates')
          .select()
          .eq('status', 'approved')
          .eq('source', 'ai')
          .order('sector')
          .order('stock_name');

      if (!mounted) return;
      setState(() {
        _pending  = List<Map<String, dynamic>>.from(pending);
        _approved = List<Map<String, dynamic>>.from(approved);
        _loading  = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _approve(dynamic id) async {
    if (!mounted) return;
    Map<String, dynamic>? removed;
    // optimistic remove from pending for immediate UI feedback
    setState(() {
      final idx = _pending.indexWhere((item) =>
          (item['id'] ?? '').toString() == (id ?? '').toString());
      if (idx >= 0) removed = _pending.removeAt(idx);
    });

    try {
      await _sb
          .from('screening_candidates')
          .update({'status': 'approved'})
          .eq('id', id);

      // refresh approved list
      final approved = await _sb
          .from('screening_candidates')
          .select()
          .eq('status', 'approved')
          .eq('source', 'ai')
          .order('sector')
          .order('stock_name');
      if (!mounted) return;
      setState(() => _approved = List<Map<String, dynamic>>.from(approved));
      _snack('✅ 승인됐습니다. 전체 유저에게 노출됩니다.');
    } catch (e) {
      // revert optimistic removal on failure
      if (!mounted) return;
      setState(() {
        if (removed != null) _pending.insert(0, removed!);
      });
      _snack('승인 실패: $e');
    }
  }

  Future<void> _reject(dynamic id, String name) async {
    if (!mounted) return;
    Map<String, dynamic>? removed;
    setState(() {
      final idx = _pending.indexWhere((item) =>
          (item['id'] ?? '').toString() == (id ?? '').toString());
      if (idx >= 0) removed = _pending.removeAt(idx);
    });

    try {
      await _sb
          .from('screening_candidates')
          .update({'status': 'rejected', 'is_active': false})
          .eq('id', id);
      _snack('❌ $name 거절됐습니다.');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (removed != null) _pending.insert(0, removed!);
      });
      _snack('거절 실패: $e');
    }
  }

  Future<void> _revoke(dynamic id, String name) async {
    if (!mounted) return;
    Map<String, dynamic>? removed;
    setState(() {
      final idx = _approved.indexWhere((item) =>
          (item['id'] ?? '').toString() == (id ?? '').toString());
      if (idx >= 0) removed = _approved.removeAt(idx);
    });

    try {
      await _sb
          .from('screening_candidates')
          .update({'status': 'rejected', 'is_active': false})
          .eq('id', id);
      _snack('$name 비활성화됐습니다.');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (removed != null) _approved.insert(0, removed!);
      });
      _snack('비활성화 실패: $e');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user  = _sb.auth.currentUser;

    // 관리자 이메일 체크
    if (user?.email != _adminEmail) {
      return Scaffold(
        appBar: AppBar(title: const Text('관리자 전용')),
        body: const Center(child: Text('접근 권한이 없습니다.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('AI 추천 종목 관리',
            style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
        bottom: TabBar(
          controller: _tab,
          tabs: [
            Tab(text: '검토 대기 (${_pending.length})'),
            Tab(text: 'AI 승인됨 (${_approved.length})'),
          ],
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          indicatorColor: theme.colorScheme.primary,
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tab,
              children: [
                _PendingTab(
                  items:    _pending,
                  onApprove: _approve,
                  onReject:  _reject,
                  theme:    theme,
                ),
                _ApprovedTab(
                  items:    _approved,
                  onRevoke: _revoke,
                  theme:    theme,
                ),
              ],
            ),
    );
  }
}

// ── 검토 대기 탭 ──────────────────────────────────────────────────────────────

class _PendingTab extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final Future<void> Function(dynamic id) onApprove;
  final Future<void> Function(dynamic id, String name) onReject;
  final ThemeData theme;

  const _PendingTab({
    required this.items, required this.onApprove,
    required this.onReject, required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 48,
                color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text('검토할 종목이 없습니다.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final item = items[i];
        return _PendingCard(
          item:      item,
          onApprove: () => onApprove(item['id']),
          onReject:  () => onReject(item['id'], item['stock_name'] as String),
          theme:     theme,
        );
      },
    );
  }
}

class _PendingCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final Future<void> Function() onApprove;
  final Future<void> Function() onReject;
  final ThemeData theme;

  const _PendingCard({
    required this.item, required this.onApprove,
    required this.onReject, required this.theme,
  });

  @override
  State<_PendingCard> createState() => _PendingCardState();
}

class _PendingCardState extends State<_PendingCard> {
  bool _processing = false;

  Future<void> _handle(Future<void> Function() action) async {
    if (_processing) return;
    setState(() => _processing = true);
    try {
      await action();
    } catch (_) {}
    if (!mounted) return;
    setState(() => _processing = false);
  }

  @override
  Widget build(BuildContext context) {
    final item  = widget.item;
    final theme = widget.theme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(item['sector'] as String,
                    style: const TextStyle(fontSize: 11, color: Colors.orange,
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              Text(item['stock_code'] as String,
                  style: TextStyle(fontFamily: 'monospace', fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(item['stock_name'] as String,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              ),
              const _AIBadge(),
            ],
          ),
          if ((item['ai_reason'] as String? ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(item['ai_reason'] as String,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.5)),
          ],
          const SizedBox(height: 12),
          _processing
              ? const Center(child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: CircularProgressIndicator(strokeWidth: 2)))
              : Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _handle(widget.onReject),
                        icon: const Icon(Icons.close, size: 16),
                        label: const Text('거절'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.error,
                          side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.5)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _handle(widget.onApprove),
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('승인'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }
}

// ── 승인된 AI 종목 탭 ─────────────────────────────────────────────────────────

class _ApprovedTab extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final Future<void> Function(dynamic id, String name) onRevoke;
  final ThemeData theme;

  const _ApprovedTab({required this.items, required this.onRevoke, required this.theme});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Text('AI가 승인한 종목이 없습니다.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) {
        final item = items[i];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Row(
            children: [
              Text(item['stock_code'] as String,
                  style: TextStyle(fontFamily: 'monospace', fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item['stock_name'] as String,
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                    Text(item['sector'] as String,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              const _AIBadge(),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                color: theme.colorScheme.error,
                onPressed: () => onRevoke(item['id'], item['stock_name'] as String),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AIBadge extends StatelessWidget {
  const _AIBadge();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.deepPurple.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text('AI', style: TextStyle(fontSize: 10, color: Colors.deepPurple,
            fontWeight: FontWeight.bold)),
      );
}
