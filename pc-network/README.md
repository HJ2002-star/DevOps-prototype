# 학교 PC 간 통신 연결 — 실행 도구 · 산출물

「Finesse — 학교 PC 간 통신 연결 · 실행 지시서」(2026-09-23)를 실행하는 도구와 산출물입니다.
PC 정보의 출처는 「Finesse — 학교 PC 배정 현황」 **v1.6 (2026-09-21)** 입니다.

- 담당: QA / DevOps (박덕현) · 검증 6단계는 백엔드(정한비)와 함께
- 마감: ① 사전 조사는 **9/28(월) 오전 보고**, ②③ 설정·검증은 **10/1(목) 회의 전**
- Notion: **"LLM PC 연동"** 행 (작업 크기 M, 우선순위 High)
- 전제: 팀원이 집에서 학교 PC에 접속하지 않음 → **포트포워딩 불필요**, 방화벽 인바운드만 연다 (지시서 2절)

## 0. 먼저 확인할 것 — 지시서와 배정 현황 v1.6이 다른 부분

| # | 지시서 | 배정 현황 v1.6 | 이 저장소에서 쓴 기준 |
|---|---|---|---|
| A | PC **8대** | 배정된 PC는 **12대** (09·10·11·12·13·14·22·24·25·26·27·28) | 12대 전부 대장에 넣음. 방화벽 출발지(팀 PC IP)도 12대 기준 |
| B | 예시에 `301B-25 = LLM 서버 1` | 25는 윤세연 **개인 개발**. LLM 서버는 **11·13·14** | LLM 서버 = 11·13·14 |
| C | — | **10**은 "LLM서버 **보조**PC" | `LLM_STANDBY`로 두고 **기본 순회에서 뺐음**. 넣을지는 PM이 결정 (`-IncludeStandby`) |
| D | 백엔드 PC를 따로 정하지 않음 | 26 = 백엔드(정한비) **개인 개발** PC | **백엔드 = 26으로 가정**. 정한비 확인 필요 |
| E | 16GB PC는 LLM 전용 | 26(백엔드)도 16GB | 이번 범위(k3s 제외)에서는 문제없음. k3s를 올릴 때는 32GB PC(24 등)를 검토 |

역할을 바꿀 때는 `pcs.csv`의 `Role` 칸만 고치면 된다. 모든 스크립트가 이 파일을 읽는다.
(`LLM`, `LLM_STANDBY`, `BACKEND`, `FRONTEND`, `DEV`, `AUX`)

## 1. 파일

| 파일 | 어디서 | 단계 | 하는 일 |
|---|---|---|---|
| `pcs.csv` | — | ②-1 | **PC 대장.** IP·역할·포트·RAM·GPU. 스크립트 전체가 읽는 단일 원본 |
| `01-precheck.ps1` | **모든 PC** | ① | 사전 조사 5개 항목 + 호스트명·RAM·GPU·네트워크 프로필 수집. 재부팅 마커를 남긴다 |
| `02-apply-firewall.ps1` | 서버 역할 PC | ②-4, ②-5 | 역할에 맞는 인바운드 규칙(출발지 제한) + 절전 해제. **몇 번 돌려도 같은 결과 = 재적용 스크립트** |
| `start-llama-server.ps1` | LLM PC | ②-3 | llama-server를 `--host 0.0.0.0 --port 8081`로 기동, 로그 파일 남김 |
| `03-verify.ps1` | **백엔드 PC** | ③ 1~5, 7 | 모든 LLM PC에 ping → 포트 → health → 추론을 차례로 확인하고 결과표 생성 |
| `04-failover.ps1` | 백엔드 PC | ③ 6 | LLM 1대를 끈 상태에서 백엔드 API를 반복 호출해 장애 대응 확인 |

실행 결과는 모두 `results\`에 `.csv` / `.txt` / `.md`로 남는다. 이걸 그대로 Notion에 첨부한다.

실행 정책 때문에 막히면 `powershell -ExecutionPolicy Bypass -File .\<스크립트>.ps1` 형태로 실행한다.
스크립트는 학교 PC 기본인 **Windows PowerShell 5.1** 기준이며, 한글이 깨지지 않게 UTF-8(BOM)으로 저장되어 있다.

## 2. 절차

### ① 사전 조사 (9/28 오전 보고)

```powershell
# 각 PC에서 (관리자 PowerShell 권장)
powershell -ExecutionPolicy Bypass -File .\01-precheck.ps1
# → 재부팅
powershell -ExecutionPolicy Bypass -File .\01-precheck.ps1   # 다시 실행: 1_RebootMarker 칸 확인
```

- `1_RebootMarker`가 재부팅 후 **"유지됨"** 이면 초기화 없음, **"없음"** 이면 복원 프로그램이 있다는 뜻 → **바로 PM에게 알린다.**
  C: 드라이브와 다른 드라이브(D: 등)를 따로 확인하고, 방화벽 규칙이 남는지도 비활성 "프로브" 규칙으로 따로 본다.
- `1_RestoreSW`는 이름으로 찾은 복원 프로그램 **후보**일 뿐이다. 확정은 반드시 재부팅 마커로 한다.
- `FirewallProfiles`에 `LocalRules=False`가 보이면 학교 그룹 정책이 로컬 방화벽 규칙을 무시하게 되어 있다는 뜻이다. **이 경우 ②-4가 효과가 없으므로** 학교 IT에 문의한다.
- DHCP 여부(`4_Addressing`)는 한 번으로 확정하지 말고 **며칠 간격으로 다시 실행해** IP가 그대로인지 비교한다.

PC별 CSV를 모아 한 표로 만들려면:

```powershell
Get-ChildItem .\results\precheck_*.csv | ForEach-Object { Import-Csv $_ -Encoding UTF8 } |
  Export-Csv .\results\precheck_all.csv -NoTypeInformation -Encoding UTF8
```

**PM 보고 양식**

| # | 항목 | 결과 | 비고 |
|---|---|---|---|
| 1 | 재부팅 초기화 | 예 / 아니오 (근거: 마커 유지 여부) | "예"면 → 복원 제외 요청 or 매번 `02-apply-firewall.ps1` 재적용 중 결정 필요 |
| 2 | 관리자 권한 | 예 / 아니오 | |
| 3 | 같은 서브넷 | 예 / 아니오 (192.168.0.0/24, GW 192.168.0.1) | 배정 현황 v1.6 기준 전부 같은 /24 → 실측으로 확인 |
| 4 | 고정 IP / DHCP | | DHCP면 학교 IT에 예약(고정) 요청 |
| 5 | 절전·자동 종료 | 절전 N분 / 종료 예약 작업 유무 | 종료 예약 작업은 스크립트로 못 끈다 → 학교 IT |

### ② 설정

1. **LLM PC (11·13·14)**: `02-apply-firewall.ps1 -AllowPing` → `start-llama-server.ps1 -Model <gguf 경로>`
   - 빌드는 GPU 실측 때 확정한 조합 그대로: **CUDA 12.6 · `GGML_CUDA=on` · `CMAKE_CUDA_ARCHITECTURES=61`**
   - 처음 기동할 때 Windows 방화벽 팝업이 뜨면 **"취소"를 누르지 않는다.** 누르면 해당 프로그램을 막는 **차단 규칙**이 생기고, 차단 규칙은 허용 규칙보다 우선한다. 이미 생겼다면 `02-apply-firewall.ps1 -RemoveConflictingBlocks`로 지운다.
2. **백엔드 PC (26)**: `02-apply-firewall.ps1 -AllowPing` — 스프링 부트는 기본적으로 0.0.0.0에 바인딩되므로 확인만 한다(`server.address`를 설정하지 않았는지).
3. **프론트 PC (28)**: `02-apply-firewall.ps1` + `npm run dev -- --host`

적용 전에 무엇이 실행될지 보려면 `-DryRun`을 붙인다.

**포트 할당** (llama-server와 스프링 부트는 기본 포트가 둘 다 8080이라 겹친다)

| 서비스 | 포트 | 받는 출발지 |
|---|---|---|
| 백엔드 (스프링 부트) | **8080** | 팀 PC 12대 |
| LLM 서버 (llama-server) | **8081** | **백엔드 PC만** (llama-server에 인증이 없음) |
| 프론트 (Vite) | **5173** | 팀 PC 12대 |

### ③ 검증 (백엔드 PC에서, 아래 단계부터 한 칸씩)

```powershell
.\03-verify.ps1                         # 1~5단계
.\04-failover.ps1 -BackendUrl "http://192.168.0.126:8080/<백엔드 API 경로>" -Down 301B-13   # 6단계 (LLM 1대 정지 상태)
# 전 PC 재부팅 후 (재부팅 초기화 PC는 먼저 02-apply-firewall.ps1 재적용)
.\03-verify.ps1 -Stage after-reboot     # 7단계
```

| 증상 | 의심할 것 |
|---|---|
| 1 ping 실패, 2 통과 | 정상. Windows는 ping을 기본 차단한다 (`-AllowPing`을 주면 팀 PC에서는 통과) |
| 2 실패 | 방화벽 규칙 누락/차단 규칙 충돌, llama-server가 안 떠 있음, 백엔드 PC IP가 대장과 다름 |
| 2 통과, 3 실패 | **127.0.0.1 바인딩** → `--host 0.0.0.0` 확인. 503이면 모델 로딩 중 |
| 4 통과 | LLM PC의 `logs\llama-server_*.log`에서 `offloaded 29/29 layers`도 확인 |

## 3. 산출물 (Notion 첨부)

### ① PC 대장 — `pcs.csv`

호스트명은 `01-precheck.ps1` 결과(`Hostname`)로 채운다. RAM·GPU는 실측값(`RAM_GB`, `GPU`)과 대조한다.
GTX 1050(2GB)이 아닌 GPU가 나오면 따로 표시하고 PM에게 알린다.

| PC 번호 | 호스트명 | IP | 역할 | 포트 | RAM | GPU | 담당 | 비고 |
|---|---|---|---|---|---|---|---|---|
| 301B-09 | | 192.168.0.109 | 보조 | — | 16GB | GTX 1050 2GB | — | |
| 301B-10 | | 192.168.0.110 | LLM 서버 (보조, 대기) | 8081 | 32GB | GTX 1050 2GB | 윤세연(주) / 조성빈(보조) | 순회 포함 여부 PM 결정 |
| 301B-11 | | 192.168.0.111 | **LLM 서버 1** | 8081 | 32GB | GTX 1050 2GB | 윤세연 | |
| 301B-12 | | 192.168.0.112 | 개인 개발 | — | 16GB | GTX 1050 2GB | 박덕현 | |
| 301B-13 | | 192.168.0.113 | **LLM 서버 2** | 8081 | 16GB | GTX 1050 2GB | 윤세연 | 16GB → LLM 전용 |
| 301B-14 | | 192.168.0.114 | **LLM 서버 3** | 8081 | 16GB | GTX 1050 2GB | 윤세연 | 16GB → LLM 전용 |
| 301B-22 | | 192.168.0.122 | 보조 | — | 16GB | GTX 1050 2GB | — | |
| 301B-24 | | 192.168.0.124 | 보조 | — | 32GB | GTX 1050 2GB | 박덕현 | |
| 301B-25 | | 192.168.0.125 | 개인 개발 | — | 16GB | GTX 1050 2GB | 윤세연 | |
| 301B-26 | | 192.168.0.126 | **백엔드** | 8080 | 16GB | GTX 1050 2GB | 정한비 | 가정 — 확인 필요 |
| 301B-27 | | 192.168.0.127 | 개인 개발 | — | 16GB | GTX 1050 2GB | 위성훈 | |
| 301B-28 | | 192.168.0.128 | 개인 개발 · 프론트 | 5173 | 16GB | GTX 1050 2GB | 호준수 | |

네트워크: 게이트웨이 192.168.0.1 · 255.255.255.0(/24) · DNS 134.75.217.2 / 168.126.63.1

### ② 방화벽 규칙 목록

`02-apply-firewall.ps1`이 재적용 스크립트이고, 각 PC에 실제로 적용한 명령과 결과는 `results\firewall_<PC>_<시각>.txt`에 남는다.
대장 기준으로 만들어지는 규칙은 다음과 같다.

```powershell
# LLM PC (11·13·14) — 백엔드 PC만
New-NetFirewallRule -DisplayName 'Finesse LLM' -Group 'Finesse' -Direction Inbound -Protocol TCP -LocalPort 8081 `
  -RemoteAddress 192.168.0.126 -Action Allow -Profile Any

# 백엔드 PC (26) — 팀 PC 12대
New-NetFirewallRule -DisplayName 'Finesse Backend' -Group 'Finesse' -Direction Inbound -Protocol TCP -LocalPort 8080 `
  -RemoteAddress 192.168.0.109,192.168.0.110,192.168.0.111,192.168.0.112,192.168.0.113,192.168.0.114,192.168.0.122,192.168.0.124,192.168.0.125,192.168.0.126,192.168.0.127,192.168.0.128 `
  -Action Allow -Profile Any

# (-AllowPing) 팀 PC에서 오는 ping만 허용
New-NetFirewallRule -DisplayName 'Finesse Ping' -Group 'Finesse' -Direction Inbound -Protocol ICMPv4 -IcmpType 8 `
  -RemoteAddress <팀 PC 12대> -Action Allow -Profile Any

# 서버 역할 PC 절전 해제
powercfg /change standby-timeout-ac 0
powercfg /change hibernate-timeout-ac 0
```

`-Profile Any`로 만들기 때문에 네트워크 프로필이 "공용"이어도 적용된다(지시서의 `-Profile Public`을 포함한다).

### ③ 검증 결과표

`03-verify.ps1`이 `results\verify_<stage>_<시각>.md`로 아래 형식의 표를 만든다. 실패한 칸에는 원인과 조치가 한 줄로 들어간다.

| PC | 1 ping | 2 포트 | 3 health | 4 추론 | 5 순회 | 7 재부팅 후 |
|---|---|---|---|---|---|---|
| LLM 1 (301B-11) | | | | | | |
| LLM 2 (301B-13) | | | | | | |
| LLM 3 (301B-14) | | | | | | |
| **6 장애 대응** | 통과 / 실패 — 한 줄 설명 (`04-failover.ps1`) | | | | | |

## 4. 완료 기준

- [ ] ① 사전 조사 5개 항목 결과를 PM에게 보고했다
- [ ] PC 대장에 전 PC의 IP·역할·포트·RAM·GPU가 채워져 있다 (호스트명은 precheck 결과로 채움)
- [ ] 백엔드 PC에서 **모든 LLM PC**에 실제 추론 1건씩 성공했다 (③ 5)
- [ ] LLM PC 1대 장애 시 백엔드가 다음 서버로 넘어간다 (③ 6)
- [ ] **재부팅 후에도** 위 두 항목이 그대로 된다 (③ 7)
- [ ] 방화벽 규칙의 출발지가 팀 PC IP로 제한되어 있다

## 5. 범위 밖

포트포워딩(같은 학교망 안이라 불필요), GPU 성능 재측정(`offloaded 29/29`만 확인), k3s 클러스터 구성.
