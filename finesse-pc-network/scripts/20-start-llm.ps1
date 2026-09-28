<#
.SYNOPSIS
  llama-server 를 0.0.0.0:8081 로 기동한다 (지시서 ②-3). LLM 서버 PC에서 실행.

.DESCRIPTION
  - --host 0.0.0.0 --port 8081 은 스크립트가 붙인다. 127.0.0.1 바인딩이 가장 흔한 실패 원인이다.
  - llama-server 경로·모델 경로·GPU 레이어 등 나머지 인자는 추측하지 않고 파라미터로 받는다.
    기존에 실측한 설정(-ngl 등)을 -ExtraArgs 로 그대로 넘긴다.
  - 표준 출력과 에러를 합쳐 results\llm-<PC>-<시각>.log 에 남긴다.
    검증 4단계에서 이 로그의 'offloaded 29/29 layers' 를 확인한다.
  - 관리자 권한은 필요 없다 (시스템 설정을 바꾸지 않음).

.EXAMPLE
  .\20-start-llm.ps1 -ServerExe 'C:\llama.cpp\build\bin\Release\llama-server.exe' `
                     -ModelPath 'C:\models\model.gguf' -ExtraArgs '-ngl','99'
  .\20-start-llm.ps1 ... -WhatIf     # 실행할 명령만 출력
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)] [string]$ServerExe,
    [Parameter(Mandatory = $true)] [string]$ModelPath,
    [string[]]$ExtraArgs = @(),
    [int]$WaitSeconds = 180,
    [string]$PcId,
    [string]$ConfigPath
)
. (Join-Path $PSScriptRoot 'common.ps1')

$config = Get-FinesseConfig -Path $ConfigPath
$self = Find-SelfPc -Config $config -PcId $PcId
$pcName = $env:COMPUTERNAME
if ($self) { $pcName = $self.id }
if (-not $self -or (Get-PcRoles -Config $config -Pc $self) -notcontains 'LLM') {
    Write-Warning "이 PC($pcName)는 pcs.json 의 llmServers 에 없습니다. 계속하지만 검증 대상에는 포함되지 않습니다."
}
$port = [int]$config.ports.llm

foreach ($p in @($ServerExe, $ModelPath)) {
    if (-not (Test-Path -LiteralPath $p)) { Write-Host "[중단] 파일이 없습니다: $p" -ForegroundColor Red; exit 1 }
}
foreach ($a in $ExtraArgs) {
    if ($a -match '^--?(host|port)$' -or $a -match '^--(host|port)=') {
        Write-Host "[중단] -ExtraArgs 에 '$a' 를 넣지 마세요. --host 0.0.0.0 --port $port 는 스크립트가 붙입니다." -ForegroundColor Red
        exit 1
    }
}

$busy = @(Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction SilentlyContinue)
if ($busy.Count -gt 0) {
    $procName = (Get-Process -Id $busy[0].OwningProcess -ErrorAction SilentlyContinue).ProcessName
    Write-Host "[중단] 포트 $port 를 이미 사용 중입니다: $procName (PID $($busy[0].OwningProcess), $($busy[0].LocalAddress))" -ForegroundColor Red
    Write-Host '  이미 떠 있는 llama-server 라면 그대로 쓰거나, 작업 관리자에서 끝낸 뒤 다시 실행하세요.'
    exit 1
}

function Quote([string]$s) { if ($s -match '[\s"]') { return '"' + ($s -replace '"', '\"') + '"' } return $s }

$argList = @('-m', $ModelPath, '--host', '0.0.0.0', '--port', "$port") + $ExtraArgs
$argText = ($argList | ForEach-Object { Quote $_ }) -join ' '
$log = Join-Path (Get-ResultsDir) ("llm-{0}-{1}.log" -f $pcName, (Get-Date -Format 'yyyyMMdd-HHmm'))
# stdout 과 stderr 를 한 파일에 합치기 위해 cmd 로 감싼다 (Start-Process 는 두 파일로만 나눠 받을 수 있음)
$cmdLine = '/s /c ""{0}" {1} > "{2}" 2>&1"' -f $ServerExe, $argText, $log

Write-Host "=== $pcName llama-server 기동 ===" -ForegroundColor Cyan
Write-Host ("명령: {0} {1}" -f (Quote $ServerExe), $argText)
Write-Host "로그: $log"

if (-not $PSCmdlet.ShouldProcess("llama-server (0.0.0.0:$port)", '기동')) { exit 0 }

Write-TextFile -Path $log -Text ''
$proc = Start-Process -FilePath $env:ComSpec -ArgumentList $cmdLine -WindowStyle Minimized -PassThru
Write-Host "기동함 (cmd PID $($proc.Id)). /health 응답을 최대 ${WaitSeconds}초 기다립니다..."

$ok = $false
$deadline = (Get-Date).AddSeconds($WaitSeconds)
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 3
    if ($proc.HasExited) { break }
    try {
        $r = Invoke-RestMethod -Uri "http://127.0.0.1:$port/health" -TimeoutSec 3 -UseBasicParsing
        if ($r.status -eq 'ok') { $ok = $true; break }
    } catch { }
}

$logText = ''
try { $logText = Get-Content -LiteralPath $log -Raw -ErrorAction Stop } catch { }
$offload = [regex]::Match([string]$logText, 'offloaded \d+/\d+ layers[^\r\n]*')

Write-Host ''
if ($ok) { Write-Host "health: ok" -ForegroundColor Green }
elseif ($proc.HasExited) { Write-Host "[실패] llama-server 가 종료되었습니다. 로그 마지막 부분:" -ForegroundColor Red }
else { Write-Host "[주의] ${WaitSeconds}초 안에 health ok 가 오지 않았습니다 (모델 로딩 중일 수 있음)." -ForegroundColor Yellow }

if ($offload.Success) { Write-Host "GPU: $($offload.Value)" -ForegroundColor Green }
else { Write-Host 'GPU: 로그에서 "offloaded N/N layers" 를 찾지 못함 — 로그를 직접 확인하세요.' -ForegroundColor Yellow }

$listen = @(Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction SilentlyContinue)
foreach ($l in $listen) {
    $color = 'Green'
    if ($l.LocalAddress -eq '127.0.0.1') { $color = 'Red' }
    Write-Host ("수신 대기: {0}:{1}" -f $l.LocalAddress, $l.LocalPort) -ForegroundColor $color
}

if (-not $ok) {
    ([string]$logText -split "`r?`n" | Select-Object -Last 15) | ForEach-Object { Write-Host "  $_" }
}
Write-Host ''
Write-Host '"Windows 보안 경고" 창이 떴다면 어느 버튼을 눌렀든 .\10-firewall-llm.ps1 -RemoveAppRules 로 그 창이 만든 규칙을 정리하세요.'
Write-Host '  ([취소] = 차단 규칙 → 연결 막힘, [액세스 허용] = 원격 주소 제한 없는 허용 → 보안 구멍)'
Write-Host '  창을 아예 안 띄우려면 기동 전에 .\10-firewall-llm.ps1 -ServerExe <llama-server.exe 경로> 로 프로그램 규칙을 만들어 두세요.'
Write-Host '끄려면: 작업 관리자에서 llama-server.exe 끝내기, 또는 Stop-Process -Name llama-server'
