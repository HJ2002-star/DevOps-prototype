<#
.SYNOPSIS
  ②-4 방화벽 인바운드 규칙 + ②-5 절전 해제를 한 번에 적용한다. (관리자 권한 필요)
  몇 번을 다시 돌려도 결과가 같다 → 재부팅 초기화 PC에서는 부팅 후 이것만 다시 돌리면 된다.

.DESCRIPTION
  pcs.csv에서 "이 PC"의 역할(Role)을 찾아 해당하는 규칙만 만든다.
    LLM / LLM_STANDBY : TCP <Port>(8081) ← BACKEND PC만 허용
                        + 이 PC의 LlmClient 칸이 채워져 있으면, LlmClient 칸이 채워진 다른 PC끼리도 서로 허용
                        (예: 11·13에 "임시(튜닝)" → 11↔13만 연결, 14는 그대로. 칸을 비우고 재실행하면 회수된다)
    BACKEND           : TCP <Port>(8080) ← 대장의 팀 PC 전체 허용
    FRONTEND          : TCP <Port>(5173) ← 대장의 팀 PC 전체 허용
    DEV / AUX         : 규칙 없음 (기존 Finesse 규칙만 정리)
  - 규칙은 모두 그룹 "Finesse"로 만들고, 실행할 때마다 그룹을 지운 뒤 다시 만든다.
  - -Profile Any 로 만든다 → 네트워크 프로필이 "공용(Public)"이어도 적용된다.
  - 출발지(RemoteAddress)는 항상 팀 PC IP로 제한한다. llama-server는 인증이 없기 때문.
  - 서버 역할(LLM/LLM_STANDBY/BACKEND)이면 AC 전원 절전·최대 절전을 끈다.

.PARAMETER Pc          대장의 PC 번호(예: 301B-11). 생략하면 로컬 IP로 찾는다.
.PARAMETER AllowPing   ping(ICMPv4 에코)도 팀 PC에서만 허용 → 검증 1단계를 의미 있게 만든다.
.PARAMETER RemoveConflictingBlocks  llama-server/java/node 를 막는 "차단" 규칙을 지운다.
                       (처음 서버를 띄울 때 뜨는 Windows 방화벽 팝업에서 "취소"를 누르면 차단 규칙이 생기고,
                        차단 규칙은 허용 규칙보다 우선한다.)
.PARAMETER SkipPower   절전 설정을 건드리지 않는다.
.PARAMETER DryRun      실제로 바꾸지 않고, 실행할 명령만 출력한다.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\02-apply-firewall.ps1 -AllowPing
#>
param(
    [string]$Pc,
    [string]$CsvPath,
    [switch]$AllowPing,
    [switch]$RemoveConflictingBlocks,
    [switch]$SkipPower,
    [switch]$DryRun
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_common.ps1')
if (-not $DryRun) { Assert-Admin }

$pcs = Get-FinessePcs -Path $CsvPath
$self = Resolve-SelfPc -Pcs $pcs -Name $Pc
$teamIps = @($pcs | ForEach-Object { $_.IP })
$backendIps = @($pcs | Where-Object { $_.Role -eq 'BACKEND' } | ForEach-Object { $_.IP })
$llmClientIps = @()
if ($self.LlmClient) { $llmClientIps = @($pcs | Where-Object { $_.LlmClient -and $_.PC -ne $self.PC } | ForEach-Object { $_.IP }) }

Write-Host ("이 PC: {0} ({1}) · 역할 {2} · 포트 {3}" -f $self.PC, $self.IP, $self.Role, $self.Port) -ForegroundColor Cyan

# ---- 만들 규칙 결정 ----------------------------------------------------------
$rules = @()
switch ($self.Role) {
    { $_ -in 'LLM', 'LLM_STANDBY' } {
        if ($backendIps.Count -eq 0) { throw 'pcs.csv에 Role=BACKEND 행이 없습니다. 백엔드 PC를 먼저 정하세요.' }
        $rules += @{ Name = 'Finesse LLM'; Port = $self.Port; From = $backendIps }
        if ($llmClientIps.Count -gt 0) {
            $rules += @{ Name = 'Finesse LLM Client (임시)'; Port = $self.Port; From = $llmClientIps }
        }
    }
    'BACKEND'  { $rules += @{ Name = 'Finesse Backend'; Port = $self.Port; From = $teamIps } }
    'FRONTEND' { $rules += @{ Name = 'Finesse Frontend'; Port = $self.Port; From = $teamIps } }
    default    { Write-Host '서버 역할이 아니므로 인바운드 규칙을 만들지 않습니다.' }
}

$log = @()
$log += "# Finesse 방화벽 적용 기록 — $($self.PC) ($($self.IP)) · 역할 $($self.Role) · $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
$log += "Get-NetFirewallRule -Group '$RuleGroup' -ErrorAction SilentlyContinue | Remove-NetFirewallRule"

if (-not $DryRun) {
    Get-NetFirewallRule -Group $RuleGroup -ErrorAction SilentlyContinue | Remove-NetFirewallRule
}

foreach ($r in $rules) {
    if (-not $r.Port) { throw "pcs.csv의 $($self.PC) 행에 Port가 비어 있습니다." }
    $cmd = "New-NetFirewallRule -DisplayName '$($r.Name)' -Group '$RuleGroup' -Direction Inbound -Protocol TCP -LocalPort $($r.Port) -RemoteAddress $($r.From -join ',') -Action Allow -Profile Any"
    $log += $cmd
    if (-not $DryRun) {
        New-NetFirewallRule -DisplayName $r.Name -Group $RuleGroup -Direction Inbound -Protocol TCP `
            -LocalPort ([int]$r.Port) -RemoteAddress $r.From -Action Allow -Profile Any | Out-Null
    }
}

if ($AllowPing) {
    $cmd = "New-NetFirewallRule -DisplayName 'Finesse Ping' -Group '$RuleGroup' -Direction Inbound -Protocol ICMPv4 -IcmpType 8 -RemoteAddress $($teamIps -join ',') -Action Allow -Profile Any"
    $log += $cmd
    if (-not $DryRun) {
        New-NetFirewallRule -DisplayName 'Finesse Ping' -Group $RuleGroup -Direction Inbound -Protocol ICMPv4 -IcmpType 8 `
            -RemoteAddress $teamIps -Action Allow -Profile Any | Out-Null
    }
}

# ---- 차단 규칙 충돌 확인 -----------------------------------------------------
$blockers = @(Get-NetFirewallRule -Direction Inbound -Action Block -Enabled True -ErrorAction SilentlyContinue | Where-Object {
    $app = $_ | Get-NetFirewallApplicationFilter
    $app.Program -match 'llama-server|java|node\.exe'
})
if ($blockers.Count -gt 0) {
    Write-Host '⚠ 서버 프로그램을 막는 차단 규칙이 있습니다 (차단이 허용보다 우선):' -ForegroundColor Yellow
    $blockers | ForEach-Object { Write-Host ("   - {0}  [{1}]" -f $_.DisplayName, ($_ | Get-NetFirewallApplicationFilter).Program) }
    if ($RemoveConflictingBlocks -and -not $DryRun) {
        $blockers | Remove-NetFirewallRule
        $log += '# 충돌 차단 규칙 삭제: ' + (($blockers | ForEach-Object { $_.DisplayName }) -join ', ')
        Write-Host '   → 삭제했습니다.' -ForegroundColor Green
    } else {
        Write-Host '   → -RemoveConflictingBlocks 를 붙여 다시 실행하면 지웁니다.'
    }
}

# ---- ②-5 절전 해제 -------------------------------------------------------
if (-not $SkipPower -and $self.Role -in 'LLM', 'LLM_STANDBY', 'BACKEND') {
    $powerCmds = @('powercfg /change standby-timeout-ac 0', 'powercfg /change hibernate-timeout-ac 0')
    foreach ($c in $powerCmds) {
        $log += $c
        if (-not $DryRun) { cmd /c $c | Out-Null }
    }
}

# ---- 결과 ------------------------------------------------------------------
$profiles = (Get-NetConnectionProfile -ErrorAction SilentlyContinue | ForEach-Object { "$($_.InterfaceAlias)=$($_.NetworkCategory)" }) -join '; '
$log += "# 네트워크 프로필: $profiles (규칙이 -Profile Any 이므로 Public이어도 적용됨)"

if (-not $DryRun) {
    $applied = Get-NetFirewallRule -Group $RuleGroup -ErrorAction SilentlyContinue | ForEach-Object {
        $pf = $_ | Get-NetFirewallPortFilter
        $af = $_ | Get-NetFirewallAddressFilter
        '# 적용됨: {0} | {1} {2} | from {3} | {4}' -f $_.DisplayName, $pf.Protocol, $pf.LocalPort, ($af.RemoteAddress -join ','), $_.Profile
    }
    $log += $applied
    $dir = New-ResultsDir
    $path = Join-Path $dir ("firewall_{0}_{1}.txt" -f $self.PC, (Get-Date -Format 'yyyyMMdd-HHmm'))
    Write-Utf8Bom -Path $path -Text ($log -join "`r`n")
    Write-Host "기록 저장: $path" -ForegroundColor Cyan
}
$log | ForEach-Object { Write-Host $_ }

if ($self.Role -in 'LLM', 'LLM_STANDBY') {
    Write-Host ''
    Write-Host "잊지 말 것: llama-server 는 --host 0.0.0.0 --port $($self.Port) 로 띄워야 한다 (start-llama-server.ps1)." -ForegroundColor Yellow
}
