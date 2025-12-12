🔧 Requirements
System Requirements
Windows 10/11 (64-bit recommended)

PowerShell 5.1 or higher

Administrator privileges (for some ADB operations)

Internet connection (for initial ADB setup only)

Android Requirements
Android 5.0+ (API 21+)

USB Debugging enabled

Developer Options unlocked

Original USB cable (data transfer capable)

Software Dependencies
Android Debug Bridge (ADB) - Automatically detected or installed

Proper USB drivers for your device manufacturer

📥 Installation
Step 1: Prepare Your Windows Environment
powershell
# Open PowerShell as Administrator
# Check your PowerShell version
$PSVersionTable.PSVersion

# If below 5.1, update PowerShell:
# https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell
Step 2: Install ADB (Android Debug Bridge)
Option A: Automatic Detection (Recommended)
The script automatically searches for ADB in common locations:

C:\Users\[YourUsername]\AppData\Local\Android\Sdk\platform-tools\

C:\Program Files\Android\platform-tools\

Current directory

Option B: Manual Installation
Download Android SDK Platform Tools

Extract to C:\platform-tools\

Add to PATH:

powershell
# In PowerShell
$env:Path += ";C:\platform-tools"
# Or add permanently via System Properties
Option C: Install via Chocolatey
powershell
# Install Chocolatey package manager
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

# Install ADB
choco install adb
Step 3: Prepare Your Android Device
Enable Developer Options
Go to Settings → About Phone

Tap Build Number 7 times

You'll see "You are now a developer!"

Enable USB Debugging
Go to Settings → Developer Options

Enable USB Debugging

Enable OEM Unlocking (if available)

Trust Computer
Connect device via USB

On device, tap Allow for USB debugging

Check "Always allow from this computer"

Step 4: Verify ADB Connection
powershell
# Check if device is detected
adb devices

# Expected output:
# List of devices attached
# ABC123456789    device
🛠️ Usage
Basic Usage
powershell
# Navigate to project folder
cd phone-clone-detector

# Run forensic analysis (interactive)
.\src\phone_passport_run.ps1
Advanced Options
Your script supports automatic detection of:

ADB location (auto-searches common paths)

Device connection (multiple device handling)

Battery capacity (design vs actual)

MTK chipsets (specialized analysis)

What Gets Analyzed?
1. Basic System Properties ✅
Manufacturer and model verification

Android version and security patch

Build fingerprint and properties

Baseband version

2. SOC / CPU / Memory Analysis 🧠
Processor architecture and cores

RAM capacity and type validation

MTK chipset detection

CPU frequency and capabilities

3. Battery Forensic Analysis 🔋
Design capacity verification

Current battery health

Capacity discrepancy detection

Power supply system check

4. Storage Verification 💾
Internal storage capacity

Partition layout analysis

Storage type detection (eMMC/UFS)

Available space analysis

5. Display Characteristics 📱
Screen resolution verification

Display density check

Refresh rate detection

Color calibration status

6. Camera System 📷
Camera sensor information

Megapixel count verification

Video recording capabilities

Camera API support

7. Device Identifiers 🔢
IMEI number validation

Serial number verification

MEID and ESN checks

Device fingerprint

8. Security Assessment 🛡️
Suspicious package detection

Factory test apps identification

Root access check

Bootloader status

📊 Understanding Reports
Report Structure
text
logs/
├── phone_passport_YYYYMMDD_HHMMSS.html  # Main report (open in browser)
└── phone_passport_YYYYMMDD_HHMMSS.txt   # Detailed technical log
HTML Report Sections
1. Device Information
html
✅ Manufacturer: Xiaomi
✅ Model: Redmi Note 10 Pro
⚠️ Android Version: 8.1.0 (Outdated)
✅ Security Patch: 2023-01-01
2. Hardware Analysis
html
🔴 MTK Platform: mt6580 (MEDIATEK - Suspicious)
✅ CPU Cores: 8 (4x2.0 GHz + 4x1.8 GHz)
⚠️ Total RAM: 4.0 GB (Claimed: 6.0 GB)
🔴 Battery Design: 3000 mAh (Claimed: 5000 mAh)
3. Color Coding System
🟢 Green (✅): Normal, expected values

🟡 Yellow (⚠️): Minor discrepancies, requires attention

🔴 Red (❌): Critical issues, potential clone/fraud

🔵 Blue (ℹ️): Informational, technical details

Interpreting Results
Normal Device Profile
text
✅ All specifications match claimed values
✅ No suspicious packages found
✅ Battery capacity matches design
✅ IMEI validates correctly
✅ Display resolution as advertised
Potential Clone Indicators
text
🔴 MTK chipset in non-MTK branded device
🔴 RAM capacity significantly lower than claimed
🔴 Battery design capacity mismatched
🔴 Multiple suspicious factory packages
🔴 IMEI validation failures
MTK-Specific Red Flags
Device claims to be Samsung but has MTK chipset

High-end specs with low-end MTK processor

Battery capacity discrepancies in MTK devices

Missing or altered factory information

🔬 Technical Methodology
Three-Tier Verification System
The tool employs a novel multi-source verification approach:

Tier 1: System Properties
powershell
# Query Android build properties
getprop ro.product.manufacturer
getprop ro.build.version.release
getprop ro.mediatek.platform
Tier 2: Kernel Exports
powershell
# Read hardware information directly
cat /proc/cpuinfo
cat /proc/meminfo
cat /sys/class/power_supply/battery/*
Tier 3: Runtime Services
powershell
# Query Android system services
dumpsys battery
dumpsys display
dumpsys media.camera
Statistical Anomaly Detection
powershell
# Risk scoring algorithm
$RiskScore = (
    ($CPU_Mismatch * 0.3) +
    ($RAM_Mismatch * 0.25) +
    ($Battery_Mismatch * 0.2) +
    ($IMEI_Anomaly * 0.15) +
    ($Security_Issues * 0.1)
)
Battery Forensic Analysis
The tool implements specialized battery verification:

Design Capacity: Reads /sys/class/power_supply/battery/charge_full_design

Current Capacity: Checks /sys/class/power_supply/battery/charge_full

Health Assessment: Compares design vs current capacity

Fraud Detection: Flags batteries with >20% capacity deviation

MTK Chipset Detection
Specialized checks for MediaTek devices:

ro.mediatek.platform property analysis

/proc/cpuinfo MTK signature detection

Platform-specific battery path verification

Chipset performance characteristic validation

🐛 Troubleshooting
Common Issues and Solutions
Issue 1: "ADB Device Not Found"
powershell
# Check device connection
adb devices

# Solutions:
# 1. Reconnect USB cable
# 2. Try different USB port
# 3. Replace USB cable (use data cable, not charge-only)
# 4. Reinstall USB drivers
# 5. Restart ADB daemon:
adb kill-server
adb start-server
Issue 2: "USB Debugging Not Enabled"
text
On Android device:
1. Settings → About Phone → Build Number (tap 7 times)
2. Settings → Developer Options → USB Debugging (enable)
3. Reconnect device, tap "Allow" on prompt
Issue 3: "Permission Denied" Errors
powershell
# Run PowerShell as Administrator
# Or adjust execution policy:
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
Issue 4: Script Doesn't Start
powershell
# Check PowerShell version
$PSVersionTable.PSVersion
# Minimum required: 5.1.19041.1

# Check script encoding
Get-Content src\phone_passport_run.ps1 -Encoding Byte | Select-Object -First 10
# Should not start with 255, 254 (UTF-8 BOM issue)
Issue 5: Incomplete Reports
text
# Enable all required permissions on Android:
1. Settings → Apps → Special app access → Install unknown apps
2. Grant permission to ADB/Shell
3. Disable any battery optimization for ADB
ADB Driver Installation
For Windows 10/11
Automatic: Windows Update usually installs correct drivers

Manual:

Download Google USB Driver

Device Manager → Unknown device → Update driver

Browse to extracted driver folder

Manufacturer Specific
Samsung: Samsung USB Drivers

Xiaomi: Mi PC Suite

Huawei: HiSuite

Generic: Universal ADB Drivers

⚖️ Legal & Ethical Use
Approved Use Cases ✅
Personal device verification before purchase

Second-hand device inspection (with owner consent)

Enterprise asset management and inventory

Educational purposes and digital forensics training

Security research with proper disclosure

Warranty validation for service centers

Prohibited Uses ❌
Unauthorized device scanning without permission

Privacy invasion or personal data collection

Commercial exploitation without licensing

Any illegal activities or harassment

Bypassing security measures on owned devices

Use in jurisdictions where such tools are restricted

Data Privacy Commitment
What we collect:

Hardware specifications (public information)

Device identifiers for validation

System property information

Performance characteristics

What we NEVER collect:

Personal files, photos, or media

Messages, contacts, or call history

Location data or GPS history

Account information or passwords

Browsing history or app usage

Financial information or credentials

Legal Disclaimer
text
THIS SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
The authors assume no liability for any damages arising from the use of this tool.
Users are solely responsible for ensuring their use complies with all applicable laws.
🔧 Development & Extending
Project Structure
text
phone-clone-detector/
├── 📁 src/                    # Source code
│   └── phone_passport_run.ps1  # Main forensic script
├── 📁 docs/                   # Documentation
│   ├── TECHNICAL.md          # Technical methodology
│   └── INVENTION_DISCLOSURE.md # Legal disclosure
├── 📁 reports/               # Example outputs
│   └── example_report.html  # Sample report
├── 📁 test_cases/            # Test documentation
├── 📁 .github/workflows/     # CI/CD automation
├── 📄 README.md              # This file
├── 📄 LICENSE                # MIT License
└── 👁️ .gitignore            # Git exclusions
Adding New Checks
powershell
# Example: Adding a new hardware check
function Check-NewComponent {
    $value = SafeGetShell "NewComponent" "cat /sys/class/new_component/value"
    Write-KeyOutput "New Component" $value $ColorDefault "NEW-SECTION"
}
Customizing Reports
Modify the Write-HtmlReport function to:

Add new report sections

Change color schemes

Include additional data visualizations

Customize risk scoring algorithms
