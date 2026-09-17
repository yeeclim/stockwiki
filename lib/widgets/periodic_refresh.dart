import 'dart:async';

import 'package:flutter/widgets.dart';

/// 화면이 열려 있는 동안 시세를 주기적으로 다시 불러오는 공용 믹스인.
///
/// 예전엔 시세 카드가 화면을 열 때 한 번만 조회해서, 화면을 켜 둔 채로 두면 예전 값이
/// 그대로 남았다. 탭이 숨겨지거나 앱이 백그라운드로 가면 멈추고(요청 낭비 방지),
/// 다시 보이면 즉시 한 번 조회한 뒤 재개한다.
mixin PeriodicRefresh<T extends StatefulWidget> on State<T> {
  static const defaultInterval = Duration(minutes: 1);

  Timer? _refreshTimer;
  _RefreshLifecycleObserver? _lifecycleObserver;

  /// 주기마다 호출된다. 로딩 표시 없이 값만 교체하도록 구현한다.
  Future<void> onPeriodicRefresh();

  void startPeriodicRefresh({Duration interval = defaultInterval}) {
    _lifecycleObserver = _RefreshLifecycleObserver(
      onPause: _stopTimer,
      onResume: () {
        if (!mounted) return;
        onPeriodicRefresh();
        _startTimer(interval);
      },
    );
    WidgetsBinding.instance.addObserver(_lifecycleObserver!);
    _startTimer(interval);
  }

  void _startTimer(Duration interval) {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(interval, (_) {
      if (mounted) onPeriodicRefresh();
    });
  }

  void _stopTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  @override
  void dispose() {
    _stopTimer();
    final observer = _lifecycleObserver;
    if (observer != null) WidgetsBinding.instance.removeObserver(observer);
    super.dispose();
  }
}

class _RefreshLifecycleObserver extends WidgetsBindingObserver {
  final VoidCallback onPause;
  final VoidCallback onResume;
  bool _paused = false;

  _RefreshLifecycleObserver({required this.onPause, required this.onResume});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      // 웹에서는 브라우저 탭이 숨겨지면 hidden 이 온다.
      // inactive(창 포커스만 잃은 상태)는 화면이 보이므로 멈추지 않는다.
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        if (!_paused) {
          _paused = true;
          onPause();
        }
      case AppLifecycleState.resumed:
        if (_paused) {
          _paused = false;
          onResume();
        }
      case AppLifecycleState.inactive:
        break;
    }
  }
}
