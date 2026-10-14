"""cron-job.org 에 정기 워크플로 dispatch 잡을 등록한다.

키는 .secrets/cronjob.env 에서 읽고 출력하지 않는다.
같은 title 의 잡이 이미 있으면 건너뛴다(재실행해도 중복 생성 안 됨).

    python scripts/register_cronjobs.py            # 등록
    python scripts/register_cronjobs.py --check    # PAT 검증 + 기존 잡 목록만
"""
import json
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

REPO = 'yeeclim/stockwiki'
ENV_FILE = Path(__file__).resolve().parent.parent / '.secrets' / 'cronjob.env'
CRONJOB_API = 'https://api.cron-job.org'
WEEKDAYS = [1, 2, 3, 4, 5]
EVERY_DAY = [-1]
POST = 1

# (title, 워크플로 파일, 시, 분, 요일) — 시각은 각 워크플로 파일 주석과 docs/cron-job-setup.md 기준
JOBS = [
    ('stockwiki 광역 스캔', 'screen_broad.yml', [6], [0], EVERY_DAY),
    ('stockwiki 미국 광역 스캔', 'screen_us_broad.yml', [7], [0], EVERY_DAY),
    ('stockwiki 야간선물 아침', 'probe_night_futures.yml', [7], [50], WEEKDAYS),
    ('stockwiki 야간선물 밤', 'probe_night_futures.yml', [21], [0], WEEKDAYS),
    ('stockwiki 스크리닝', 'screen.yml', [8], [0], WEEKDAYS),
    ('stockwiki AI 추천', 'ai_screening.yml', [8], [0], [1]),
    ('stockwiki 장중 체크포인트', 'forecast_checkpoint.yml', [11], [0], WEEKDAYS),
    ('stockwiki 장전 국내 시세 탐색', 'probe_preopen_kr.yml', [8], [10], WEEKDAYS),
]


def load_env() -> dict[str, str]:
    env = {}
    for line in ENV_FILE.read_text(encoding='utf-8').splitlines():
        key, sep, value = line.partition('=')
        if sep and value.strip():
            env[key.strip()] = value.strip()

    missing = {'CRONJOB_API_KEY', 'GH_DISPATCH_PAT'} - env.keys()
    if missing:
        sys.exit(f'{ENV_FILE} 에 값 없음: {", ".join(sorted(missing))}')

    return env


def request(method: str, url: str, token: str, body: dict | None = None) -> tuple[int, str]:
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method, headers={
        'Authorization': f'Bearer {token}',
        'Content-Type': 'application/json',
        'Accept': 'application/vnd.github+json' if 'github' in url else 'application/json',
    })
    try:
        with urllib.request.urlopen(req, timeout=30) as res:
            return res.status, res.read().decode()
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()


def check_pat(pat: str) -> None:
    for _, workflow, *_ in JOBS:
        status, body = request('GET', f'https://api.github.com/repos/{REPO}/actions/workflows/{workflow}', pat)
        if status != 200:
            sys.exit(f'PAT 검증 실패 {workflow}: HTTP {status} {body[:200]}')

    print(f'PAT OK — 워크플로 {len({j[1] for j in JOBS})}개 조회 가능')


def existing_titles(api_key: str) -> set[str]:
    status, body = request('GET', f'{CRONJOB_API}/jobs', api_key)
    if status != 200:
        sys.exit(f'cron-job.org 잡 목록 조회 실패: HTTP {status} {body[:200]}')

    jobs = json.loads(body)['jobs']
    for job in jobs:
        print(f'  기존 잡 #{job["jobId"]} {job["title"]} enabled={job["enabled"]}')

    return {job['title'] for job in jobs}


def job_payload(title: str, workflow: str, hours: list[int], minutes: list[int], wdays: list[int], pat: str) -> dict:
    return {'job': {
        'title': title,
        'url': f'https://api.github.com/repos/{REPO}/actions/workflows/{workflow}/dispatches',
        'enabled': True,
        'saveResponses': True,
        'requestMethod': POST,
        'schedule': {
            'timezone': 'Asia/Seoul',
            'expiresAt': 0,
            'hours': hours,
            'minutes': minutes,
            'mdays': [-1],
            'months': [-1],
            'wdays': wdays,
        },
        'extendedData': {
            'headers': {
                'Authorization': f'Bearer {pat}',
                'Accept': 'application/vnd.github+json',
                'X-GitHub-Api-Version': '2022-11-28',
                'Content-Type': 'application/json',
            },
            'body': json.dumps({'ref': 'main'}),
        },
        'notification': {'onFailure': True, 'onFailureCount': 1, 'onDisable': True},
    }}


def main() -> None:
    env = load_env()
    api_key = env['CRONJOB_API_KEY']
    pat = env['GH_DISPATCH_PAT']

    check_pat(pat)
    titles = existing_titles(api_key)
    if '--check' in sys.argv:
        return

    for title, workflow, hours, minutes, wdays in JOBS:
        if title in titles:
            print(f'건너뜀(이미 있음): {title}')
            continue

        status, body = request('PUT', f'{CRONJOB_API}/jobs', api_key, job_payload(title, workflow, hours, minutes, wdays, pat))
        if status != 200:
            sys.exit(f'생성 실패 {title}: HTTP {status} {body[:200]}')

        print(f'생성: #{json.loads(body)["jobId"]} {title}')
        time.sleep(13)  # 생성 API 한도: 분당 5회


if __name__ == '__main__':
    main()
