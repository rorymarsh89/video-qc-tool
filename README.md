# Video QC Dashboard Generator

A professional, automated Quality Control (QC) pipeline for video files. This PowerShell script utilizes FFmpeg and FFprobe to perform deep technical scans of video and audio, generating a visual scope overlay (MP4) and an interactive HTML dashboard report.

## ✨ Features

* **Cloud Bootstrapper Setup:** Run a single line of code, and the script autonomously downloads and configures the required FFmpeg/FFprobe engines into your local AppData. No manual installation required.
* **Interactive HTML Dashboard:** Generates a clean, filterable HTML report with a 3-tier status system (PASS, WARN, FAIL) for rapid triage.
* **Dynamic Visual Scopes:** Automatically renders an MP4 proxy featuring a timecode burn-in, Luma Waveform, Chroma Vectorscope, and an active LUFS meter.
* **Deep Audio & Video Scanning:**
  * Detects exact timestamps for Black Frames and Video Freezes.
  * Detects Completely Dead Tracks, Left/Right only audio, and Dual Mono setups.
  * Flags Audio Peak Clipping (Distortion).
* **Broadcast Legal Luma & Chroma (Gamut) Check:** Optional deep-scan mode to flag illegal Super-Whites, Sub-Blacks, and out-of-bounds Chroma saturation.
* **Dynamic Loudness Targeting:** Choose between Web Delivery (-14 LUFS, +/- 2.0) or strict Broadcast Delivery (EBU R128 -23 LUFS, +/- 0.5) to automatically flag non-compliant audio levels.

## 🚀 Quick Start (Recommended)

You can launch the tool directly from PowerShell without downloading the repository manually. 

1. Open **Windows PowerShell**.
2. Paste the following command and press Enter:

```powershell
[IRM [https://raw.githubusercontent.com/YOUR-USERNAME/YOUR-REPO/main/qc-generator.ps1](https://raw.githubusercontent.com/YOUR-USERNAME/YOUR-REPO/main/qc-generator.ps1) | IEX](https://raw.githubusercontent.com/rorymarsh89/video-qc-tool/refs/heads/main/qc-generator.ps1)
