Clear-Host
Write-Host '================================================================' -ForegroundColor Yellow
Write-Host '   FFMPEG VIDEO QUALITY CONTROL DASHBOARD v3.2.0                ' -ForegroundColor White
Write-Host '================================================================' -ForegroundColor Yellow
Write-Host '   Developed by rorymarsh89' -ForegroundColor DarkGray
Write-Host ''
Write-Host '   This tool automates professional video QC. It analyzes ' -ForegroundColor Gray
Write-Host '   your media for broadcast compliance, audio errors, and ' -ForegroundColor Gray
Write-Host '   corrupt frames, generating an interactive HTML report ' -ForegroundColor Gray
Write-Host '   and a visual proxy with burnt-in scopes.' -ForegroundColor Gray
Write-Host '================================================================' -ForegroundColor Yellow

# --- [0] CLOUD BOOTSTRAPPER & DEPENDENCY LOADER ---
$AppDataDir = Join-Path $env:LOCALAPPDATA 'VideoQC_Dashboard'
if (-not (Test-Path $AppDataDir)) {
    New-Item -ItemType Directory -Force -Path $AppDataDir | Out-Null
}

$script:ffmpegPath  = Join-Path $AppDataDir 'ffmpeg.exe'
$script:ffprobePath = Join-Path $AppDataDir 'ffprobe.exe'

# ------------------------------------------------------------------------------
# GITHUB RELEASE LINKS
# ------------------------------------------------------------------------------
$ffmpegUrl  = "https://github.com/rorymarsh89/video-qc-tool/releases/download/v1.0-dependencies/ffmpeg.exe"
$ffprobeUrl = "https://github.com/rorymarsh89/video-qc-tool/releases/download/v1.0-dependencies/ffprobe.exe"
# ------------------------------------------------------------------------------

if (-not (Test-Path $script:ffmpegPath) -or -not (Test-Path $script:ffprobePath)) {
    Write-Host ''
    Write-Host ' [SYSTEM] First-time setup required.' -ForegroundColor Yellow
    Write-Host ' This tool requires FFmpeg and FFprobe (approx. 150MB) to analyze and' -ForegroundColor Gray
    Write-Host ' process your video files. They will be downloaded to a temporary' -ForegroundColor Gray
    Write-Host ' local AppData folder on your computer.' -ForegroundColor Gray
    Write-Host ''
    
    $dlChoice = Read-Host ' Do you grant permission to download these files now? [Y/N]'
    if ($dlChoice -notmatch '^y') {
        Write-Host ' [!] Setup cancelled. The tool cannot run without these files.' -ForegroundColor Red
        Pause; exit
    }

    Write-Host ''
    Write-Host '  -> Downloading FFmpeg engines... This may take a minute.' -ForegroundColor DarkGray
    
    try {
        if (-not (Test-Path $script:ffmpegPath)) {
            Write-Host '     Fetching ffmpeg.exe... ' -NoNewline
            Invoke-WebRequest -Uri $ffmpegUrl -OutFile $script:ffmpegPath
            Write-Host 'Done!' -ForegroundColor Green
        }
        if (-not (Test-Path $script:ffprobePath)) {
            Write-Host '     Fetching ffprobe.exe... ' -NoNewline
            Invoke-WebRequest -Uri $ffprobeUrl -OutFile $script:ffprobePath
            Write-Host 'Done!' -ForegroundColor Green
        }
    } catch {
        Write-Host "`n [!] CRITICAL ERROR: Failed to download dependencies." -ForegroundColor Red
        Write-Host "     Ensure your URLs are correct and you are connected to the internet." -ForegroundColor Gray
        Pause; exit
    }
}

Write-Host ''
Write-Host ' [SYSTEM] FFmpeg Engines Ready.' -ForegroundColor DarkGray

# --- [1] SELECT INPUT ---
Write-Host ''
Write-Host '================================================================' -ForegroundColor Yellow
Write-Host '   STEP 1: SELECT MEDIA' -ForegroundColor White
Write-Host '================================================================' -ForegroundColor Yellow
Write-Host ' You can process a single video file or a whole folder of videos.' -ForegroundColor Gray
Write-Host ''
$inputPath = Read-Host ' Copy and paste the file path or folder containing your videos'
$inputPath = $inputPath.Trim('''').Trim('"').Trim()

if (-not (Test-Path $inputPath)) {
    Write-Host ' [!] Path not found!' -ForegroundColor Red; Pause; exit
}

$files = if (Test-Path -Path $inputPath -PathType Container) {
    Get-ChildItem -Path $inputPath -File | Where-Object { $_.Extension -match '\.(mp4|mkv|mov|mxf|avi|wmv|flv|webm)$' }
} else {
    @(Get-Item -Path $inputPath)
}

if ($files.Count -eq 0) {
    Write-Host ' [!] No supported video files found.' -ForegroundColor Red; Pause; exit
}

Write-Host (" Found $($files.Count) file(s) to process.") -ForegroundColor Green

# --- [2] OUTPUT SELECTION ---
Write-Host ''
Write-Host '================================================================' -ForegroundColor Yellow
Write-Host '   STEP 2: OUTPUT SELECTION' -ForegroundColor White
Write-Host '================================================================' -ForegroundColor Yellow
Write-Host ' How would you like to review your quality control data?' -ForegroundColor Gray
Write-Host ''
Write-Host ' [1] Visual Proxy + HTML Report (Recommended)' -ForegroundColor Cyan
Write-Host '     Generates the HTML report AND outputs a new version of your video' -ForegroundColor DarkGray
Write-Host '     with burnt-in visual scopes, timecode, and audio meters for review.' -ForegroundColor DarkGray
Write-Host ''
Write-Host ' [2] HTML Report Only (Faster)' -ForegroundColor Cyan
Write-Host '     Generates only the .html document with all the metadata and alerts.' -ForegroundColor DarkGray
Write-Host '     (Does not render a new video).' -ForegroundColor DarkGray
Write-Host ''

$scopeChoice = Read-Host ' Choose option [1-2] or press Enter for Visual Proxy'
$scopeChoice = $scopeChoice.Trim()
if ($scopeChoice -eq '') { $scopeChoice = '1' }

$useWaveform    = $true
$useVectorscope = $true
$useAudioMeter  = $true
$renderVideo    = if ($scopeChoice -eq '2') { $false } else { $true }

# --- [3] LOUDNESS (LUFS) TARGET SELECTION ---
Write-Host ''
Write-Host '================================================================' -ForegroundColor Yellow
Write-Host '   STEP 3: LOUDNESS TARGET' -ForegroundColor White
Write-Host '================================================================' -ForegroundColor Yellow
Write-Host ' What platform are you delivering this video to?' -ForegroundColor Gray
Write-Host ''
Write-Host ' [1] Web Delivery (-14 LUFS, +/- 2.0 tolerance) - [Default]' -ForegroundColor Cyan
Write-Host ' [2] Broadcast EBU R128 (-23 LUFS, +/- 0.5 tolerance)' -ForegroundColor Cyan
Write-Host ''

$lufsChoice = Read-Host ' Choose option [1-2] or press Enter for Web'
$lufsChoice = $lufsChoice.Trim()

if ($lufsChoice -eq '2') {
    $targetLUFS = -23.0
    $minLUFS = -23.5
    $maxLUFS = -22.5
    $lufsLabel = "Broadcast EBU R128 (-23 LUFS)"
} else {
    $targetLUFS = -14.0
    $minLUFS = -16.0
    $maxLUFS = -12.0
    $lufsLabel = "Web Delivery (-14 LUFS)"
}

# --- [4] GAMUT SCAN SELECTION ---
Write-Host ''
Write-Host '================================================================' -ForegroundColor Yellow
Write-Host '   STEP 4: COLOR GAMUT SCAN' -ForegroundColor White
Write-Host '================================================================' -ForegroundColor Yellow
Write-Host ' Do you need to check for broadcast-legal colors (Super-whites/Sub-blacks)?' -ForegroundColor Gray
Write-Host ' Note: This analyzes every pixel and significantly increases processing time.' -ForegroundColor DarkGray
Write-Host ''
Write-Host ' [1] Skip Gamut Scan (Faster) - [Default]' -ForegroundColor Cyan
Write-Host ' [2] Run Full Gamut Scan (Slower)' -ForegroundColor Cyan
Write-Host ''

$gamutChoice = Read-Host ' Choose option [1-2] or press Enter to Skip'
$gamutChoice = $gamutChoice.Trim()
$runGamutCheck = if ($gamutChoice -eq '2') { $true } else { $false }

# --- [5] OUTPUT FOLDER (Flattened Structure) ---
$baseDir = if (Test-Path -Path $inputPath -PathType Container) { $inputPath } else { Split-Path $inputPath }
$outputDir = Join-Path $baseDir 'QC_Output'
$reportsDir = $outputDir

New-Item -ItemType Directory -Force -Path $outputDir  | Out-Null

# --- [6] HELPER: FFPROBE REPORT ---
function Get-FileReport {
    param([System.IO.FileInfo]$File)

    $probe = & $script:ffprobePath -v quiet -print_format json -show_streams -show_format $File.FullName 2>$null | ConvertFrom-Json

    $report = [ordered]@{
        Filename          = $File.Name
        FilePath          = $File.FullName
        FileSizeMB        = [math]::Round($File.Length / 1MB, 2)
        Format            = $null
        Duration_HMS      = $null
        OverallBitrate    = $null
        VideoCodec        = $null
        VideoProfile      = $null
        Resolution        = $null
        CalculatedAR      = ''
        FrameRate         = $null
        ColorSpace        = $null
        ColorTransfer     = $null
        BitDepth          = $null
        VideoBitrate      = $null
        Gamut_Status      = 'Not Checked'
        AudioCodec        = $null
        AudioProfile      = $null
        AudioChannels     = $null
        AudioSampleRate   = $null
        AudioBitrate      = $null
        IntegratedLUFS    = 'N/A'
        QC_Status         = 'PASS'
        QC_Flags          = @()
        QC_VideoOutput    = ''
    }

    if ($probe.format) {
        $report.Format = $probe.format.format_long_name
        $dur = [double]$probe.format.duration
        $ts = [timespan]::FromSeconds($dur)
        $report.Duration_HMS = $ts.Hours.ToString('D2') + 'h ' + $ts.Minutes.ToString('D2') + 'm ' + $ts.Seconds.ToString('D2') + 's'
        if ($probe.format.bit_rate) {
            $report.OverallBitrate = [math]::Round([double]$probe.format.bit_rate / 1000).ToString() + ' kb/s'
        }
    }

    foreach ($stream in $probe.streams) {
        if ($stream.codec_type -eq 'video' -and -not $report.VideoCodec) {
            $report.VideoCodec    = $stream.codec_long_name
            $report.VideoProfile  = $stream.profile
            $report.Resolution    = $stream.width.ToString() + 'x' + $stream.height.ToString()
            $report.ColorSpace    = if ($stream.color_space) { $stream.color_space } else { 'Unknown' }
            $report.ColorTransfer = if ($stream.color_transfer) { $stream.color_transfer } else { 'Unknown' }
            $report.BitDepth      = if ($stream.bits_per_raw_sample) { $stream.bits_per_raw_sample.ToString() + ' bits' } else { '8 bits (assumed)' }
            if ($stream.bit_rate) { $report.VideoBitrate = [math]::Round([double]$stream.bit_rate / 1000).ToString() + ' kb/s' }
            
            # Frame Rate Check
            if ($stream.r_frame_rate -and $stream.r_frame_rate -match '(\d+)/(\d+)') {
                $fpsRaw = [double]$Matches[1] / [double]$Matches[2]
                $report.FrameRate = [math]::Round($fpsRaw, 3).ToString() + ' FPS'
                $standardFps = @(23.976, 24, 25, 29.97, 30, 50, 59.94, 60)
                $isFpsOk = $false
                foreach ($std in $standardFps) {
                    if ([math]::Abs($fpsRaw - $std) -le 0.05) { $isFpsOk = $true; break }
                }
                if (-not $isFpsOk) {
                    $report.QC_Flags += 'NOTE: Non-standard frame rate (' + $report.FrameRate + ')'
                }
            }
            
            # Aspect Ratio Check
            if ($stream.width -gt 0 -and $stream.height -gt 0) {
                $arVal = $stream.width / $stream.height
                $report.CalculatedAR = [math]::Round($arVal, 2).ToString() + ':1'
                $standards = @( (16/9), (4/3), 1.0, (9/16), 1.85, 2.39 )
                $isOk = $false
                foreach ($std in $standards) {
                    if ([math]::Abs($arVal - $std) -le 0.02) { $isOk = $true; break }
                }
                if (-not $isOk) {
                    $report.QC_Flags += 'NOTE: Non-standard aspect ratio (' + $report.CalculatedAR + ')'
                }
            }
        }
        if ($stream.codec_type -eq 'audio' -and -not $report.AudioCodec) {
            $report.AudioCodec      = $stream.codec_long_name
            $report.AudioProfile    = $stream.profile
            $report.AudioChannels   = $stream.channels.ToString() + ' channels'
            $report.AudioSampleRate = [math]::Round($stream.sample_rate / 1000, 1).ToString() + ' kHz'
            if ($stream.bit_rate) { $report.AudioBitrate = [math]::Round([double]$stream.bit_rate / 1000).ToString() + ' kb/s' }
        }
    }
    return $report
}

# --- [7] HELPER: DEEP SCAN ---
function Get-DeepScan {
    param([string]$FilePath, [bool]$HasAudio, [bool]$IsStereo, [bool]$RunGamut)
    
    $filter = if ($RunGamut) { '[0:v:0]signalstats,blackdetect=d=0.01:pix_th=0.02,freezedetect=n=0.003:d=2[vout]' } else { '[0:v:0]blackdetect=d=0.01:pix_th=0.02,freezedetect=n=0.003:d=2[vout]' }
    $maps = @('-map', '[vout]')
    
    if ($HasAudio) {
        if ($IsStereo) {
            $filter += ';[0:a:0]asplit=3[aebu][adiff][astat];' + 
                       '[aebu]ebur128[aout];' + 
                       '[adiff]pan=1c|c0=c0-c1,volumedetect[adiffout];' + 
                       '[astat]astats=measure_overall=none[astatout]'
            $maps += '-map', '[aout]', '-map', '[adiffout]', '-map', '[astatout]'
        } else {
            $filter += ';[0:a:0]ebur128[aout]'
            $maps += '-map', '[aout]'
        }
    }
    
    $args = @('-nostats', '-i', $FilePath, '-filter_complex', $filter) + $maps + @('-f', 'null', '-')
    $output = & $script:ffmpegPath $args 2>&1
    
    $integrated = 'N/A'; $blackEvents = @(); $freezeEvents = @()
    $isDualMono = $false; $isClipping = $false; $currentChannel = 0; $ch1Peak = 'N/A'; $ch2Peak = 'N/A'
    $highLuma = $false; $lowLuma = $false; $highChroma = $false; $lowChroma = $false
    
    $currentFreezeStart = 0.0

    foreach ($line in $output) {
        if ($line -match 'I:\s+(-?\d+\.\d+) LUFS') { $integrated = $Matches[1] }
        if ($line -match 'black_start: ([\d.]+) black_end: ([\d.]+) black_duration: ([\d.]+)') {
            $blackEvents += [PSCustomObject]@{ Start = [double]$Matches[1]; End = [double]$Matches[2]; Duration = [double]$Matches[3] }
        }
        if ($line -match 'freeze_start:\s+([\d.]+)') { $currentFreezeStart = [double]$Matches[1] }
        if ($line -match 'freeze_duration:\s+([\d.]+)') {
            $freezeEvents += [PSCustomObject]@{ Start = $currentFreezeStart; Duration = [double]$Matches[1] }
        }
        
        if ($RunGamut) {
            if ($line -match 'YMAX=(\d+)') { if ([int]$Matches[1] -gt 235) { $highLuma = $true } }
            if ($line -match 'YMIN=(\d+)') { if ([int]$Matches[1] -lt 16) { $lowLuma = $true } }
            if ($line -match 'UMAX=(\d+)') { if ([int]$Matches[1] -gt 240) { $highChroma = $true } }
            if ($line -match 'VMAX=(\d+)') { if ([int]$Matches[1] -gt 240) { $highChroma = $true } }
            if ($line -match 'UMIN=(\d+)') { if ([int]$Matches[1] -lt 16)  { $lowChroma = $true } }
            if ($line -match 'VMIN=(\d+)') { if ([int]$Matches[1] -lt 16)  { $lowChroma = $true } }
        }

        if ($IsStereo -and $line -match 'max_volume:\s+(-inf|-?[\d.]+)\s+dB') {
            $vol = $Matches[1]
            if ($vol -eq '-inf' -or [double]$vol -lt -60.0) { $isDualMono = $true }
        }

        if ($IsStereo) {
            if ($line -match 'Channel:\s+(\d+)') { $currentChannel = [int]$Matches[1] }
            if ($line -match 'Peak level dB:\s+(-inf|-?[\d.]+)') {
                $val = $Matches[1]
                if ($val -ne '-inf' -and [double]$val -ge -0.1) { $isClipping = $true }
                if ($currentChannel -eq 1) { $ch1Peak = $val }
                if ($currentChannel -eq 2) { $ch2Peak = $val }
            }
        }
    }
    
    $isLeftOnly = $false; $isRightOnly = $false; $isFullyDead = $false
    
    if ($IsStereo) {
        $leftDead = ($ch1Peak -eq '-inf' -or ([double]::TryParse($ch1Peak, [ref]$null) -and [double]$ch1Peak -lt -60.0))
        $rightDead = ($ch2Peak -eq '-inf' -or ([double]::TryParse($ch2Peak, [ref]$null) -and [double]$ch2Peak -lt -60.0))
        
        if ($leftDead -and $rightDead) { $isFullyDead = $true } 
        elseif (-not $leftDead -and $rightDead) { $isLeftOnly = $true } 
        elseif ($leftDead -and -not $rightDead) { $isRightOnly = $true }
    }

    return @{ 
        I = $integrated; BlackFrames = $blackEvents; Freeze = $freezeEvents;
        IsDualMono = $isDualMono; IsClipping = $isClipping; IsLeftOnly = $isLeftOnly; IsRightOnly = $isRightOnly; IsFullyDead = $isFullyDead;
        HighLuma = $highLuma; LowLuma = $lowLuma; HighChroma = $highChroma; LowChroma = $lowChroma
    }
}

# --- [8] BUILD FILTER GRAPH ---
function Build-FilterGraph {
    param([bool]$Waveform, [bool]$Vectorscope, [bool]$AudioMeter, [string]$Filename, [string]$Codec, [string]$Resolution, [string]$FPS, [string]$TgtLUFS, [string]$LblLUFS)
    
    $safeLabel = $Filename -replace '\\', '/' -replace '''', ''
    $font = 'fontfile=''C\:/Windows/Fonts/arial.ttf'''
    $metaLine1 = 'FILE\: ' + $safeLabel
    $metaLine2 = $Resolution + ' @ ' + $FPS + ' | ' + $Codec
    $videoPanels = 1
    
    if ($Waveform) { $videoPanels++ }
    if ($Vectorscope) { $videoPanels++ }
    
    $totalPanels = $videoPanels + $(if ($AudioMeter) { 1 } else { 0 })
    $splitLabels = (0..($videoPanels-1) | ForEach-Object { '[s' + $_ + ']' }) -join ''
    $splitFilter = '[0:v:0]split=' + $videoPanels.ToString() + $splitLabels
    
    $filters = @($splitFilter)
    $panelLabels = @()
    
    $burnIn = '[s0]scale=trunc(oh*a/2)*2:512,' +
              'drawtext=' + $font + ':fontsize=18:fontcolor=white:box=1:boxcolor=black@0.6:boxborderw=4:x=10:y=10:text=''' + $metaLine1 + ''',' +
              'drawtext=' + $font + ':fontsize=14:fontcolor=yellow:box=1:boxcolor=black@0.6:boxborderw=3:x=10:y=36:text=''' + $metaLine2 + ''',' +
              'drawtext=' + $font + ':fontsize=14:fontcolor=cyan:box=1:boxcolor=black@0.6:boxborderw=3:x=10:y=58:text=''TC\: %{pts\:hms}'',' +
              'drawtext=' + $font + ':fontsize=14:fontcolor=white:box=1:boxcolor=black@0.6:boxborderw=3:x=10:y=80:text=''FRAME\: %{n}''[main]'
    
    $filters += $burnIn
    $panelLabels += '[main]'
    $idx = 1
    
    if ($Waveform) {
        $wvChunk = '[s' + $idx.ToString() + ']waveform=d=overlay:g=green,scale=512:512,' +
                   'drawtext=' + $font + ':fontsize=16:fontcolor=white:box=1:boxcolor=black@0.7:boxborderw=3:x=10:y=h-th-15:text=''WAVEFORM (Luma)''[wv]'
        $filters += $wvChunk
        $panelLabels += '[wv]'
        $idx++
    }
    
    if ($Vectorscope) {
        $vsChunk = '[s' + $idx.ToString() + ']vectorscope=m=color3:g=green,scale=512:512,' +
                   'drawtext=' + $font + ':fontsize=16:fontcolor=white:box=1:boxcolor=black@0.7:boxborderw=3:x=10:y=h-th-15:text=''VECTORSCOPE (Chroma)''[vs]'
        $filters += $vsChunk
        $panelLabels += '[vs]'
        $idx++
    }
    
    if ($AudioMeter) {
        $amChunk = '[0:a:0]ebur128=video=1:size=640x512:meter=18:target=' + $TgtLUFS + '[ebuvid][ebuaud];' +
                   '[ebuaud]anullsink;' +
                   '[ebuvid]drawtext=' + $font + ':fontsize=16:fontcolor=white:box=1:boxcolor=black@0.7:boxborderw=3:x=10:y=h-th-15:text=''LUFS METER (' + $LblLUFS + ')''[aw]'
        $filters += $amChunk
        $panelLabels += '[aw]'
    }
    
    $filters += ($panelLabels -join '') + 'hstack=inputs=' + $totalPanels.ToString() + '[out]'
    return ($filters -join '; ')
}

# --- [9] MAIN PROCESSING LOOP ---
$allReports = @()
$totalFiles = $files.Count
$processedCount = 0

foreach ($f in $files) {
    $processedCount++
    $pct = [int](($processedCount / $totalFiles) * 100)

    Write-Host ''
    Write-Host '==============================================================' -ForegroundColor DarkGray
    Write-Host (' [' + $processedCount + ' / ' + $totalFiles + '] (' + $pct + '%)  ' + $f.Name) -ForegroundColor Cyan
    Write-Host '==============================================================' -ForegroundColor DarkGray

    $report = Get-FileReport -File $f
    $hasAudio = [bool]$report.AudioCodec
    $isStereo = ($report.AudioChannels -eq '2 channels')
    
    # User feedback: Scanning starting
    if ($runGamutCheck) {
        Write-Host '  -> Running deep scan (Audio, Black Frames, Freezes, Gamut)... ' -NoNewline
    } else {
        Write-Host '  -> Running deep scan (Audio, Black Frames, Freezes)... ' -NoNewline
    }
    
    $deepScan = Get-DeepScan -FilePath $f.FullName -HasAudio $hasAudio -IsStereo $isStereo -RunGamut $runGamutCheck
    
    # User feedback: Scanning finished
    Write-Host 'Done!' -ForegroundColor Green
    
    # 1. Flag Audio Issues
    if ($hasAudio) {
        $report.IntegratedLUFS = if ($deepScan.I -ne 'N/A') { $deepScan.I + ' LUFS' } else { 'N/A' }
        
        if ($deepScan.I -ne 'N/A') {
            $lufsVal = 0.0
            if ([double]::TryParse($deepScan.I, [ref]$lufsVal)) {
                if ($lufsVal -lt $minLUFS -or $lufsVal -gt $maxLUFS) {
                    $report.QC_Flags += ('WARN: Out of Spec Loudness (' + $report.IntegratedLUFS + '. Target: ' + $targetLUFS + ' LUFS)')
                    if ($report.QC_Status -eq 'PASS') { $report.QC_Status = 'WARN' }
                }
            }
        }
        
        if ($deepScan.IsClipping) {
            $report.QC_Flags += 'WARN: Audio Peak Clipping Detected (Distortion)'
            if ($report.QC_Status -eq 'PASS') { $report.QC_Status = 'WARN' }
        }
        if ($deepScan.IsFullyDead) {
            $report.QC_Flags += 'FAIL: Audio Track Error: Track is completely silent'
            $report.QC_Status = 'FAIL'
        } elseif ($deepScan.IsLeftOnly) {
            $report.QC_Flags += 'FAIL: Audio Track Error: No audio detected on RIGHT Channel'
            $report.QC_Status = 'FAIL'
        } elseif ($deepScan.IsRightOnly) {
            $report.QC_Flags += 'FAIL: Audio Track Error: No audio detected on LEFT Channel'
            $report.QC_Status = 'FAIL'
        } elseif ($deepScan.IsDualMono) {
            $report.QC_Flags += 'NOTE: Track is Dual Mono (L/R channels are identical)'
        }
    }
    
    # 2. Flag Video Events (Black frames, Freezes)
    foreach ($bf in $deepScan.BlackFrames) {
        $report.QC_Flags += "FAIL: Blank Frame Event Detected at $([math]::Round($bf.Start, 3))s (Duration: $([math]::Round($bf.Duration, 3))s)"
        $report.QC_Status = 'FAIL'
    }
    foreach ($fe in $deepScan.Freeze) {
        $report.QC_Flags += "FAIL: Video Freeze Detected at $([math]::Round($fe.Start, 3))s (Duration: $([math]::Round($fe.Duration, 3))s)"
        $report.QC_Status = 'FAIL'
    }

    # 3. Flag Gamut Issues (If Enabled)
    if ($runGamutCheck) {
        $report.Gamut_Status = 'Legal' 
        if ($deepScan.HighLuma) { $report.QC_Flags += 'WARN: Luma exceeds Broadcast Legal (Super-Whites)'; $report.Gamut_Status = 'ILLEGAL'; if ($report.QC_Status -eq 'PASS') { $report.QC_Status = 'WARN' } }
        if ($deepScan.LowLuma) { $report.QC_Flags += 'WARN: Luma below Broadcast Legal (Sub-Blacks)'; $report.Gamut_Status = 'ILLEGAL'; if ($report.QC_Status -eq 'PASS') { $report.QC_Status = 'WARN' } }
        if ($deepScan.HighChroma -or $deepScan.LowChroma) { $report.QC_Flags += 'WARN: Chroma Saturation out of bounds'; $report.Gamut_Status = 'ILLEGAL'; if ($report.QC_Status -eq 'PASS') { $report.QC_Status = 'WARN' } }
    }

    # 4. Render Video
    if ($renderVideo) {
        Write-Host '  -> Rendering visual scopes proxy... ' -NoNewline
        
        $safeAudioMeter = $useAudioMeter -and $hasAudio
        $currentCodec = 'unknown'
        if ($report.VideoCodec) { $currentCodec = $report.VideoCodec }
        
        $filterGraph = Build-FilterGraph -Waveform $useWaveform -Vectorscope $useVectorscope -AudioMeter $safeAudioMeter -Filename $f.Name -Codec $currentCodec -Resolution $report.Resolution -FPS $report.FrameRate -TgtLUFS $targetLUFS.ToString() -LblLUFS $lufsLabel

        $outVideo = Join-Path $outputDir ('QC_' + $f.BaseName + '.mp4')
        $ffmpegArgs = @('-i', $f.FullName, '-filter_complex', $filterGraph, '-map', '[out]', '-map', '0:a:0?', '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-preset', 'faster', '-crf', '20', '-c:a', 'aac', '-b:a', '192k', $outVideo, '-y', '-loglevel', 'error')

        & $script:ffmpegPath $ffmpegArgs
        
        if ($LASTEXITCODE -eq 0) { Write-Host 'Done!' -ForegroundColor Green; $report.QC_VideoOutput = $outVideo }
        else { Write-Host 'FAILED.' -ForegroundColor Red; $report.QC_VideoOutput = 'FAILED RENDER'; $report.QC_Status = 'ERROR' }
    } else {
        $report.QC_VideoOutput = 'Not Generated (Report Only Mode)'
    }

    $allReports += $report
}

# --- [10] WRITE HTML REPORT ---
Write-Host ''
Write-Host '================================================================' -ForegroundColor Yellow
Write-Host '   WRITING QC REPORT (HTML)' -ForegroundColor White
Write-Host '================================================================' -ForegroundColor Yellow

$htmlPath = Join-Path $reportsDir 'QC_Report.html'

$passCount = ($allReports | Where-Object { $_.QC_Status -eq 'PASS' }).Count
$warnCount = ($allReports | Where-Object { $_.QC_Status -eq 'WARN' }).Count
$failCount = ($allReports | Where-Object { $_.QC_Status -eq 'FAIL' }).Count

$htmlOutput = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Video QC Dashboard</title>
    <style>
        :root { 
            --bg: #0f1115; --card: #1a1d24; --text: #e2e8f0; 
            --muted: #94a3b8; --border: #334155; 
            --pass: #10b981; --warn: #f59e0b; --fail: #ef4444; 
        }
        body { font-family: system-ui, -apple-system, sans-serif; background: var(--bg); color: var(--text); padding: 2rem; margin: 0; }
        .container { max-width: 1000px; margin: 0 auto; display: flex; flex-direction: column; gap: 1.5rem; }
        .header { margin-bottom: 2rem; border-bottom: 2px solid var(--border); padding-bottom: 1rem; }
        .header h1 { margin: 0; font-size: 1.8rem; }
        .header-top { display: flex; justify-content: space-between; align-items: baseline; margin-bottom: 0.5rem; }
        .dev-credit { color: var(--muted); font-size: 0.75rem; text-transform: uppercase; letter-spacing: 0.05em; font-weight: 600; }
        .summary-stats { display: flex; gap: 1rem; margin-top: 1rem; }
        
        .stat-badge { padding: 0.5rem 1rem; border-radius: 4px; font-weight: bold; cursor: pointer; transition: opacity 0.2s; user-select: none;}
        .stat-badge:hover { opacity: 0.8; }
        .stat-pass { background: rgba(16, 185, 129, 0.2); color: var(--pass); }
        .stat-warn { background: rgba(245, 158, 11, 0.2); color: var(--warn); }
        .stat-fail { background: rgba(239, 68, 68, 0.2); color: var(--fail); }
        
        .card { background: var(--card); border-radius: 8px; border-left: 6px solid var(--muted); box-shadow: 0 4px 6px rgba(0,0,0,0.3); overflow: hidden; }
        .card.status-PASS { border-color: var(--pass); }
        .card.status-WARN { border-color: var(--warn); }
        .card.status-FAIL { border-color: var(--fail); }
        .card-header { padding: 1rem 1.5rem; border-bottom: 1px solid var(--border); display: flex; justify-content: space-between; align-items: center; background: rgba(255,255,255,0.02); }
        .card-header h2 { margin: 0; font-size: 1.1rem; word-break: break-all; max-width: 80%; }
        .status-badge { padding: 0.25rem 0.75rem; border-radius: 999px; font-size: 0.875rem; font-weight: bold; text-transform: uppercase; }
        .badge-PASS { background: var(--pass); color: #000; }
        .badge-WARN { background: var(--warn); color: #000; }
        .badge-FAIL { background: var(--fail); color: #fff; }
        .card-body { padding: 1.5rem; display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 1.5rem; }
        .data-group h3 { margin: 0 0 0.75rem; color: var(--muted); font-size: 0.875rem; text-transform: uppercase; letter-spacing: 0.05em; border-bottom: 1px solid var(--border); padding-bottom: 0.25rem; }
        .data-row { display: flex; justify-content: space-between; margin-bottom: 0.5rem; font-size: 0.95rem; }
        .data-label { color: var(--muted); }
        .data-value { font-weight: 500; text-align: right; }
        
        /* 3-Tier Alert System CSS */
        .alerts { grid-column: 1 / -1; background: rgba(30, 41, 59, 0.5); border: 1px solid var(--border); border-radius: 6px; padding: 1rem; }
        .alerts h3 { margin-top: 0; margin-bottom: 0.5rem; color: var(--text); }
        .alerts ul { margin: 0; padding-left: 1.5rem; }
        .alerts li { margin-bottom: 0.4rem; font-size: 0.95rem; }
        .li-fail { color: var(--fail); font-weight: bold; }
        .li-warn { color: var(--warn); }
        .li-note { color: var(--muted); font-style: italic; }
    </style>
    <script>
        function filterCards(status) {
            const cards = document.querySelectorAll('.card');
            cards.forEach(card => {
                if (status === 'ALL') {
                    card.style.display = 'block';
                } else {
                    if (card.classList.contains('status-' + status)) {
                        card.style.display = 'block';
                    } else {
                        card.style.display = 'none';
                    }
                }
            });
        }
    </script>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="header-top">
                <h1>Video QC Report</h1>
                <div class="dev-credit">Video QC Dashbboard 3.2.0 | Developed By Rory M.</div>
            </div>
            <div style="color: var(--muted);">Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</div>
            <div class="summary-stats">
                <div class="stat-badge stat-pass" onclick="filterCards('PASS')">PASS: $passCount</div>
                <div class="stat-badge stat-warn" onclick="filterCards('WARN')">WARN: $warnCount</div>
                <div class="stat-badge stat-fail" onclick="filterCards('FAIL')">FAIL: $failCount</div>
                <div class="stat-badge" style="background: var(--border); color: var(--text);" onclick="filterCards('ALL')">SHOW ALL ($totalFiles)</div>
            </div>
        </div>
"@

function Format-HtmlRow($Label, $Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) { $Value = 'Unknown' }
    return "<div class='data-row'><span class='data-label'>$Label</span><span class='data-value'>$Value</span></div>"
}

foreach ($r in $allReports) {
    $statusClass = "status-" + $r.QC_Status
    $badgeClass = "badge-" + $r.QC_Status
    
    $htmlOutput += "        <div class='card $statusClass'>"
    $htmlOutput += "            <div class='card-header'>"
    $htmlOutput += "                <h2>" + $r.Filename + "</h2>"
    $htmlOutput += "                <span class='status-badge $badgeClass'>" + $r.QC_Status + "</span>"
    $htmlOutput += "            </div>"
    
    $htmlOutput += "            <div class='card-body'>"
    
    # General Column
    $htmlOutput += "                <div class='data-group'><h3>General</h3>"
    $htmlOutput += Format-HtmlRow "Format" $r.Format
    $htmlOutput += Format-HtmlRow "File Size" ($r.FileSizeMB.ToString() + ' MiB')
    $htmlOutput += Format-HtmlRow "Duration" $r.Duration_HMS
    $htmlOutput += Format-HtmlRow "Overall Bitrate" $r.OverallBitrate
    $htmlOutput += "                </div>"
    
    # Video Column
    $htmlOutput += "                <div class='data-group'><h3>Video</h3>"
    $htmlOutput += Format-HtmlRow "Codec" $r.VideoCodec
    $htmlOutput += Format-HtmlRow "Resolution" $r.Resolution
    $htmlOutput += Format-HtmlRow "Frame Rate" $r.FrameRate
    $htmlOutput += Format-HtmlRow "Bitrate" $r.VideoBitrate
    
    $gamutStr = $r.Gamut_Status
    if ($gamutStr -eq 'ILLEGAL') {
        $gamutStr = "<span style='color:var(--warn); font-weight:bold;'>$gamutStr</span>"
    } elseif ($gamutStr -eq 'Legal') {
        $gamutStr = "<span style='color:var(--pass); font-weight:bold;'>$gamutStr</span>"
    } else {
        $gamutStr = "<span style='color:var(--muted); font-style:italic;'>$gamutStr</span>"
    }
    
    $htmlOutput += Format-HtmlRow "Color Gamut" $gamutStr
    $htmlOutput += "                </div>"
    
    # Audio Column
    if ($r.AudioCodec) {
        $htmlOutput += "                <div class='data-group'><h3>Audio</h3>"
        $htmlOutput += Format-HtmlRow "Codec" $r.AudioCodec
        $htmlOutput += Format-HtmlRow "Channels" $r.AudioChannels
        $htmlOutput += Format-HtmlRow "Sample Rate" $r.AudioSampleRate
        $htmlOutput += Format-HtmlRow "Loudness" $r.IntegratedLUFS
        $htmlOutput += Format-HtmlRow "Bitrate" $r.AudioBitrate
        $htmlOutput += "                </div>"
    } else {
        $htmlOutput += "                <div class='data-group'><h3>Audio</h3><div style='color:var(--muted); font-style:italic;'>No audio stream detected.</div></div>"
    }

    # 3-Tier Alerts Block
    if ($r.QC_Flags.Count -gt 0) {
        $htmlOutput += "                <div class='alerts'><h3>QC Flags & Alerts</h3><ul>"
        foreach ($flag in $r.QC_Flags) {
            $liClass = "li-note"
            if ($flag -match '^FAIL') { $liClass = "li-fail" }
            if ($flag -match '^WARN') { $liClass = "li-warn" }
            
            $htmlOutput += "<li class='$liClass'>$flag</li>"
        }
        $htmlOutput += "                </ul></div>"
    }

    $htmlOutput += "            </div>"
    $htmlOutput += "        </div>"
}

$htmlOutput += @"
    </div>
</body>
</html>
"@

$htmlOutput | Set-Content -Path $htmlPath -Encoding UTF8
Write-Host ('  [HTML]  ' + $htmlPath) -ForegroundColor Green

# --- [11] CLEANUP & FINISH ---
Write-Host ''
Write-Host '================================================================' -ForegroundColor Yellow
Write-Host '   CLEANUP OPTIONS' -ForegroundColor White
Write-Host '================================================================' -ForegroundColor Yellow
Write-Host ' Would you like to remove the FFmpeg background engines?' -ForegroundColor Cyan
Write-Host ' (Type Y to delete them and save 150MB of space, or N to keep them' -ForegroundColor DarkGray
Write-Host ' so the tool loads instantly without downloading next time).' -ForegroundColor DarkGray
Write-Host ''

$cleanup = Read-Host ' Remove engines? [Y/N]'

if ($cleanup -match '^y') {
    Write-Host '  -> Cleaning up... ' -NoNewline
    Remove-Item -Path $AppDataDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host 'Done!' -ForegroundColor Green
}

Write-Host ''
Write-Host '================================================================' -ForegroundColor Yellow
Write-Host '   BATCH COMPLETE' -ForegroundColor White
Write-Host '================================================================' -ForegroundColor Yellow
Write-Host ('  Total files processed : ' + $totalFiles)
Write-Host ('  PASS                  : ' + $passCount) -ForegroundColor Green
Write-Host ('  WARN (flags)          : ' + $warnCount) -ForegroundColor Yellow
Write-Host ('  FAIL (media errors)   : ' + $failCount) -ForegroundColor Red
Write-Host '================================================================' -ForegroundColor Yellow

Write-Host ''
Write-Host '  Opening report in default browser...' -ForegroundColor DarkGray
Invoke-Item $htmlPath

Pause
