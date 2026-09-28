<#
.SYNOPSIS
  ① 사전 조사 — 설정 전에 각 PC에서 1회씩 실행한다. (관리자 권한 권장, 없어도 실행됨)

.DESCRIPTION
  지시서 ①의 5개 항목을 한 번에 수집해 results\precheck_<PC>_<시각>.csv / .txt 로 남긴다.
    1. 재부팅 초기화 여부  — 복원 프로그램 후보 탐지 + "재부팅 마커" (아래 사용법 참고)
    2. 관리자 권한        — 현재 세션이 관리자인지
    3. 같은 서브넷인가    — IP / 서브넷 마스크 / 게이트웨이
    4. 고정 IP / DHCP     — DHCP 사용 여부, 임대 시각
    5. 절전·자동 종료     — AC 절전/최대 절전 시간, 종료 예약 작업
  덤으로 PC 대장에 필요한 호스트명·RAM·GPU, 방화벽 설정에 필요한 네트워크 프로필도 모은다.

  재부팅 초기화 확인 방법:
    (1) 이 스크립트를 실행한다  → 마커 파일(+관리자면 비활성 방화벽 규칙)을 남긴다
    (2) PC를 재부팅한다
    (3) 이 스크립트를 다시 실행한다 → "RebootMarker" 칸이 '유지됨'이면 초기화 없음,
        '없음'이면 복원 프로그램이 있는 것 → 즉시 PM에게 보고

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\01-precheck.ps1
#>
param(
    [string]$Pc,
    [string]$CsvPath
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_common.ps1')

function Try-Get([scriptblock]$Block, $Default = '확인 실패') {
    try { & $Block } catch { $Default }
}

$now = Get-Date
$isAdmin = Test-Admin

# ---- 대장 매칭 -------------------------------------------------------------
$pcs = Get-FinessePcs -Path $CsvPath
$self = $null
try { $self = Resolve-SelfPc -Pcs $pcs -Name $Pc } catch { }
$pcName = if ($self) { $self.PC } else { '대장에없음' }

# ---- 하드웨어 --------------------------------------------------------------
$cs = Get-CimInstance Win32_ComputerSystem
$ramGB = [math]::Round($cs.TotalPhysicalMemory / 1GB)
$gpus = (Get-CimInstance Win32_VideoController | ForEach-Object { $_.Name }) -join '; '
$gpuNote = if ($gpus -match 'GTX 1050') { '' } else { '⚠ GTX 1050 아님 — PM 보고 (LLM 빌드 조건 달라짐)' }
$ramNote = ''
if ($self -and $self.RAM_GB -and ([int]$self.RAM_GB -ne $ramGB)) { $ramNote = "⚠ 대장($($self.RAM_GB)GB)과 다름" }

# ---- 네트워크 (3, 4) -------------------------------------------------------
$nic = Get-CimInstance Win32_NetworkAdapterConfiguration -Filter 'IPEnabled=TRUE' |
    Where-Object { $_.DefaultIPGateway } | Select-Object -First 1
$ip = ''; $mask = ''; $gw = ''; $dhcp = ''; $dhcpServer = ''; $leaseObtained = ''; $leaseExpires = ''
if ($nic) {
    $ip = ($nic.IPAddress | Where-Object { $_ -match '^\d+\.\d+\.\d+\.\d+$' } | Select-Object -First 1)
    $mask = ($nic.IPSubnet | Where-Object { $_ -match '^\d+\.\d+\.\d+\.\d+$' } | Select-Object -First 1)
    $gw = ($nic.DefaultIPGateway | Where-Object { $_ -match '^\d+\.' }) -join ','
    $dhcp = if ($nic.DHCPEnabled) { 'DHCP' } else { '고정' }
    if ($nic.DHCPEnabled) {
        $dhcpServer = $nic.DHCPServer
        $leaseObtained = Try-Get { $nic.DHCPLeaseObtained.ToString('yyyy-MM-dd HH:mm') } ''
        $leaseExpires = Try-Get { $nic.DHCPLeaseExpires.ToString('yyyy-MM-dd HH:mm') } ''
    }
}
$ipNote = ''
if ($self -and $ip -and $ip -ne $self.IP) { $ipNote = "⚠ 대장 IP($($self.IP))와 다름" }
if (-not $self) { $ipNote = '⚠ 이 IP가 pcs.csv에 없음 — IP가 바뀌었을 수 있음(DHCP)' }

$netProfile = Try-Get { (Get-NetConnectionProfile | ForEach-Object { "$($_.InterfaceAlias)=$($_.NetworkCategory)" }) -join '; ' }

# 학교 GPO가 로컬 방화벽 규칙을 무시하게 해 두었는지 (False면 우리가 만든 규칙이 안 먹는다)
$fwLocalRules = Try-Get {
    (Get-NetFirewallProfile -PolicyStore ActiveStore | ForEach-Object { "$($_.Name):Enabled=$($_.Enabled),LocalRules=$($_.AllowLocalFirewallRules)" }) -join '; '
}

# ---- 절전·자동 종료 (5) -----------------------------------------------------
function Get-PowerAcMinutes([string]$Sub, [string]$Setting) {
    $out = powercfg /query SCHEME_CURRENT $Sub $Setting 2>$null
    # 한국어("현재 AC 전원 설정 인덱스: 0x...") / 영어("Current AC Power Setting Index: 0x...") 둘 다 매칭
    $line = $out | Where-Object { $_ -match 'AC.*:\s*0x([0-9a-fA-F]+)' } | Select-Object -First 1
    if ($line -and ($line -match '0x([0-9a-fA-F]+)')) {
        $sec = [Convert]::ToInt32($Matches[1], 16)
        if ($sec -eq 0) { return '사용 안 함' }
        return ('{0}분' -f [math]::Round($sec / 60))
    }
    '확인 실패'
}
$standby = Get-PowerAcMinutes 'SUB_SLEEP' 'STANDBYIDLE'
$hibernate = Get-PowerAcMinutes 'SUB_SLEEP' 'HIBERNATEIDLE'

$shutdownTasks = Try-Get {
    $names = Get-ScheduledTask | Where-Object { $_.State -ne 'Disabled' } | Where-Object {
        $hit = $false
        foreach ($a in $_.Actions) {
            $exe = [string]$a.Execute; $arg = [string]$a.Arguments
            if ($exe -match 'shutdown' -or ($exe -match 'powershell|cmd' -and $arg -match 'shutdown|Stop-Computer')) { $hit = $true }
        }
        $hit
    } | ForEach-Object { $_.TaskPath + $_.TaskName }
    if ($names) { $names -join '; ' } else { '없음' }
}

# ---- 재부팅 초기화 (1) ------------------------------------------------------
# 복원 프로그램 "후보"만 탐지한다. 확정은 재부팅 마커로 한다.
$restorePattern = 'Freeze|DFServ|Faronics|Reboot ?Restore|Rollback|Shield|SteadyState|Time ?Freeze|HDD ?Guard|Magic ?Restore|복원|클리닉|Clinic'
$restoreCandidates = Try-Get {
    $found = @()
    $found += Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match $restorePattern } | ForEach-Object { "proc:$($_.ProcessName)" }
    $found += Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.Name -match $restorePattern -or $_.DisplayName -match $restorePattern } | ForEach-Object { "svc:$($_.Name)" }
    $uninst = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    $found += Get-ItemProperty $uninst -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -match $restorePattern } | ForEach-Object { "app:$($_.DisplayName)" }
    # Windows 내장 UWF(Unified Write Filter)
    $uwf = Get-CimInstance -Namespace 'root\standardcimv2\embedded' -ClassName UWF_Filter -ErrorAction SilentlyContinue
    if ($uwf -and $uwf.CurrentEnabled) { $found += 'UWF:켜짐' }
    $found = $found | Select-Object -Unique
    if ($found) { $found -join '; ' } else { '발견 안 됨' }
}

# 마커: C:\ProgramData 와 다른 고정 드라이브(D: 등)에 각각 남긴다. 복원 프로그램이 C:만 보호하는 경우도 있어서.
$markerDirs = @('C:\ProgramData\Finesse')
$markerDirs += Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | Where-Object { $_.DeviceID -ne 'C:' } | ForEach-Object { "$($_.DeviceID)\Finesse" }
$markerReport = @()
foreach ($d in $markerDirs) {
    $f = Join-Path $d 'reboot-marker.txt'
    $prev = if (Test-Path $f) { (Get-Content $f -Raw).Trim() } else { $null }
    try {
        if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
        Set-Content -Path $f -Value $now.ToString('yyyy-MM-dd HH:mm:ss') -Encoding ASCII
    } catch { }
    if ($prev) { $markerReport += "$($d.Substring(0,2)) 유지됨(작성 $prev)" } else { $markerReport += "$($d.Substring(0,2)) 없음(첫 실행이거나 초기화됨)" }
}
# 방화벽 규칙도 남는지 확인 (실제로 날아가면 곤란한 게 방화벽 규칙이므로). 비활성 규칙이라 동작에는 영향 없음.
$probeName = 'Finesse Reboot Probe'
$probe = Get-NetFirewallRule -DisplayName $probeName -ErrorAction SilentlyContinue
if ($probe) {
    $markerReport += "방화벽 프로브 유지됨($($probe.Description))"
} elseif ($isAdmin) {
    New-NetFirewallRule -DisplayName $probeName -Group 'FinesseProbe' -Direction Inbound -Protocol TCP -LocalPort 65000 `
        -Action Allow -Enabled False -Description $now.ToString('yyyy-MM-dd HH:mm') | Out-Null
    $markerReport += '방화벽 프로브 없음(방금 생성)'
} else {
    $markerReport += '방화벽 프로브 확인 불가(관리자 아님)'
}
$bootTime = Try-Get { (Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToString('yyyy-MM-dd HH:mm') }

# ---- 결과 ------------------------------------------------------------------
$row = [pscustomobject][ordered]@{
    CheckedAt         = $now.ToString('yyyy-MM-dd HH:mm')
    PC                = $pcName
    Hostname          = $env:COMPUTERNAME
    '1_RestoreSW'     = $restoreCandidates
    '1_RebootMarker'  = $markerReport -join '; '
    LastBoot          = $bootTime
    '2_Admin'         = if ($isAdmin) { '예' } else { '아니오(이 세션)' }
    '3_IP'            = $ip
    '3_Mask'          = $mask
    '3_Gateway'       = $gw
    IPNote            = $ipNote
    '4_Addressing'    = $dhcp
    '4_DhcpServer'    = $dhcpServer
    '4_LeaseObtained' = $leaseObtained
    '4_LeaseExpires'  = $leaseExpires
    '5_SleepAC'       = $standby
    '5_HibernateAC'   = $hibernate
    '5_ShutdownTasks' = $shutdownTasks
    NetProfile        = $netProfile
    FirewallProfiles  = $fwLocalRules
    RAM_GB            = $ramGB
    RAMNote           = $ramNote
    GPU               = $gpus
    GPUNote           = $gpuNote
}

$dir = New-ResultsDir
$stamp = $now.ToString('yyyyMMdd-HHmm')
$base = Join-Path $dir "precheck_${pcName}_$stamp"
$row | Export-Csv -Path "$base.csv" -NoTypeInformation -Encoding UTF8
Write-Utf8Bom -Path "$base.txt" -Text (($row | Format-List | Out-String).Trim())

$row | Format-List
Write-Host ''
Write-Host "저장: $base.csv / .txt" -ForegroundColor Cyan
if ($restoreCandidates -ne '발견 안 됨' -or ($markerReport -match '초기화됨' -and $markerReport -match '유지됨')) {
    Write-Host '⚠ 복원 프로그램 후보 발견 또는 마커 일부 소실 — 재부팅 후 다시 실행해 확정하고, 확정되면 바로 PM에게 알릴 것.' -ForegroundColor Yellow
}
if ($fwLocalRules -match 'LocalRules=False') {
    Write-Host '⚠ 그룹 정책이 로컬 방화벽 규칙을 막고 있음(AllowLocalFirewallRules=False) — 우리가 만든 규칙이 적용되지 않는다. 학교 IT 문의 필요.' -ForegroundColor Yellow
}
