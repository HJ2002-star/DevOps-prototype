<#
.SYNOPSIS
  LLM 서버 PC에서 실행 (지시서 ②-4). TCP 8081 인바운드를 백엔드 PC(+ extraLlmAllow)에만 허용.

.DESCRIPTION
  - 규칙 이름: Finesse-LLM-8081-In (같은 이름이 있으면 삭제 후 재생성 → 여러 번 실행해도 안전)
  - 허용 IP: pcs.json 의 backend + extraLlmAllow. 둘 다 비어 있으면 적용하지 않고 멈춘다.
  - 네트워크 프로필은 바꾸지 않는다. 규칙에 Domain,Private,Public 을 모두 명시한다.
  - 실행한 명령과 결과를 docs\방화벽규칙목록.md 에 덧붙인다.
  - -ServerExe : llama-server.exe 경로를 주면 같은 조건의 프로그램 규칙(Finesse-LLM-App-In)도 만든다.
    프로그램 규칙이 있으면 첫 실행 때 "Windows 보안 경고" 창이 뜨지 않는다 (20-start-llm.ps1 전에 실행 권장).
  - -RemoveAppRules : 보안 경고 창이 이미 만든 llama 관련 규칙(차단 규칙, 원격 주소 제한 없는 허용 규칙)을 지운다.
    지우기 전에 목록이 출력되므로 -WhatIf 로 먼저 확인한다.

.EXAMPLE
  .\10-firewall-llm.ps1 -WhatIf     # 무엇을 할지 보기만 (관리자 없이도 됨)
  .\10-firewall-llm.ps1 -ServerExe 'C:\llama.cpp\build\bin\Release\llama-server.exe'
  .\10-firewall-llm.ps1 -RemoveAppRules -WhatIf
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$ServerExe,
    [switch]$RemoveAppRules,
    [string]$PcId,
    [string]$ConfigPath
)
. (Join-Path $PSScriptRoot 'common.ps1')

Assert-Admin -WhatIfMode ([bool]$WhatIfPreference)
$config = Get-FinesseConfig -Path $ConfigPath
$self = Find-SelfPc -Config $config -PcId $PcId
if (-not $self) { Write-Host '[중단] pcs.json에서 이 PC를 찾지 못했습니다. -PcId 301B-xx 를 붙이세요.' -ForegroundColor Red; exit 1 }
if ((Get-PcRoles -Config $config -Pc $self) -notcontains 'LLM') {
    Write-Host "[중단] $($self.id) 는 llmServers($(@($config.llmServers) -join ', '))에 없습니다." -ForegroundColor Red
    exit 1
}

$port = [int]$config.ports.llm
$allow = @()
if ($config.backend) { $allow += (Resolve-PcIp -Config $config -Item $config.backend) }
foreach ($x in @($config.extraLlmAllow)) { if ($x) { $allow += (Resolve-PcIp -Config $config -Item $x) } }
$allow = @($allow | Where-Object { $_ -ne $self.ip } | Sort-Object -Unique)
if ($allow.Count -eq 0) {
    Write-Host '[중단] 8081 을 허용할 IP가 없습니다.' -ForegroundColor Red
    Write-Host '  config\pcs.json 의 "backend" 에 백엔드 PC(예: "301B-26")를 넣거나,'
    Write-Host '  임시 검증용이면 "extraLlmAllow" 에 검증할 PC(예: ["301B-12"])를 넣은 뒤 다시 실행하세요.'
    exit 1
}

Write-Host "=== $($self.id) LLM 방화벽: TCP $port ← $($allow -join ', ') ===" -ForegroundColor Cyan

$profiles = @(Get-NetConnectionProfile -ErrorAction SilentlyContinue)
foreach ($p in $profiles) {
    if ($p.NetworkCategory.ToString() -eq 'Public') {
        Write-Warning "네트워크 '$($p.InterfaceAlias)' 가 공용 프로필입니다. 프로필은 바꾸지 않고 규칙에 Public 을 포함합니다."
    }
}

if ($ServerExe -and -not (Test-Path -LiteralPath $ServerExe)) {
    Write-Host "[중단] 파일이 없습니다: $ServerExe" -ForegroundColor Red; exit 1
}

$cmd = Set-FinesseInboundRule -Cmdlet $PSCmdlet -DisplayName "Finesse-LLM-$port-In" -Port $port -RemoteAddress $allow `
    -Description 'Finesse llama-server 인바운드 (백엔드 PC만 허용)'
if ($ServerExe) {
    $exe = (Resolve-Path -LiteralPath $ServerExe).Path
    $cmd += "`r`n" + (Set-FinesseInboundRule -Cmdlet $PSCmdlet -DisplayName 'Finesse-LLM-App-In' -Port $port -RemoteAddress $allow `
        -Program $exe -Description 'Finesse llama-server 프로그램 규칙 (보안 경고 창 방지)')
}

$conflicts = @(Find-ConflictingRules -Port $port -ProgramPattern 'llama')
Show-ConflictingRules -Rules $conflicts
if ($conflicts.Count -gt 0) {
    if ($RemoveAppRules) {
        foreach ($c in $conflicts) {
            if ($PSCmdlet.ShouldProcess("방화벽 규칙 '$($c.DisplayName)' ($($c.Action), $($c.Program))", '삭제')) {
                Remove-NetFirewallRule -Name $c.Name -WhatIf:$false
                $cmd += "`r`nRemove-NetFirewallRule -Name '$($c.Name)'   # $($c.DisplayName) ($($c.Action))"
            }
        }
    } else {
        Write-Host '  → llama-server 첫 실행 때 "Windows 보안 경고" 창이 만든 규칙일 수 있습니다.'
        Write-Host '    목록 확인: .\10-firewall-llm.ps1 -RemoveAppRules -WhatIf   /  삭제: .\10-firewall-llm.ps1 -RemoveAppRules'
    }
}

if ($WhatIfPreference) {
    Write-Host ''
    Write-Host '[WhatIf] 실제로 실행할 명령:' -ForegroundColor Yellow
    Write-Host $cmd
    exit 0
}

$summary = @(Get-FinesseRuleSummary)
$summary | Format-Table -AutoSize | Out-String -Width 300 | Write-Host
Add-FirewallLog -PcId $self.id -ScriptName '10-firewall-llm.ps1' -Command $cmd -Summary $summary
Write-Host '기록: docs\방화벽규칙목록.md, results\firewall-*.txt' -ForegroundColor Green
