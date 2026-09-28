# Finesse PC 간 통신 — 공용 함수. 다른 스크립트가 dot-source 해서 쓴다.
# Windows PowerShell 5.1 기준 (학교 PC 기본). PS 7 전용 문법(??, 삼항 연산자 등) 금지.

$script:RuleGroup = 'Finesse'
$script:ResultsDir = Join-Path $PSScriptRoot 'results'

function Get-FinessePcs {
    param([string]$Path)
    if (-not $Path) { $Path = Join-Path $PSScriptRoot 'pcs.csv' }
    Import-Csv -Path $Path -Encoding UTF8 | Where-Object { $_.PC -and -not $_.PC.StartsWith('#') }
}

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Assert-Admin {
    if (-not (Test-Admin)) {
        throw '관리자 권한이 필요합니다. PowerShell을 "관리자 권한으로 실행"한 뒤 다시 실행하세요.'
    }
}

function Get-LocalIPv4 {
    @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } |
        ForEach-Object { $_.IPAddress })
}

# 이 PC가 대장의 어느 행인지 찾는다. -Name(예: 301B-11)을 주면 그걸 쓰고, 아니면 로컬 IP로 매칭.
function Resolve-SelfPc {
    param($Pcs, [string]$Name)
    if ($Name) {
        $hit = @($Pcs | Where-Object { $_.PC -eq $Name })
        if ($hit.Count -eq 0) { throw "pcs.csv에 '$Name' 행이 없습니다." }
        return $hit[0]
    }
    $ips = Get-LocalIPv4
    $hit = @($Pcs | Where-Object { $ips -contains $_.IP })
    if ($hit.Count -eq 0) {
        throw ("이 PC의 IP({0})가 pcs.csv에 없습니다. IP가 바뀌었다면(DHCP) 대장을 고치거나 -Pc 301B-xx 로 지정하세요." -f ($ips -join ', '))
    }
    $hit[0]
}

function New-ResultsDir {
    if (-not (Test-Path $script:ResultsDir)) { New-Item -ItemType Directory -Path $script:ResultsDir | Out-Null }
    $script:ResultsDir
}

# UTF-8(BOM) 으로 저장 — 엑셀·메모장에서 한글이 깨지지 않게.
function Write-Utf8Bom {
    param([string]$Path, [string]$Text)
    [IO.File]::WriteAllText($Path, $Text, (New-Object Text.UTF8Encoding($true)))
}

function ConvertTo-MarkdownTable {
    param([object[]]$Rows, [string[]]$Columns)
    $lines = @()
    $lines += '| ' + ($Columns -join ' | ') + ' |'
    $lines += '|' + (($Columns | ForEach-Object { '---' }) -join '|') + '|'
    foreach ($r in $Rows) {
        $cells = foreach ($c in $Columns) { ([string]$r.$c) -replace '\|', '/' }
        $lines += '| ' + ($cells -join ' | ') + ' |'
    }
    $lines -join "`r`n"
}
