param(
    [switch]$AutoInstall
)

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$PackRoot  = Join-Path $ScriptDir "DriverPack"
$Manifest  = Join-Path $PackRoot "00_MANIFEST"
$ManualDir = Join-Path $PackRoot "99_MANUAL_DOWNLOADS"
$LogFile   = Join-Path $Manifest "driverpack.log"

$global:LogBox = $null

function New-Dir {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Force -Path $Path | Out-Null
    }
}

function Log {
    param([string]$Message)

    New-Dir $Manifest

    $line = "[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message

    if ($global:LogBox) {
        $global:LogBox.AppendText("$line`r`n")
        $global:LogBox.SelectionStart = $global:LogBox.Text.Length
        $global:LogBox.ScrollToCaret()
    }

    Write-Host $line
    Add-Content -Path $LogFile -Value $line
}

function SafeName {
    param([string]$Name)
    return ($Name -replace '[\\/:*?"<>|]', '_' -replace '\s+', '_')
}

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Write-UrlShortcut {
    param(
        [string]$Path,
        [string]$Url
    )

@"
[InternetShortcut]
URL=$Url
"@ | Set-Content -Path $Path -Encoding ASCII
}

function Download-File {
    param(
        [string]$Url,
        [string]$Destination
    )

    New-Dir (Split-Path $Destination -Parent)

    if (Test-Path $Destination) {
        Log "SKIP exists: $Destination"
        return
    }

    Log "Downloading: $Url"
    Log "To: $Destination"

    try {
        Start-BitsTransfer -Source $Url -Destination $Destination -ErrorAction Stop
    }
    catch {
        Log "BITS failed. Falling back to Invoke-WebRequest."
        Invoke-WebRequest -Uri $Url -OutFile $Destination -UseBasicParsing
    }
}

$Items = @(
    [pscustomobject]@{
        Order        = 10
        Vendor       = "Keysight"
        Name         = "IO Libraries Suite"
        Models       = "Required prerequisite"
        Folder       = "01_KEYSIGHT\00_IO_Libraries"
        Type         = "Manual"
        Url          = ""
        FileName     = ""
        Page         = "https://www.keysight.com/us/en/lib/software-detail/computer-software/io-libraries-suite-downloads-2175637.html"
        Notes        = "Install before Keysight IVI drivers."
    },

    [pscustomobject]@{
        Order        = 20
        Vendor       = "Keysight"
        Name         = "InfiniiVision X-Series Oscilloscope IVI Driver"
        Models       = "DSOX2024A"
        Folder       = "01_KEYSIGHT\01_DSOX2024A_InfiniiVision"
        Type         = "Manual"
        Url          = ""
        FileName     = ""
        Page         = "https://www.keysight.com/us/en/lib/software-detail/driver/infiniivision-x-series-oscilloscope-ivi-instrument-drivers.html"
        Notes        = "Scope IVI driver."
    },

    [pscustomobject]@{
        Order        = 30
        Vendor       = "Keysight"
        Name         = "N67xx Modular Power Supply IVI Driver"
        Models       = "N6701C, N6733B, N6751A"
        Folder       = "01_KEYSIGHT\02_N6700_Modular_Power"
        Type         = "Manual"
        Url          = ""
        FileName     = ""
        Page         = "https://www.keysight.com/us/en/lib/software-detail/driver/n67xx-modular-power-supply-ivi-and-matlab-instrument-drivers-1960676.html"
        Notes        = "Mainframe plus modules."
    },

    [pscustomobject]@{
        Order        = 40
        Vendor       = "Keysight"
        Name         = "N6900/N7900/RP7900 APS IVI Driver"
        Models       = "N6972A, RP7932A"
        Folder       = "01_KEYSIGHT\03_N6900_N7900_RP7900_APS"
        Type         = "Manual"
        Url          = ""
        FileName     = ""
        Page         = "https://www.keysight.com/us/en/lib/software-detail/driver/advanced-power-system-n6900-n7900-and-rp7900-series-ivi-and-matlab-instrument-drivers-2379610.html"
        Notes        = "Advanced Power System driver."
    },

    [pscustomobject]@{
        Order        = 50
        Vendor       = "Keysight"
        Name         = "N57xx/N87xx DC Power Supply IVI Driver"
        Models       = "N5750A"
        Folder       = "01_KEYSIGHT\04_N57xx_N87xx"
        Type         = "Manual"
        Url          = ""
        FileName     = ""
        Page         = "https://www.keysight.com/us/en/lib/software-detail/driver/n57xx-n87xx-dc-power-supply-ivi-and-matlab-instrument-drivers-1670385.html"
        Notes        = "N5750A driver family."
    },

    [pscustomobject]@{
        Order        = 60
        Vendor       = "Keysight"
        Name         = "MP4300 Modular Power System IVI Driver"
        Models       = "MP4301A"
        Folder       = "01_KEYSIGHT\05_MP4300"
        Type         = "Manual"
        Url          = ""
        FileName     = ""
        Page         = "https://www.keysight.com/us/en/lib/software-detail/driver/mp4300-modular-power-system-ivi-instrument-drivers.html"
        Notes        = "MP4301A driver family."
    },

    [pscustomobject]@{
        Order        = 70
        Vendor       = "Chroma"
        Name         = "63200A LabVIEW Driver"
        Models       = "63203A-150-200"
        Folder       = "02_CHROMA\63200A"
        Type         = "Direct"
        Url          = "https://www.chromaate.com/downloads/drivers/63200A_series/Chr63200A_LabVIEW.zip"
        FileName     = "Chr63200A_LabVIEW.zip"
        Page         = "https://www.chromaate.com/en/data_center/63200a_series_dc_electronic_load"
        Notes        = "LabVIEW driver ZIP."
    },

    [pscustomobject]@{
        Order        = 71
        Vendor       = "Chroma"
        Name         = "63200A LabWindows Driver"
        Models       = "63203A-150-200"
        Folder       = "02_CHROMA\63200A"
        Type         = "Direct"
        Url          = "https://www.chromaate.com/downloads/drivers/63200A_series/Chr63200A_LabWindows.zip"
        FileName     = "Chr63200A_LabWindows.zip"
        Page         = "https://www.chromaate.com/en/data_center/63200a_series_dc_electronic_load"
        Notes        = "LabWindows/CVI driver ZIP."
    },

    [pscustomobject]@{
        Order        = 80
        Vendor       = "Pickering"
        Name         = "PXI/LXI Driver Package"
        Models       = "40-670C-022-99/2, 40-290-021, 42-411A-001, 60-106-002"
        Folder       = "03_PICKERING\PXI_LXI_Drivers"
        Type         = "Manual"
        Url          = ""
        FileName     = ""
        Page         = "https://downloads.pickeringtest.info/downloads/drivers/PXI_Drivers/"
        Notes        = "Download latest package from official directory."
    },

    [pscustomobject]@{
        Order        = 81
        Vendor       = "Pickering"
        Name         = "PXI Driver Release Notes"
        Models       = "Reference"
        Folder       = "03_PICKERING\PXI_LXI_Drivers"
        Type         = "Direct"
        Url          = "https://downloads.pickeringtest.info/downloads/drivers/PXI_Drivers/Release%20Notes.txt"
        FileName     = "Pickering_PXI_Driver_Release_Notes.txt"
        Page         = "https://downloads.pickeringtest.info/downloads/drivers/PXI_Drivers/"
        Notes        = "Reference only."
    },

    [pscustomobject]@{
        Order        = 90
        Vendor       = "Ballard/Astronics"
        Name         = "BTIDriver / Avionics Interface Driver"
        Models       = "1553 2-channel"
        Folder       = "04_BALLARD_ASTRONICS"
        Type         = "Manual"
        Url          = ""
        FileName     = ""
        Page         = "https://www.astronics.com/avionics-interface-driver-software"
        Notes        = "Vendor gated/support download."
    },

    [pscustomobject]@{
        Order        = 91
        Vendor       = "NI / Astronics"
        Name         = "Astronics Ballard Avionics Driver"
        Models       = "NI-branded PXI/PXIe Ballard modules"
        Folder       = "04_BALLARD_ASTRONICS\NI_Ballard_Driver_Page"
        Type         = "Manual"
        Url          = ""
        FileName     = ""
        Page         = "https://www.ni.com/en/support/downloads/drivers/download.astronics-ballard-avionics-driver.html"
        Notes        = "Use this if hardware is NI-branded."
    },

    [pscustomobject]@{
        Order        = 100
        Vendor       = "AP Instruments / Ridley"
        Name         = "Model 300/310 Software"
        Models       = "Ridley AP310"
        Folder       = "05_RIDLEY_AP310"
        Type         = "Manual"
        Url          = ""
        FileName     = ""
        Page         = "https://www.apinstruments.com/downloads.html"
        Notes        = "Manual download."
    },

    [pscustomobject]@{
        Order        = 110
        Vendor       = "Devantech"
        Name         = "dScript Windows Installer"
        Models       = "DS2832"
        Folder       = "06_DEVANTECH_DS2832"
        Type         = "Direct"
        Url          = "https://www.robot-electronics.co.uk/files/dScript-4.16.msi"
        FileName     = "dScript-4.16.msi"
        Page         = "https://www.robot-electronics.co.uk/dscript.html"
        Notes        = "dScript software."
    },

    [pscustomobject]@{
        Order        = 120
        Vendor       = "Samsung"
        Name         = "Samsung Magician"
        Models       = "Unknown Samsung 960GB SSD"
        Folder       = "07_SAMSUNG_SSD"
        Type         = "Direct"
        Url          = "https://download.semiconductor.samsung.com/resources/software-resources/Samsung_Magician_Installer_Official_9.0.1.950.exe"
        FileName     = "Samsung_Magician_Installer_Official_9.0.1.950.exe"
        Page         = "https://semiconductor.samsung.com/consumer-storage/support/tools/"
        Notes        = "Use to identify SSD."
    },

    [pscustomobject]@{
        Order        = 121
        Vendor       = "Samsung"
        Name         = "Samsung NVMe Driver"
        Models       = "950/960/970 family only"
        Folder       = "07_SAMSUNG_SSD"
        Type         = "Direct"
        Url          = "https://semiconductor.samsung.com/resources/software-resources/Samsung_NVM_Express_Driver_3.3.exe"
        FileName     = "Samsung_NVM_Express_Driver_3.3.exe"
        Page         = "https://semiconductor.samsung.com/consumer-storage/support/tools/"
        Notes        = "Downloaded but skipped during auto install. Run manually only if compatible."
    }
)

function Invoke-PrepDownload {
    Log "=== PREP / DOWNLOAD START ==="
    Log "Script folder: $ScriptDir"
    Log "Driver pack folder: $PackRoot"

    New-Dir $PackRoot
    New-Dir $Manifest
    New-Dir $ManualDir

    foreach ($item in $Items) {
        New-Dir (Join-Path $PackRoot $item.Folder)
    }

    $Items | Export-Csv -Path (Join-Path $Manifest "driver_manifest.csv") -NoTypeInformation
    $Items | ConvertTo-Json -Depth 5 | Set-Content -Path (Join-Path $Manifest "driver_manifest.json") -Encoding UTF8

    $manualMd = Join-Path $ManualDir "MANUAL_DOWNLOADS.md"
    $manualHtml = Join-Path $ManualDir "MANUAL_DOWNLOADS.html"

    $md = @()
    $md += "# Manual Downloads"
    $md += ""
    $md += "Download manual/session-gated installers and drop them into the matching folders."
    $md += ""

    $html = @()
    $html += "<html><body><h1>Manual Downloads</h1>"
    $html += "<p>Download manual/session-gated installers and drop them into the matching folders.</p>"

    foreach ($item in $Items) {
        $folderPath = Join-Path $PackRoot $item.Folder

        if ($item.Page) {
            $shortcut = Join-Path $folderPath ("{0}_OfficialPage.url" -f (SafeName "$($item.Vendor)_$($item.Name)"))
            Write-UrlShortcut -Path $shortcut -Url $item.Page
        }

        if ($item.Type -eq "Manual") {
            $md += "## $($item.Vendor) - $($item.Name)"
            $md += "- Models: $($item.Models)"
            $md += "- Folder: ``$folderPath``"
            $md += "- Page: $($item.Page)"
            $md += "- Notes: $($item.Notes)"
            $md += ""

            $html += "<h2>$($item.Vendor) - $($item.Name)</h2>"
            $html += "<p><b>Models:</b> $($item.Models)</p>"
            $html += "<p><b>Folder:</b> $folderPath</p>"
            $html += "<p><a href='$($item.Page)'>Open official page</a></p>"
            $html += "<p><b>Notes:</b> $($item.Notes)</p>"
        }
    }

    $html += "</body></html>"

    $md | Set-Content -Path $manualMd -Encoding UTF8
    $html | Set-Content -Path $manualHtml -Encoding UTF8

    foreach ($item in $Items | Where-Object { $_.Type -eq "Direct" }) {
        $dest = Join-Path (Join-Path $PackRoot $item.Folder) $item.FileName

        try {
            Download-File -Url $item.Url -Destination $dest
        }
        catch {
            Log "FAILED download: $($item.Name)"
            Log $_.Exception.Message
        }
    }

    $hashPath = Join-Path $Manifest "sha256_hashes.csv"

    Get-ChildItem $PackRoot -Recurse -File |
        Where-Object {
            $_.Extension -match '^\.(exe|msi|zip|iso)$'
        } |
        Get-FileHash -Algorithm SHA256 |
        Select-Object Path, Hash |
        Export-Csv -Path $hashPath -NoTypeInformation

    Log "Manifest written: $(Join-Path $Manifest 'driver_manifest.csv')"
    Log "Manual download list: $manualMd"
    Log "Manual download HTML: $manualHtml"
    Log "Hashes written: $hashPath"

    $answer = [System.Windows.Forms.MessageBox]::Show(
        "Prep/download complete.`n`nOpen the manual download page list now?",
        "Driver Pack",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )

    if ($answer -eq [System.Windows.Forms.DialogResult]::Yes) {
        Start-Process $manualHtml
        Start-Process $ManualDir
    }

    Log "=== PREP / DOWNLOAD COMPLETE ==="
}

function Invoke-InstallPack {
    Log "=== INSTALL START ==="

    if (-not (Test-Path $PackRoot)) {
        Log "DriverPack folder not found. Run Prep / Download first."
        return
    }

    $installerExt = @(".msi", ".exe", ".zip")
    $skipNames = @(
        "Samsung_NVM_Express_Driver_3.3.exe"
    )

    foreach ($item in $Items | Sort-Object Order) {
        $folder = Join-Path $PackRoot $item.Folder

        if (-not (Test-Path $folder)) {
            Log "Missing folder: $folder"
            continue
        }

        $files = Get-ChildItem $folder -Recurse -File |
            Where-Object {
                $installerExt -contains $_.Extension.ToLower() -and
                $_.FullName -notmatch "\\EXTRACTED_"
            } |
            Sort-Object FullName

        if (-not $files) {
            Log "No installer found for: $($item.Vendor) - $($item.Name)"
            continue
        }

        foreach ($file in $files) {
            if ($skipNames -contains $file.Name) {
                Log "SKIP protected/manual installer: $($file.FullName)"
                continue
            }

            Log "Processing: $($file.FullName)"

            switch ($file.Extension.ToLower()) {
                ".zip" {
                    $extractTo = Join-Path $file.DirectoryName ("EXTRACTED_" + $file.BaseName)

                    New-Dir $extractTo
                    Log "Extracting ZIP to: $extractTo"

                    try {
                        Expand-Archive -Path $file.FullName -DestinationPath $extractTo -Force
                    }
                    catch {
                        Log "ZIP extraction failed: $($_.Exception.Message)"
                    }

                    $nestedInstallers = Get-ChildItem $extractTo -Recurse -File |
                        Where-Object { $_.Extension.ToLower() -in @(".msi", ".exe") } |
                        Sort-Object FullName

                    foreach ($nested in $nestedInstallers) {
                        Log "Launching extracted installer: $($nested.FullName)"

                        if ($nested.Extension.ToLower() -eq ".msi") {
                            Start-Process "msiexec.exe" -ArgumentList "/i `"$($nested.FullName)`"" -Wait
                        }
                        else {
                            Start-Process $nested.FullName -Wait
                        }
                    }
                }

                ".msi" {
                    Log "Launching MSI installer."
                    Start-Process "msiexec.exe" -ArgumentList "/i `"$($file.FullName)`"" -Wait
                }

                ".exe" {
                    Log "Launching EXE installer."
                    Start-Process $file.FullName -Wait
                }
            }
        }
    }

    Log "=== INSTALL COMPLETE ==="

    [System.Windows.Forms.MessageBox]::Show(
        "Install pass complete.`n`nCheck the log and vendor installers for any prompts/errors.",
        "Driver Pack",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    ) | Out-Null
}

if ($AutoInstall) {
    New-Dir $Manifest
    Invoke-InstallPack
    exit
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "Driver Pack Builder"
$form.Size = New-Object System.Drawing.Size(900, 620)
$form.StartPosition = "CenterScreen"

$title = New-Object System.Windows.Forms.Label
$title.Text = "Driver Pack Builder"
$title.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
$title.AutoSize = $true
$title.Location = New-Object System.Drawing.Point(20, 15)
$form.Controls.Add($title)

$pathLabel = New-Object System.Windows.Forms.Label
$pathLabel.Text = "Pack folder: $PackRoot"
$pathLabel.AutoSize = $true
$pathLabel.Location = New-Object System.Drawing.Point(23, 55)
$form.Controls.Add($pathLabel)

$prepButton = New-Object System.Windows.Forms.Button
$prepButton.Text = "Prep / Download"
$prepButton.Size = New-Object System.Drawing.Size(180, 45)
$prepButton.Location = New-Object System.Drawing.Point(25, 90)
$prepButton.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($prepButton)

$installButton = New-Object System.Windows.Forms.Button
$installButton.Text = "Install"
$installButton.Size = New-Object System.Drawing.Size(180, 45)
$installButton.Location = New-Object System.Drawing.Point(220, 90)
$installButton.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($installButton)

$note = New-Object System.Windows.Forms.Label
$note.Text = "Prep creates folders, downloads direct files, writes manifests, and opens manual-download links. Install launches local installers in order."
$note.AutoSize = $true
$note.Location = New-Object System.Drawing.Point(25, 150)
$form.Controls.Add($note)

$logBox = New-Object System.Windows.Forms.TextBox
$logBox.Multiline = $true
$logBox.ScrollBars = "Vertical"
$logBox.ReadOnly = $true
$logBox.Font = New-Object System.Drawing.Font("Consolas", 9)
$logBox.Location = New-Object System.Drawing.Point(25, 180)
$logBox.Size = New-Object System.Drawing.Size(835, 360)
$form.Controls.Add($logBox)

$global:LogBox = $logBox

$prepButton.Add_Click({
    try {
        Invoke-PrepDownload
    }
    catch {
        Log "ERROR: $($_.Exception.Message)"
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, "Prep / Download Error")
    }
})

$installButton.Add_Click({
    try {
        if (-not (Test-IsAdmin)) {
            $answer = [System.Windows.Forms.MessageBox]::Show(
                "Driver installation should run as Administrator.`n`nRelaunch elevated and start install now?",
                "Admin Required",
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )

            if ($answer -eq [System.Windows.Forms.DialogResult]::Yes) {
                Start-Process "powershell.exe" `
                    -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -AutoInstall" `
                    -Verb RunAs

                $form.Close()
            }

            return
        }

        $confirm = [System.Windows.Forms.MessageBox]::Show(
            "Install will launch installers found under:`n`n$PackRoot`n`nContinue?",
            "Start Install",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question
        )

        if ($confirm -eq [System.Windows.Forms.DialogResult]::Yes) {
            Invoke-InstallPack
        }
    }
    catch {
        Log "ERROR: $($_.Exception.Message)"
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, "Install Error")
    }
})

Log "Ready."
Log "Put this script anywhere. Everything builds relative to: $ScriptDir"

[void]$form.ShowDialog()
