# Mayniak AI Studio - Setup Script
# scripts/ lives at root, app/ is a sibling folder

$scriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir     = Split-Path -Parent $scriptDir
$appDir      = Join-Path $rootDir "app"
$frontendDir = Join-Path $appDir  "frontend"
$toolsDir    = Join-Path $appDir  "tools"
$nodeDir     = Join-Path $toolsDir "node-win"
$nodeExe     = Join-Path $nodeDir  "node.exe"
$npmCmd      = Join-Path $nodeDir  "npm.cmd"
$distDir     = Join-Path $appDir   "dist"
$pythonDir   = Join-Path $toolsDir "python"
$pythonExe   = Join-Path $pythonDir "python.exe"
$pydepsDir   = Join-Path $appDir   "pydeps"

# ── Helpers ───────────────────────────────────────────────────────────────────
function Print-Header {
    Clear-Host
    Write-Host ""
    Write-Host "  ============================================================" -ForegroundColor Cyan
    Write-Host "   MAYNIAK AI STUDIO  -  First-Time Setup" -ForegroundColor Cyan
    Write-Host "   100% Self-Contained  |  No System Install Required" -ForegroundColor DarkCyan
    Write-Host "  ============================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Print-Step {
    param([int]$n, [int]$total, [string]$title)
    Write-Host ""
    Write-Host "  [$n/$total] $title" -ForegroundColor White
    Write-Host ("  " + "-" * 56) -ForegroundColor DarkGray
}

function Print-OK   { param([string]$m); Write-Host "   OK  $m" -ForegroundColor Green }
function Print-Info { param([string]$m); Write-Host "   >>  $m" -ForegroundColor Cyan }
function Print-Warn { param([string]$m); Write-Host "   !!  $m" -ForegroundColor Yellow }
function Print-Fail { param([string]$m); Write-Host "   XX  $m" -ForegroundColor Red }

function Format-Bytes {
    param([long]$b)
    if ($b -gt 1GB) { return "{0:N2} GB" -f ($b / 1GB) }
    if ($b -gt 1MB) { return "{0:N1} MB" -f ($b / 1MB) }
    return "{0:N0} KB" -f ($b / 1KB)
}

function Format-Speed {
    param([double]$bps)
    if ($bps -gt 1MB) { return "{0:N1} MB/s" -f ($bps / 1MB) }
    return "{0:N0} KB/s" -f ($bps / 1KB)
}

function Invoke-RichDownload {
    param([string]$Url, [string]$Dest, [string]$Label)
    Print-Info "Downloading: $Label"
    Write-Host ""

    $barWidth  = 48
    $lastBytes = [long]0
    $lastTime  = [DateTime]::Now

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $req    = [System.Net.HttpWebRequest]::Create($Url)
        $req.UserAgent = "Mozilla/5.0"
        $resp   = $req.GetResponse()
        $total  = [long]$resp.ContentLength
        $stream = $resp.GetResponseStream()
        $out    = [System.IO.File]::Create($Dest)
        $buf    = New-Object byte[] 65536
        $done   = [long]0

        while ($true) {
            $read = $stream.Read($buf, 0, $buf.Length)
            if ($read -le 0) { break }
            $out.Write($buf, 0, $read)
            $done += $read

            $now     = [DateTime]::Now
            $elapsed = ($now - $lastTime).TotalSeconds
            if ($elapsed -ge 0.35) {
                $speed     = ($done - $lastBytes) / $elapsed
                $lastBytes = $done
                $lastTime  = $now
                $pct  = if ($total -gt 0) { [int](($done / $total) * 100) } else { 0 }
                $fill = [int](($pct / 100) * $barWidth)
                $bar  = ("#" * $fill) + ("-" * ($barWidth - $fill))

                $eta = ""
                if ($speed -gt 0 -and $total -gt 0) {
                    $rem = [int](($total - $done) / $speed)
                    $eta = "  ETA $([int]($rem/60))m$($rem%60)s"
                }

                $dl  = Format-Bytes $done
                $tot = if ($total -gt 0) { " / " + (Format-Bytes $total) } else { "" }
                $spd = Format-Speed $speed
                Write-Host -NoNewline "`r  [$bar] $pct%  $dl$tot  $spd$eta   "
            }
        }

        $out.Close(); $stream.Close()
        Write-Host "`r  [$("#" * $barWidth)] 100%  $(Format-Bytes $done)  Done!                         " -ForegroundColor Green
        Write-Host ""
        return $true
    } catch {
        Write-Host ""
        Print-Fail "Download failed: $_"
        return $false
    }
}

function Expand-WithProgress {
    param([string]$ZipPath, [string]$Destination, [string]$Label)
    Print-Info "Extracting $Label..."
    Write-Host ""

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip   = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
    $total = $zip.Entries.Count
    $barW  = 48
    $i = 0

    New-Item -ItemType Directory -Force -Path $Destination | Out-Null

    foreach ($entry in $zip.Entries) {
        $i++
        $pct  = [int](($i / $total) * 100)
        $fill = [int](($pct / 100) * $barW)
        $bar  = ("#" * $fill) + ("-" * ($barW - $fill))
        $name = $entry.Name
        if ($name.Length -gt 28) { $name = "..." + $name.Substring($name.Length - 28) }
        Write-Host -NoNewline "`r  [$bar] $pct%  $name                    "

        if ($entry.FullName.EndsWith("/") -or $entry.FullName.EndsWith("\")) {
            New-Item -ItemType Directory -Force -Path (Join-Path $Destination $entry.FullName) | Out-Null
        } else {
            $destFile = Join-Path $Destination $entry.FullName
            $destDir  = Split-Path -Parent $destFile
            New-Item -ItemType Directory -Force -Path $destDir | Out-Null
            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $destFile, $true)
        }
    }

    $zip.Dispose()
    Write-Host "`r  [$("#" * $barW)] 100%  $total files extracted!                    " -ForegroundColor Green
    Write-Host ""
}

# ══════════════════════════════════════════════════════════════════════════════
function Test-DiffusersRuntime {
    if (-not ((Test-Path $pythonExe) -and (Test-Path $pydepsDir))) {
        return $false
    }

    $oldPythonPath = $env:PYTHONPATH
    $oldPath = $env:PATH
    try {
        $env:PYTHONPATH = $pydepsDir
        $torchLib = Join-Path $pydepsDir "torch\lib"
        $pathParts = @($pythonDir)
        if (Test-Path $torchLib) { $pathParts += $torchLib }
        $env:PATH = (($pathParts | Where-Object { Test-Path $_ }) -join ";") + ";$env:PATH"
        & $pythonExe -c "import torch, diffusers, safetensors" *> $null
        return $LASTEXITCODE -eq 0
    } catch {
        return $false
    } finally {
        $env:PYTHONPATH = $oldPythonPath
        $env:PATH = $oldPath
    }
}

Print-Header

$steps = 5

# ── Step 1: Portable Node.js ──────────────────────────────────────────────────
Print-Step 1 $steps "Setting up portable Node.js (app/tools/node-win/)"

if ((Test-Path $nodeExe) -and (Test-Path $npmCmd)) {
    $v = & $nodeExe --version
    Print-OK "Portable Node.js already ready: $v"
} else {
    $nodeZip = Join-Path $toolsDir "node.zip"
    New-Item -ItemType Directory -Force -Path $toolsDir | Out-Null

    $ok = Invoke-RichDownload `
        -Url  "https://nodejs.org/dist/v22.12.0/node-v22.12.0-win-x64.zip" `
        -Dest $nodeZip `
        -Label "Node.js v22.12.0 LTS (Portable ZIP)"

    if (-not $ok) { Print-Fail "Cannot download Node.js."; Read-Host; exit 1 }

    Expand-WithProgress -ZipPath $nodeZip -Destination $toolsDir -Label "Node.js"
    Remove-Item $nodeZip -Force

    $extracted = Get-ChildItem $toolsDir -Directory | Where-Object { $_.Name -like "node-v*" } | Select-Object -First 1
    if ($extracted) {
        if (Test-Path $nodeDir) { Remove-Item $nodeDir -Recurse -Force }
        Rename-Item $extracted.FullName "node-win"
    }

    if (-not ((Test-Path $nodeExe) -and (Test-Path $npmCmd))) {
        Print-Fail "Portable Node.js install is incomplete. Close any running Mayniak AI Studio windows, delete app/tools/node-win, then run setup again."
        Read-Host; exit 1
    }

    $v = & $nodeExe --version
    Print-OK "Portable Node.js ready: $v"
}

# ── Step 2: stable-diffusion.cpp GPU Backend (Dynamic Detection) ──────────────
$hasNvidia = $false
try {
    $gpus = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue
    foreach ($gpu in $gpus) {
        if ($gpu.Name -like "*NVIDIA*") {
            $hasNvidia = $true
        }
    }
} catch {}
if (-not $hasNvidia) {
    try {
        & nvidia-smi *> $null
        if ($LASTEXITCODE -eq 0) { $hasNvidia = $true }
    } catch {}
}

if ($hasNvidia) {
    Print-Step 2 $steps "Setting up stable-diffusion.cpp CUDA GPU backend (app/backend/win/cuda/)"
    $backendDest = Join-Path $appDir "backend\win\cuda"
    $backendExe  = Join-Path $backendDest "sd-cuda.exe"
    $backendDll  = Join-Path $backendDest "stable-diffusion.dll"
    
    if ((Test-Path $backendExe) -and (Test-Path $backendDll)) {
        Print-OK "CUDA GPU backend binaries already ready."
    } else {
        $backendZip = Join-Path $toolsDir "sd-cuda.zip"
        New-Item -ItemType Directory -Force -Path $toolsDir | Out-Null
        New-Item -ItemType Directory -Force -Path $backendDest | Out-Null

        $ok = Invoke-RichDownload `
            -Url  "https://github.com/leejet/stable-diffusion.cpp/releases/download/master-669-2d40a8b/sd-master-2d40a8b-bin-win-cuda12-x64.zip" `
            -Dest $backendZip `
            -Label "stable-diffusion.cpp CUDA Backend (Windows x64)"

        if (-not $ok) { Print-Fail "Cannot download CUDA backend binaries."; Read-Host; exit 1 }

        $tempExt = Join-Path $toolsDir "sd-cuda-temp"
        Expand-WithProgress -ZipPath $backendZip -Destination $tempExt -Label "CUDA Backend"
        Remove-Item $backendZip -Force

        # Move files and rename sd.exe/sd-server.exe to sd-cuda.exe
        if (Test-Path $tempExt) {
            $extractedExe = Join-Path $tempExt "bin\sd-server.exe"
            if (-not (Test-Path $extractedExe)) { $extractedExe = Join-Path $tempExt "sd-server.exe" }
            if (-not (Test-Path $extractedExe)) { $extractedExe = Join-Path $tempExt "bin\sd.exe" }
            if (-not (Test-Path $extractedExe)) { $extractedExe = Join-Path $tempExt "sd.exe" }
            
            $extractedDll = Join-Path $tempExt "bin\stable-diffusion.dll"
            if (-not (Test-Path $extractedDll)) { $extractedDll = Join-Path $tempExt "stable-diffusion.dll" }

            if (Test-Path $extractedExe) { Copy-Item $extractedExe $backendExe -Force }
            if (Test-Path $extractedDll) { Copy-Item $extractedDll $backendDll -Force }
            
            # Copy any other DLLs or EXEs
            Get-ChildItem $tempExt -Filter "*.dll" -Recurse | ForEach-Object { Copy-Item $_.FullName $backendDest -Force }
            Get-ChildItem $tempExt -Filter "*.exe" -Recurse | ForEach-Object {
                if ($_.FullName -ne $extractedExe) { Copy-Item $_.FullName $backendDest -Force }
            }
            Remove-Item $tempExt -Recurse -Force
        }

        if ((Test-Path $backendExe) -and (Test-Path $backendDll)) {
            Print-OK "CUDA GPU backend binaries installed successfully!"
        } else {
            Print-Fail "Failed to copy backend binaries to app/backend/win/cuda/."
            Read-Host; exit 1
        }
    }

    $cudaDllsExist = (Test-Path (Join-Path $backendDest "cublas64_12.dll")) -and `
                     (Test-Path (Join-Path $backendDest "cublasLt64_12.dll")) -and `
                     (Test-Path (Join-Path $backendDest "cudart64_12.dll"))

    if (-not $cudaDllsExist) {
        Print-Info "CUDA runtime DLLs are missing from backend folder. Downloading portable CUDA v12 runtime..."
        $dllZip = Join-Path $toolsDir "cuda-dlls.zip"
        $ok = Invoke-RichDownload `
            -Url  "https://github.com/ggml-org/llama.cpp/releases/download/b9509/cudart-llama-bin-win-cuda-12.4-x64.zip" `
            -Dest $dllZip `
            -Label "CUDA v12 Runtime DLLs (llama.cpp)"

        if ($ok) {
            Expand-WithProgress -ZipPath $dllZip -Destination $backendDest -Label "CUDA Runtime DLLs"
            Remove-Item $dllZip -Force
            Print-OK "CUDA runtime DLLs set up successfully!"
        } else {
            Print-Warn "Could not download portable CUDA runtime DLLs automatically. If the app fails to start in CUDA mode, you may need to install the CUDA Toolkit manually."
        }
    }

    Print-Step 2 $steps "Setting up stable-diffusion.cpp Vulkan GPU backend for comparison (app/backend/win/vulkan/)"
    $backendDest = Join-Path $appDir "backend\win\vulkan"
    $backendExe  = Join-Path $backendDest "sd-vulkan.exe"
    $backendDll  = Join-Path $backendDest "stable-diffusion.dll"

    if ((Test-Path $backendExe) -and (Test-Path $backendDll)) {
        Print-OK "Vulkan GPU backend binaries already ready."
    } else {
        $backendZip = Join-Path $toolsDir "sd-vulkan.zip"
        New-Item -ItemType Directory -Force -Path $toolsDir | Out-Null
        New-Item -ItemType Directory -Force -Path $backendDest | Out-Null

        $ok = Invoke-RichDownload `
            -Url  "https://github.com/leejet/stable-diffusion.cpp/releases/download/master-669-2d40a8b/sd-master-2d40a8b-bin-win-vulkan-x64.zip" `
            -Dest $backendZip `
            -Label "stable-diffusion.cpp Vulkan Backend (Windows x64)"

        if (-not $ok) { Print-Fail "Cannot download Vulkan backend binaries."; Read-Host; exit 1 }

        $tempExt = Join-Path $toolsDir "sd-vulkan-temp"
        Expand-WithProgress -ZipPath $backendZip -Destination $tempExt -Label "Vulkan Backend"
        Remove-Item $backendZip -Force

        if (Test-Path $tempExt) {
            $extractedExe = Join-Path $tempExt "bin\sd-server.exe"
            if (-not (Test-Path $extractedExe)) { $extractedExe = Join-Path $tempExt "sd-server.exe" }
            if (-not (Test-Path $extractedExe)) { $extractedExe = Join-Path $tempExt "bin\sd.exe" }
            if (-not (Test-Path $extractedExe)) { $extractedExe = Join-Path $tempExt "sd.exe" }

            $extractedDll = Join-Path $tempExt "bin\stable-diffusion.dll"
            if (-not (Test-Path $extractedDll)) { $extractedDll = Join-Path $tempExt "stable-diffusion.dll" }

            if (Test-Path $extractedExe) { Copy-Item $extractedExe $backendExe -Force }
            if (Test-Path $extractedDll) { Copy-Item $extractedDll $backendDll -Force }

            Get-ChildItem $tempExt -Filter "*.dll" -Recurse | ForEach-Object { Copy-Item $_.FullName $backendDest -Force }
            Get-ChildItem $tempExt -Filter "*.exe" -Recurse | ForEach-Object {
                if ($_.FullName -ne $extractedExe) { Copy-Item $_.FullName $backendDest -Force }
            }
            Remove-Item $tempExt -Recurse -Force
        }

        if ((Test-Path $backendExe) -and (Test-Path $backendDll)) {
            Print-OK "Vulkan GPU backend binaries installed successfully!"
        } else {
            Print-Fail "Failed to copy backend binaries to app/backend/win/vulkan/."
            Read-Host; exit 1
        }
    }
} else {
    Print-Step 2 $steps "Setting up stable-diffusion.cpp Vulkan GPU backend (app/backend/win/vulkan/)"
    $backendDest = Join-Path $appDir "backend\win\vulkan"
    $backendExe  = Join-Path $backendDest "sd-vulkan.exe"
    $backendDll  = Join-Path $backendDest "stable-diffusion.dll"
    
    if ((Test-Path $backendExe) -and (Test-Path $backendDll)) {
        Print-OK "Vulkan GPU backend binaries already ready."
    } else {
        $backendZip = Join-Path $toolsDir "sd-vulkan.zip"
        New-Item -ItemType Directory -Force -Path $toolsDir | Out-Null
        New-Item -ItemType Directory -Force -Path $backendDest | Out-Null

        $ok = Invoke-RichDownload `
            -Url  "https://github.com/leejet/stable-diffusion.cpp/releases/download/master-669-2d40a8b/sd-master-2d40a8b-bin-win-vulkan-x64.zip" `
            -Dest $backendZip `
            -Label "stable-diffusion.cpp Vulkan Backend (Windows x64)"

        if (-not $ok) { Print-Fail "Cannot download Vulkan backend binaries."; Read-Host; exit 1 }

        $tempExt = Join-Path $toolsDir "sd-vulkan-temp"
        Expand-WithProgress -ZipPath $backendZip -Destination $tempExt -Label "Vulkan Backend"
        Remove-Item $backendZip -Force

        # Move files and rename sd.exe/sd-server.exe to sd-vulkan.exe
        if (Test-Path $tempExt) {
            $extractedExe = Join-Path $tempExt "bin\sd-server.exe"
            if (-not (Test-Path $extractedExe)) { $extractedExe = Join-Path $tempExt "sd-server.exe" }
            if (-not (Test-Path $extractedExe)) { $extractedExe = Join-Path $tempExt "bin\sd.exe" }
            if (-not (Test-Path $extractedExe)) { $extractedExe = Join-Path $tempExt "sd.exe" }
            
            $extractedDll = Join-Path $tempExt "bin\stable-diffusion.dll"
            if (-not (Test-Path $extractedDll)) { $extractedDll = Join-Path $tempExt "stable-diffusion.dll" }

            if (Test-Path $extractedExe) { Copy-Item $extractedExe $backendExe -Force }
            if (Test-Path $extractedDll) { Copy-Item $extractedDll $backendDll -Force }
            
            # Copy any other DLLs or EXEs
            Get-ChildItem $tempExt -Filter "*.dll" -Recurse | ForEach-Object { Copy-Item $_.FullName $backendDest -Force }
            Get-ChildItem $tempExt -Filter "*.exe" -Recurse | ForEach-Object {
                if ($_.FullName -ne $extractedExe) { Copy-Item $_.FullName $backendDest -Force }
            }
            Remove-Item $tempExt -Recurse -Force
        }

        if ((Test-Path $backendExe) -and (Test-Path $backendDll)) {
            Print-OK "Vulkan GPU backend binaries installed successfully!"
        } else {
            Print-Fail "Failed to copy backend binaries to app/backend/win/vulkan/."
            Read-Host; exit 1
        }
    }
}

# ── Step 3: npm install ───────────────────────────────────────────────────────
Print-Step 3 $steps "Setting up Python image runtime (app/pydeps/)"
Write-Host ""

if (Test-DiffusersRuntime) {
    Print-OK "Python image runtime already ready."
} else {
    New-Item -ItemType Directory -Force -Path $toolsDir | Out-Null
    New-Item -ItemType Directory -Force -Path $pydepsDir | Out-Null

    if (-not (Test-Path $pythonExe)) {
        $pythonPackage = Join-Path $toolsDir "python-3.12.nupkg"
        $pythonTemp = Join-Path $toolsDir "python-nuget-temp"
        $ok = Invoke-RichDownload `
            -Url "https://www.nuget.org/api/v2/package/python/3.12.10" `
            -Dest $pythonPackage `
            -Label "Python 3.12 Runtime"

        if (-not $ok) { Print-Fail "Cannot download Python runtime."; Read-Host; exit 1 }

        if (Test-Path $pythonTemp) { Remove-Item $pythonTemp -Recurse -Force }
        if (Test-Path $pythonDir) { Remove-Item $pythonDir -Recurse -Force }
        Expand-WithProgress -ZipPath $pythonPackage -Destination $pythonTemp -Label "Python Runtime"
        Move-Item (Join-Path $pythonTemp "tools") $pythonDir
        Remove-Item $pythonPackage -Force -ErrorAction SilentlyContinue
        Remove-Item $pythonTemp -Recurse -Force -ErrorAction SilentlyContinue

        if (-not (Test-Path $pythonExe)) {
            Print-Fail "Python runtime install failed."
            Read-Host; exit 1
        }
    }

    $vcDll = Join-Path $pythonDir "msvcp140.dll"
    if (-not (Test-Path $vcDll)) {
        $vcPackage = Join-Path $toolsDir "vcruntime140.nupkg"
        $vcTemp = Join-Path $toolsDir "vcruntime140-temp"
        $ok = Invoke-RichDownload `
            -Url "https://www.nuget.org/api/v2/package/ThinkGeo.Dependency.MicrosoftVisualCRunTime140/15.0.0-beta007" `
            -Dest $vcPackage `
            -Label "Microsoft Visual C++ Runtime DLLs"

        if (-not $ok) { Print-Fail "Cannot download Microsoft Visual C++ runtime DLLs."; Read-Host; exit 1 }

        if (Test-Path $vcTemp) { Remove-Item $vcTemp -Recurse -Force }
        Expand-WithProgress -ZipPath $vcPackage -Destination $vcTemp -Label "Microsoft Visual C++ Runtime"
        Copy-Item (Join-Path $vcTemp "runtimes\win-x64\native\*.dll") $pythonDir -Force
        Remove-Item $vcPackage -Force -ErrorAction SilentlyContinue
        Remove-Item $vcTemp -Recurse -Force -ErrorAction SilentlyContinue
    }

    if (Test-DiffusersRuntime) {
        Print-OK "Python image runtime ready."
    } else {
        Print-Info "Installing Python image packages. This is several GB and can take a while..."
        & $pythonExe -m pip install --upgrade pip
        if ($LASTEXITCODE -ne 0) { Print-Fail "pip upgrade failed."; Read-Host; exit 1 }

        & $pythonExe -m pip install `
            --upgrade `
            --target $pydepsDir `
            --extra-index-url "https://download.pytorch.org/whl/cu124" `
            torch==2.6.0+cu124 `
            diffusers==0.38.0 `
            transformers==4.57.3 `
            accelerate `
            safetensors `
            pillow `
            sentencepiece `
            protobuf `
            psutil
        if ($LASTEXITCODE -ne 0) {
            Print-Fail "Python image runtime install failed."
            Read-Host; exit 1
        }

        if (Test-DiffusersRuntime) {
            Print-OK "Python image runtime ready."
        } else {
            Print-Fail "Python image runtime did not validate."
            Read-Host; exit 1
        }
    }
}

Print-Step 4 $steps "Installing frontend dependencies (app/frontend/)"
Write-Host ""

if (-not (Test-Path $npmCmd)) {
    Print-Fail "npm.cmd was not found at $npmCmd"
    Print-Fail "Close any running Mayniak AI Studio windows, delete app/tools/node-win, then run setup again."
    Read-Host; exit 1
}

Push-Location $frontendDir
$oldPath = $env:PATH
try {
    $env:PATH = "$nodeDir;$env:PATH"
    & $npmCmd install --prefer-offline 2>&1
    if ($LASTEXITCODE -ne 0) {
        Print-Fail "npm install failed."
        Read-Host; exit 1
    }
    Write-Host ""
    Print-OK "Dependencies installed!"

    # ── Step 4: Build frontend ────────────────────────────────────────────────
    Print-Step 5 $steps "Building frontend -> app/dist/"
    Write-Host ""

    & $npmCmd run build 2>&1
    if ($LASTEXITCODE -ne 0) {
        Print-Fail "Frontend build failed."
        Read-Host; exit 1
    }
    Write-Host ""
    Print-OK "Frontend built!"
} finally {
    $env:PATH = $oldPath
    Pop-Location
}

# ── Done ─────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  ============================================================" -ForegroundColor Green
Write-Host "   Setup complete! Just double-click start.bat to launch." -ForegroundColor Green
Write-Host "  ============================================================" -ForegroundColor Green
Write-Host ""
Read-Host "  Press Enter to close..."
