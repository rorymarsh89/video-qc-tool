Clear-Host
Write-Host ""
Write-Host " ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀" -ForegroundColor DarkCyan
Write-Host "   FFMPEG VIDEO QUALITY CONTROL DASHBOARD " -NoNewline -ForegroundColor Cyan; Write-Host "v3.2.0" -ForegroundColor White
Write-Host "   Developed by rorymarsh89" -ForegroundColor DarkGray
Write-Host " ▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄" -ForegroundColor DarkCyan
Write-Host ""
Write-Host "   This tool automates professional video QC. It analyzes " -ForegroundColor Gray
Write-Host "   media for broadcast compliance, audio errors, " -ForegroundColor Gray
Write-Host "   corrupt frames, and generates an interactive HTML report " -ForegroundColor Gray
Write-Host "   and visual proxy video file with burnt-in scopes." -ForegroundColor Gray
Write-Host ""
Write-Host " ---------------------------------------------------------------" -ForegroundColor DarkGray

# --- [0] CLOUD BOOTSTRAPPER & DEPENDENCY LOADER ---
$AppDataDir = Join-Path $env:LOCALAPPDATA 'VideoQC_Dashboard'
if (-not (Test-Path $AppDataDir)) {
    New-Item -ItemType Directory -Force -Path $AppDataDir | Out-Null
}

$script:ffmpegPath  = Join-Path $AppDataDir 'ffmpeg.exe'
$script:ffprobePath = Join-Path $AppDataDir 'ffprobe.exe'

$ffmpegUrl  = "https://github.com/rorymarsh89/video-qc-tool/releases/download/v1.0-dependencies/ffmpeg.exe"
$ffprobeUrl = "https://github.com/rorymarsh89/video-qc-tool/releases/download/v1.0-dependencies/ffprobe.exe"
# ------------------------------------------------------------------------------

if (-not (Test-Path $script:ffmpegPath) -or -not (Test-Path $script:ffprobePath)) {
    Write-Host ""
    Write-Host "   [!] FIRST-TIME SETUP REQUIRED" -ForegroundColor Yellow
    Write-Host "   -------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "   This tool requires " -NoNewline -ForegroundColor Gray; Write-Host "FFmpeg" -NoNewline -ForegroundColor White; Write-Host " and " -NoNewline -ForegroundColor Gray; Write-Host "FFprobe" -NoNewline -ForegroundColor White; Write-Host " (approx. 150MB) to" -ForegroundColor Gray
    Write-Host "   analyze and process your video files. They will be downloaded" -ForegroundColor Gray
    Write-Host "   to a temporary local AppData folder on your computer." -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "   Do you grant permission to download these files now?" -ForegroundColor Cyan
    $dlChoice = Read-Host '   [Y/N]'
    
    if ($dlChoice -notmatch '^y') {
        Write-Host ''
        Write-Host '   [X] Setup cancelled. The tool cannot run without these files.' -ForegroundColor Red
        Pause; exit
    }

    Write-Host ''
    Write-Host '   -> Downloading FFmpeg engines... This may take a minute.' -ForegroundColor DarkGray
    
    try {
        if (-not (Test-Path $script:ffmpegPath)) {
            Write-Host '      Fetching ffmpeg.exe... ' -NoNewline
            Invoke-WebRequest -Uri $ffmpegUrl -OutFile $script:ffmpegPath
            Write-Host 'Done!' -ForegroundColor Green
        }
        if (-not (Test-Path $script:ffprobePath)) {
            Write-Host '      Fetching ffprobe.exe... ' -NoNewline
            Invoke-WebRequest -Uri $ffprobeUrl -OutFile $script:ffprobePath
            Write-Host 'Done!' -ForegroundColor Green
        }
    } catch {
        Write-Host "`n   [!] CRITICAL ERROR: Failed to download dependencies." -ForegroundColor Red
        Write-Host "       Ensure your URLs are correct and you are connected to the internet." -ForegroundColor Gray
        Pause; exit
    }
}

Write-Host ''
Write-Host '   [SYSTEM] FFmpeg Engines Ready.' -ForegroundColor DarkGray
