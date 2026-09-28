<#
.SYNOPSIS
  백엔드 PC에서 실행 (지시서 ②-4). TCP 8080 인바운드를 팀 PC(pcs.json 의 backendAllow)에만 허용.

.DESCRIPTION
  - 규칙 이름: Finesse-Backend-8080-In (같은 이름이 있으면 삭제 후 재생성)
  - pcs.json 의 "backend" 가 비어 있으면 적용하지 않고 멈춘다.
  - 실행한 명령과 결과를 docs\방화벽규칙목록.md 에 덧붙인다.

.EXAMPLE
  .\11-firewall-backend.ps1 -WhatIf
  .\11-firewall-backend.ps1
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param([string]$PcId, [string]$ConfigPath)
. (Join-Path $PSScriptRoot 'common.ps1')

Assert-Admin -WhatIfMode ([bool]$WhatIfPreference)
$config = Get-FinesseConfig -Path $ConfigPath
if (-not $config.backend) {
    Write-Host '[중단] 백엔드 PC가 아직 정해지지 않았습니다. config\pcs.json 의 "backend" 를 채운 뒤 실행하세요.' -ForegroundColor Red
    exit 1
}
$self = Find-SelfPc -Config $config -PcId $PcId
if (-not $self) { Write-Host '[중단] pcs.json에서 이 PC를 찾지 못했습니다. -PcId 301B-xx 를 붙이세요.' -ForegroundColor Red; exit 1 }
if ((Get-PcRoles -Config $config -Pc $self) -notcontains 'Backend') {
    Write-Host "[중단] $($self.id) 는 백엔드 PC($($config.backend))가 아닙니다." -ForegroundColor Red
    exit 1
}

$port = [int]$config.ports.backend
$allow = @(@($config.backendAllow) | Where-Object { $_ } | ForEach-Object { Resolve-PcIp -Config $config -Item $_ } |
    Where-Object { $_ -ne $self.ip } | Sort-Object -Unique)
if ($allow.Count -eq 0) { Write-Host '[중단] backendAllow 가 비어 있습니다.' -ForegroundColor Red; exit 1 }

Write-Host "=== $($self.id) 백엔드 방화벽: TCP $port ← $($allow.Count)대 ===" -ForegroundColor Cyan
foreach ($p in @(Get-NetConnectionProfile -ErrorAction SilentlyContinue)) {
    if ($p.NetworkCategory.ToString() -eq 'Public') {
        Write-Warning "네트워크 '$($p.InterfaceAlias)' 가 공용 프로필입니다. 프로필은 바꾸지 않고 규칙에 Public 을 포함합니다."
    }
}

$cmd = Set-FinesseInboundRule -Cmdlet $PSCmdlet -DisplayName "Finesse-Backend-$port-In" -Port $port -RemoteAddress $allow `
    -Description 'Finesse 스프링 부트 인바운드 (팀 PC만 허용)'

Show-ConflictingRules -Rules (Find-ConflictingRules -Port $port -ProgramPattern 'java')

if ($WhatIfPreference) {
    Write-Host ''
    Write-Host '[WhatIf] 실제로 실행할 명령:' -ForegroundColor Yellow
    Write-Host $cmd
    exit 0
}

$summary = @(Get-FinesseRuleSummary)
$summary | Format-Table -AutoSize | Out-String -Width 300 | Write-Host
Add-FirewallLog -PcId $self.id -ScriptName '11-firewall-backend.ps1' -Command $cmd -Summary $summary
Write-Host '기록: docs\방화벽규칙목록.md, results\firewall-*.txt' -ForegroundColor Green
