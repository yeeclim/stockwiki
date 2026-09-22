/// Google AdSense 설정.
///
/// 슬롯 ID 는 HTML 에 그대로 노출되는 공개 값이라 소스에 둬도 된다(시크릿 아님).
/// AdSense 콘솔 → 광고 → 광고 단위 기준 → "디스플레이 광고" 로 만든 뒤
/// 발급되는 `data-ad-slot` 숫자 10자리를 아래에 채워 넣는다.
///
/// 빈 문자열이면 [AdBanner] 가 아무것도 렌더링하지 않으므로,
/// 슬롯을 만들기 전에 배포해도 빈 박스가 생기지 않는다.
library;

/// 게시자 ID. web/index.html 의 adsbygoogle.js 쿼리와 반드시 같아야 한다.
const String kAdSenseClient = 'ca-pub-1004612113553207';

/// 위치별 광고 단위. 위치마다 따로 만들어야 어디서 수익이 나는지 구분된다.
class AdSlots {
  const AdSlots._();

  /// 홈 화면 푸터 바로 위.
  static const String homeBottom = '7469173279';

  /// 종목 상세 페이지 하단.
  static const String stockDetailBottom = '2238871205';

  /// 테마·AI 추천 목록 페이지 하단.
  static const String recommendBottom = '5008504779';

  /// 국내·미국 종목 검색 결과 하단.
  /// 전용 광고 단위(sw-search-bottom)를 만들면 여기만 교체하면 된다.
  static const String searchBottom = recommendBottom;

  /// AI 매매일지 목록 중간에 글처럼 끼어드는 인피드 광고.
  /// 전용 광고 단위(sw-feed-inline)를 만들면 여기만 교체하면 된다.
  static const String feedInline = recommendBottom;
}
