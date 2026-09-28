<#
.SYNOPSIS
  ③ 검증 6단계(장애 대응) 보조 — 정한비와 함께 한다.

.DESCRIPTION
  LLM PC 1대를 끄거나 llama-server 를 내린 상태에서, 백엔드 API에 요청을 여러 번 보내
  "백엔드가 멈추지 않고 다음 서버로 넘어가는가"를 본다.
  백엔드 API 경로는 백엔드 쪽에서 정하므로 -BackendUrl 로 받는다.
  라운드로빈이면 요청 N건 중 1/N 꼴로 죽은 서버 차례가 오므로, LLM 대수보다 넉넉히(기본 9건) 보낸다.

  판정: 전부 2xx 이고 어떤 요청도 타임아웃되지 않으면 통과.
  어느 서버로 갔는지는 백엔드 로그에서 함께 확인한다 (죽은 서버 → 다음 서버로 재시도했는지).

.EXAMPLE
  .\04-failover.ps1 -BackendUrl "http://192.168.0.126:8080/api/v1/comment/testuser?scope=light" -Down 301B-13
#>
param(
    [Parameter(Mandatory = $true)][string]$BackendUrl,
    [string]$Down = '(기록 안 함)',
    [int]$Count = 9,
    [int]$TimeoutSec = 180
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_common.ps1')
[System.Net.WebRequest]::DefaultWebProxy = New-Object System.Net.WebProxy

$rows = @()
for ($i = 1; $i -le $Count; $i++) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $status = ''
    try {
        $res = Invoke-WebRequest -Uri $BackendUrl -UseBasicParsing -TimeoutSec $TimeoutSec
        $status = [int]$res.StatusCode
    } catch {
        $resp = $_.Exception.Response
        $status = if ($resp) { [int]$resp.StatusCode } else { "오류: $($_.Exception.Message)" }
    }
    $sw.Stop()
    $row = [pscustomobject][ordered]@{ '#' = $i; Status = $status; Seconds = ('{0:N1}' -f $sw.Elapsed.TotalSeconds) }
    $rows += $row
    Write-Host ("{0,2}. {1}  {2}s" -f $i, $row.Status, $row.Seconds)
}

$ok = @($rows | Where-Object { $_.Status -is [int] -and $_.Status -ge 200 -and $_.Status -lt 300 }).Count
$pass = ($ok -eq $Count)
$line = '6 장애 대응 | {0} — 정지한 LLM: {1} · {2}/{3}건 2xx · 최대 {4}s' -f `
    $(if ($pass) { '통과' } else { '실패' }), $Down, $ok, $Count, (($rows | ForEach-Object { [double]$_.Seconds } | Measure-Object -Maximum).Maximum)

$now = Get-Date
$md = @("# Finesse 장애 대응 검증 — $($now.ToString('yyyy-MM-dd HH:mm'))", '', "대상: $BackendUrl", '',
    (ConvertTo-MarkdownTable -Rows $rows -Columns '#', 'Status', 'Seconds'), '', "**$line**")
$dir = New-ResultsDir
$path = Join-Path $dir ("failover_{0}.md" -f $now.ToString('yyyyMMdd-HHmm'))
Write-Utf8Bom -Path $path -Text ($md -join "`r`n")

Write-Host ''
Write-Host $line -ForegroundColor $(if ($pass) { 'Green' } else { 'Red' })
Write-Host "저장: $path  (백엔드 로그에서 다음 서버로 넘어간 기록도 함께 캡처할 것)" -ForegroundColor Cyan
if (-not $pass) { exit 1 }
