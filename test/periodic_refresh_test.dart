import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockwiki/widgets/periodic_refresh.dart';

class _Probe extends StatefulWidget {
  final void Function() onRefresh;
  const _Probe({required this.onRefresh});

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> with PeriodicRefresh {
  @override
  void initState() {
    super.initState();
    startPeriodicRefresh(interval: const Duration(minutes: 1));
  }

  @override
  Future<void> onPeriodicRefresh() async => widget.onRefresh();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

void main() {
  testWidgets('1분마다 갱신, 백그라운드에서 정지, 복귀 시 즉시 갱신, dispose 시 해제', (tester) async {
    var calls = 0;
    await tester.pumpWidget(_Probe(onRefresh: () => calls++));

    await tester.pump(const Duration(seconds: 59));
    expect(calls, 0, reason: '주기 전에는 호출되지 않는다');
    await tester.pump(const Duration(seconds: 1));
    expect(calls, 1, reason: '1분이 되면 호출');
    await tester.pump(const Duration(minutes: 1));
    expect(calls, 2);

    // 탭 숨김/백그라운드 → 정지
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump(const Duration(minutes: 5));
    expect(calls, 2, reason: '숨겨진 동안에는 호출되지 않는다');

    // 복귀 → 즉시 한 번 + 주기 재개
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(calls, 3, reason: '다시 보이면 즉시 갱신');
    await tester.pump(const Duration(minutes: 1));
    expect(calls, 4, reason: '주기 재개');

    // 화면 제거 → 타이머 해제 (남아 있으면 테스트 프레임워크가 실패시킨다)
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(minutes: 3));
    expect(calls, 4);
  });
}
