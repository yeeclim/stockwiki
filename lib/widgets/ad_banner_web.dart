import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import '../config/ads_config.dart';

/// 같은 viewType 을 두 번 등록하면 DOM 노드가 공유돼서 광고가 한쪽에만 뜬다.
/// 인스턴스마다 고유 viewType 을 만든다.
int _viewTypeSeq = 0;

/// AdSense 디스플레이 광고 한 칸.
///
/// Flutter 웹은 화면이 캔버스라 자동 광고(Auto ads)가 삽입 지점을 못 찾는다.
/// `HtmlElementView` 로 실제 `<ins class="adsbygoogle">` DOM 을 올려야 노출된다.
///
/// 광고가 안 채워지거나(`data-ad-status=unfilled`) 차단기에 막히면 자리를 접는다.
class AdBanner extends StatefulWidget {
  const AdBanner({super.key, required this.slot});

  /// [AdSlots] 의 값. 비어 있으면 아무것도 렌더링하지 않는다.
  final String slot;

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner>
    with AutomaticKeepAliveClientMixin {
  /// 리스트에서 스크롤로 벗어날 때마다 dispose 되면 다시 붙을 때 `push` 가
  /// 또 호출돼 같은 자리에서 광고 요청이 반복된다(무효 트래픽 위험).
  /// 한 번 띄운 칸은 그대로 살려 둔다.
  @override
  bool get wantKeepAlive => _enabled;

  /// 로컬 개발 중 자기 광고를 찍으면 무효 트래픽으로 계정이 정지될 수 있다.
  static bool get _isServed {
    if (kDebugMode) return false;
    final host = web.window.location.hostname;
    return host != 'localhost' && host != '127.0.0.1' && host.isNotEmpty;
  }

  bool get _enabled => widget.slot.isNotEmpty && _isServed;

  late final String _viewType;
  web.HTMLElement? _ins;
  Timer? _poll;
  int _ticks = 0;
  bool _pushed = false;
  bool _collapsed = false;

  /// adsbygoogle.js 가 <ins> 에 직접 박아 넣은 높이(px).
  /// 반응형 유닛은 우리가 준 높이를 무시하고 폭에 맞춰 제 높이를 정한다.
  /// 이걸 따라가지 않으면 호스트가 overflow:hidden 이라 광고가 잘린다.
  double? _adHeight;

  /// 광고가 실린 시점의 tick. 구글이 크기를 바로 못 정하고 조금 뒤에
  /// 조정하는 경우가 있어, 실린 직후에도 잠깐 더 높이를 지켜본다.
  int? _filledAt;

  @override
  void initState() {
    super.initState();
    if (!_enabled) return;
    _viewType = 'adsense-${widget.slot}-${_viewTypeSeq++}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) {
      final host = web.document.createElement('div') as web.HTMLDivElement;
      host.style
        ..width = '100%'
        ..height = '100%'
        ..overflow = 'hidden';

      final ins = web.document.createElement('ins') as web.HTMLElement;
      ins.className = 'adsbygoogle';
      ins.style
        ..display = 'block'
        ..width = '100%'
        ..height = '100%';
      ins
        ..setAttribute('data-ad-client', kAdSenseClient)
        ..setAttribute('data-ad-slot', widget.slot)
        ..setAttribute('data-ad-format', 'auto')
        ..setAttribute('data-full-width-responsive', 'true');

      host.appendChild(ins);
      _ins = ins;
      return host;
    });
    _poll = Timer.periodic(const Duration(milliseconds: 120), _tick);
  }

  /// `adsbygoogle.push` 는 `<ins>` 폭이 0 이면 "availableWidth=0" 으로 실패한다.
  /// 플랫폼 뷰가 실제로 붙어 폭이 잡힌 뒤에 밀어 넣고, 그다음 채움 여부를 본다.
  void _tick(Timer timer) {
    _ticks++;
    final ins = _ins;
    if (ins == null) {
      if (_ticks > 40) _giveUp(timer);
      return;
    }

    if (!_pushed) {
      if (ins.offsetWidth > 0) {
        _pushAd();
        _pushed = true;
      } else if (_ticks > 40) {
        _giveUp(timer); // 약 5초간 레이아웃이 안 잡히면 포기
      }
      return;
    }

    _syncHeight(ins);

    switch (ins.getAttribute('data-ad-status')) {
      case 'filled':
        _filledAt ??= _ticks;
        if (_ticks > _filledAt! + 12) timer.cancel();
      case 'unfilled':
        _giveUp(timer);
      default:
        // 차단기에 막히면 상태 속성 자체가 안 붙는다. 약 10초 뒤 접는다.
        if (_ticks > 80) _giveUp(timer);
    }
  }

  /// 구글이 인라인으로 높이를 지정했으면 바깥 상자를 거기에 맞춘다.
  /// 스타일이 여전히 '100%' 면 우리 상자를 따라가는 상태라 건드리지 않는다
  /// (읽고 다시 쓰면 서로를 쫓는 무한 루프가 된다).
  void _syncHeight(web.HTMLElement ins) {
    final style = ins.style.height;
    if (!style.endsWith('px')) return;
    final h = double.tryParse(style.substring(0, style.length - 2));
    if (h == null || h <= 0 || h == _adHeight) return;
    if (!mounted) return;
    setState(() => _adHeight = h);
  }

  void _pushAd() {
    final queue = globalContext['adsbygoogle'] as JSObject?;
    if (queue == null) {
      // adsbygoogle.js 가 async 라 아직 안 떴을 수 있다. 공식 스니펫과 동일하게
      // 큐를 먼저 만들어 두면 스크립트가 로드될 때 밀린 요청을 처리한다.
      final created = <JSAny>[].toJS;
      globalContext['adsbygoogle'] = created;
      created.callMethod('push'.toJS, JSObject());
      return;
    }
    queue.callMethod('push'.toJS, JSObject());
  }

  void _giveUp(Timer timer) {
    timer.cancel();
    if (!mounted || _collapsed) return;
    setState(() => _collapsed = true);
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (!_enabled || _collapsed) return const SizedBox.shrink();
    // 첫 렌더에는 구글이 고를 높이를 모르니 대략치를 준다. 광고가 실리면
    // _syncHeight 가 실제 높이로 바꾼다.
    final height =
        _adHeight ?? (MediaQuery.sizeOf(context).width >= 900 ? 250.0 : 280.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: HtmlElementView(viewType: _viewType),
      ),
    );
  }
}
