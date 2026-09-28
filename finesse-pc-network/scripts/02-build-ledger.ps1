<#
.SYNOPSIS
  PC 대장 생성 (지시서 ②-1). results\precheck-*.json + config\pcs.json → docs\PC대장.md
  시스템을 바꾸지 않는다. 아무 PC에서나 실행 가능 (USB에 결과를 모은 뒤).
#>
[CmdletBinding()]
param([string]$ConfigPath)
. (Join-Path $PSScriptRoot 'common.ps1')

$config = Get-FinesseConfig -Path $ConfigPath
$resultsDir = Get-ResultsDir
$prechecks = @()
foreach ($f in @(Get-ChildItem -Path $resultsDir -Filter 'precheck-*.json' -ErrorAction SilentlyContinue)) {
    try {
        $prechecks += (Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8 | ConvertFrom-Json)
    } catch { Write-Warning "읽기 실패: $($f.Name) — $($_.Exception.Message)" }
}

function Find-Precheck {
    param($Pc)
    $hit = @($prechecks | Where-Object { $_.pcId -eq $Pc.id })
    if ($hit.Count -eq 0) { $hit = @($prechecks | Where-Object { @($_.ipv4 | ForEach-Object { $_.ip }) -contains $Pc.ip }) }
    if ($hit.Count -eq 0) { return $null }
    return ($hit | Sort-Object collectedAt | Select-Object -Last 1)
}

function Esc([string]$s) { if ($null -eq $s) { return '' }; return ($s -replace '\|', '\|') }

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine('# PC 대장')
[void]$sb.AppendLine('')
[void]$sb.AppendLine("> 생성: $(Get-Date -Format 'yyyy-MM-dd HH:mm') · ``scripts/02-build-ledger.ps1`` 자동 생성 — 직접 고치지 말고 ``config/pcs.json`` 수정 후 다시 생성")
[void]$sb.AppendLine("> 기준: $($config.source)")
[void]$sb.AppendLine("> 네트워크: $($config.subnet) · 게이트웨이 $($config.gateway) · DNS $(@($config.dns) -join ' / ')")
$backendText = if ($config.backend) { $config.backend } else { '**미정**' }
$frontendText = if ($config.frontend) { $config.frontend } else { '미정' }
[void]$sb.AppendLine("> 연동 대상 LLM 서버: $(@($config.llmServers) -join ', ') · 백엔드: $backendText · 프론트: $frontendText")
[void]$sb.AppendLine('')
[void]$sb.AppendLine('| PC | 호스트명 | IP | 역할 | 포트 | RAM | GPU | DHCP | 프로필 | 복원 후보 | 비고 |')
[void]$sb.AppendLine('|---|---|---|---|---|---|---|---|---|---|---|')

$missing = 0
foreach ($pc in $config.pcs) {
    $roles = Get-PcRoles -Config $config -Pc $pc
    $ports = @()
    if ($roles -contains 'LLM') { $ports += $config.ports.llm }
    if ($roles -contains 'Backend') { $ports += $config.ports.backend }
    if ($roles -contains 'Frontend') { $ports += $config.ports.frontend }
    $roleText = $pc.role
    if ($roles.Count -gt 0) { $roleText = "**$($roles -join '+')** ($($pc.role))" }
    if ($pc.owner) { $roleText += " · $($pc.owner)" }
    $portText = if ($ports.Count -gt 0) { $ports -join ', ' } else { '—' }

    $p = Find-Precheck -Pc $pc
    $notes = @()
    if (-not $p) {
        $missing++
        $row = @($pc.id, (Esc $pc.hostname), $pc.ip, $roleText, $portText, "$($pc.ramGB)G", $pc.gpu, '미수집', '미수집', '미수집', '미수집')
    } else {
        $teamIp = @($p.ipv4 | Where-Object { $_.inTeamSubnet }) | Select-Object -First 1
        $ipText = $pc.ip
        if (-not $teamIp) { $notes += "배정표: $($pc.ip) / 실측: 팀 서브넷 IP 없음" }
        elseif ($teamIp.ip -ne $pc.ip) { $notes += "IP 배정표: $($pc.ip) / 실측: $($teamIp.ip)"; $ipText = $teamIp.ip }

        $ramText = "$($pc.ramGB)G"
        if ($p.ramGB -and [math]::Abs([int]$p.ramGB - [int]$pc.ramGB) -gt 1) { $notes += "RAM 배정표: $($pc.ramGB)G / 실측: $($p.ramGB)G"; $ramText = "$($p.ramGB)G" }

        $gpuNames = @($p.gpus | ForEach-Object { $_.name })
        $gpuText = if ($gpuNames.Count -gt 0) { $gpuNames -join ' + ' } else { '조회 실패' }
        if (@($gpuNames | Where-Object { $_ -notmatch 'GTX 1050' }).Count -gt 0) { $notes += "GPU 배정표: $($pc.gpu) / 실측: $gpuText" }

        $dhcpText = if ($teamIp) { if ($teamIp.dhcp -eq 'Enabled') { 'DHCP ⚠' } elseif ($teamIp.dhcp -eq 'Disabled') { '고정' } else { $teamIp.dhcp } } else { '—' }
        $profText = (@($p.networkProfiles | ForEach-Object { if ($_.category -eq 'Public') { '공용 ⚠' } elseif ($_.category -eq 'Private') { '개인' } elseif ($_.category -eq 'DomainAuthenticated') { '도메인' } else { $_.category } }) -join ', ')
        if (-not $profText) { $profText = '—' }

        $cands = @($p.restore.candidates | ForEach-Object { $_.name } | Sort-Object -Unique)
        $restoreText = if ($cands.Count -gt 0) { "⚠ " + ($cands -join ', ') } else { '없음' }
        if ($p.restore.marker -and $p.restore.marker.mode -eq 'check') { $notes += "마커: $($p.restore.marker.verdict)" }

        if ($pc.hostname -and $p.computerName -ne $pc.hostname) { $notes += "호스트명 배정표: $($pc.hostname) / 실측: $($p.computerName)" }
        if (-not $p.isAdmin) { $notes += '수집 시 관리자 아님' }
        if ($p.power.standbyAcSec -gt 0 -or $p.power.hibernateAcSec -gt 0) {
            $notes += ("절전 {0}분 / 최대절전 {1}분" -f [math]::Round($p.power.standbyAcSec / 60), [math]::Round($p.power.hibernateAcSec / 60))
        }
        if (@($p.power.shutdownTasks).Count -gt 0) { $notes += "종료 예약작업 $(@($p.power.shutdownTasks).Count)건" }
        $notes += "수집 $($p.collectedAt)"

        $row = @($pc.id, (Esc $p.computerName), $ipText, $roleText, $portText, $ramText, (Esc $gpuText), $dhcpText, $profText, (Esc $restoreText), (Esc ($notes -join '; ')))
    }
    [void]$sb.AppendLine('| ' + ($row -join ' | ') + ' |')
}

[void]$sb.AppendLine('')
[void]$sb.AppendLine("수집 $(@($config.pcs).Count - $missing) / $(@($config.pcs).Count)대 · 미수집 $missing대")
[void]$sb.AppendLine('')
[void]$sb.AppendLine('⚠ 표시는 조치가 필요한 항목이다: DHCP(재부팅 시 IP가 바뀔 수 있음) · 공용 프로필(인바운드 기본 차단) · 복원 후보(설정이 재부팅 때 사라질 수 있음).')

$out = Join-Path (Get-DocsDir) 'PC대장.md'
Write-TextFile -Path $out -Text $sb.ToString()
Write-Host "저장: $out (수집 $(@($config.pcs).Count - $missing)대, 미수집 ${missing}대)"
