@echo off
setlocal

cd /d "%~dp0" || exit /b 1

where docker >nul 2>&1
if errorlevel 1 (
    echo Docker is required. Install Docker Desktop first.
    exit /b 1
)

where powershell.exe >nul 2>&1
if errorlevel 1 (
    echo Windows PowerShell is required.
    exit /b 1
)

if not defined FRONTEND_URL set "FRONTEND_URL=https://github.com/alinkiot/alinkiot_dashboard/releases/download/v0.0.2/dist.zip"

echo Downloading frontend from %FRONTEND_URL%
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; $root=(Get-Location).Path; $www=Join-Path $root 'www'; New-Item -ItemType Directory -Path $www -Force | Out-Null; $work=Join-Path $env:TEMP ('alinkiot-'+[guid]::NewGuid().ToString()); $stage=Join-Path $www ('.dist-stage-'+[guid]::NewGuid().ToString()); try { New-Item -ItemType Directory -Path $work,$stage -Force | Out-Null; Invoke-WebRequest -UseBasicParsing -Uri $env:FRONTEND_URL -OutFile (Join-Path $work 'frontend.zip'); Expand-Archive -LiteralPath (Join-Path $work 'frontend.zip') -DestinationPath (Join-Path $work 'extracted'); $source=Join-Path $work 'extracted\dist'; if (-not (Test-Path (Join-Path $source 'index.html'))) { $source=Join-Path $work 'extracted' }; if (-not (Test-Path (Join-Path $source 'index.html'))) { throw 'Frontend archive does not contain index.html' }; Copy-Item -Path (Join-Path $source '*') -Destination $stage -Recurse -Force; $dist=Join-Path $www 'dist'; if (Test-Path $dist) { Remove-Item $dist -Recurse -Force }; Move-Item -LiteralPath $stage -Destination $dist } finally { if (Test-Path $work) { Remove-Item $work -Recurse -Force }; if (Test-Path $stage) { Remove-Item $stage -Recurse -Force } }"
if errorlevel 1 (
    echo Frontend download or extraction failed.
    exit /b 1
)

docker compose version >nul 2>&1
if not errorlevel 1 (
    docker compose up -d
) else (
    docker-compose up -d
)
if errorlevel 1 (
    echo Docker Compose failed to start the services.
    exit /b 1
)

echo AlinkIoT is starting. Frontend: http://localhost:58080/
exit /b 0
