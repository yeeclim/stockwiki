import 'package:flutter/material.dart';
import '../services/screening_service.dart';
import '../utils/admin.dart';

class ScreeningManagePage extends StatefulWidget {
  const ScreeningManagePage({super.key});

  @override
  State<ScreeningManagePage> createState() => _ScreeningManagePageState();
}

class _ScreeningManagePageState extends State<ScreeningManagePage> {
  List<ScreeningCandidate> _all = [];
  List<ScreeningCandidate> _mine = [];
  List<Map<String, dynamic>> _excluded = [];
  bool _loading = true;

  // 추가 폼
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _sectorCtrl = TextEditingController();
  bool _adding = false;

  static const _sectors = ['반도체', 'AI', '데이터센터', '유리기판', '양자컴퓨터', '클라우드', '기타'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final all = await ScreeningService.loadAll();
      final mine = await ScreeningService.loadMine();
      var excluded = <Map<String, dynamic>>[];
      if (isAdminUser) {
        try {
          excluded = await ScreeningService.loadExcluded();
        } catch (e) {
          _snack('제외 종목 목록을 불러오지 못했습니다: $e');
        }
      }
      if (!mounted) return;
      setState(() {
        _all = all;
        _mine = mine;
        _excluded = excluded;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add() async {
    final code = _codeCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    final sector = _sectorCtrl.text.trim();
    if (code.isEmpty || name.isEmpty || sector.isEmpty) return;
    if (code.length != 6 || int.tryParse(code) == null) {
      _snack('종목코드는 6자리 숫자입니다.');
      return;
    }
    setState(() => _adding = true);
    try {
      await ScreeningService.add(
          stockCode: code, stockName: name, sector: sector);
      _codeCtrl.clear();
      _nameCtrl.clear();
      _sectorCtrl.clear();
      await _load();
      _snack('추가됐습니다.');
    } catch (e) {
      _snack('오류: $e');
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _remove(ScreeningCandidate c) async {
    try {
      await ScreeningService.remove(c.id);
      await _load();
      _snack('${c.stockName} 삭제됐습니다.');
    } catch (e) {
      _snack('삭제 실패: $e');
    }
  }

  /// 관리자: 종목을 스크리닝 전체에서 제외 (메일·추천·자동매매 포함, 다음 스캔에도 유지)
  Future<void> _exclude(ScreeningCandidate c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('종목 제외'),
        content: Text('${c.stockName}(${c.stockCode})을(를) 스크리닝에서 제외할까요?\n\n'
            '스크리닝 메일·추천 목록·자동매매에서 모두 빠지고, 다음 날 광역 스캔이 '
            '다시 올리지 않습니다. 아래 "제외한 종목"에서 복원할 수 있습니다.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('제외')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ScreeningService.excludeAsAdmin(c.stockCode);
      await _load();
      _snack('${c.stockName} 제외됐습니다.');
    } catch (e) {
      _snack('제외 실패: $e');
    }
  }

  Future<void> _restore(String code, String name) async {
    try {
      await ScreeningService.restoreAsAdmin(code);
      await _load();
      _snack('$name 복원됐습니다. 다음 스크리닝부터 다시 평가합니다.');
    } catch (e) {
      _snack('복원 실패: $e');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _sectorCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAdmin = isAdminUser;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('스크리닝 종목 관리',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 내 종목 추가 ───────────────────────────────────────────
                  _SectionTitle(theme: theme, title: '종목 추가'),
                  const SizedBox(height: 10),
                  _AddForm(
                    codeCtrl: _codeCtrl,
                    nameCtrl: _nameCtrl,
                    sectorCtrl: _sectorCtrl,
                    sectors: _sectors,
                    adding: _adding,
                    onAdd: _add,
                    theme: theme,
                  ),
                  const SizedBox(height: 24),

                  // ── 내가 추가한 종목 ───────────────────────────────────────
                  _SectionTitle(
                      theme: theme, title: '내가 추가한 종목 (${_mine.length}개)'),
                  const SizedBox(height: 8),
                  if (_mine.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text('추가한 종목이 없습니다.',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                    )
                  else
                    ..._mine.map((c) => _CandidateTile(
                          candidate: c,
                          onRemove: () => _remove(c),
                          theme: theme,
                        )),

                  const SizedBox(height: 24),

                  // ── 전체 후보 ──────────────────────────────────────────────
                  _SectionTitle(
                      theme: theme, title: '전체 스크리닝 대상 (${_all.length}개)'),
                  const SizedBox(height: 4),
                  Text('시스템 기본 + 모든 유저 추가 종목',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  ..._groupBySector(_all).entries.map((entry) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 12, bottom: 6),
                            child: Text(entry.key,
                                style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1)),
                          ),
                          ...entry.value.map((c) => _CandidateTile(
                                candidate: c,
                                // 관리자는 제외(서버 처리), 일반 사용자는 본인 종목만 삭제
                                onRemove: isAdmin
                                    ? () => _exclude(c)
                                    : c.isUserAdded
                                        ? () => _remove(c)
                                        : null,
                                theme: theme,
                              )),
                        ],
                      )),

                  // ── 관리자: 제외한 종목 ─────────────────────────────────────
                  if (isAdmin) ...[
                    const SizedBox(height: 24),
                    _SectionTitle(
                        theme: theme, title: '제외한 종목 (${_excluded.length}개)'),
                    const SizedBox(height: 4),
                    Text('메일·추천·자동매매에서 빠져 있는 종목 — 복원하면 다음 스크리닝부터 다시 평가',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    if (_excluded.isEmpty)
                      Text('제외한 종목이 없습니다.',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant))
                    else
                      ..._excluded.map((e) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text('${e['stock_name']}'),
                            subtitle:
                                Text('${e['stock_code']} · ${e['sector']}'),
                            trailing: TextButton(
                              onPressed: () => _restore(
                                  '${e['stock_code']}', '${e['stock_name']}'),
                              child: const Text('복원'),
                            ),
                          )),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Map<String, List<ScreeningCandidate>> _groupBySector(
      List<ScreeningCandidate> list) {
    final map = <String, List<ScreeningCandidate>>{};
    for (final c in list) {
      map.putIfAbsent(c.sector, () => []).add(c);
    }
    return map;
  }
}

// ── 위젯 ─────────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final ThemeData theme;
  final String title;
  const _SectionTitle({required this.theme, required this.title});
  @override
  Widget build(BuildContext context) => Text(title,
      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold));
}

class _CandidateTile extends StatelessWidget {
  final ScreeningCandidate candidate;
  final VoidCallback? onRemove;
  final ThemeData theme;
  const _CandidateTile(
      {required this.candidate, required this.onRemove, required this.theme});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Row(
          children: [
            Text(candidate.stockCode,
                style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(candidate.stockName,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w500)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(candidate.sector,
                  style: TextStyle(
                      fontSize: 11, color: theme.colorScheme.primary)),
            ),
            if (onRemove != null) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                color: theme.colorScheme.error,
                onPressed: onRemove,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ],
        ),
      );
}

class _AddForm extends StatefulWidget {
  final TextEditingController codeCtrl;
  final TextEditingController nameCtrl;
  final TextEditingController sectorCtrl;
  final List<String> sectors;
  final bool adding;
  final VoidCallback onAdd;
  final ThemeData theme;
  const _AddForm({
    required this.codeCtrl,
    required this.nameCtrl,
    required this.sectorCtrl,
    required this.sectors,
    required this.adding,
    required this.onAdd,
    required this.theme,
  });
  @override
  State<_AddForm> createState() => _AddFormState();
}

class _AddFormState extends State<_AddForm> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: widget.theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: widget.theme.dividerColor),
      ),
      child: Column(
        children: [
          Row(children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: widget.codeCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: '종목코드 (6자리)',
                  counterText: '',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: TextField(
                controller: widget.nameCtrl,
                decoration: const InputDecoration(
                  labelText: '종목명',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: widget.sectorCtrl.text.isEmpty
                    ? null
                    : widget.sectorCtrl.text,
                hint: const Text('섹터 선택'),
                decoration: const InputDecoration(
                    isDense: true, border: OutlineInputBorder()),
                items: widget.sectors
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) =>
                    setState(() => widget.sectorCtrl.text = v ?? ''),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: widget.adding ? null : widget.onAdd,
              child: widget.adding
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('추가'),
            ),
          ]),
        ],
      ),
    );
  }
}
