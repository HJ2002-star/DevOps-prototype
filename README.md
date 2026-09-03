# Finesse 개발환경 프로토타입 (최소 버전)

Mock서버도입제안 문서(2026-09-03)의 아이디어를 회의 전에 먼저 눈으로 확인해보기 위한
**최소 프로토타입**입니다. 팀 논의 전 상태이므로, 아래 "제외된 것" 항목은 아직 정해진 게
아니라 회의 안건으로 남겨둔 것입니다.

## 포함된 것

- LLM Mock 서버 **1개 인스턴스** (기능명세서 3.4/3.5절 스키마 그대로 따름, scope=light만)
- 정상 응답 + 데모용 예외 모드 3종 (지연 / 서버 오류 / 하이라이트 개수 오류)
- `docker compose up` 한 번으로 실행

## 제외된 것 (회의에서 논의 필요)

- LLM Mock 2개 인스턴스 + 라운드로빈 (FR-12 검증용)
- TETR.IO API Mock
- QA 예외 모드의 정식 스펙 (지금 있는 3종은 데모용 임시 버전)
- CI 파이프라인 연동

## 실행 방법

```bash
docker compose up --build
```

서버는 `localhost:9001`에서 뜹니다 (컨테이너 내부는 9000번, 호스트에 9001번으로 매핑).

## 테스트 방법

```bash
# 정상 응답 (하이라이트 3개)
curl "http://localhost:9001/api/v1/comment/testuser?scope=light"

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

## Docker 없이 바로 테스트하고 싶다면

```bash
cd mock-llm
node server.js
```

외부 패키지 설치가 필요 없어서 (Node.js 내장 http 모듈만 사용) `npm install` 없이 바로 됩니다.

## 다음 단계 (팀 논의 후 진행)

1. 이 프로토타입을 회의에서 공유하고 채택 여부 확인
2. 채택 시 → 2개 인스턴스 확장, TETR.IO Mock 추가, QA 예외 스펙 정식화
3. 미채택 시 → 병목 해소를 위한 대안 논의
