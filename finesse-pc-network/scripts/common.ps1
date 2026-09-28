# Finesse PC 간 통신 — 공통 함수 (다른 스크립트가 dot-source 한다)
# Windows PowerShell 5.1 호환. PS7 전용 문법 사용 금지.

$ErrorActionPreference = 'Stop'

$script:FinesseRoot = Split-Path -Parent $PSScriptRoot

function Get-FinesseRoot { $script:FinesseRoot }

function Get-FinesseConfig {
    param([string]$Path)
    if (-not $Path) { $Path = Join-Path $script:FinesseRoot 'config\pcs.json' }
    if (-not (Test-Path -LiteralPath $Path)) { throw "설정 파일이 없습니다: $Path" }
    $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    return ($raw | ConvertFrom-Json)
}

function Get-ResultsDir {
    $dir = Join-Path $script:FinesseRoot 'results'
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
    return $dir
}

function Get-DocsDir {
    $dir = Join-Path $script:FinesseRoot 'docs'
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
    return $dir
}

# UTF-8(BOM 없음)으로 저장. 5.1의 Out-File -Encoding UTF8은 BOM을 붙이므로 직접 쓴다.
function Write-TextFile {
    param([string]$Path, [string]$Text, [switch]$Append)
    $enc = New-Object System.Text.UTF8Encoding($false)
    if ($Append) { [System.IO.File]::AppendAllText($Path, $Text, $enc) }
    else { [System.IO.File]::WriteAllText($Path, $Text, $enc) }
}

function Save-Json {
    param([string]$Path, $Object)
    Write-TextFile -Path $Path -Text ($Object | ConvertTo-Json -Depth 8)
}

function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# 변경 스크립트 맨 앞에서 호출. -WhatIf 미리보기는 관리자 없이도 허용한다.
function Assert-Admin {
    param([bool]$WhatIfMode)
    if (Test-IsAdmin) { return }
    if ($WhatIfMode) {
        Write-Warning '관리자 권한이 아닙니다. -WhatIf 미리보기만 진행합니다.'
        return
    }
    Write-Host ''
    Write-Host '[중단] 관리자 권한이 필요합니다.' -ForegroundColor Red
    Write-Host '  시작 메뉴 > "PowerShell" 검색 > 마우스 오른쪽 > "관리자 권한으로 실행" 후 다시 실행하세요.'
    Write-Host '  (미리보기만 하려면 -WhatIf 를 붙이면 관리자 없이도 됩니다.)'
    exit 1
}

function Get-LocalIPv4 {
    $list = @()
    try {
        $list = @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop |
            Where-Object { $_.IPAddress -ne '127.0.0.1' -and $_.IPAddress -notlike '169.254.*' })
    } catch { }
    return $list
}

# 자기 PC 찾기: -PcId > pcs[].hostname > COMPUTERNAME == id > 로컬 IP 일치
function Find-SelfPc {
    param($Config, [string]$PcId)
    if ($PcId) {
        $pc = $Config.pcs | Where-Object { $_.id -eq $PcId }
        if (-not $pc) { throw "pcs.json에 '$PcId' 가 없습니다." }
        return $pc
    }
    $name = $env:COMPUTERNAME
    $pc = $Config.pcs | Where-Object { $_.hostname -and ($_.hostname -eq $name) }
    if ($pc) { return $pc }
    $pc = $Config.pcs | Where-Object { $_.id -eq $name }
    if ($pc) { return $pc }
    $ips = @(Get-LocalIPv4 | ForEach-Object { $_.IPAddress })
    $pc = $Config.pcs | Where-Object { $ips -contains $_.ip }
    if ($pc) { return @($pc)[0] }
    return $null
}

# 'LLM' / 'Backend' / 'Frontend' 중 해당하는 역할 목록
function Get-PcRoles {
    param($Config, $Pc)
    $roles = @()
    if (@($Config.llmServers) -contains $Pc.id) { $roles += 'LLM' }
    if ($Config.backend -and $Config.backend -eq $Pc.id) { $roles += 'Backend' }
    if ($Config.frontend -and $Config.frontend -eq $Pc.id) { $roles += 'Frontend' }
    return $roles
}

# PC id 또는 IP 문자열 → IP. 서브넷 밖이면 예외.
function Resolve-PcIp {
    param($Config, [string]$Item)
    $pc = $Config.pcs | Where-Object { $_.id -eq $Item }
    $ip = $Item
    if ($pc) { $ip = $pc.ip }
    if (-not (Test-InSubnet -Ip $ip -Cidr $Config.subnet)) {
        throw "'$Item' ($ip) 는 팀 서브넷 $($Config.subnet) 밖입니다. 허용 목록에 넣을 수 없습니다."
    }
    return $ip
}

function Test-InSubnet {
    param([string]$Ip, [string]$Cidr)
    if ($Ip -notmatch '^\d{1,3}(\.\d{1,3}){3}$') { return $false }
    $parsed = $null
    if (-not [System.Net.IPAddress]::TryParse($Ip, [ref]$parsed)) { return $false }
    $parts = $Cidr.Split('/')
    $net = [System.Net.IPAddress]::Parse($parts[0]).GetAddressBytes()
    $bits = [int]$parts[1]
    $addr = $parsed.GetAddressBytes()
    if ($addr.Length -ne 4) { return $false }
    for ($i = 0; $i -lt 4; $i++) {
        $maskBits = [Math]::Max(0, [Math]::Min(8, $bits - 8 * $i))
        $mask = [byte]((0xFF -shl (8 - $maskBits)) -band 0xFF)
        if (($addr[$i] -band $mask) -ne ($net[$i] -band $mask)) { return $false }
    }
    return $true
}

# 인바운드 TCP 허용 규칙을 멱등하게 (삭제 후 재생성) 만든다.
# 반환: 실행한(또는 실행할) 명령 문자열
function Set-FinesseInboundRule {
    param(
        [Parameter(Mandatory)] $Cmdlet,          # 호출 스크립트의 $PSCmdlet (ShouldProcess 용)
        [Parameter(Mandatory)] [string]$DisplayName,
        [Parameter(Mandatory)] [int]$Port,
        [Parameter(Mandatory)] [string[]]$RemoteAddress,
        [string]$Description = '',
        [string]$Program            # 지정하면 그 프로그램에만 적용되는 규칙이 된다
    )
    if (-not $DisplayName.StartsWith('Finesse-')) { throw '규칙 이름은 Finesse- 로 시작해야 합니다.' }
    if (@($RemoteAddress).Count -eq 0) { throw 'RemoteAddress 가 비어 있습니다.' }
    foreach ($a in $RemoteAddress) {
        if ($a -match '^(?i)any$|^\*$|^0\.0\.0\.0') { throw "RemoteAddress 에 '$a' 는 허용하지 않습니다 (llama-server는 인증이 없음)." }
    }

    $addrText = ($RemoteAddress | ForEach-Object { "'$_'" }) -join ','
    $removeCmd = "Get-NetFirewallRule -DisplayName '$DisplayName' -ErrorAction SilentlyContinue | Remove-NetFirewallRule"
    $newCmd = "New-NetFirewallRule -DisplayName '$DisplayName' -Direction Inbound -Protocol TCP -LocalPort $Port " +
              "-RemoteAddress $addrText -Action Allow -Profile Domain,Private,Public -Enabled True"
    if ($Program) { $newCmd += " -Program '$Program'" }

    if ($Cmdlet.ShouldProcess("방화벽 규칙 $DisplayName", "삭제 후 재생성 (TCP $Port, 허용 IP $($RemoteAddress.Count)개)")) {
        Get-NetFirewallRule -DisplayName $DisplayName -ErrorAction SilentlyContinue | Remove-NetFirewallRule -WhatIf:$false
        $ruleArgs = @{
            DisplayName = $DisplayName; Direction = 'Inbound'; Protocol = 'TCP'; LocalPort = $Port
            RemoteAddress = $RemoteAddress; Action = 'Allow'; Profile = @('Domain', 'Private', 'Public'); Enabled = 'True'
            Description = $Description
        }
        if ($Program) { $ruleArgs.Program = $Program }
        New-NetFirewallRule @ruleArgs -WhatIf:$false | Out-Null
    }
    return "$removeCmd`r`n$newCmd"
}

# 적용 결과를 표로 돌려준다 (콘솔·문서 기록용)
function Get-FinesseRuleSummary {
    $rules = @(Get-NetFirewallRule -DisplayName 'Finesse-*' -ErrorAction SilentlyContinue)
    foreach ($r in $rules) {
        $addr = $r | Get-NetFirewallAddressFilter
        $port = $r | Get-NetFirewallPortFilter
        [pscustomobject]@{
            DisplayName   = $r.DisplayName
            Enabled       = $r.Enabled
            Direction     = $r.Direction
            Action        = $r.Action
            Profile       = $r.Profile
            Protocol      = $port.Protocol
            LocalPort     = ($port.LocalPort -join ',')
            RemoteAddress = ($addr.RemoteAddress -join ',')
        }
    }
}

# Finesse- 가 아닌 인바운드 규칙 중 충돌 가능성이 있는 것:
#   - 같은 포트를 막는 차단 규칙 (차단은 허용보다 우선한다)
#   - 프로그램(llama-server 등)에 걸린 규칙. 첫 실행 때 뜨는 "Windows 보안 경고" 창이 만든다.
#     [취소] → 차단 규칙(연결 막힘), [액세스 허용] → 원격 주소 제한 없는 허용 규칙(보안 구멍).
function Find-ConflictingRules {
    param([int]$Port, [string]$ProgramPattern)
    $found = @()
    $rules = @(Get-NetFirewallRule -Direction Inbound -Enabled True -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -notlike 'Finesse-*' })
    foreach ($r in $rules) {
        $af = $r | Get-NetFirewallApplicationFilter
        $progHit = $ProgramPattern -and $af.Program -and ($af.Program -match $ProgramPattern)
        $portHit = $false
        if ($r.Action.ToString() -eq 'Block') {
            $pf = $r | Get-NetFirewallPortFilter
            $portHit = @($pf.LocalPort) -contains "$Port"
        }
        if ($progHit -or $portHit) {
            $addr = $r | Get-NetFirewallAddressFilter
            # 원격 주소가 이미 제한된 허용 규칙은 문제 삼지 않는다
            if ($r.Action.ToString() -eq 'Allow' -and @($addr.RemoteAddress) -notcontains 'Any') { continue }
            $found += [pscustomobject]@{
                Name = $r.Name; DisplayName = $r.DisplayName; Action = $r.Action.ToString()
                Program = $af.Program; RemoteAddress = (@($addr.RemoteAddress) -join ',')
            }
        }
    }
    return $found
}

function Show-ConflictingRules {
    param($Rules)
    foreach ($c in @($Rules)) {
        if ($c.Action -eq 'Block') {
            Write-Warning "차단 규칙이 Finesse 허용 규칙보다 우선합니다: '$($c.DisplayName)' (프로그램 $($c.Program))"
        } else {
            Write-Warning "원격 주소 제한이 없는 허용 규칙: '$($c.DisplayName)' (프로그램 $($c.Program), 원격 $($c.RemoteAddress))"
        }
    }
}

function Add-FirewallLog {
    param([string]$PcId, [string]$ScriptName, [string]$Command, $Summary)
    $doc = Join-Path (Get-DocsDir) '방화벽규칙목록.md'
    $ts = Get-Date -Format 'yyyy-MM-dd HH:mm'
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine("### $PcId — $ts ($ScriptName, 실행자: $env:USERNAME@$env:COMPUTERNAME)")
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('```powershell')
    [void]$sb.AppendLine($Command.TrimEnd())
    [void]$sb.AppendLine('```')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('적용 결과 (`Get-NetFirewallRule -DisplayName "Finesse-*"`):')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('| 규칙 | 사용 | 동작 | 프로필 | 포트 | 허용 원격 IP |')
    [void]$sb.AppendLine('|---|---|---|---|---|---|')
    foreach ($s in @($Summary)) {
        [void]$sb.AppendLine("| $($s.DisplayName) | $($s.Enabled) | $($s.Action) | $($s.Profile) | $($s.Protocol) $($s.LocalPort) | $($s.RemoteAddress) |")
    }
    Write-TextFile -Path $doc -Text $sb.ToString() -Append

    $res = Join-Path (Get-ResultsDir) ("firewall-{0}-{1}.txt" -f $PcId, (Get-Date -Format 'yyyyMMdd-HHmm'))
    Write-TextFile -Path $res -Text ($Command + "`r`n`r`n" + ($Summary | Format-Table -AutoSize | Out-String -Width 300))
}

# powercfg /query 의 AC 값(초). 한국어/영어 출력 모두 처리.
function Get-PowerAcSeconds {
    param([string]$Setting)   # STANDBYIDLE / HIBERNATEIDLE
    $out = & powercfg /query SCHEME_CURRENT SUB_SLEEP $Setting 2>$null
    if (-not $out) { return $null }
    foreach ($line in $out) {
        if ($line -match 'AC[^:]*:\s*0x([0-9a-fA-F]+)') { return [Convert]::ToInt64($Matches[1], 16) }
    }
    return $null
}
