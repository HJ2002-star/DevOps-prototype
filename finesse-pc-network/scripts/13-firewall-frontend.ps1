<#
.SYNOPSIS
  프론트(Vite) 개발 PC에서 실행. TCP 5173 인바운드를 팀 PC(pcs.json 의 backendAllow)에만 허용.
  다른 PC에서 Vite 화면을 열어 볼 필요가 없으면 실행하지 않아도 된다.

.DESCRIPTION
  - 대상 PC는 pcs.json 의 "frontend" (비어 있으면 멈춘다)
  - 규칙 이름: Finesse-Frontend-5173-In (같은 이름이 있으면 삭제 후 재생성)

.EXAMPLE
  .\13-firewall-frontend.ps1 -WhatIf
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param([string]$PcId, [string]$ConfigPath)
. (Join-Path $PSScriptRoot 'common.ps1')

Assert-Admin -WhatIfMode ([bool]$WhatIfPreference)
$config = Get-FinesseConfig -Path $ConfigPath
if (-not $config.frontend) {
    Write-Host '[중단] 프론트 PC가 정해지지 않았습니다. config\pcs.json 의 "frontend" 를 채운 뒤 실행하세요.' -ForegroundColor Red
    exit 1
}
$self = Find-SelfPc -Config $config -PcId $PcId
if (-not $self) { Write-Host '[중단] pcs.json에서 이 PC를 찾지 못했습니다. -PcId 301B-xx 를 붙이세요.' -ForegroundColor Red; exit 1 }
if ((Get-PcRoles -Config $config -Pc $self) -notcontains 'Frontend') {
    Write-Host "[중단] $($self.id) 는 프론트 PC($($config.frontend))가 아닙니다." -ForegroundColor Red
    exit 1
}

$port = [int]$config.ports.frontend
$allow = @(@($config.backendAllow) | Where-Object { $_ } | ForEach-Object { Resolve-PcIp -Config $config -Item $_ } |
    Where-Object { $_ -ne $self.ip } | Sort-Object -Unique)
if ($allow.Count -eq 0) { Write-Host '[중단] backendAllow 가 비어 있습니다.' -ForegroundColor Red; exit 1 }

Write-Host "=== $($self.id) 프론트 방화벽: TCP $port ← $($allow.Count)대 ===" -ForegroundColor Cyan
$cmd = Set-FinesseInboundRule -Cmdlet $PSCmdlet -DisplayName "Finesse-Frontend-$port-In" -Port $port -RemoteAddress $allow `
    -Description 'Finesse Vite 개발 서버 인바운드 (팀 PC만 허용)'

Show-ConflictingRules -Rules (Find-ConflictingRules -Port $port -ProgramPattern 'node')

if ($WhatIfPreference) {
    Write-Host ''
    Write-Host '[WhatIf] 실제로 실행할 명령:' -ForegroundColor Yellow
    Write-Host $cmd
    exit 0
}

$summary = @(Get-FinesseRuleSummary)
$summary | Format-Table -AutoSize | Out-String -Width 300 | Write-Host
Add-FirewallLog -PcId $self.id -ScriptName '13-firewall-frontend.ps1' -Command $cmd -Summary $summary
Write-Host '기록: docs\방화벽규칙목록.md, results\firewall-*.txt' -ForegroundColor Green
