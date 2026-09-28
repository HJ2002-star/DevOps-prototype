<#
.SYNOPSIS
  ②-3 llama-server 를 "다른 PC 요청도 받게"(0.0.0.0) 8081 포트로 띄운다.

.DESCRIPTION
  기본값(127.0.0.1:8080)으로 띄우면 방화벽을 다 열어도 다른 PC에서 접속되지 않고,
  스프링 부트(8080)와 포트도 겹친다. 이 스크립트는 항상 --host 0.0.0.0 --port 8081 로 띄운다.
  빌드는 GPU 실측 때 확정된 조합(CUDA 12.6 · GGML_CUDA=on · CMAKE_CUDA_ARCHITECTURES=61)을 그대로 쓴다.

  로그는 logs\llama-server_<시각>.log 에도 남는다. 기동 후 확인:
    Select-String -Path .\logs\llama-server_*.log -Pattern 'offloaded'   → "offloaded 29/29 layers" 여야 함

.EXAMPLE
  .\start-llama-server.ps1 -Model C:\models\model.gguf
  .\start-llama-server.ps1 -Model C:\models\model.gguf -Exe D:\llama.cpp\build\bin\Release\llama-server.exe
#>
param(
    [Parameter(Mandatory = $true)][string]$Model,
    [string]$Exe = '.\llama.cpp\build\bin\Release\llama-server.exe',
    [int]$Port = 8081,
    [int]$GpuLayers = 99,
    [string[]]$ExtraArgs = @()
)
$ErrorActionPreference = 'Stop'

if (-not (Test-Path $Exe)) { throw "llama-server.exe 를 찾을 수 없습니다: $Exe  (-Exe 로 경로 지정)" }
if (-not (Test-Path $Model)) { throw "모델 파일이 없습니다: $Model" }

$busy = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
if ($busy) {
    $owner = (Get-Process -Id $busy[0].OwningProcess -ErrorAction SilentlyContinue).ProcessName
    throw "포트 $Port 를 이미 '$owner' 가 쓰고 있습니다."
}

$logDir = Join-Path $PSScriptRoot 'logs'
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
$logFile = Join-Path $logDir ("llama-server_{0}.log" -f (Get-Date -Format 'yyyyMMdd-HHmm'))

$llamaArgs = @('-m', $Model, '--host', '0.0.0.0', '--port', $Port, '-ngl', $GpuLayers, '--log-file', $logFile) + $ExtraArgs
Write-Host ("실행: {0} {1}" -f $Exe, ($llamaArgs -join ' ')) -ForegroundColor Cyan
& $Exe @llamaArgs
