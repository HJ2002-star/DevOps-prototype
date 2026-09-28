<#
.SYNOPSIS
  서버 역할 PC(LLM·백엔드)의 절전·최대 절전을 끈다 (지시서 ②-5). 모니터 끄기 시간은 건드리지 않는다.

.DESCRIPTION
  - 바꾸기 전 값을 results\power-backup-<PC>.json 에 저장한다. 백업 파일이 이미 있으면 덮어쓰지 않는다
    (두 번째 실행 때 '0'이 원래 값으로 저장되는 것을 막기 위함).
  - -Restore : 백업한 값으로 되돌린다.
  - -DisableShutdownTasks : 예약 작업 중 shutdown.exe 를 호출하는 작업(\Microsoft\ 아래 제외)을 끈다.
    학교 관리 프로그램의 작업일 수 있으니 목록을 먼저 -WhatIf 로 보고 판단한다. -Restore 때 다시 켠다.

.EXAMPLE
  .\12-power.ps1 -WhatIf
  .\12-power.ps1
  .\12-power.ps1 -DisableShutdownTasks
  .\12-power.ps1 -Restore
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$Restore,
    [switch]$DisableShutdownTasks,
    [string]$PcId,
    [string]$ConfigPath
)
. (Join-Path $PSScriptRoot 'common.ps1')

Assert-Admin -WhatIfMode ([bool]$WhatIfPreference)
$config = Get-FinesseConfig -Path $ConfigPath
$self = Find-SelfPc -Config $config -PcId $PcId
if (-not $self) { Write-Host '[중단] pcs.json에서 이 PC를 찾지 못했습니다. -PcId 301B-xx 를 붙이세요.' -ForegroundColor Red; exit 1 }
$roles = Get-PcRoles -Config $config -Pc $self
if (-not $Restore -and -not ($roles -contains 'LLM' -or $roles -contains 'Backend')) {
    Write-Host "[중단] $($self.id) 는 서버 역할(LLM·백엔드) PC가 아닙니다. 개인 개발 PC의 전원 설정은 바꾸지 않습니다." -ForegroundColor Red
    exit 1
}

$backupPath = Join-Path (Get-ResultsDir) ("power-backup-{0}.json" -f $self.id)

function Set-AcIndex {
    param([string]$Setting, [long]$Seconds)
    & powercfg /setacvalueindex SCHEME_CURRENT SUB_SLEEP $Setting $Seconds
    if ($LASTEXITCODE -ne 0) { throw "powercfg /setacvalueindex $Setting 실패 (exit $LASTEXITCODE)" }
    & powercfg /setactive SCHEME_CURRENT | Out-Null
}

function Get-ShutdownTasks {
    @(Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object {
        $t = $_
        ($t.TaskPath -notlike '\Microsoft\*') -and
        (@($t.Actions | Where-Object { ($_.Execute -match 'shutdown') -or ($_.Arguments -match 'shutdown(\.exe)?\s+[/-][sp]') }).Count -gt 0)
    })
}

if ($Restore) {
    if (-not (Test-Path -LiteralPath $backupPath)) { Write-Host "[중단] 백업 파일이 없습니다: $backupPath" -ForegroundColor Red; exit 1 }
    $b = Get-Content -LiteralPath $backupPath -Raw -Encoding UTF8 | ConvertFrom-Json
    Write-Host "=== $($self.id) 전원 설정 복원 ($($b.savedAt) 백업) ===" -ForegroundColor Cyan
    if ($null -ne $b.standbyAcSec -and $PSCmdlet.ShouldProcess('절전(AC)', "$($b.standbyAcSec)초로 복원")) { Set-AcIndex -Setting STANDBYIDLE -Seconds $b.standbyAcSec }
    if ($null -ne $b.hibernateAcSec -and $PSCmdlet.ShouldProcess('최대 절전(AC)', "$($b.hibernateAcSec)초로 복원")) { Set-AcIndex -Setting HIBERNATEIDLE -Seconds $b.hibernateAcSec }
    foreach ($t in @($b.disabledTasks)) {
        if ($t -and $PSCmdlet.ShouldProcess("예약 작업 $t", '다시 사용')) {
            $name = Split-Path $t -Leaf
            $path = $t.Substring(0, $t.Length - $name.Length)
            Enable-ScheduledTask -TaskPath $path -TaskName $name | Out-Null
        }
    }
    if (-not $WhatIfPreference) {
        Rename-Item -LiteralPath $backupPath -NewName ("power-backup-{0}-restored-{1}.json" -f $self.id, (Get-Date -Format 'yyyyMMdd-HHmm'))
        Write-Host '복원 완료. 백업 파일은 이름을 바꿔 보관했습니다.' -ForegroundColor Green
    }
    exit 0
}

$standby = Get-PowerAcSeconds -Setting STANDBYIDLE
$hibernate = Get-PowerAcSeconds -Setting HIBERNATEIDLE
Write-Host "=== $($self.id) 전원 설정 ($($roles -join '+')) ===" -ForegroundColor Cyan
Write-Host ("현재: 절전 {0}초 / 최대 절전 {1}초 (0 = 안 함)" -f $standby, $hibernate)

$tasks = @()
if ($DisableShutdownTasks) {
    $tasks = @(Get-ShutdownTasks | Where-Object { $_.State.ToString() -ne 'Disabled' })
    if ($tasks.Count -eq 0) { Write-Host '끌 종료 예약 작업이 없습니다.' }
    foreach ($t in $tasks) {
        Write-Host ("종료 예약 작업: {0}{1} → {2}" -f $t.TaskPath, $t.TaskName, ((@($t.Actions) | ForEach-Object { "$($_.Execute) $($_.Arguments)" }) -join ' ; ')) -ForegroundColor Yellow
    }
}

if (-not $WhatIfPreference) {
    if (Test-Path -LiteralPath $backupPath) {
        $backup = Get-Content -LiteralPath $backupPath -Raw -Encoding UTF8 | ConvertFrom-Json
        Write-Host "기존 백업 유지: $backupPath ($($backup.savedAt))"
        $disabled = @($backup.disabledTasks | Where-Object { $_ })
    } else {
        $backup = $null
        $disabled = @()
    }
    $disabled = @($disabled + @($tasks | ForEach-Object { $_.TaskPath + $_.TaskName }) | Sort-Object -Unique)
    $obj = [ordered]@{
        savedAt        = $(if ($backup) { $backup.savedAt } else { (Get-Date).ToString('yyyy-MM-dd HH:mm:ss') })
        pcId           = $self.id
        standbyAcSec   = $(if ($backup) { $backup.standbyAcSec } else { $standby })
        hibernateAcSec = $(if ($backup) { $backup.hibernateAcSec } else { $hibernate })
        disabledTasks  = $disabled
    }
    Save-Json -Path $backupPath -Object $obj
    if (-not $backup) { Write-Host "백업: $backupPath" }
}

if ($PSCmdlet.ShouldProcess('절전(AC)', '0 (안 함)으로 변경')) {
    & powercfg /change standby-timeout-ac 0
    if ($LASTEXITCODE -ne 0) { throw 'powercfg standby-timeout-ac 실패' }
}
if ($PSCmdlet.ShouldProcess('최대 절전(AC)', '0 (안 함)으로 변경')) {
    & powercfg /change hibernate-timeout-ac 0
    if ($LASTEXITCODE -ne 0) { throw 'powercfg hibernate-timeout-ac 실패' }
}
foreach ($t in $tasks) {
    if ($PSCmdlet.ShouldProcess("예약 작업 $($t.TaskPath)$($t.TaskName)", '사용 안 함')) {
        Disable-ScheduledTask -TaskPath $t.TaskPath -TaskName $t.TaskName | Out-Null
    }
}

if (-not $WhatIfPreference) {
    Write-Host ("변경 후: 절전 {0}초 / 최대 절전 {1}초" -f (Get-PowerAcSeconds -Setting STANDBYIDLE), (Get-PowerAcSeconds -Setting HIBERNATEIDLE)) -ForegroundColor Green
    Write-Host '되돌리려면: .\12-power.ps1 -Restore'
}
