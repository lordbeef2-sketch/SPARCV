# SPARC/LEON VxWorks 6.9 Installer

This repo contains a PowerShell-based helper to install the Frontgrade Gaisler SPARC/LEON VxWorks 6.9 distribution on top of an existing Wind River VxWorks 6.9 installation.

## Included files

- `Install-SparcLeon-VxWorks6.9.ps1`
- `Run-SparcLeon-Installer.cmd`

## Local prerequisites

Place licensed installers and archives in a local `InstallFiles/` folder next to the script. That folder is intentionally ignored by git.

Expected files include:

- `dist-vxworks-6.9-2.3.0.tar.gz.zip`
- `sparc-wrs-vxworks-4.9-1.0.7-mingw.exe`
- `sparc-wrs-vxworks-4.9-1.0.7-mingw.zip`

## Usage

Run from an elevated PowerShell window:

```powershell
cd C:\sand\SPARC_6.9_Installer
.\Install-SparcLeon-VxWorks6.9.ps1 -WindRiverRoot "C:\WindRiver6.9"
```

Or use:

```cmd
Run-SparcLeon-Installer.cmd
```

## Notes

- The Wind River base install must already be present and patched to the version required by the current Gaisler release.
- The Gaisler distribution ZIP password is required to extract `dist-vxworks-6.9-2.3.0.tar.gz.zip`.
