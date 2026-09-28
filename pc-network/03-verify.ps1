<#
.SYNOPSIS
  ③ 검증 1~5단계 — 백엔드 PC에서 실행한다. 대장의 모든 LLM PC를 아래에서 위로 한 칸씩 확인한다.

.DESCRIPTION
  PC마다:
    1 ping    Test-Connection. Windows는 ping을 기본 차단하므로 실패해도 판단하지 않고 2단계로 간다.
    2 포트    TCP 연결 (Test-NetConnection 과 같은 검사, 3초 타임아웃)
    3 health  GET http://<IP>:<Port>/health   — 2 통과·3 실패면 127.0.0.1 바인딩을 의심
    4 추론    POST /completion 짧은 프롬프트 1건
    5 순회    대장의 LLM PC 전부가 4를 통과했는가
  결과는 지시서 산출물 ③ 형식의 표로 results\verify_<stage>_<시각>.md / .csv 에 저장된다.
  6(장애 대응)은 04-failover.ps1, 7(재부팅 후)은 재부팅 뒤 이 스크립트를 -Stage after-reboot 로 다시 돌린다.

.PARAMETER Stage           normal | after-reboot. after-reboot 면 "7 재부팅 후" 칸을 채운다.
.PARAMETER IncludeStandby  LLM_STANDBY(301B-10)도 대상에 넣는다.
.PARAMETER Target          특정 PC만 (예: -Target 301B-11,301B-13). 11↔13 튜닝 연동 확인은 11에서 -Target 301B-13, 13에서 -Target 301B-11
.PARAMETER TimeoutSec      추론 요청 타임아웃(초). GTX 1050 첫 요청은 느릴 수 있다.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\03-verify.ps1
  powershell -ExecutionPolicy Bypass -File .\03-verify.ps1 -Stage after-reboot
#>
param(
    [ValidateSet('normal', 'after-reboot')][string]$Stage = 'normal',
    [string]$CsvPath,
    [switch]$IncludeStandby,
    [string[]]$Target,
    [int]$TimeoutSec = 120
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_common.ps1')

# LAN 대상이므로 시스템 프록시를 타지 않게 한다 (학교 프록시가 있으면 192.168.* 요청이 막히거나 느려질 수 있음)
[System.Net.WebRequest]::DefaultWebProxy = New-Object System.Net.WebProxy

$pcs = Get-FinessePcs -Path $CsvPath
$roles = @('LLM'); if ($IncludeStandby) { $roles += 'LLM_STANDBY' }
$llms = @($pcs | Where-Object { $roles -contains $_.Role })
if ($Target) { $llms = @($pcs | Where-Object { $Target -contains $_.PC }) }
if ($llms.Count -eq 0) { throw '검증할 LLM PC가 없습니다. pcs.csv의 Role 을 확인하세요.' }

$me = $null; try { $me = Resolve-SelfPc -Pcs $pcs } catch { }
if ($me -and $me.Role -ne 'BACKEND' -and -not $me.LlmClient) {
    Write-Host "⚠ 이 PC($($me.PC))는 BACKEND도 LlmClient도 아닙니다. LLM 방화벽이 막으므로 2단계부터 실패하는 게 정상입니다." -ForegroundColor Yellow
}

function Test-Tcp([string]$Ip, [int]$Port, [int]$TimeoutMs = 3000) {
    $c = New-Object System.Net.Sockets.TcpClient
    try {
        $ar = $c.BeginConnect($Ip, $Port, $null, $null)
        if (-not $ar.AsyncWaitHandle.WaitOne($TimeoutMs)) { return $false }
        $c.EndConnect($ar); return $true
    } catch { return $false } finally { $c.Close() }
}

function Get-HttpErrorStatus($err) {
    $resp = $err.Exception.Response
    if ($resp) { return [int]$resp.StatusCode }
    $null
}

$rows = @()
foreach ($pc in $llms) {
    $ip = $pc.IP; $port = [int]$pc.Port
    Write-Host ("── {0} ({1}:{2})" -f $pc.PC, $ip, $port) -ForegroundColor Cyan
    $r = [ordered]@{ PC = "$($pc.PC)"; IP = $ip; S1 = ''; S2 = ''; S3 = ''; S4 = ''; S5 = ''; S7 = ''; Pass4 = $false }

    # 1 ping — 참고용
    $r.S1 = if (Test-Connection -ComputerName $ip -Count 2 -Quiet) { '통과' } else { '실패 (Windows 기본 ICMP 차단일 수 있음 — 판단 보류)' }

    # 2 포트
    if (Test-Tcp $ip $port) { $r.S2 = '통과' }
    else { $r.S2 = "실패 — 방화벽 규칙(02-apply-firewall) 또는 llama-server 미기동 확인" }

    # 3 health
    if ($r.S2 -eq '통과') {
        try {
            $h = Invoke-WebRequest -Uri "http://${ip}:$port/health" -UseBasicParsing -TimeoutSec 10
            $r.S3 = "통과 ($($h.StatusCode))"
        } catch {
            $code = Get-HttpErrorStatus $_
            if ($code -eq 503) { $r.S3 = '실패 — 503: 모델 로딩 중. 잠시 후 재시도' }
            elseif ($code) { $r.S3 = "실패 — HTTP $code" }
            else { $r.S3 = "실패 — $($_.Exception.Message)" }
        }
    } else { $r.S3 = '건너뜀 (2 실패)' }

    # 4 추론
    if ($r.S3 -like '통과*') {
        $body = @{ prompt = 'Reply with one short word: hello'; n_predict = 8; temperature = 0 } | ConvertTo-Json
        $sw = [Diagnostics.Stopwatch]::StartNew()
        try {
            $res = Invoke-RestMethod -Method Post -Uri "http://${ip}:$port/completion" -Body ([Text.Encoding]::UTF8.GetBytes($body)) `
                -ContentType 'application/json; charset=utf-8' -TimeoutSec $TimeoutSec
            $sw.Stop()
            $tps = ''
            if ($res.timings -and $res.timings.predicted_per_second) { $tps = (' · {0:N1} tok/s' -f $res.timings.predicted_per_second) }
            $text = ([string]$res.content).Trim() -replace '\s+', ' '
            if ($text.Length -gt 20) { $text = $text.Substring(0, 20) + '…' }
            $r.S4 = ('통과 ({0:N1}s{1}) "{2}" — LLM PC 로그에서 offloaded 29/29 확인' -f $sw.Elapsed.TotalSeconds, $tps, $text)
            $r.Pass4 = $true
        } catch {
            $r.S4 = "실패 — $($_.Exception.Message)"
        }
    } else { $r.S4 = '건너뜀 (3 실패)' }

    $rows += [pscustomobject]$r
    Write-Host ("   1 {0}`n   2 {1}`n   3 {2}`n   4 {3}" -f $r.S1, $r.S2, $r.S3, $r.S4)
}

# 5 순회 — 한 대라도 빠지면 라운드로빈이 그 차례에서 실패한다
$passCount = @($rows | Where-Object { $_.Pass4 }).Count
$allPass = ($passCount -eq $rows.Count)
foreach ($r in $rows) {
    $r.S5 = if ($r.Pass4) { '통과' } else { '실패 — 이 PC 차례에서 라운드로빈 실패' }
    if ($Stage -eq 'after-reboot') {
        $r.S7 = if ($r.Pass4) { '통과 (2~5 재확인)' } else { '실패 — 초기화 여부 확인 후 02-apply-firewall 재적용' }
    }
}

$cols = '1 ping', '2 포트', '3 health', '4 추론', '5 순회', '7 재부팅 후'
$table = $rows | ForEach-Object {
    [pscustomobject][ordered]@{
        PC = "$($_.PC) ($($_.IP))"; '1 ping' = $_.S1; '2 포트' = $_.S2; '3 health' = $_.S3
        '4 추론' = $_.S4; '5 순회' = $_.S5; '7 재부팅 후' = $_.S7
    }
}
$now = Get-Date
$md = @()
$md += "# Finesse 검증 결과 — $Stage · $($now.ToString('yyyy-MM-dd HH:mm'))"
$md += ''
$md += "실행 PC: $(if ($me) { "$($me.PC) ($($me.IP))" } else { $env:COMPUTERNAME })"
$md += ''
$md += ConvertTo-MarkdownTable -Rows $table -Columns (@('PC') + $cols)
$md += ''
$md += "**5 전체 순회: $passCount / $($rows.Count) $(if ($allPass) { '— 통과' } else { '— 실패' })**"
$md += ''
$md += '| **6 장애 대응** | (04-failover.ps1 결과를 한 줄로) |'
$md += '|---|---|'

$dir = New-ResultsDir
$base = Join-Path $dir ("verify_{0}_{1}" -f $Stage, $now.ToString('yyyyMMdd-HHmm'))
Write-Utf8Bom -Path "$base.md" -Text ($md -join "`r`n")
$table | Export-Csv -Path "$base.csv" -NoTypeInformation -Encoding UTF8

Write-Host ''
Write-Host ($md -join "`n")
Write-Host ''
Write-Host "저장: $base.md / .csv" -ForegroundColor Cyan
if (-not $allPass) { exit 1 }
