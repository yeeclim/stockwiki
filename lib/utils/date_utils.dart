/// 상대적 시간 표시 ("방금 전", "3분 전", "2시간 전", "5일 전", "3/15")
String formatTimeAgo(DateTime dateTime) {
  final now = DateTime.now();
  final diff = now.difference(dateTime);
  if (diff.inMinutes < 1) return '방금 전';
  if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
  if (diff.inHours < 24) return '${diff.inHours}시간 전';
  if (diff.inDays < 7) return '${diff.inDays}일 전';
  return '${dateTime.month}월 ${dateTime.day}일';
}

/// ISO 8601 문자열을 파싱해 상대적 시간 표시 (파싱 실패 시 '알 수 없음')
String formatTimeAgoFromString(String isoString) {
  try {
    return formatTimeAgo(DateTime.parse(isoString));
  } catch (_) {
    return '알 수 없음';
  }
}
