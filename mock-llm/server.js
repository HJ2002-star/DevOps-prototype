// Finesse LLM Mock 서버 (프로토타입)
// 기능명세서 - 3.4/3.5절 스키마를 그대로 따르는 스텁 서버.
// 실제 추론 없이 고정 응답만 반환한다. scope=light만 우선 구현 (heavy는 다음 단계).
//
// 실행: node server.js
// 테스트: curl "http://localhost:9000/api/v1/comment/testuser?scope=light"
//        curl "http://localhost:9000/api/v1/comment/testuser?scope=light&mode=delay"
//        curl "http://localhost:9000/api/v1/comment/testuser?scope=light&mode=error"
//        curl "http://localhost:9000/api/v1/comment/testuser?scope=light&mode=excess"
//
// stats 파라미터 (신규): 이 유저에게 "실제로 존재하는" 후보 지표 목록을 쉼표로 전달하면,
// 그 안에서만 하이라이트를 고른다. 안 주면 기존 기본값(delta_plonk/comeback_rate/tr_trend_delta)을 그대로 씀.
// 예 — comeback_rate가 0회라 후보에서 빠진 유저를 흉내내기:
//        curl "http://localhost:9000/api/v1/comment/testuser?scope=light&stats=delta_plonk,strength_split,session_vs_slope"

const http = require("http");
const { URL } = require("url");

const PORT = process.env.PORT || 9000;

// 알려진 후보 지표별 코멘트 문장 (기능명세서 3.4절 후보 풀 기준)
const SENTENCES = {
  delta_opener: "상대 대비 Opener 성향이 뚜렷합니다.",
  delta_plonk: "상대 대비 Plonk 성향이 뚜렷하게 강한 편입니다.",
  delta_stride: "상대 대비 Stride 성향이 낮은 편입니다.",
  delta_inf_ds: "상대 대비 Inf DS 성향이 강한 편입니다.",
  delta_app: "상대 대비 공격 효율(APP)이 높은 편입니다.",
  delta_weighted_app: "상대 대비 가중 공격 효율이 높은 편입니다.",
  delta_vs_apm: "상대 대비 수비 지표(VS/APM)가 안정적입니다.",
  delta_cheese_index: "상대 대비 가비지 처리 패턴이 특징적입니다.",
  strength_split: "본인보다 강한 상대와의 승률이 눈에 띄게 낮습니다.",
  comeback_rate: "2판 이상 뒤진 상황에서의 역전승 비율이 평균보다 높습니다.",
  session_vs_slope: "경기가 진행될수록 컨디션이 상승하는 경향이 있습니다.",
  tr_trend_delta: "최근 10판 기준 TR이 이전 대비 상승하는 흐름을 보이고 있습니다.",
};

// stats 파라미터가 없을 때 쓰는 기존 기본값 (하위 호환용, 그대로 유지)
const DEFAULT_STATS = ["delta_plonk", "comeback_rate", "tr_trend_delta"];

function sentenceFor(stat) {
  return SENTENCES[stat] || `${stat} 관련 특징이 관찰됩니다.`;
}

function buildHighlights(stats) {
  return stats.map((stat) => ({ stat, sentence: sentenceFor(stat) }));
}

// QA 데모용 예외 응답 모드 (실제 채택 시 mock서버제안 문서 2.1절 기준으로 확장 논의 필요)
function buildResponse(mode, requestedStats) {
  // 실제 LLM은 입력에 없는 지표를 하이라이트로 고를 수 없으므로, 여기도 주어진 후보 안에서만 고른다.
  const pool = requestedStats && requestedStats.length ? requestedStats : DEFAULT_STATS;
  const light_summary =
    "최근 대전에서 상대 대비 다소 공격적인 플레이 스타일을 보이고 있습니다. 전반적인 TR 흐름은 상승세입니다.";

  switch (mode) {
    case "excess":
      // 3개 초과 응답 - 기능명세서 3.3절 "앞 3개만 사용" 검증용 (여분 항목은 의도적으로 후보 밖 값 사용)
      return {
        light_summary,
        highlights: [
          ...buildHighlights(pool.slice(0, 3)),
          { stat: "session_vs_slope", sentence: "여분의 4번째 하이라이트 (형식 오류 시뮬레이션)." },
        ],
      };
    case "few":
      // 3개 미만 응답 - 재요청 로직 검증용
      return { light_summary, highlights: buildHighlights(pool.slice(0, 1)) };
    default:
      return { light_summary, highlights: buildHighlights(pool.slice(0, 3)) };
  }
}

const server = http.createServer((req, res) => {
  const url = new URL(req.url, `http://${req.headers.host}`);

  if (url.pathname === "/health") {
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ status: "ok" }));
    return;
  }

  const match = url.pathname.match(/^\/api\/v1\/comment\/([^/]+)$/);
  if (req.method === "GET" && match) {
    const scope = url.searchParams.get("scope") || "light";
    const mode = url.searchParams.get("mode") || "normal";
    const statsParam = url.searchParams.get("stats");
    const requestedStats = statsParam
      ? statsParam.split(",").map((s) => s.trim()).filter(Boolean)
      : null;

    if (scope !== "light") {
      res.writeHead(501, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ error: "scope=heavy는 다음 단계에서 구현 예정입니다." }));
      return;
    }

    if (mode === "error") {
      res.writeHead(500, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ error: "Mock: LLM 서버 내부 오류 시뮬레이션" }));
      return;
    }

    const respond = () => {
      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(JSON.stringify(buildResponse(mode, requestedStats), null, 2));
    };

    if (mode === "delay") {
      setTimeout(respond, 3000); // 3초 지연 - 프론트 로딩 스켈레톤 테스트용
    } else {
      respond();
    }
    return;
  }

  res.writeHead(404, { "Content-Type": "application/json" });
  res.end(JSON.stringify({ error: "not found" }));
});

server.listen(PORT, () => {
  console.log(`[mock-llm] listening on port ${PORT}`);
});
