// Finesse LLM Payload Mock — 파인튜닝 완료 전까지만 쓰는 임시 스크립트.
// LLM/AI 담당이 실제 Qwen 모델에 넣어볼 입력값(prompt 조립 재료)이 필요한데,
// 백엔드 계산 파이프라인(Fancy/Delta/Highlight Calculator)이 아직 없어도
// 형식만 맞는 더미를 뽑아 쓸 수 있게 하는 스크립트다.
//
// 기존 mock-llm(llm-mock-1/2)과는 반대 방향이다:
//   mock-llm    = LLM이 "낼 법한 출력(코멘트)"을 흉내냄 — 백엔드/프론트가 씀
//   이 스크립트 = LLM이 "받을 입력(payload)"을 흉내냄 — LLM/AI 담당이 씀
//
// 근거: TETR.IO 분석 데이터 파이프라인 모듈 설계서 v1.4
//   17.1절 styleSignals, 17.2절 highlightCandidates, 17.3절 금지 필드,
//   18.1절 확정 9종 후보, 18.2절 summaryHint enum 7종, 18.3절 view별 노출 매트릭스
//
// 원시 계산값(Δ 델타, percentile 등)은 17.3절에서 LLM Payload에 넣는 것 자체가
// 금지되어 있다. 그래서 이 스크립트는 중간 수치를 만들지 않고, LLM이 실제로
// 받는 최종 categorical 형태(styleSignals/highlightCandidates)를 바로 만든다.
//
// 서버로 안 만든 이유: LLM/AI 담당이 원격 PC에서 혼자 쓰는 용도라
// 포트 열어두는 상시 서버보다, 필요할 때 한 번 실행해서 JSON 받는 스크립트가 더 가볍다.
//
// 실행 (로컬):
//   node generate-dummy-payload.js testuser
//   node generate-dummy-payload.js testuser --scope=heavy --totalGames=45
//
// 실행 (Docker, 레포 통합 관리 — docker compose up 만으로는 안 뜸, profile 명시 필요):
//   docker compose --profile llm-payload run --rm llm-payload-mock testuser --scope=heavy

// ---------------------------------------------------------------------------
// 결정론적 난수 — mock-llm/server.js, tetrio-mock/server.js와 동일한 mulberry32.
// 같은 유저명이면 항상 같은 payload가 나와야 LLM/AI 담당이 프롬프트를 비교/디버깅하기 쉽다.
// ---------------------------------------------------------------------------
function mulberry32(seed) {
  return function () {
    seed |= 0;
    seed = (seed + 0x6d2b79f5) | 0;
    let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function seedFrom(username, salt) {
  return [...username].reduce((a, c) => a + c.charCodeAt(0), 0) + salt;
}

// 17.1절 — 허용 라벨/strength 그대로
const STYLE_LABELS = ["개방형", "표준", "집중형"];
const STRENGTHS = ["weak", "moderate", "strong"];
const STYLE_KEYS = ["opener", "plonk", "stride", "infDs"];

// 18.2절 — HighlightSummaryHint enum 7종 (자유 서술형 금지, 이 값만 사용)
const HINT = {
  LARGE_GAP_DOMINANT: "large_gap_dominant",
  UPWARD_TREND: "upward_trend",
  DOWNWARD_TREND: "downward_trend",
  COMEBACK_STRONG: "comeback_strong",
  COMEBACK_WEAK: "comeback_weak",
  STABLE: "stable",
  INSUFFICIENT_SAMPLE: "insufficient_sample",
};

// 18.1절 — 확정된 9종 후보 (우선순위 1~9). tr_trend_delta는 별도(라이트 후보 제외, 헤비 전용).
// summaryHint 후보는 표의 "summaryHint 후보" 열 그대로.
const CANDIDATE_POOL = [
  { key: "strength_split", priority: 1, hints: [HINT.LARGE_GAP_DOMINANT, HINT.STABLE] },
  { key: "comeback_rate", priority: 2, hints: [HINT.COMEBACK_STRONG, HINT.COMEBACK_WEAK] },
  { key: "session_vs_slope", priority: 3, hints: [HINT.UPWARD_TREND, HINT.DOWNWARD_TREND, HINT.STABLE] },
  { key: "win_streak_highlight", priority: 4, hints: [HINT.STABLE] },
  { key: "loss_streak_recovery", priority: 5, hints: [HINT.COMEBACK_WEAK] },
  { key: "underdog_win_highlight", priority: 6, hints: [HINT.LARGE_GAP_DOMINANT] },
  { key: "session_volume_highlight", priority: 7, hints: [HINT.STABLE] },
  { key: "consistency_highlight", priority: 8, hints: [HINT.STABLE, HINT.INSUFFICIENT_SAMPLE] },
  { key: "session_recency_activity", priority: 9, hints: [HINT.STABLE] },
];
// tr_trend_delta: 18장 "Light View는 명시적으로 제외" — heavy에서만 노출.
const TR_TREND_DELTA = { key: "tr_trend_delta", hints: [HINT.UPWARD_TREND, HINT.DOWNWARD_TREND, HINT.STABLE] };

const LIGHT_MAX = 3; // 18.3절 기본 N

function buildStyleSignals(rng) {
  return STYLE_KEYS.map((key) => ({
    key,
    label: STYLE_LABELS[Math.floor(rng() * STYLE_LABELS.length)],
    strength: STRENGTHS[Math.floor(rng() * STRENGTHS.length)],
  }));
}

function buildCandidate(def, rng) {
  const eligible = rng() < 0.75; // 더미이므로 대략 75% 확률로 eligible — 실제 최소 표본 조건은 계산하지 않음
  if (!eligible) {
    return { key: def.key, eligible: false, reason: "insufficient_sample" };
  }
  const hint = def.hints[Math.floor(rng() * def.hints.length)];
  return { key: def.key, eligible: true, summaryHint: hint };
}

function generate(username, scope, totalGames) {
  const rng = mulberry32(seedFrom(username, scope === "heavy" ? 900 : 100));

  // 10판 미만: 콜드스타트 — LLM 호출 자체가 없는 구간이므로 payload도 비워서 반환
  if (totalGames < 10) {
    return { llmPayload: null, note: "totalGames < 10 — Cold Start Bypass, LLM 호출 없음" };
  }

  const styleSignals = buildStyleSignals(rng);
  let candidates = CANDIDATE_POOL.map((def) => buildCandidate(def, rng));

  if (scope === "heavy") {
    // heavy: eligible 전체 노출, 캡 없음 + tr_trend_delta 포함 (18.3절)
    candidates.push(buildCandidate(TR_TREND_DELTA, rng));
    candidates = candidates.filter((c) => c.eligible);
  } else {
    // light: tr_trend_delta 제외, 우선순위 상위 eligible 것만 최대 3개 (18.3절)
    candidates = candidates.filter((c) => c.eligible).slice(0, LIGHT_MAX);
  }

  return { llmPayload: { styleSignals, highlightCandidates: candidates } };
}

// ---------------------------------------------------------------------------
// CLI
// ---------------------------------------------------------------------------
function parseArgs(argv) {
  const [username, ...rest] = argv;
  const opts = { scope: "light", totalGames: 60 };
  for (const arg of rest) {
    const [k, v] = arg.replace(/^--/, "").split("=");
    if (k === "scope") opts.scope = v;
    if (k === "totalGames") opts.totalGames = parseInt(v, 10);
  }
  return { username, opts };
}

const { username, opts } = parseArgs(process.argv.slice(2));

if (!username) {
  console.error("사용법: node generate-dummy-payload.js <username> [--scope=light|heavy] [--totalGames=N]");
  process.exit(1);
}

console.log(JSON.stringify(generate(username, opts.scope, opts.totalGames), null, 2));
