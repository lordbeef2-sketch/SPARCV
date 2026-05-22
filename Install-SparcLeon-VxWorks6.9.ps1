#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$WindRiverRoot = 'C:\WindRiver6.9',
    [string]$SourceFilesRoot,
    [string]$DownloadUser = 'VxWorks6',
    [string]$DownloadPassword = $env:GAISLER_DOWNLOAD_PASSWORD,
    [string]$DistributionPassword = 'password',
    [string]$ExpandedDistributionRoot,
    [string]$WorkRoot,
    [switch]$SkipToolchainInstall,
    [switch]$SkipCompileGui,
    [switch]$SkipElevation,
    [switch]$ValidateOnly,
    [switch]$NoPause
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($SourceFilesRoot)) {
    $SourceFilesRoot = Join-Path $PSScriptRoot 'InstallFiles'
}

if ([string]::IsNullOrWhiteSpace($WorkRoot)) {
    $WorkRoot = Join-Path $PSScriptRoot 'artifacts'
}

$script:Config = [ordered]@{
    ProductName            = 'Frontgrade Gaisler SPARC/LEON VxWorks 6.9'
    ReleaseVersion         = '2.3.0'
    RequiredVxWorks        = '6.9.4.12 RCPL8'
    RequiredWorkbench      = 'Workbench 3.3 Update 6'
    ToolchainVersion       = '4.9-1.0.7'
    DownloadBaseUrl        = 'https://download.gaisler.com/products/vxworks6.9'
    DistributionZipName    = 'dist-vxworks-6.9-2.3.0.tar.gz.zip'
    ToolchainInstallerName = 'sparc-wrs-vxworks-4.9-1.0.7-mingw.exe'
    ToolchainZipName       = 'sparc-wrs-vxworks-4.9-1.0.7-mingw.zip'
    GuidePdfName           = 'vxworks-installing-6.9-2.3.0.pdf'
    SevenZipInstallerUrl   = 'https://github.com/ip7z/7zip/releases/download/26.01/7z2601-x64.exe'
    SevenZipInstallerName  = '7z2601-x64.exe'
    SevenZipInstallDirName = '7-Zip'
    ToolchainInstallRoot   = 'C:\opt'
    ToolchainInstallDir    = 'C:\opt\sparc-wrs-vxworks'
    ToolchainBinDir        = 'C:\opt\sparc-wrs-vxworks\bin'
}

function Write-Step {
    param([string]$Message)
    Write-Host ''
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Restart-Elevated {
    $argumentList = @(
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        ('"{0}"' -f $PSCommandPath)
    )

    foreach ($entry in $PSBoundParameters.GetEnumerator()) {
        if ($entry.Value -is [System.Management.Automation.SwitchParameter]) {
            if ($entry.Value.IsPresent) {
                $argumentList += "-$($entry.Key)"
            }
            continue
        }

        if ($null -ne $entry.Value -and $entry.Value -ne '') {
            $argumentList += "-$($entry.Key)"
            $argumentList += ('"{0}"' -f ($entry.Value.ToString().Replace('"', '\"')))
        }
    }

    Start-Process -FilePath 'powershell.exe' -ArgumentList $argumentList -Verb RunAs | Out-Null
    exit
}

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Read-PlainSecret {
    param([string]$PromptText)
    $secureValue = Read-Host -Prompt $PromptText -AsSecureString
    return [System.Net.NetworkCredential]::new('', $secureValue).Password
}

function Get-SecretValue {
    param(
        [string]$Value,
        [string]$PromptText
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return Read-PlainSecret -PromptText $PromptText
    }

    return $Value
}

function Assert-Command {
    param([string]$Name)
    $command = Get-Command -Name $Name -ErrorAction SilentlyContinue
    if (-not $command) {
        throw "Required command '$Name' was not found."
    }

    return $command.Source
}

function Invoke-Download {
    param(
        [string]$Uri,
        [pscredential]$Credential,
        [string]$DestinationPath
    )

    if (Test-Path -LiteralPath $DestinationPath) {
        Write-Host "Reusing $(Split-Path -Leaf $DestinationPath)"
        return
    }

    Write-Host "Downloading $(Split-Path -Leaf $DestinationPath)"
    Invoke-WebRequest -Uri $Uri -Credential $Credential -OutFile $DestinationPath
}

function Find-ArtifactPath {
    param(
        [string]$FileName,
        [string[]]$SearchRoots,
        [switch]$Required
    )

    foreach ($root in $SearchRoots) {
        if ([string]::IsNullOrWhiteSpace($root)) {
            continue
        }

        $candidate = Join-Path $root $FileName
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    if ($Required) {
        $locations = ($SearchRoots | Where-Object { $_ }) -join ', '
        throw "Required artifact '$FileName' was not found. Checked: $locations"
    }

    return $null
}

function Get-DistributionRootFromPath {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $null
    }

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Expanded distribution root '$Path' does not exist."
    }

    $resolvedPath = (Resolve-Path -LiteralPath $Path).Path
    $releaseTarball = Get-ChildItem -Path $resolvedPath -Recurse -File -Filter 'vxworks-6.9-*.tar.gz' | Select-Object -First 1
    if (-not $releaseTarball) {
        throw "Expanded distribution root '$resolvedPath' does not contain release/vxworks-6.9-*.tar.gz."
    }

    return $resolvedPath
}

function Resolve-DownloadCredential {
    param(
        [string]$UserName,
        [string]$Password
    )

    $resolvedPassword = Get-SecretValue `
        -Value $Password `
        -PromptText "Enter the Gaisler web-download password for user '$UserName'"
    $securePassword = ConvertTo-SecureString $resolvedPassword -AsPlainText -Force
    return New-Object System.Management.Automation.PSCredential($UserName, $securePassword)
}

function Invoke-Process {
    param(
        [string]$FilePath,
        [string[]]$ArgumentList,
        [int[]]$SuccessExitCodes = @(0),
        [string]$Description = $FilePath
    )

    Write-Host $Description
    $process = Start-Process -FilePath $FilePath -ArgumentList ($ArgumentList -join ' ') -Wait -PassThru
    if ($SuccessExitCodes -notcontains $process.ExitCode) {
        throw "'$Description' failed with exit code $($process.ExitCode)."
    }
}

function Add-PathEntry {
    param(
        [string]$PathEntry,
        [ValidateSet('Machine', 'User')]
        [string]$Scope = 'Machine'
    )

    $currentValue = [Environment]::GetEnvironmentVariable('Path', $Scope)
    $entries = @()
    if (-not [string]::IsNullOrWhiteSpace($currentValue)) {
        $entries = $currentValue -split ';' | Where-Object { $_ }
    }

    $alreadyPresent = $false
    foreach ($entry in $entries) {
        if ($entry.TrimEnd('\') -ieq $PathEntry.TrimEnd('\')) {
            $alreadyPresent = $true
            break
        }
    }

    if (-not $alreadyPresent) {
        $newValue = (($entries + $PathEntry) -join ';')
        [Environment]::SetEnvironmentVariable('Path', $newValue, $Scope)
    }

    $sessionEntries = $env:Path -split ';' | Where-Object { $_ }
    $sessionPresent = $false
    foreach ($entry in $sessionEntries) {
        if ($entry.TrimEnd('\') -ieq $PathEntry.TrimEnd('\')) {
            $sessionPresent = $true
            break
        }
    }

    if (-not $sessionPresent) {
        $env:Path = "$PathEntry;$env:Path"
    }
}

function Install-LocalSevenZip {
    param([string]$ToolsRoot)

    $sevenZipHome = Join-Path $ToolsRoot $script:Config.SevenZipInstallDirName
    $sevenZipExe = Join-Path $sevenZipHome '7z.exe'
    if (Test-Path -LiteralPath $sevenZipExe) {
        return $sevenZipExe
    }

    Ensure-Directory -Path $ToolsRoot
    $installerPath = Join-Path $ToolsRoot $script:Config.SevenZipInstallerName
    if (-not (Test-Path -LiteralPath $installerPath)) {
        Write-Host "Downloading $($script:Config.SevenZipInstallerName)"
        Invoke-WebRequest -Uri $script:Config.SevenZipInstallerUrl -OutFile $installerPath
    }

    Invoke-Process `
        -FilePath $installerPath `
        -ArgumentList @('/S', ('/D="{0}"' -f $sevenZipHome)) `
        -Description 'Installing 7-Zip command line tools'

    if (-not (Test-Path -LiteralPath $sevenZipExe)) {
        throw '7-Zip was installed, but 7z.exe was not found afterwards.'
    }

    return $sevenZipExe
}

function Expand-EncryptedZip {
    param(
        [string]$SevenZipExe,
        [string]$ArchivePath,
        [string]$Password,
        [string]$DestinationPath
    )

    Ensure-Directory -Path $DestinationPath
    Invoke-Process `
        -FilePath $SevenZipExe `
        -ArgumentList @(
            'x',
            ('"{0}"' -f $ArchivePath),
            ('-o"{0}"' -f $DestinationPath),
            '-aoa',
            '-y',
            ('-p"{0}"' -f $Password)
        ) `
        -SuccessExitCodes @(0, 1) `
        -Description 'Extracting password-protected Gaisler archive'
}

function Expand-TarArchive {
    param(
        [string]$TarExe,
        [string]$ArchivePath,
        [string]$DestinationPath
    )

    Ensure-Directory -Path $DestinationPath
    & $TarExe -xf $ArchivePath -C $DestinationPath
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to extract archive '$ArchivePath'."
    }
}

function Copy-DirectoryTree {
    param(
        [string]$SourcePath,
        [string]$DestinationPath
    )

    Ensure-Directory -Path $DestinationPath
    & robocopy $SourcePath $DestinationPath /E /COPY:DAT /R:2 /W:2 /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -gt 7) {
        throw "Backup copy failed for '$SourcePath'."
    }
}

function Assert-WindRiverLayout {
    param([string]$RootPath)

    if (-not (Test-Path -LiteralPath $RootPath)) {
        throw "Wind River root '$RootPath' does not exist."
    }

    foreach ($requiredFolder in @('vxworks-6.9', 'components', 'workbench-3.3')) {
        $fullPath = Join-Path $RootPath $requiredFolder
        if (-not (Test-Path -LiteralPath $fullPath)) {
            throw "Expected folder '$fullPath' was not found."
        }
    }
}

function Backup-WindRiverInstall {
    param([string]$RootPath)

    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $backupRoot = Join-Path $RootPath "gr_manual_backup_$stamp"
    Ensure-Directory -Path $backupRoot

    foreach ($folderName in @('vxworks-6.9', 'components', 'workbench-3.3')) {
        $sourcePath = Join-Path $RootPath $folderName
        $destinationPath = Join-Path $backupRoot $folderName
        Write-Host "Backing up $folderName"
        Copy-DirectoryTree -SourcePath $sourcePath -DestinationPath $destinationPath
    }

    return $backupRoot
}

function Get-SingleFile {
    param(
        [string]$RootPath,
        [string]$Filter
    )

    $match = Get-ChildItem -Path $RootPath -Recurse -File -Filter $Filter | Select-Object -First 1
    if (-not $match) {
        throw "Could not find '$Filter' under '$RootPath'."
    }

    return $match.FullName
}

function Install-GccToolchain {
    param(
        [string]$InstallerPath,
        [string]$ZipPath,
        [string]$LogPath,
        [string]$SevenZipExe,
        [string]$ScratchRoot
    )

    if (Test-Path -LiteralPath $script:Config.ToolchainBinDir) {
        Write-Host "Reusing existing GCC toolchain at $($script:Config.ToolchainBinDir)"
        Add-PathEntry -PathEntry $script:Config.ToolchainBinDir
        return
    }

    if ($ZipPath -and (Test-Path -LiteralPath $ZipPath)) {
        Write-Host "Installing LEON GCC toolchain from ZIP: $ZipPath"
        Ensure-Directory -Path $script:Config.ToolchainInstallRoot

        $extractRoot = Join-Path $ScratchRoot 'toolchain-zip'
        if (Test-Path -LiteralPath $extractRoot) {
            Remove-Item -LiteralPath $extractRoot -Recurse -Force
        }
        Ensure-Directory -Path $extractRoot

        Invoke-Process `
            -FilePath $SevenZipExe `
            -ArgumentList @(
                'x',
                ('"{0}"' -f $ZipPath),
                ('-o"{0}"' -f $extractRoot),
                '-aoa',
                '-y'
            ) `
            -SuccessExitCodes @(0, 1) `
            -Description 'Extracting LEON GCC toolchain ZIP'

        $extractedRoot = Get-ChildItem -Path $extractRoot -Directory | Select-Object -First 1
        if (-not $extractedRoot) {
            throw "Could not find the extracted GCC toolchain folder under '$extractRoot'."
        }

        if (Test-Path -LiteralPath $script:Config.ToolchainInstallDir) {
            Remove-Item -LiteralPath $script:Config.ToolchainInstallDir -Recurse -Force
        }

        Move-Item -LiteralPath $extractedRoot.FullName -Destination $script:Config.ToolchainInstallDir
    }
    elseif ($InstallerPath -and (Test-Path -LiteralPath $InstallerPath)) {
        Invoke-Process `
            -FilePath $InstallerPath `
            -ArgumentList @(
                '/VERYSILENT',
                '/SUPPRESSMSGBOXES',
                '/NORESTART',
                '/SP-',
                ('/LOG="{0}"' -f $LogPath)
            ) `
            -Description 'Installing LEON GCC toolchain'
    }
    else {
        throw 'Neither the LEON GCC installer EXE nor the ZIP archive was found.'
    }

    if (-not (Test-Path -LiteralPath $script:Config.ToolchainBinDir)) {
        throw "Expected GCC bin folder '$($script:Config.ToolchainBinDir)' was not created."
    }

    Add-PathEntry -PathEntry $script:Config.ToolchainBinDir
}

function Install-LeonSourcesManual {
    param(
        [string]$WindRiverPath,
        [string]$ExpandedDistributionRoot,
        [string]$TarExe
    )

    $releaseTarball = Get-SingleFile -RootPath $ExpandedDistributionRoot -Filter 'vxworks-6.9-*.tar.gz'
    $backupRoot = Backup-WindRiverInstall -RootPath $WindRiverPath
    Write-Host "Backup saved to $backupRoot"
    Write-Host "Extracting LEON overlay into $WindRiverPath"

    & $TarExe -xf $releaseTarball -C $WindRiverPath
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to install LEON distribution from '$releaseTarball'."
    }

    return $backupRoot
}

function Launch-CompileGui {
    param([string]$ExpandedDistributionRoot)

    $compileGui = Get-ChildItem -Path $ExpandedDistributionRoot -Recurse -File -Filter 'compile-6.9*.exe' | Select-Object -First 1
    if (-not $compileGui) {
        Write-Warning 'The compile GUI was not found in the expanded distribution.'
        return
    }

    Start-Process -FilePath $compileGui.FullName
    Write-Host "Opened compile GUI: $($compileGui.FullName)"
}

if (-not $ValidateOnly -and -not $SkipElevation -and -not (Test-Administrator)) {
    Restart-Elevated
}

$tarExe = Assert-Command -Name 'tar.exe'
$null = Assert-Command -Name 'robocopy.exe'

$downloadRoot = Join-Path $WorkRoot 'downloads'
$toolsRoot = Join-Path $WorkRoot 'tools'
$expandedRoot = Join-Path $WorkRoot 'expanded'
$logRoot = Join-Path $WorkRoot 'logs'

foreach ($path in @($WorkRoot, $downloadRoot, $toolsRoot, $expandedRoot, $logRoot)) {
    Ensure-Directory -Path $path
}

$transcriptPath = Join-Path $logRoot ("install-{0}.log" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
$transcriptStarted = $false

try {
    Start-Transcript -Path $transcriptPath -Force | Out-Null
    $transcriptStarted = $true

    Write-Host "$($script:Config.ProductName) installer" -ForegroundColor Green
    Write-Host "Release: $($script:Config.ReleaseVersion)"
    Write-Host "Wind River root: $WindRiverRoot"
    Write-Host ''
    Write-Warning "Frontgrade Gaisler release $($script:Config.ReleaseVersion) requires Wind River VxWorks $($script:Config.RequiredVxWorks) and $($script:Config.RequiredWorkbench)."
    Write-Warning 'If your base Wind River install is 6.9.4.7, the current Gaisler release is outside the supported matrix.'

    Write-Step 'Validating Wind River installation layout'
    Assert-WindRiverLayout -RootPath $WindRiverRoot

    if (Test-Path -LiteralPath $SourceFilesRoot) {
        Write-Host "Using local source folder: $SourceFilesRoot"

        $partialDownloads = Get-ChildItem -LiteralPath $SourceFilesRoot -Filter '*.crdownload' -File -ErrorAction SilentlyContinue
        foreach ($partialDownload in $partialDownloads) {
            Write-Warning "Found incomplete download: $($partialDownload.Name)"
        }
    }
    else {
        Write-Host "Local source folder not found: $SourceFilesRoot"
    }

    $distributionZipPath = $null
    if (-not $ExpandedDistributionRoot) {
        $distributionZipPath = Find-ArtifactPath `
            -FileName $script:Config.DistributionZipName `
            -SearchRoots @($SourceFilesRoot, $downloadRoot)
    }

    $toolchainInstallerPath = $null
    $toolchainZipPath = $null
    if (-not $SkipToolchainInstall) {
        $toolchainInstallerPath = Find-ArtifactPath `
            -FileName $script:Config.ToolchainInstallerName `
            -SearchRoots @($SourceFilesRoot, $downloadRoot)
        $toolchainZipPath = Find-ArtifactPath `
            -FileName $script:Config.ToolchainZipName `
            -SearchRoots @($SourceFilesRoot, $downloadRoot)
    }

    $guidePdfPath = Find-ArtifactPath `
        -FileName $script:Config.GuidePdfName `
        -SearchRoots @($SourceFilesRoot, $downloadRoot)

    $needsDownloadCredential = $false
    if (-not $ExpandedDistributionRoot -and -not $distributionZipPath) {
        $needsDownloadCredential = $true
    }
    if (-not $SkipToolchainInstall -and -not $toolchainInstallerPath -and -not $toolchainZipPath) {
        $needsDownloadCredential = $true
    }

    $downloadCredential = $null
    if ($needsDownloadCredential) {
        Write-Step 'Downloading missing official Gaisler artifacts'
        $downloadCredential = Resolve-DownloadCredential -UserName $DownloadUser -Password $DownloadPassword
    }
    else {
        Write-Step 'Using locally provided Gaisler artifacts'
    }

    if (-not $ExpandedDistributionRoot -and -not $distributionZipPath) {
        $distributionZipPath = Join-Path $downloadRoot $script:Config.DistributionZipName
        Invoke-Download `
            -Uri "$($script:Config.DownloadBaseUrl)/$($script:Config.DistributionZipName)" `
            -Credential $downloadCredential `
            -DestinationPath $distributionZipPath
    }

    if (-not $SkipToolchainInstall -and -not $toolchainInstallerPath -and -not $toolchainZipPath) {
        $toolchainInstallerPath = Join-Path $downloadRoot $script:Config.ToolchainInstallerName
        Invoke-Download `
            -Uri "$($script:Config.DownloadBaseUrl)/$($script:Config.ToolchainInstallerName)" `
            -Credential $downloadCredential `
            -DestinationPath $toolchainInstallerPath
    }

    if (-not $guidePdfPath) {
        if ($downloadCredential) {
            $guidePdfPath = Join-Path $downloadRoot $script:Config.GuidePdfName
            Invoke-Download `
                -Uri "$($script:Config.DownloadBaseUrl)/$($script:Config.GuidePdfName)" `
                -Credential $downloadCredential `
                -DestinationPath $guidePdfPath
        }
        else {
            Write-Warning "Optional guide PDF not found in '$SourceFilesRoot'."
        }
    }

    if ($ValidateOnly) {
        Write-Step 'Validation complete'
        Write-Host "Distribution ZIP : $distributionZipPath"
        Write-Host "Toolchain EXE    : $toolchainInstallerPath"
        Write-Host "Toolchain ZIP    : $toolchainZipPath"
        Write-Host "Guide PDF        : $guidePdfPath"
        if (-not $ExpandedDistributionRoot) {
            Write-Host 'Next requirement : the separate Gaisler ZIP password is still needed to extract the distribution archive.'
        }
        return
    }

    $sevenZipExe = $null
    if ($toolchainZipPath -or -not $ExpandedDistributionRoot) {
        Write-Step 'Preparing archive tools'
        $sevenZipExe = Install-LocalSevenZip -ToolsRoot $toolsRoot
    }

    $distExpandedRoot = $null
    if ($ExpandedDistributionRoot) {
        Write-Step 'Using a pre-expanded LEON distribution'
        $distExpandedRoot = Get-DistributionRootFromPath -Path $ExpandedDistributionRoot
    }
    else {

        Write-Step 'Prompting for the Gaisler distribution ZIP password'
        $distributionPassword = Get-SecretValue `
            -Value $DistributionPassword `
            -PromptText 'Enter the separate ZIP password for dist-vxworks-6.9-2.3.0.tar.gz.zip'

        Write-Step 'Expanding the protected LEON distribution'
        $zipExpandedRoot = Join-Path $expandedRoot 'zip'
        $distExpandedRoot = Join-Path $expandedRoot 'dist'
        Expand-EncryptedZip `
            -SevenZipExe $sevenZipExe `
            -ArchivePath $distributionZipPath `
            -Password $distributionPassword `
            -DestinationPath $zipExpandedRoot

        $distributionTarball = Get-SingleFile -RootPath $zipExpandedRoot -Filter 'dist-vxworks-6.9-*.tar.gz'
        Expand-TarArchive `
            -TarExe $tarExe `
            -ArchivePath $distributionTarball `
            -DestinationPath $distExpandedRoot
    }

    if (-not $SkipToolchainInstall) {
        Write-Step 'Installing the LEON GCC toolchain'
        $toolchainLog = Join-Path $logRoot 'gcc-toolchain-install.log'
        Install-GccToolchain `
            -InstallerPath $toolchainInstallerPath `
            -ZipPath $toolchainZipPath `
            -LogPath $toolchainLog `
            -SevenZipExe $sevenZipExe `
            -ScratchRoot $expandedRoot
    }
    else {
        Write-Step 'Skipping GCC toolchain install by request'
    }

    Write-Step 'Installing the LEON VxWorks sources using the documented manual overlay flow'
    $backupRoot = Install-LeonSourcesManual `
        -WindRiverPath $WindRiverRoot `
        -ExpandedDistributionRoot $distExpandedRoot `
        -TarExe $tarExe

    if (-not $SkipCompileGui) {
        Write-Step 'Launching the vendor compile GUI'
        Launch-CompileGui -ExpandedDistributionRoot $distExpandedRoot
    }
    else {
        Write-Step 'Skipping compile GUI launch by request'
    }

    Write-Step 'Install complete'
    Write-Host "Backup folder : $backupRoot"
    Write-Host "Transcript    : $transcriptPath"
    Write-Host "Guide PDF     : $guidePdfPath"
    Write-Host ''
    Write-Host 'Remember to update Workbench build rules in each workspace:'
    Write-Host 'Window -> Preferences -> Wind River -> Build -> Build Properties -> Restore Defaults for each VxWorks rule'
}
catch {
    Write-Error $_
    throw
}
finally {
    if ($transcriptStarted) {
        Stop-Transcript | Out-Null
    }

    if (-not $NoPause) {
        Write-Host ''
        Read-Host 'Press Enter to close'
    }
}
