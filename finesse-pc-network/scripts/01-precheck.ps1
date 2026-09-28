<#
.SYNOPSIS
  사전 조사 (지시서 ①). 각 PC에서 실행. 시스템을 바꾸지 않는다 (마커 파일 1개만 만든다).

.DESCRIPTION
  수집 항목: 복원 프로그램 후보 / 관리자 권한 / 서브넷 / IP 고정·DHCP / 절전·자동 종료
            + 네트워크 프로필 / GPU / RAM / 8080·8081 사용 여부
  결과: results\precheck-<COMPUTERNAME>.json

  복원 프로그램은 자동 판정이 안 되므로 마커 파일로 확인한다:
    1) 지금 실행 → C:\finesse-marker.txt 생성
    2) 재부팅
    3) .\01-precheck.ps1 -CheckMarker → 마커가 남았는지 판정

.EXAMPLE
  .\01-precheck.ps1
  .\01-precheck.ps1 -CheckMarker
  .\01-precheck.ps1 -PcId 301B-11      # 호스트명·IP로 PC를 못 찾을 때
#>
[CmdletBinding()]
param(
    [string]$PcId,
    [switch]$CheckMarker,
    [string]$ConfigPath
)
. (Join-Path $PSScriptRoot 'common.ps1')

$config = Get-FinesseConfig -Path $ConfigPath
$self = Find-SelfPc -Config $config -PcId $PcId
$risks = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]

Write-Host "=== Finesse 사전 조사: $env:COMPUTERNAME ===" -ForegroundColor Cyan
if ($self) { Write-Host "배정표 PC: $($self.id) ($($self.ip), $($self.role))" }
else {
    Write-Warning 'pcs.json에서 이 PC를 찾지 못했습니다. 다시 실행할 때 -PcId 301B-xx 를 붙이세요.'
    $risks.Add('배정표 PC 미확인')
}

function Invoke-Safe {
    param([scriptblock]$Block, $Default)
    try { & $Block } catch { $Default }
}

# ---------- 1. 복원 프로그램 후보 ----------
$pattern = 'Deep ?Freeze|Faronics|Reboot ?Restore|Shadow ?Defender|Returnil|Rollback|Toolwiz|Time ?Freeze|Freeze|Restore|복원|보안|지킴이|초기화'
# 너무 흔한 윈도우 기본 항목은 후보에서 뺀다
$ignore = '^Windows (보안|Security)|System Restore Service|Windows Defender|Microsoft Defender|SecurityHealth'

$candidates = @()
$uninstallKeys = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
)
foreach ($k in $uninstallKeys) {
    Invoke-Safe {
        Get-ItemProperty -Path $k -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -and $_.DisplayName -match $pattern -and $_.DisplayName -notmatch $ignore } |
            ForEach-Object { $script:candidates += [pscustomobject]@{ source = '설치 프로그램'; name = $_.DisplayName; detail = $_.Publisher } }
    } $null
}
Invoke-Safe {
    Get-Service -ErrorAction SilentlyContinue |
        Where-Object { ($_.Name -match $pattern -or $_.DisplayName -match $pattern) -and $_.DisplayName -notmatch $ignore } |
        ForEach-Object { $script:candidates += [pscustomobject]@{ source = '서비스'; name = $_.DisplayName; detail = "$($_.Name) / $($_.Status)" } }
} $null
Invoke-Safe {
    Get-Process -ErrorAction SilentlyContinue |
        Where-Object { $_.ProcessName -match $pattern -and $_.ProcessName -notmatch $ignore } |
        ForEach-Object { $script:candidates += [pscustomobject]@{ source = '실행 중 프로세스'; name = $_.ProcessName; detail = "PID $($_.Id)" } }
} $null
$candidates = @($candidates | Sort-Object source, name -Unique)
if ($candidates.Count -gt 0) { $risks.Add("복원 후보 $($candidates.Count)건") }

# 마커 파일
$bootTime = Invoke-Safe { (Get-CimInstance Win32_OperatingSystem).LastBootUpTime } $null
$markerPaths = @('C:\finesse-marker.txt', (Join-Path $env:PUBLIC 'finesse-marker.txt'))
$marker = [ordered]@{ mode = $null; path = $null; writtenAt = $null; lastBoot = $null; verdict = $null }
if ($bootTime) { $marker.lastBoot = $bootTime.ToString('yyyy-MM-dd HH:mm:ss') }

if ($CheckMarker) {
    $marker.mode = 'check'
    $existing = $markerPaths | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if (-not $existing) {
        $marker.verdict = '마커 없음 → 재부팅 때 지워짐 (복원 프로그램 있음 추정). 첫 실행에서 마커를 만들었는지도 확인'
        $risks.Add('마커 사라짐(복원 의심)')
    } else {
        $marker.path = $existing
        $text = (Get-Content -LiteralPath $existing -Raw).Trim()
        $written = $null
        try { $written = [datetime]::Parse($text) } catch { }
        if ($written) { $marker.writtenAt = $written.ToString('yyyy-MM-dd HH:mm:ss') }
        if ($written -and $bootTime -and $written -lt $bootTime) {
            $marker.verdict = '마커 유지됨 (재부팅 후에도 남음 → 적어도 이 경로는 복원되지 않음)'
        } elseif ($written -and $bootTime) {
            $marker.verdict = '판정 불가: 마커를 만든 뒤 아직 재부팅하지 않았음'
        } else {
            $marker.verdict = '판정 불가: 마커 내용 또는 부팅 시각을 읽지 못함'
        }
    }
} else {
    $marker.mode = 'write'
    $now = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    foreach ($p in $markerPaths) {
        try {
            Set-Content -LiteralPath $p -Value $now -Encoding ASCII -ErrorAction Stop
            $marker.path = $p; $marker.writtenAt = $now
            $marker.verdict = '마커 작성함. 재부팅 후 -CheckMarker 로 다시 실행'
            break
        } catch { }
    }
    if (-not $marker.path) { $marker.verdict = '마커 작성 실패 (권한 없음)' }
    elseif ($marker.path -ne $markerPaths[0]) { $marker.verdict += " (C:\ 쓰기 권한 없음 → $($marker.path) 사용)" }
}

# ---------- 2. 관리자 권한 ----------
$isAdmin = Test-IsAdmin

# ---------- 3·4. 서브넷 / DHCP ----------
$ipList = @()
foreach ($a in (Get-LocalIPv4)) {
    $dhcp = Invoke-Safe { (Get-NetIPInterface -InterfaceIndex $a.InterfaceIndex -AddressFamily IPv4 -ErrorAction Stop).Dhcp.ToString() } '알 수 없음'
    $ipList += [pscustomobject]@{
        ip = $a.IPAddress; prefixLength = $a.PrefixLength; interface = $a.InterfaceAlias
        interfaceIndex = $a.InterfaceIndex; prefixOrigin = $a.PrefixOrigin.ToString(); dhcp = $dhcp
        inTeamSubnet = (Test-InSubnet -Ip $a.IPAddress -Cidr $config.subnet)
    }
}
$teamIp = $ipList | Where-Object { $_.inTeamSubnet } | Select-Object -First 1
if (-not $teamIp) { $risks.Add("팀 서브넷($($config.subnet)) IP 없음") }
else {
    if ($teamIp.prefixLength -ne [int]$config.subnet.Split('/')[1]) { $warnings.Add("PrefixLength $($teamIp.prefixLength) (예상 $($config.subnet.Split('/')[1]))") }
    if ($teamIp.dhcp -eq 'Enabled') { $risks.Add('DHCP') }
    if ($self -and $teamIp.ip -ne $self.ip) { $risks.Add("IP 불일치(배정표 $($self.ip) / 실측 $($teamIp.ip))") }
}

# ---------- 5. 절전·자동 종료 ----------
$standby = Get-PowerAcSeconds -Setting 'STANDBYIDLE'
$hibernate = Get-PowerAcSeconds -Setting 'HIBERNATEIDLE'
if ($standby -gt 0) { $warnings.Add("절전 $([math]::Round($standby / 60))분") }
if ($hibernate -gt 0) { $warnings.Add("최대 절전 $([math]::Round($hibernate / 60))분") }

$shutdownTasks = @()
Invoke-Safe {
    Get-ScheduledTask -ErrorAction Stop | ForEach-Object {
        $t = $_
        $hit = $t.TaskName -match 'shutdown|종료|poweroff|restart|재부팅'
        foreach ($act in @($t.Actions)) {
            if (($act.Execute -match 'shutdown') -or ($act.Arguments -match 'shutdown')) { $hit = $true }
        }
        if ($hit) {
            $script:shutdownTasks += [pscustomobject]@{
                path = $t.TaskPath + $t.TaskName; state = $t.State.ToString()
                action = (@($t.Actions) | ForEach-Object { "$($_.Execute) $($_.Arguments)".Trim() }) -join ' ; '
            }
        }
    }
} $null
if ($shutdownTasks.Count -gt 0) { $warnings.Add("종료 관련 예약 작업 $($shutdownTasks.Count)건") }

# ---------- + 네트워크 프로필 ----------
$profiles = @(Invoke-Safe {
    Get-NetConnectionProfile -ErrorAction Stop | ForEach-Object {
        [pscustomobject]@{ name = $_.Name; interface = $_.InterfaceAlias; category = $_.NetworkCategory.ToString() }
    }
} @())
if ($profiles | Where-Object { $_.category -eq 'Public' }) { $risks.Add('공용 프로필') }

# ---------- + GPU ----------
$gpus = @(Invoke-Safe {
    Get-CimInstance Win32_VideoController -ErrorAction Stop | ForEach-Object {
        [pscustomobject]@{ name = $_.Name; driverVersion = $_.DriverVersion; adapterRamMB = [math]::Round($_.AdapterRAM / 1MB) }
    }
} @())
$otherGpu = @($gpus | Where-Object { $_.name -notmatch 'GTX 1050' })
if ($gpus.Count -eq 0) { $risks.Add('GPU 조회 실패') }
elseif ($otherGpu.Count -gt 0) { $risks.Add("GTX 1050 아닌 GPU: $(($otherGpu | ForEach-Object { $_.name }) -join ', ')") }

# ---------- + RAM ----------
$ramBytes = Invoke-Safe { (Get-CimInstance Win32_ComputerSystem -ErrorAction Stop).TotalPhysicalMemory } $null
$ramGB = $null
if ($ramBytes) { $ramGB = [math]::Round($ramBytes / 1GB) }
if ($self -and $ramGB -and [math]::Abs($ramGB - [int]$self.ramGB) -gt 1) { $risks.Add("RAM 불일치(배정표 $($self.ramGB)G / 실측 ${ramGB}G)") }

# ---------- + 포트 사용 여부 ----------
$listening = @()
foreach ($port in @($config.ports.backend, $config.ports.llm, $config.ports.frontend)) {
    Invoke-Safe {
        Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction Stop | ForEach-Object {
            $procName = Invoke-Safe { (Get-Process -Id $_.OwningProcess -ErrorAction Stop).ProcessName } '?'
            $script:listening += [pscustomobject]@{ port = $port; localAddress = $_.LocalAddress; process = $procName; pid = $_.OwningProcess }
        }
    } $null
}

# ---------- 저장 ----------
$result = [ordered]@{
    collectedAt   = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    computerName  = $env:COMPUTERNAME
    pcId          = $(if ($self) { $self.id } else { $null })
    user          = $env:USERNAME
    isAdmin       = $isAdmin
    restore       = [ordered]@{ candidates = $candidates; marker = $marker }
    ipv4          = $ipList
    power         = [ordered]@{ standbyAcSec = $standby; hibernateAcSec = $hibernate; shutdownTasks = $shutdownTasks }
    networkProfiles = $profiles
    gpus          = $gpus
    ramGB         = $ramGB
    listening     = $listening
    risks         = @($risks)
    warnings      = @($warnings)
}
$out = Join-Path (Get-ResultsDir) ("precheck-{0}.json" -f $env:COMPUTERNAME)
# -CheckMarker 는 기존 결과에 마커 판정만 덧붙이는 게 아니라 전체를 다시 수집해 덮어쓴다.
Save-Json -Path $out -Object $result

# ---------- 콘솔 출력 ----------
Write-Host ''
Write-Host ("관리자 권한   : {0}" -f $(if ($isAdmin) { '예' } else { '아니오' }))
foreach ($i in $ipList) { Write-Host ("IPv4          : {0}/{1} [{2}] DHCP={3}" -f $i.ip, $i.prefixLength, $i.interface, $i.dhcp) }
foreach ($p in $profiles) { Write-Host ("네트워크 프로필: {0} ({1})" -f $p.category, $p.interface) }
Write-Host ("절전/최대절전 : {0} / {1} (초, 0=안 함)" -f $standby, $hibernate)
foreach ($g in $gpus) { Write-Host ("GPU           : {0} (드라이버 {1})" -f $g.name, $g.driverVersion) }
Write-Host ("RAM           : {0} GB" -f $ramGB)
foreach ($c in $candidates) { Write-Host ("복원 후보     : [{0}] {1} {2}" -f $c.source, $c.name, $c.detail) -ForegroundColor Yellow }
Write-Host ("마커          : {0}" -f $marker.verdict)
foreach ($l in $listening) { Write-Host ("포트 사용 중  : {0} {1} ({2}, PID {3})" -f $l.port, $l.localAddress, $l.process, $l.pid) }
foreach ($t in $shutdownTasks) { Write-Host ("종료 예약작업 : {0} [{1}] {2}" -f $t.path, $t.state, $t.action) -ForegroundColor Yellow }
Write-Host ''
Write-Host "저장: $out"
Write-Host ''
if ($risks.Count -eq 0) { Write-Host '요약: 위험 항목 없음' -ForegroundColor Green }
else { Write-Host ('요약: ' + ($risks -join ' / ')) -ForegroundColor Red }
if ($warnings.Count -gt 0) { Write-Host ('참고: ' + ($warnings -join ' / ')) -ForegroundColor Yellow }
