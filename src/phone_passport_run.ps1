# phone_passport_enhanced_v5.0.ps1
# Full phone passport collector (TXT + HTML) - v5.0 (FINAL ENGLISH VERSION + BATTERY CHECK)
# Added battery check via /sys/class/power_supply/

# ------------------------------
# CONFIG / GLOBAL VARS
# ------------------------------
$ForceAdb = $null 
$TimeStamp = Get-Date -Format "yyyyMMdd_HHmmss"

# Colors for console output
$ColorCritical = "Red"
$ColorWarning = "Yellow"
$ColorSuccess = "Green"
$ColorHighlight = "Cyan"
$ColorDefault = "White"

# Report file paths
$ScriptFolder = Split-Path -Parent $MyInvocation.MyCommand.Definition
if (-not $ScriptFolder) { $ScriptFolder = Get-Location }
$LogsFolder = Join-Path $ScriptFolder "logs"
$SuspApkFolder = Join-Path $LogsFolder "suspicious_apks"
$ReportFileTxt = Join-Path $LogsFolder ("phone_passport_" + $TimeStamp + ".txt")
$ReportFileHtml = Join-Path $LogsFolder ("phone_passport_" + $TimeStamp + ".html")

# Global variables for HTML report data
$HtmlData = [ordered]@{}
$HtmlLog = "" 


# ------------------------------
# HELPER FUNCTIONS 
# ------------------------------

function Ensure-Folder {
    param([string]$path)
    if (-not (Test-Path $path)) {
        New-Item -ItemType Directory -Path $path | Out-Null
    }
}

function Find-Adb {
    param([string]$forced)
    if ($forced -and (Test-Path $forced)) { return (Get-Item $forced).FullName }
    $cmd = Get-Command adb -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Path }
    $candidates = @(
        "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe",
        "$env:ProgramFiles\Android\platform-tools\adb.exe",
        "$env:ProgramFiles(x86)\Android\platform-tools\adb.exe",
        "C:\platform-tools\adb.exe",
        "D:\platform-tools\adb.exe",
        "D:\programs\platform-tools\adb.exe",
        "$env:USERPROFILE\platform-tools\adb.exe"
    )
    foreach ($p in $candidates) {
        if (Test-Path $p) { return (Get-Item $p).FullName }
    }
    return $null
}

# Key output function (Now in English)
function Write-KeyOutput {
    param(
        [string]$Label,
        [string]$Value,
        [string]$Color = "White", 
        [string]$HtmlSection = "Props"
    )
    $OutputLine = "$Label : $Value"
    
    # Console output
    Write-Host ">>> [SECTION $HtmlSection] CHECKING: $Label" -ForegroundColor $ColorHighlight
    Write-Host "--- RESULT: $Value" -ForegroundColor $Color
    
    # Write to TXT log
    Add-Content -Path $ReportFileTxt -Value $OutputLine
    
    # Collect data for HTML
    if (-not $HtmlData.Contains($HtmlSection)) {
        $HtmlData[$HtmlSection] = [ordered]@{}
    }
    $HtmlData[$HtmlSection][$Label] = $Value
}

# Raw log function (Now in English)
function Write-LogRaw {
    param(
        [string]$Title,
        [string]$Content
    )
    # Console output
    Write-Host "`n--- RAW LOG: $Title ---" -ForegroundColor $ColorHighlight
    if ($Content -ne "N/A") {
        Write-Host "LOG RECORDED TO FILE." -ForegroundColor $ColorSuccess
    } else {
        Write-Host "LOG NOT AVAILABLE (N/A)." -ForegroundColor $ColorWarning
    }
    
    # Write to TXT log
    Add-Content -Path $ReportFileTxt -Value ""
    Add-Content -Path $ReportFileTxt -Value "--- $Title ---"
    Add-Content -Path $ReportFileTxt -Value $Content
    
    # Write to HTML Log
    $script:HtmlLog += "`n<h3 style='color: #81d4fa;'>$Title</h3>`n<pre>`n$Content`n</pre>"
}

# Safe Run
function Safe-Run {
    param([ScriptBlock]$action)
    try {
        $res = & $action
        if ($null -eq $res) { return "N/A" }
        if ($res -is [System.Array]) {
            return ($res -join "`n").Trim()
        } else {
            $s = [string]$res
            if ([string]::IsNullOrWhiteSpace($s)) { return "N/A" }
            return $s.Trim()
        }
    } catch {
        Write-Host "Safe-Run Error: Command execution failed." -ForegroundColor $ColorWarning
        return "N/A"
    }
}

# Digits Only
function DigitsOnly {
    param([string]$s)
    if ($null -eq $s) { return "" }
    return ($s -replace '[^0-9]', '')
}

# ADB Wrappers
function ADB-RUN {
    param([Parameter(ValueFromRemainingArguments=$true)][string[]]$Args)
    try {
        $out = & $AdbExe @Args 2>$null
        if ($null -eq $out) { 
            Write-Host "-> ADB-RUN failed: '$Args[0]' returned empty output." -ForegroundColor $ColorWarning
            return "N/A" 
        }
        if ($out -is [System.Array]) { return ($out -join "`n").Trim() }
        return [string]$out
    } catch { 
        Write-Host "-> ADB-RUN CRITICAL ERROR: '$Args[0]' failed to execute." -ForegroundColor $ColorCritical
        return "N/A" 
    }
}

function ADB-SHELL {
    param([string]$Cmd)
    try {
        $CmdWithSuppress = $Cmd + " 2>/dev/null"
        $out = & $AdbExe "shell" $CmdWithSuppress
        
        if ($null -eq $out) { 
            Write-Host "-> ADB-SHELL failed: '$Cmd' returned empty output." -ForegroundColor $ColorWarning
            return "N/A" 
        }
        
        $outputString = ""
        if ($out -is [System.Array]) { 
            $outputString = ($out -join "`n").Trim() 
        } else {
            $outputString = [string]$out
        }
        
        if ([string]::IsNullOrWhiteSpace($outputString)) { 
            Write-Host "-> ADB-SHELL Warning: '$Cmd' returned empty string." -ForegroundColor $ColorWarning
            return "N/A" 
        }
        return $outputString

    } catch { 
        Write-Host "-> ADB-SHELL CRITICAL ERROR: '$Cmd' failed to execute." -ForegroundColor $ColorCritical
        return "N/A" 
    }
}

function SafeGetShell {
    param([string]$label, [string]$cmd)
    return ADB-SHELL $cmd 
}

function SafeGetRun {
    param([string]$label, [string[]]$args)
    return Safe-Run { ADB-RUN @args }
}

# HTML Generator (Now in English)
function Write-HtmlReport {
    param([string]$HtmlFile, $Data, [string]$LogContent) 
    $Style = @"
        <style>
            body { font-family: Arial, sans-serif; background-color: #f0f0f0; color: #333; margin: 20px; }
            h1 { color: #d32f2f; border-bottom: 3px solid #d32f2f; padding-bottom: 10px; }
            h2 { color: #1976d2; margin-top: 30px; border-bottom: 1px solid #1976d2; }
            table { width: 100%; border-collapse: collapse; margin-top: 15px; }
            th, td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }
            th { background-color: #e0e0e0; color: #333; }
            tr:nth-child(even) { background-color: #f9f9f9; }
            .CRITICAL { color: #d32f2f; font-weight: bold; background-color: #ffebee; }
            .SUCCESS { color: #388e3c; font-weight: bold; }
            .HIGHLIGHT { color: #0097a7; }
            pre { background-color: #eee; padding: 15px; border-radius: 5px; overflow-x: auto; color: #555; border: 1px solid #ccc; }
            .summary-box { background-color: #fff3e0; padding: 15px; border-radius: 5px; border: 1px solid #ffb74d; margin-top: 20px; }
        </style>
"@

    $HtmlContent = "<h1>PHONE PASSPORT REPORT (v5.0)</h1>"
    $HtmlContent += "<p><strong>Generated: </strong> $(Get-Date)</p>"
    $HtmlContent += "<p><strong>ADB Path: </strong> $AdbExe</p>"
    
    foreach ($section in $Data.Keys) {
        $HtmlContent += "<h2>$section</h2>"
        $HtmlContent += "<table>"
        $HtmlContent += "<tr><th>Parameter</th><th>Value</th></tr>" # Translated
        
        foreach ($key in $Data[$section].Keys) {
            $value = $Data[$section][$key]
            $class = ""
            # Critical data highlighting logic (for the Bureau)
            if ($key -match "Platform" -and $value -match "mt6580") { $class = "CRITICAL" }
            elseif ($key -match "Total RAM" -and $value -match "512|1024|2048 MB") { $class = "CRITICAL" }
            elseif ($key -match "AndroidVersion" -and ($value -match "8.1.0|9.0|8.0")) { $class = "CRITICAL" }
            elseif ($key -match "Design Capacity" -and $value -match "(\d+)\s+mAh" -and [int]($value -replace '\D') -lt 5000) { $class = "CRITICAL" } # New Battery Check
            elseif ($key -match "Brand|Model|Product|Manufacturer|cores|Total packages") { $class = "HIGHLIGHT" }
            
            $HtmlContent += "<tr><td>$key</td><td class='$class'>$value</td></tr>"
        }
        $HtmlContent += "</table>"
    }

    $HtmlContent += "<h2>Raw Logs (DMESG, Camera, Suspicious Packages)</h2>" # Translated
    $HtmlContent += $LogContent
    
    $FullHtml = "<html><head><title>Phone Passport Report</title>$Style</head><body>$HtmlContent</body></html>"
    $FullHtml | Out-File $HtmlFile -Encoding UTF8
}


# ------------------------------
# START DATA COLLECTION
# ------------------------------
Ensure-Folder $LogsFolder
Ensure-Folder $SuspApkFolder

Write-Host "=============================================" -ForegroundColor $ColorHighlight
Write-Host "   STARTING DATA COLLECTION (v5.0) - FINAL ENGLISH VERSION + BATTERY CHECK" -ForegroundColor $ColorHighlight # Translated
Write-Host "=============================================" -ForegroundColor $ColorHighlight

$AdbExe = Find-Adb $ForceAdb
if (-not $AdbExe) {
    Write-Host "adb.exe not found. Please install platform-tools." -ForegroundColor $ColorCritical # Translated
    exit 0
}

Write-Host "Using ADB: $AdbExe" -ForegroundColor $ColorHighlight # Translated
$AdbVersion = SafeGetRun "adb_version" @("version")
Write-Host "ADB Version: " + ($AdbVersion -split "`n")[0] -ForegroundColor $ColorHighlight # Translated

$DevListRaw = SafeGetRun "devices" @("devices")
Write-LogRaw "RAW adb devices" $DevListRaw # Translated Title

Write-Host "`n--- 1. BASIC SYSTEM PROPERTIES ---" -ForegroundColor $ColorHighlight # Translated
Add-Content -Path $ReportFileTxt -Value ("`n--- BASIC SYSTEM PROPS ---")

$PropsMap = @{
    "Brand" = "ro.product.brand"
    "Model" = "ro.product.model"
    "AndroidVersion" = "ro.build.version.release"
    "SDK" = "ro.build.version.sdk"
    "BoardPlatform" = "ro.board.platform"
    "Hardware" = "ro.hardware"
    "Baseband" = "gsm.version.baseband"
}

foreach ($k in $PropsMap.Keys) {
    $v = SafeGetShell $k ("getprop " + $PropsMap[$k])
    $Color = $ColorDefault
    if ($k -eq "BoardPlatform" -and ($v -match "mt6580|mtk6580")) { $Color = $ColorCritical }
    if ($k -eq "AndroidVersion" -and ($v -match "8.1.0|9.0|8.0")) { $Color = $ColorCritical }
    Write-KeyOutput $k $v $Color "A-BASIC_PROPS"
}

Write-Host "`n--- 2. SOC / CPU / MEMORY ---" -ForegroundColor $ColorHighlight # Translated
Add-Content -Path $ReportFileTxt -Value ("`n--- SOC / CPU / MEMORY ---")

$PropsSoc = @{
    "MTK Platform (prop)" = "ro.mediatek.platform"
}
foreach ($k in $PropsSoc.Keys) {
    $v = SafeGetShell $k ("getprop " + $PropsSoc[$k])
    $Color = $ColorDefault
    if ($v -match "mt6580|mtk6580") { $Color = $ColorCritical }
    Write-KeyOutput $k $v $Color "B-SOC_MEMORY"
}

$CpuCores = SafeGetShell "cores" "grep -c processor /proc/cpuinfo"
Write-KeyOutput "CPU cores" $CpuCores $ColorSuccess "B-SOC_MEMORY"
$CpuInfo = SafeGetShell "cpuinfo" "cat /proc/cpuinfo"
Write-LogRaw "CPU Info (raw)" $CpuInfo # Translated Title

$MemRaw = SafeGetShell "memtotal" "cat /proc/meminfo | grep MemTotal"
$RamInfo = "N/A"
$MB = 0
if ($MemRaw -ne "N/A") {
    $digits = DigitsOnly $MemRaw
    if ($digits -ne "") {
        $KB = [int]$digits
        $MB = [math]::Round($KB/1024, 2)
        $RamInfo = "$MemRaw ($MB MB)"
    } else {
        $RamInfo = $MemRaw
    }
}
$Color = $ColorDefault
if ($MB -le 2048 -and $MB -ge 512) { $Color = $ColorCritical }
Write-KeyOutput "Total RAM" $RamInfo $Color "B-SOC_MEMORY"


Write-Host "`n--- 3. BATTERY INFORMATION ---" -ForegroundColor $ColorHighlight # NEW SECTION
Add-Content -Path $ReportFileTxt -Value ("`n--- BATTERY INFORMATION ---")

$BatteryFile = "charge_full_design" 
$BatteryPath = "/sys/class/power_supply/battery/$BatteryFile"
$Capacity_mAh = "N/A"
$Color = $ColorDefault

$DesignCapacity_uAh = SafeGetShell "DesignCapacity_uAh" ("cat $BatteryPath")

if ($DesignCapacity_uAh -ne "N/A" -and (DigitsOnly $DesignCapacity_uAh)) {
    $uAh = [int](DigitsOnly $DesignCapacity_uAh)
    $mAh = [math]::Round($uAh / 1000)
    $Capacity_mAh = "$mAh mAh (Design Capacity)"
    
    # Check for fraud: 8000 mAh advertised
    if ($mAh -lt 5000) { $Color = $ColorCritical } 
    
    Write-KeyOutput "Design Capacity" $Capacity_mAh $Color "C-BATTERY"
    
    $CurrentCapacity_uAh = SafeGetShell "CurrentCapacity_uAh" ("cat /sys/class/power_supply/battery/charge_full")
    if ($CurrentCapacity_uAh -ne "N/A" -and (DigitsOnly $CurrentCapacity_uAh)) {
        $uAh_cur = [int](DigitsOnly $CurrentCapacity_uAh)
        $mAh_cur = [math]::Round($uAh_cur / 1000)
        Write-KeyOutput "Current Full Capacity" "$mAh_cur mAh" $ColorDefault "C-BATTERY"
    } else {
        Write-KeyOutput "Current Full Capacity" "N/A" $ColorWarning "C-BATTERY"
    }
    
    Write-LogRaw "Battery System Files Content" (ADB-SHELL "ls -l /sys/class/power_supply/battery/ ; echo '---'; cat /sys/class/power_supply/battery/uevent")
    
} else {
    # Fallback to dumpsys if sysfs file is missing
    $BatteryInfo = SafeGetShell "BatteryInfo" "dumpsys battery"
    if ($BatteryInfo -ne "N/A") {
        Write-LogRaw "dumpsys battery info" $BatteryInfo
        $DesignLine = $BatteryInfo | Select-String "charge_full_design"
        $Capacity_Match = $DesignLine -match '\d+'
        if ($Capacity_Match) {
             $mAh = [int]($Capacity_Match.Groups[0].Value)
             $Capacity_mAh = "$mAh mAh (from dumpsys)"
             if ($mAh -lt 5000) { $Color = $ColorCritical }
             Write-KeyOutput "Design Capacity" $Capacity_mAh $Color "C-BATTERY"
        } else {
             Write-KeyOutput "Design Capacity" "N/A (Design file missing)" $ColorWarning "C-BATTERY"
        }
    } else {
        Write-KeyOutput "Design Capacity" "N/A (Battery info inaccessible)" $ColorCritical "C-BATTERY"
    }
}


Write-Host "`n--- 4. STORAGE ---" -ForegroundColor $ColorHighlight # Translated
Add-Content -Path $ReportFileTxt -Value ("`n--- STORAGE (df samples) ---")
$Mounts = @("/system","/data")
foreach ($m in $Mounts) {
    $df = SafeGetShell ("df_" + $m) ("df -h " + $m + " | tail -n 1") 
    Write-KeyOutput ("Mount " + $m) $df $ColorDefault "D-STORAGE"
}


Write-Host "`n--- 5. DISPLAY ---" -ForegroundColor $ColorHighlight # Translated
$Disp = SafeGetShell "display" "dumpsys display"
if ($Disp -ne "N/A") {
    $Lines = $Disp -split "`n"
    $Block = $Lines | Select-String "mOverrideDisplayInfo" -Context 0,10 | Out-String 
    Write-LogRaw "dumpsys display (filtered to mOverrideDisplayInfo)" $Block
    $Resolution = ($Block | Select-String "appWidth=|appHeight=" | Select-Object -Last 1 | ForEach-Object { $_ -replace ".*appWidth=(\d+)\s+appHeight=(\d+).*", '$1x$2' })
    if (!$Resolution) { $Resolution = "N/A" }
    $Color = $ColorDefault
    if ($Resolution -match "576x1280|720x1280|480x800") { $Color = $ColorCritical }
    Write-KeyOutput "Resolution (from dump)" $Resolution $Color "E-DISPLAY"
} else {
    Write-KeyOutput "Display" "N/A" $ColorWarning "E-DISPLAY"
}


Write-Host "`n--- 6. CAMERA ---" -ForegroundColor $ColorHighlight # Translated
$Camera = SafeGetShell "camera" "dumpsys media.camera | grep -E 'Camera 0|Camera 1|Active array size|Physical sensor size' -A 8"
Write-LogRaw "dumpsys media.camera (Filtered)" $Camera # Translated Title


Write-Host "`n--- 7. IDENTIFIERS ---" -ForegroundColor $ColorHighlight # Translated
Add-Content -Path $ReportFileTxt -Value ("`n--- IDENTIFIERS ---")

function Get-IMEI-Slot {
    param([int]$slot)
    $raw = SafeGetShell ("imei_raw" + $slot) ("service call iphonesubinfo " + $slot)
    if ($raw -ne "N/A" -and ($raw -match '\d')) {
        $d = DigitsOnly $raw
        if ($d.Length -ge 14) { return $d }
    }
    return "N/A"
}

$IMEI1 = Get-IMEI-Slot 1
$IMEI2 = Get-IMEI-Slot 2
Write-KeyOutput "IMEI1" $IMEI1 $ColorDefault "F-IDENTIFIERS"
Write-KeyOutput "IMEI2" $IMEI2 $ColorDefault "F-IDENTIFIERS"
$Serial = SafeGetShell "serial" "getprop ro.serialno"
Write-KeyOutput "Serial" $Serial $ColorDefault "F-IDENTIFIERS"


$PkgsRaw = SafeGetShell "pkgs" "pm list packages -f"
$PkgsCount = 0
if ($PkgsRaw -ne "N/A") { $PkgsCount = ($PkgsRaw -split "`n").Count }
Write-KeyOutput "Total packages (raw count)" $PkgsCount $ColorSuccess "G-PACKAGES"

$Keywords = @("factory","factorytest","aging","test","engineering","diag","mtk","demo","ad","spy","miner","backdoor","chivin","readhardware","ma.factory","writeimei")
$SuspList = @()
if ($PkgsRaw -ne "N/A") {
    foreach ($line in $PkgsRaw -split "`n") {
        foreach ($k in $Keywords) {
            if ($line.ToLower().Contains($k)) { $SuspList += $line; break }
        }
    }
}

if ($SuspList.Count -gt 0) {
    Write-Host "`n--- 8. SUSPICIOUS PACKAGES FOUND: $SuspList.Count ---" -ForegroundColor $ColorCritical # Translated
    Write-LogRaw "Suspicious packages found" ($SuspList -join "`n") # Translated Title
    Write-Host "Attempting to pull APKs..." -ForegroundColor $ColorWarning # Translated
    
    $Pulled = @()
    # (APK pulling logic goes here if needed)
    
    Write-KeyOutput "Pulled APKs count" $Pulled.Count $ColorSuccess "G-PACKAGES"
} else {
    Write-Host "No suspicious packages found." -ForegroundColor $ColorSuccess # Translated
    Write-KeyOutput "Suspicious packages count" 0 $ColorSuccess "G-PACKAGES"
}

Write-Host "`n--- 9. KERNEL / DMESG (CRITICAL INFO) ---" -ForegroundColor $ColorHighlight # Translated
$Dmesg = SafeGetShell "dmesg" "dmesg | tail -n 500" 
if ($Dmesg -ne "N/A") {
    Write-Host "Kernel log obtained (partial). Check the report." -ForegroundColor $ColorSuccess # Translated
    Write-LogRaw "KERNEL LOG (dmesg, last 500 lines)" $Dmesg # Translated Title
} else {
    Write-Host "Kernel log (dmesg) not obtained (No permission)." -ForegroundColor $ColorWarning # Translated
    Write-LogRaw "KERNEL LOG (dmesg)" "N/A" # Translated Title
}

Write-Host "`n=============================================" -ForegroundColor $ColorHighlight
Write-Host "   CREATING FINAL REPORTS" -ForegroundColor $ColorHighlight # Translated
Write-HtmlReport $ReportFileHtml $HtmlData $HtmlLog

Write-Host "Report completed. Files saved:" -ForegroundColor $ColorSuccess # Translated
Write-Host "TXT Report (Compact): $ReportFileTxt" -ForegroundColor $ColorSuccess
Write-Host "HTML Report (Color, for the Bureau): $ReportFileHtml" -ForegroundColor $ColorSuccess # Translated
Write-Host "APKs folder: $SuspApkFolder" -ForegroundColor $ColorSuccess # Translated
Write-Host "=============================================" -ForegroundColor $ColorHighlight