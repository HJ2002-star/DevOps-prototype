// Finesse LLM Mock 서버 (프로토타입)
// 기능명세서 v1.0 - 3.4/3.5절 스키마를 그대로 따르는 스텁 서버.
// 실제 추론 없이 고정 응답만 반환한다. scope=light만 우선 구현 (heavy는 다음 단계).
//
// 실행: node server.js
// 테스트: curl "http://localhost:9000/api/v1/comment/testuser?scope=light"
//        curl "http://localhost:9000/api/v1/comment/testuser?scope=light&mode=delay"
//        curl "http://localhost:9000/api/v1/comment/testuser?scope=light&mode=error"
//        curl "http://localhost:9000/api/v1/comment/testuser?scope=light&mode=excess"

const http = require("http");
const { URL } = require("url");

const PORT = process.env.PORT || 9000;

// 3.5절 정상 응답 fixture (하이라이트 정확히 3개, 중요도 순)
const NORMAL_RESPONSE = {
  light_summary:
    "최근 대전에서 상대 대비 다소 공격적인 플레이 스타일을 보이고 있습니다. 전반적인 TR 흐름은 상승세입니다.",
  highlights: [
    { stat: "delta_plonk", sentence: "상대 대비 Plonk 성향이 뚜렷하게 강한 편입니다." },
    { stat: "clutch", sentence: "2판 이상 뒤진 상황에서의 역전승 비율이 평균보다 높습니다." },
    { stat: "tr_trend_delta", sentence: "최근 10판 기준 TR이 이전 대비 상승하는 흐름을 보이고 있습니다." },
  ],
};

// QA 데모용 예외 응답 모드 (실제 채택 시 mock서버제안 문서 2.1절 기준으로 확장 논의 필요)
function buildResponse(mode) {
  switch (mode) {
    case "excess":
      // 3개 초과 응답 - 기능명세서 3.3절 "앞 3개만 사용" 검증용
      return {
        ...NORMAL_RESPONSE,
        highlights: [
          ...NORMAL_RESPONSE.highlights,
          { stat: "session_vs_slope", sentence: "여분의 4번째 하이라이트 (형식 오류 시뮬레이션)." },
        ],
      };
    case "few":
      // 3개 미만 응답 - 재요청 로직 검증용
      return { ...NORMAL_RESPONSE, highlights: NORMAL_RESPONSE.highlights.slice(0, 1) };
    default:
      return NORMAL_RESPONSE;
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
      res.end(JSON.stringify(buildResponse(mode), null, 2));
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
