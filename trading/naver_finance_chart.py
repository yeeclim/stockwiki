"""
네이버 금융 지수 차트 이미지(PNG) 다운로드.

블로그 글에 "차트 스냅샷"을 넣기 위한 용도. 네이버가 정적으로 서비스하는 지수 차트
이미지 URL을 쓰는데, 비공식이라 언제든 형식이 바뀔 수 있다 → 실패는 조용히 건너뛰고
(글 발행은 그대로 진행), 첫 실행 후 안 나오면 URL만 갱신하면 된다.

NAVER_INDEX_CHART_URL_TMPL 환경변수로 URL 틀을 직접 지정할 수 있다 ({code} 치환).
"""
import os

import requests

_UA = ('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
       '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36')

# 코스피/코스닥 지수 코드
_INDEX_CODES = [('코스피', 'KOSPI'), ('코스닥', 'KOSDAQ')]

# 후보 URL 틀 — 위에서부터 시도해 첫 번째로 유효한 PNG를 쓴다.
_URL_TEMPLATES = [
    'https://ssl.pstatic.net/imgfinance/chart/mobile/day/{code}_end.png',
    'https://ssl.pstatic.net/imgfinance/chart/day/{code}.png',
    'https://ssl.pstatic.net/imgfinance/chart/sise/day/{code}.png',
]

_PNG_MAGIC = b'\x89PNG\r\n\x1a\n'


def _templates() -> list[str]:
    override = os.environ.get('NAVER_INDEX_CHART_URL_TMPL', '').strip()
    return [override, *_URL_TEMPLATES] if override else list(_URL_TEMPLATES)


def _try_download(code: str) -> bytes | None:
    for tmpl in _templates():
        url = tmpl.format(code=code)
        try:
            r = requests.get(url, headers={'User-Agent': _UA}, timeout=10)
            if r.ok and r.content[:8] == _PNG_MAGIC and len(r.content) > 800:
                return r.content
        except Exception:
            continue
    return None


def download_index_charts(out_dir: str) -> list[dict]:
    """코스피·코스닥 일간 차트 PNG를 out_dir에 저장. [{'label','path'}, ...] 반환 (실패분은 제외)."""
    os.makedirs(out_dir, exist_ok=True)
    results = []
    for label, code in _INDEX_CODES:
        data = _try_download(code)
        if not data:
            print(f'⚠️  {label} 지수 차트 이미지를 받지 못했습니다 (URL 형식 변경 가능성).')
            continue
        path = os.path.join(out_dir, f'chart_{code}.png')
        with open(path, 'wb') as fh:
            fh.write(data)
        print(f'📈 {label} 차트 이미지 저장: {path}')
        results.append({'label': f'{label} 일간 차트', 'code': code, 'path': path})
    return results


if __name__ == '__main__':
    here = os.path.dirname(os.path.abspath(__file__))
    print(download_index_charts(os.path.join(here, '_preview')))
