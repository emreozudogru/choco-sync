# ChocoAlign.psm1
# PowerShell Module for ChocoAlign
# Author: Gemini Antigravity
# Language: English
#
# Copyright (C) 2026 Emre Ozudogru <emre@ozudogru.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

# Disable warning about using Write-Host
# [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]

$CommonMappings = @{
    "google chrome"               = "googlechrome"
    "mozilla firefox"             = "firefox"
    "visual studio code"          = "vscode"
    "git"                         = "git"
    "github desktop"              = "github-desktop"
    "7-zip"                       = "7zip"
    "vlc media player"            = "vlc"
    "notepad++"                   = "notepadplusplus"
    "winrar"                      = "winrar"
    "docker desktop"              = "docker-desktop"
    "node.js"                     = "nodejs"
    "python"                      = "python"
    "putty"                       = "putty"
    "steam"                       = "steam"
    "discord"                     = "discord"
    "zoom"                        = "zoom"
    "spotify"                     = "spotify"
    "slack"                       = "slack"
    "skype"                       = "skype"
    "anydesk"                     = "anydesk"
    "teamviewer"                  = "teamviewer"
    "gimp"                        = "gimp"
    "postman"                     = "postman"
    "brave browser"               = "brave"
    "opera web browser"           = "opera"
    "tortoisegit"                 = "tortoisegit"
    "winscp"                      = "winscp"
    "dbeaver community edition"   = "dbeaver"
    "libreoffice"                 = "libreoffice"
    "obs studio"                  = "obs-studio"
    "dropbox"                     = "dropbox"
    "microsoft onedrive"          = "onedrive"
    "google drive"                = "googledrive"
    "fiddler"                     = "fiddler"
    "rufus"                       = "rufus"
    "utorrent"                    = "utorrent"
    "qbittorrent"                 = "qbittorrent"
    "filezilla client"            = "filezilla"
    "paint.net"                   = "paint.net"
    "audacity"                    = "audacity"
    "handbrake"                   = "handbrake"
    "putty release"               = "putty"
    "wireshark"                   = "wireshark"
    "virtualbox"                  = "virtualbox"
    "vmware workstation"          = "vmware-workstation-player"
    "whatsapp"                    = "whatsapp"
    "telegram desktop"            = "telegram"
}

# Helper to check if a command exists
function Test-CommandExists {
    param ([string]$Command)
    return (Get-Command $Command -ErrorAction SilentlyContinue) -ne $null
}

# Scan Windows Registry for installed applications
function Get-InstalledApps {
    [CmdletBinding()]
    param()

    Write-Host "[*] Scanning Registry for installed applications..." -ForegroundColor Cyan

    $regPaths = @(
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    $apps = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($path in $regPaths) {
        if (Test-Path (Split-Path $path)) {
            $items = Get-ItemProperty -Path $path -ErrorAction SilentlyContinue
            foreach ($item in $items) {
                # Filtering rules for system components and updates
                $displayName = $item.DisplayName
                $systemComponent = $item.SystemComponent
                $parentKeyName = $item.ParentKeyName
                $uninstallString = $item.UninstallString
                $publisher = $item.Publisher
                $displayVersion = $item.DisplayVersion

                if (-not [string]::IsNullOrWhiteSpace($displayName)) {
                    # Skip Windows Updates and Language Packs
                    if ($displayName -match "Security Update|Update for Windows|Language Pack|KB\d{6}") {
                        continue
                    }
                    # Skip if flagged as system component
                    if ($systemComponent -eq 1) {
                        continue
                    }
                    # Skip if there's a parent key (often sub-components)
                    if (-not [string]::IsNullOrWhiteSpace($parentKeyName)) {
                        continue
                    }
                    # Skip if no uninstall string (usually not a full app)
                    if ([string]::IsNullOrWhiteSpace($uninstallString)) {
                        continue
                    }

                    # Clean duplicate additions (same name and version)
                    $isDuplicate = $apps | Where-Object { $_.AppName -eq $displayName -and $_.DisplayVersion -eq $displayVersion }
                    if (-not $isDuplicate) {
                        $apps.Add([PSCustomObject]@{
                            AppName        = $displayName.Trim()
                            Publisher      = if ($publisher) { $publisher.Trim() } else { "Unknown" }
                            DisplayVersion = if ($displayVersion) { $displayVersion.Trim() } else { "Unknown" }
                        })
                    }
                }
            }
        }
    }

    Write-Host "[+] Found $($apps.Count) unique installed applications." -ForegroundColor Green
    return $apps
}

# Normalize application name and search for a matching Chocolatey ID
function Search-ChocoPackage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$AppName,
        
        [Parameter(Mandatory=$false)]
        [string]$Publisher = "Unknown"
    )

    $lowerName = $AppName.ToLower().Trim()

    # Step 1: Check in the static common mappings list using word boundaries
    foreach ($key in $CommonMappings.Keys) {
        $escapedKey = [regex]::Escape($key)
        # Use word boundaries if it's normal text, otherwise anchor to non-word chars
        $pattern = if ($key -match '^[a-z0-9\s\-\.]+$') { "\b$escapedKey\b" } else { "\b$escapedKey(?!\w)" }
        
        if ($lowerName -match $pattern) {
            return [PSCustomObject]@{
                ChocoId    = $CommonMappings[$key]
                Confidence = "High"
                Source     = "CommonMappings"
            }
        }
    }

    # Step 2: Normalize the name to clean alphanumeric string for search
    # Remove version numbers
    $cleanName = $lowerName -replace '\b\d+(\.\d+)+\b', ''
    $cleanName = $cleanName -replace '\b(x64|x86|64-bit|32-bit)\b', ''
    $cleanName = $cleanName -replace '[\(\)\[\]]', ''
    $cleanName = $cleanName -replace '\b(corporation|inc|co|ltd|software|systems|technologies|group)\b', ''
    $cleanName = $cleanName -replace '\b(version|build|release|client|edition|player)\b', ''
    $cleanName = ($cleanName -replace '\s+', ' ').Trim()

    $candidateId = $cleanName -replace '\s+', '-'
    $candidateId = $candidateId -replace '[^a-z0-9\-\.]', '' # keep alphanumeric, hyphen, dot
    $candidateId = ($candidateId -replace '-+', '-').Trim('-')

    if ([string]::IsNullOrWhiteSpace($candidateId)) {
        return [PSCustomObject]@{
            ChocoId    = ""
            Confidence = "None"
            Source     = "Search"
        }
    }

    # Step 3: Run choco search if choco is installed
    if (Test-CommandExists "choco") {
        # 3.1 Exact search first
        $exactResult = choco search $candidateId -r --exact -y 2>$null
        if (-not [string]::IsNullOrWhiteSpace($exactResult)) {
            $chocoMatch = ($exactResult -split '\|')[0].Trim()
            return [PSCustomObject]@{
                ChocoId    = $chocoMatch
                Confidence = "High"
                Source     = "ChocoExactSearch"
            }
        }

        # 3.2 Broad search
        $broadResults = choco search $candidateId -r -y 2>$null
        if (-not [string]::IsNullOrWhiteSpace($broadResults)) {
            $lines = $broadResults -split "`r`n" -split "`n"
            foreach ($line in $lines) {
                if (-not [string]::IsNullOrWhiteSpace($line)) {
                    $parts = $line -split '\|'
                    $pkgId = $parts[0].Trim()
                    
                    # Check if the returned package ID matches candidateId or is a close variant
                    if ($pkgId -eq $candidateId -or 
                        $pkgId -eq "$candidateId.install" -or 
                        $pkgId -eq "$candidateId.portable" -or
                        $pkgId -eq "$candidateId-app" -or
                        $pkgId -eq "$candidateId-desktop" -or
                        $candidateId -eq "$pkgId-desktop") {
                        
                        return [PSCustomObject]@{
                            ChocoId    = $pkgId
                            Confidence = "Medium"
                            Source     = "ChocoBroadSearch"
                        }
                    }
                }
            }
        }
    }

    # Step 4: If no search results found, DO NOT GUESS.
    # Return empty package ID so user can review and fill it manually if desired.
    return [PSCustomObject]@{
        ChocoId    = ""
        Confidence = "None"
        Source     = "Search"
    }
}

# Export scanned apps and mappings to CSV, preserving existing user overrides
function Export-MappingCsv {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [array]$Apps,
        
        [Parameter(Mandatory=$true)]
        [string]$Path,
        
        [switch]$OnlineSearch # Retained as legacy flag, search is now always automated
    )

    $existingMappings = @{}
    if (Test-Path $Path) {
        Write-Host "[*] Existing mapping file found at '$Path'. Loading current overrides..." -ForegroundColor Cyan
        try {
            $csvData = Import-Csv -Path $Path -ErrorAction Stop
            foreach ($row in $csvData) {
                if (-not [string]::IsNullOrWhiteSpace($row.ApplicationName)) {
                    # Key by lower application name to ensure case insensitivity
                    $existingMappings[$row.ApplicationName.ToLower().Trim()] = $row
                }
            }
            Write-Host "[+] Loaded $($existingMappings.Count) existing mappings to preserve." -ForegroundColor Green
        } catch {
            Write-Warning "Failed to parse existing mapping CSV file: $_. Mappings will be regenerated."
        }
    }

    $finalRows = [System.Collections.Generic.List[PSCustomObject]]::new()
    $totalCount = $Apps.Count
    $currentIndex = 0

    Write-Host "[*] Resolving Chocolatey packages via search (this may take a moment)..." -ForegroundColor Cyan

    foreach ($app in $Apps) {
        $currentIndex++
        $appNameLower = $app.AppName.ToLower().Trim()
        $idxStr = $currentIndex.ToString().PadLeft($totalCount.ToString().Length)
        $prefix = "[$idxStr/$totalCount]"

        if ($existingMappings.ContainsKey($appNameLower)) {
            # Preserve existing mapping
            $exist = $existingMappings[$appNameLower]
            Write-Host "$prefix [*] Preserved: '$($app.AppName)' -> '$($exist.ChocoPackageId)'" -ForegroundColor Gray
            $finalRows.Add([PSCustomObject]@{
                ApplicationName = $app.AppName
                Publisher       = $app.Publisher
                DisplayVersion  = $app.DisplayVersion
                ChocoPackageId  = $exist.ChocoPackageId
                MatchConfidence = $exist.MatchConfidence
                Action          = $exist.Action
            })
        } else {
            # Perform exact/broad choco search mapping
            $match = Search-ChocoPackage -AppName $app.AppName -Publisher $app.Publisher

            # Default action rules
            $action = "Review"
            if ($match.Confidence -eq "High") {
                $action = "Include"
            } elseif ($match.Confidence -eq "None" -or [string]::IsNullOrWhiteSpace($match.ChocoId)) {
                $action = "Ignore"
            }

            # Interactive logging based on match source
            if ($match.Confidence -eq "High" -and $match.Source -eq "CommonMappings") {
                Write-Host "$prefix [+] Common Map:  '$($app.AppName)' -> '$($match.ChocoId)'" -ForegroundColor Cyan
            } elseif ($match.Confidence -eq "High" -and $match.Source -eq "ChocoExactSearch") {
                Write-Host "$prefix [+] Exact Search: '$($app.AppName)' -> '$($match.ChocoId)'" -ForegroundColor Green
            } elseif ($match.Confidence -eq "Medium" -and $match.Source -eq "ChocoBroadSearch") {
                Write-Host "$prefix [+] Broad Search: '$($app.AppName)' -> '$($match.ChocoId)'" -ForegroundColor Yellow
            } else {
                Write-Host "$prefix [-] Unresolved:   '$($app.AppName)'" -ForegroundColor DarkGray
            }

            $finalRows.Add([PSCustomObject]@{
                ApplicationName = $app.AppName
                Publisher       = $app.Publisher
                DisplayVersion  = $app.DisplayVersion
                ChocoPackageId  = $match.ChocoId
                MatchConfidence = $match.Confidence
                Action          = $action
            })
        }
    }

    # Ensure parent directory exists
    $parentDir = Split-Path $Path
    if (-not [string]::IsNullOrWhiteSpace($parentDir) -and -not (Test-Path $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
    }

    # Sort rows by Confidence: High first, then Medium, then Low, then None
    $confidenceWeight = @{
        "High"   = 1
        "Medium" = 2
        "Low"    = 3
        "None"   = 4
    }
    $sortedRows = $finalRows | Sort-Object @{ Expression = { 
        if ($confidenceWeight.ContainsKey($_.MatchConfidence)) { $confidenceWeight[$_.MatchConfidence] } else { 4 } 
    } }

    $sortedRows | Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8 -Force
    Write-Host "[+] Mappings successfully saved to '$Path'." -ForegroundColor Green
    Write-Host "    Please open this file, review the matched package IDs, set Action to 'Include' or 'Ignore', and save." -ForegroundColor Yellow
}

# Generate packages.config XML from the mapping CSV
function New-ChocoConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$CsvPath,
        
        [Parameter(Mandatory=$true)]
        [string]$ConfigPath
    )

    if (-not (Test-Path $CsvPath)) {
        throw "Mapping CSV file not found at '$CsvPath'. Please run with -GenerateMap first."
    }

    Write-Host "[*] Reading mappings from '$CsvPath'..." -ForegroundColor Cyan
    $rows = Import-Csv -Path $CsvPath
    
    $includedPackages = @()
    foreach ($row in $rows) {
        if ($row.Action -eq "Include" -and -not [string]::IsNullOrWhiteSpace($row.ChocoPackageId)) {
            $includedPackages += $row.ChocoPackageId.Trim().ToLower()
        }
    }

    # Remove duplicates from package list
    $includedPackages = $includedPackages | Select-Object -Unique

    if ($includedPackages.Count -eq 0) {
        Write-Host "[-] No packages marked with Action 'Include' in mapping file. Nothing to generate." -ForegroundColor Yellow
        return
    }

    Write-Host "[*] Generating standard packages.config XML for $($includedPackages.Count) packages..." -ForegroundColor Cyan

    $xmlLines = @(
        '<?xml version="1.0" encoding="utf-8"?>',
        '<packages>'
    )
    foreach ($pkg in $includedPackages) {
        $xmlLines += "  <package id=`"$pkg`" />"
    }
    $xmlLines += '</packages>'

    # Ensure parent directory exists
    $parentDir = Split-Path $ConfigPath
    if (-not [string]::IsNullOrWhiteSpace($parentDir) -and -not (Test-Path $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
    }

    $xmlLines | Out-File -FilePath $ConfigPath -Encoding utf8 -Force
    Write-Host "[+] Package configuration generated at '$ConfigPath'." -ForegroundColor Green
}

# Install packages using Chocolatey packages.config
function Invoke-ChocoInstall {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ConfigPath,
        
        [switch]$DryRun
    )

    if (-not (Test-Path $ConfigPath)) {
        throw "Chocolatey configuration file not found at '$ConfigPath'. Please run with -GenerateConfig first."
    }

    if (-not (Test-CommandExists "choco")) {
        Write-Error "Chocolatey (choco) was not found on this system. Please install it first from https://chocolatey.org/install"
        return
    }

    Write-Host "[*] Launching Chocolatey installation..." -ForegroundColor Cyan
    if ($DryRun) {
        Write-Host "[DRY-RUN] Command to run: choco install `"$ConfigPath`" -y --noop" -ForegroundColor Yellow
        # Actually execute dry run via Chocolatey if possible to check package validity
        choco install $ConfigPath -y --noop
    } else {
        Write-Host "[!] Executing: choco install `"$ConfigPath`" -y" -ForegroundColor Red
        choco install $ConfigPath -y
    }
}

Export-ModuleMember -Function Get-InstalledApps, Search-ChocoPackage, Export-MappingCsv, New-ChocoConfig, Invoke-ChocoInstall
