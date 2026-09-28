<#
.SYNOPSIS
  검증 1~5단계 (지시서 ③). 백엔드 PC에서 실행. 시스템을 바꾸지 않는다.

.DESCRIPTION
  pcs.json 의 모든 LLM 서버(llmServers)에 대해:
    1 ping    Test-Connection (실패해도 계속 — Windows는 ping 기본 차단)
    2 포트    Test-NetConnection -Port 8081
    3 health  GET  http://<ip>:8081/health      (타임아웃 5초)
    4 추론    POST http://<ip>:8081/completion  {"prompt":"Hello","n_predict":16} (타임아웃 60초)
    5 순회    모든 LLM PC가 4까지 통과해야 전체 통과
  2~4 중 하나라도 실패하면 그 PC는 이후 단계를 건너뛰고 원인을 기록한다.

  결과: results\verify-<yyyyMMdd-HHmm>.csv, results\verify-state.json(누적), docs\검증결과표.md(재생성)

.EXAMPLE
  .\30-verify.ps1
  .\30-verify.ps1 -Label AfterReboot    # 재부팅 후 → "7 재부팅 후" 열에 기록
#>
[CmdletBinding()]
param(
    [ValidateSet('Initial', 'AfterReboot')] [string]$Label = 'Initial',
    [int]$HealthTimeoutSec = 5,
    [int]$InferTimeoutSec = 60,
    [string]$PcId,
    [string]$ConfigPath
)
. (Join-Path $PSScriptRoot 'common.ps1')

$config = Get-FinesseConfig -Path $ConfigPath
$port = [int]$config.ports.llm
$self = Find-SelfPc -Config $config -PcId $PcId
$selfId = if ($self) { $self.id } else { $env:COMPUTERNAME }

# 학교 프록시 설정이 있어도 팀 내부 IP로는 직접 붙도록
[System.Net.WebRequest]::DefaultWebProxy = New-Object System.Net.WebProxy

Write-Host "=== Finesse 검증 ($Label) — 실행 PC: $selfId ===" -ForegroundColor Cyan

$allowed = @()
if ($config.backend) { $allowed += (Resolve-PcIp -Config $config -Item $config.backend) }
foreach ($x in @($config.extraLlmAllow)) { if ($x) { $allowed += (Resolve-PcIp -Config $config -Item $x) } }
if (-not $config.backend) { Write-Warning '백엔드 PC가 아직 정해지지 않았습니다 (pcs.json "backend": null).' }
if (-not $self) {
    Write-Warning '이 PC를 pcs.json 에서 찾지 못했습니다. LLM 방화벽에 막힐 수 있습니다.'
} elseif ($allowed -notcontains $self.ip) {
    Write-Warning "이 PC($($self.id), $($self.ip))는 LLM 방화벽 허용 목록에 없습니다 → 2단계에서 막힐 것입니다."
    Write-Warning '  백엔드 PC에서 실행하거나, pcs.json 의 extraLlmAllow 에 이 PC를 넣고 LLM PC에서 10-firewall-llm.ps1 을 다시 실행하세요.'
}

$rows = @()
foreach ($id in @($config.llmServers)) {
    $pc = $config.pcs | Where-Object { $_.id -eq $id }
    $r = [ordered]@{
        at = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'); label = $Label; from = $selfId; pc = $id; ip = $pc.ip
        ping = 'skip'; port = 'skip'; health = 'skip'; infer = 'skip'; round = 'fail'
        inferSec = $null; tokPerSec = $null; reply = $null; cause = $null
    }
    Write-Host ''
    Write-Host "[$id $($pc.ip)]" -ForegroundColor Cyan

    # 1 ping
    $pingOk = $false
    try { $pingOk = [bool](Test-Connection -ComputerName $pc.ip -Count 2 -Quiet -ErrorAction Stop) } catch { }
    $r.ping = if ($pingOk) { 'pass' } else { 'fail' }
    Write-Host ("  1 ping   : {0}" -f $(if ($pingOk) { '응답' } else { '응답 없음 (Windows 기본 차단일 수 있음, 계속 진행)' }))

    # 2 포트
    $tcpOk = $false
    try {
        $t = Test-NetConnection -ComputerName $pc.ip -Port $port -WarningAction SilentlyContinue -ErrorAction Stop
        $tcpOk = [bool]$t.TcpTestSucceeded
    } catch { }
    $r.port = if ($tcpOk) { 'pass' } else { 'fail' }
    Write-Host ("  2 포트   : {0}" -f $(if ($tcpOk) { '열림' } else { '닫힘' }))
    if (-not $tcpOk) {
        $r.cause = "2 포트: $port 접속 불가 — LLM PC에서 ① llama-server 기동 여부 ② netstat -ano | findstr :$port 가 0.0.0.0:$port 인지(127.0.0.1이면 --host 0.0.0.0 누락) ③ Finesse-LLM-$port-In 규칙의 허용 IP에 이 PC($($self.ip))가 있는지 ④ 차단 규칙(10-firewall-llm.ps1 -RemoveAppRules -WhatIf) 확인"
        if (-not $pingOk) { $r.cause += ' / ping도 실패: PC 전원·랜선·IP 확인' }
    }

    # 3 health
    if ($r.port -eq 'pass') {
        try {
            $h = Invoke-RestMethod -Uri "http://$($pc.ip):$port/health" -TimeoutSec $HealthTimeoutSec -UseBasicParsing -ErrorAction Stop
            if ($h.status -eq 'ok') { $r.health = 'pass' }
            else { $r.health = 'fail'; $r.cause = "3 health: status='$($h.status)' — 모델 로딩이 끝날 때까지 기다린 뒤 재실행" }
        } catch {
            $r.health = 'fail'
            $code = $null
            try { $code = [int]$_.Exception.Response.StatusCode } catch { }
            if ($code -eq 503) { $r.cause = '3 health: 503 모델 로딩 중 — 1~2분 뒤 재실행 (계속이면 LLM PC 로그 확인)' }
            elseif ($code) { $r.cause = "3 health: HTTP $code — 8081 에 llama-server 가 아닌 다른 프로그램이 떠 있는지 확인" }
            else { $r.cause = "3 health: 포트는 열렸으나 HTTP 응답 없음(${HealthTimeoutSec}초) — llama-server 가 멈췄거나 다른 프로그램이 8081 을 점유. LLM PC 로그 확인" }
        }
        Write-Host ("  3 health : {0}" -f $r.health)
    }

    # 4 추론
    if ($r.health -eq 'pass') {
        $body = [System.Text.Encoding]::UTF8.GetBytes('{"prompt":"Hello","n_predict":16}')
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            $c = Invoke-RestMethod -Method Post -Uri "http://$($pc.ip):$port/completion" -Body $body `
                -ContentType 'application/json' -TimeoutSec $InferTimeoutSec -UseBasicParsing -ErrorAction Stop
            $sw.Stop()
            $r.inferSec = [math]::Round($sw.Elapsed.TotalSeconds, 1)
            if ($c.timings -and $c.timings.predicted_per_second) { $r.tokPerSec = [math]::Round([double]$c.timings.predicted_per_second, 1) }
            $text = [string]$c.content
            $r.reply = ($text -replace '\s+', ' ').Trim()
            if ($text.Trim().Length -gt 0) { $r.infer = 'pass'; $r.round = 'pass' }
            else { $r.infer = 'fail'; $r.cause = '4 추론: 응답은 왔으나 content 가 비어 있음 — 모델/프롬프트 설정 확인' }
        } catch {
            $sw.Stop()
            $r.inferSec = [math]::Round($sw.Elapsed.TotalSeconds, 1)
            $r.infer = 'fail'
            if ($r.inferSec -ge $InferTimeoutSec - 1) { $r.cause = "4 추론: ${InferTimeoutSec}초 타임아웃 — GPU 오프로드 실패(CPU로 도는 중) 의심. LLM PC 로그에서 offloaded N/N layers 확인" }
            else { $r.cause = "4 추론: 요청 실패 ($($_.Exception.Message))" }
        }
        $extra = ''
        if ($r.tokPerSec) { $extra = ", $($r.tokPerSec) tok/s" }
        Write-Host ("  4 추론   : {0} ({1}초{2}) {3}" -f $r.infer, $r.inferSec, $extra, $r.reply)
    }
    if ($r.cause) { Write-Host "  원인     : $($r.cause)" -ForegroundColor Red }
    $rows += [pscustomobject]$r
}

$overall = if ($rows.Count -gt 0 -and @($rows | Where-Object { $_.round -ne 'pass' }).Count -eq 0) { 'pass' } else { 'fail' }
Write-Host ''
Write-Host ("5 순회 (전체 {0}대): {1}" -f $rows.Count, $(if ($overall -eq 'pass') { '통과' } else { '실패' })) -ForegroundColor $(if ($overall -eq 'pass') { 'Green' } else { 'Red' })
Write-Host '※ GPU 사용 여부(offloaded 29/29 layers)는 각 LLM PC의 results\llm-<PC>-<시각>.log 에서 확인하세요.' -ForegroundColor Yellow

# ---------- 저장 ----------
$stamp = Get-Date -Format 'yyyyMMdd-HHmm'
$csvName = if ($Label -eq 'Initial') { "verify-$stamp.csv" } else { "verify-$stamp-$Label.csv" }
$csv = Join-Path (Get-ResultsDir) $csvName
$rows | Export-Csv -LiteralPath $csv -NoTypeInformation -Encoding UTF8

$statePath = Join-Path (Get-ResultsDir) 'verify-state.json'
$state = @{ pcs = @{}; runs = @() }
if (Test-Path -LiteralPath $statePath) {
    $old = Get-Content -LiteralPath $statePath -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($prop in @($old.pcs.PSObject.Properties)) {
        $entry = @{}
        foreach ($q in @($prop.Value.PSObject.Properties)) { $entry[$q.Name] = $q.Value }
        $state.pcs[$prop.Name] = $entry
    }
    $state.runs = @($old.runs)
}
foreach ($row in $rows) {
    if (-not $state.pcs.ContainsKey($row.pc)) { $state.pcs[$row.pc] = @{} }
    $state.pcs[$row.pc][$Label] = $row
}
$state.runs = @($state.runs) + @([pscustomobject]@{ at = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'); label = $Label; from = $selfId; overall = $overall; csv = (Split-Path $csv -Leaf) })
Save-Json -Path $statePath -Object $state

# ---------- 검증결과표.md ----------
function Cell($row, [string]$step) {
    if (-not $row) { return '—' }
    $v = $row.$step
    if ($step -eq 'ping') {
        if ($v -eq 'pass') { return '✅' }
        return '⚠ 응답 없음 (기본 차단, 무시 가능)'
    }
    if ($v -eq 'pass') {
        if ($step -eq 'infer') {
            $t = "✅ $($row.inferSec)초"
            if ($row.tokPerSec) { $t += " · $($row.tokPerSec) tok/s" }
            return $t
        }
        return '✅'
    }
    if ($v -eq 'skip') { return '⏭' }
    $stepNo = @{ port = '2'; health = '3'; infer = '4' }[$step]
    if ($row.cause -and $row.cause.StartsWith("$stepNo ")) { return "❌ $($row.cause -replace '\|', '\|')" }
    return '❌'
}
function Summary($row) {
    if (-not $row) { return '—' }
    if ($row.round -eq 'pass') { return "✅ 추론 $($row.inferSec)초 ($($row.at))" }
    return "❌ $($row.cause -replace '\|', '\|') ($($row.at))"
}
function Get-Row($id, $label) {
    if (-not $state.pcs.ContainsKey($id)) { return $null }
    $e = $state.pcs[$id]
    if ($e.ContainsKey($label)) { return $e[$label] }
    return $null
}

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine('# 검증 결과표')
[void]$sb.AppendLine('')
[void]$sb.AppendLine("> ``scripts/30-verify.ps1`` 자동 생성 · 마지막 실행: $(Get-Date -Format 'yyyy-MM-dd HH:mm') ($Label, 실행 PC $selfId)")
$backendText = if ($config.backend) { $config.backend } else { '미정' }
[void]$sb.AppendLine("> 대상 LLM 서버: $(@($config.llmServers) -join ', ') · 포트 $port · 백엔드 PC: $backendText")
[void]$sb.AppendLine('')
[void]$sb.AppendLine('| PC | 1 ping | 2 포트 | 3 health | 4 추론 | 5 순회 | 7 재부팅 후 |')
[void]$sb.AppendLine('|---|---|---|---|---|---|---|')
foreach ($id in @($config.llmServers)) {
    $ini = Get-Row $id 'Initial'
    $aft = Get-Row $id 'AfterReboot'
    $round = if (-not $ini) { '—' } elseif ($ini.round -eq 'pass') { '✅' } else { '❌' }
    [void]$sb.AppendLine(("| {0} | {1} | {2} | {3} | {4} | {5} | {6} |" -f $id, (Cell $ini 'ping'), (Cell $ini 'port'), (Cell $ini 'health'), (Cell $ini 'infer'), $round, (Summary $aft)))
}
function Overall($label) {
    $list = @($config.llmServers | ForEach-Object { Get-Row $_ $label })
    if (@($list | Where-Object { $_ }).Count -eq 0) { return '미실행' }
    if (@($list | Where-Object { -not $_ -or $_.round -ne 'pass' }).Count -eq 0) { return '✅ 통과' }
    return '❌ 실패'
}
[void]$sb.AppendLine('')
[void]$sb.AppendLine("- **5 순회 (전체)**: $(Overall 'Initial')")
[void]$sb.AppendLine('- **6 장애 대응**: ☐ 통과 / ☐ 실패 — (정한비와 수동 확인. 절차는 `docs/실행가이드.md` 6절)')
[void]$sb.AppendLine("- **7 재부팅 후 (전체)**: $(Overall 'AfterReboot')")
[void]$sb.AppendLine('- GPU 사용(`offloaded 29/29 layers`): LLM PC별 `results/llm-<PC>-<시각>.log` 에서 확인 → ' + ((@($config.llmServers) | ForEach-Object { "☐ $_" }) -join ' '))
[void]$sb.AppendLine('')
[void]$sb.AppendLine('## 실행 기록')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('| 시각 | 구분 | 실행 PC | 결과 | 파일 |')
[void]$sb.AppendLine('|---|---|---|---|---|')
foreach ($run in @($state.runs)) {
    [void]$sb.AppendLine(("| {0} | {1} | {2} | {3} | {4} |" -f $run.at, $run.label, $run.from, $(if ($run.overall -eq 'pass') { '통과' } else { '실패' }), $run.csv))
}
$doc = Join-Path (Get-DocsDir) '검증결과표.md'
Write-TextFile -Path $doc -Text $sb.ToString()

Write-Host ''
Write-Host "저장: $csv"
Write-Host "갱신: $doc"
