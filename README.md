# Finesse 개발환경 프로토타입

Mock서버도입제안 / Mock개발환경-구축가이드 문서(2026-09-03)의 아이디어를 실제로
확인해보기 위한 프로토타입입니다. 팀 논의 전 상태이므로, 채택 여부는 아직 회의 안건입니다.

## 포함된 것

- **LLM Mock 서버 2개 인스턴스** (`llm-mock-1`, `llm-mock-2`) — 기능명세서 3.4/3.5절 스키마 그대로 따름, scope=light만. 백엔드의 라운드로빈 분배 로직(FR-12)을 두 인스턴스 상대로 검증할 수 있음
- 정상 응답 + 데모용 예외 모드 4종 (지연 / 서버 오류 / 하이라이트 개수 오류 / **입력에 없는 지표는 하이라이트로 고르지 않음**)
- **TETR.IO API Mock** (`tetrio-mock`) — 유저 조회 + 매치 히스토리(상대 스탯 포함) 고정 fixture. 표본 부족(콜드스타트) 케이스 포함
- `docker compose up` 한 번으로 3개 서비스 전부 실행

## 제외된 것 (회의에서 논의 필요)

- QA 예외 모드의 정식 스펙 (지금 있는 것은 데모용 임시 버전)
- CI 파이프라인 연동
- 실제 프론트엔드/백엔드/캐시(Redis) — 이건 원래 다른 역할(프론트·백엔드) 담당이라 이 저장소 범위 밖

## 실행 방법

```bash
docker compose up --build -d
```

| 서비스 | 포트 | 역할 |
|---|---|---|
| `llm-mock-1` | `localhost:9001` | LLM Mock (1번 서버) |
| `llm-mock-2` | `localhost:9002` | LLM Mock (2번 서버, 라운드로빈 대상) |
| `tetrio-mock` | `localhost:9003` | TETR.IO API Mock |

## 테스트 방법 — LLM Mock

```bash
# 정상 응답 (하이라이트 3개) — 1번/2번 서버 둘 다 동일하게 동작
curl "http://localhost:9001/api/v1/comment/testuser?scope=light"
curl "http://localhost:9002/api/v1/comment/testuser?scope=light"

# 입력에 있는 지표만 하이라이트로 고르기 (comeback_rate가 후보에서 빠진 유저 흉내내기)
curl "http://localhost:9001/api/v1/comment/testuser?scope=light&stats=delta_plonk,strength_split,session_vs_slope"

# 하이라이트 4개 반환 (형식 오류 시뮬레이션 - 백엔드가 앞 3개만 쓰는지 확인용)
curl "http://localhost:9001/api/v1/comment/testuser?scope=light&mode=excess"

# 하이라이트 1개만 반환 (재요청 로직 검증용)
curl "http://localhost:9001/api/v1/comment/testuser?scope=light&mode=few"

# 500 에러 시뮬레이션
curl -i "http://localhost:9001/api/v1/comment/testuser?scope=light&mode=error"

# 3초 지연 (프론트 로딩 스켈레톤 확인용)
curl "http://localhost:9001/api/v1/comment/testuser?scope=light&mode=delay"

# 헬스체크
curl "http://localhost:9001/health"
```

## 테스트 방법 — TETR.IO Mock

```bash
# 유저 조회 (정상)
curl "http://localhost:9003/users/testuser"

# 매치 히스토리 (페이지네이션 — limit/offset)
curl "http://localhost:9003/users/testuser/matches?limit=47&offset=0"

# 표본 부족(콜드스타트) 유저 — 5판만 존재
curl "http://localhost:9003/users/coldstartuser/matches"

# 존재하지 않는 유저 — 404
curl "http://localhost:9003/users/nosuchuser"

# 헬스체크
curl "http://localhost:9003/health"
```

주의: 실제 TETR.IO 공식 API의 정확한 필드명/경로는 아직 대조 확인 전입니다(백엔드 API 명세서
10절 미정 사항). 이 Mock의 응답 형태는 백엔드가 파싱 로직을 미리 연습할 수 있는 수준의
근사치이며, 실제 API 스펙이 확정되면 함께 갱신해야 합니다.

## Docker 없이 바로 테스트하고 싶다면

```bash
cd mock-llm && PORT=9001 node server.js   # 한 터미널
cd mock-llm && PORT=9002 node server.js   # 다른 터미널
cd tetrio-mock && PORT=9003 node server.js  # 또 다른 터미널
```

외부 패키지 설치가 필요 없어서 (Node.js 내장 http 모듈만 사용) `npm install` 없이 바로 됩니다.

## 다음 단계 (팀 논의 후 진행)

1. 이 프로토타입을 회의에서 공유하고 채택 여부 확인
2. 채택 시 → QA 예외 스펙 정식화, CI 파이프라인 연동, 실제 TETR.IO API 필드명 확인 후 Mock 갱신
3. 미채택 시 → 병목 해소를 위한 대안 논의
