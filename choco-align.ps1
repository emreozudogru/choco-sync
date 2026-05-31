<#
.SYNOPSIS
    ChocoAlign CLI utility - Aligns installed Windows applications with Chocolatey.
.DESCRIPTION
    Scans installed programs from the registry, suggests equivalent Chocolatey package IDs,
    saves them to an editable CSV, generates a packages.config, and syncs/installs them.
.PARAMETER GenerateMap
    Scans registry and writes suggestions to the choco-mappings.csv file.
.PARAMETER GenerateConfig
    Generates a packages.config from the edited choco-mappings.csv file.
.PARAMETER Install
    Executes 'choco install' on the generated packages.config.
.PARAMETER OnlineSearch
    Enables slow but accurate online search against the Chocolatey repository during mapping.
.PARAMETER DryRun
    Simulates the installation process using Chocolatey's --noop flag.
.PARAMETER CsvPath
    Overrides the default path for the mappings CSV file.
.PARAMETER ConfigPath
    Overrides the default path for the packages.config XML file.
.EXAMPLE
    .\choco-align.ps1 -GenerateMap
.EXAMPLE
    .\choco-align.ps1 -GenerateMap -OnlineSearch
.EXAMPLE
    .\choco-align.ps1 -GenerateConfig
.EXAMPLE
    .\choco-align.ps1 -Install -DryRun
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [switch]$GenerateMap,

    [Parameter(Mandatory=$false)]
    [switch]$GenerateConfig,

    [Parameter(Mandatory=$false)]
    [switch]$Install,

    [Parameter(Mandatory=$false)]
    [switch]$OnlineSearch,

    [Parameter(Mandatory=$false)]
    [switch]$DryRun,

    [Parameter(Mandatory=$false)]
    [string]$CsvPath = "choco-mappings.csv",

    [Parameter(Mandatory=$false)]
    [string]$ConfigPath = "packages.config"
)

# Set strict mode and error action preference
$ErrorActionPreference = "Stop"

# Resolve absolute paths
$CsvPath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot $CsvPath))
$ConfigPath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot $ConfigPath))

# Print ASCII Art Banner
function Show-Banner {
    Clear-Host
    Write-Host @"
   ______ __                     ___   __ _               
  / ____// /_   ____   _____ ___/   | / /(_)____ _ ____  
 / /    / __ \ / __ \ / ___// __  |/ / / // __ `// __ \ 
/ /___ / / / // /_/ // /__ / /_/  / / / // /_/ // / / / 
\____//_/ /_/ \____/ \___/ \__,_/_/ /_/ \__, //_/ /_/  
                                       /____/          
"@ -ForegroundColor Cyan
    Write-Host "=========================================================" -ForegroundColor DarkCyan
    Write-Host "   ChocoAlign - Align Windows Programs with Chocolatey   " -ForegroundColor White
    Write-Host "   Designed by Gemini Antigravity                        " -ForegroundColor Gray
    Write-Host "=========================================================" -ForegroundColor DarkCyan
    Write-Host ""
}

# Import core module
$ModulePath = Join-Path $PSScriptRoot "src/ChocoAlign.psm1"
if (-not (Test-Path $ModulePath)) {
    Write-Error "Required module file not found at '$ModulePath'!"
    exit 1
}

Import-Module $ModulePath -Force

# Execute based on flags
if ($GenerateMap) {
    Show-Banner
    Write-Host "[*] Action Selected: Generate Mappings" -ForegroundColor Yellow
    $apps = Get-InstalledApps
    Export-MappingCsv -Apps $apps -Path $CsvPath -OnlineSearch:$OnlineSearch
    Write-Host "`n[!] Next Step: Open '$CsvPath', check suggestions, set Action='Include' for packages you want, and run:" -ForegroundColor Yellow
    Write-Host "    .\choco-align.ps1 -GenerateConfig" -ForegroundColor Cyan
}
elseif ($GenerateConfig) {
    Show-Banner
    Write-Host "[*] Action Selected: Generate packages.config" -ForegroundColor Yellow
    New-ChocoConfig -CsvPath $CsvPath -ConfigPath $ConfigPath
    Write-Host "`n[!] Next Step: Review '$ConfigPath' and run the installation script on this or another PC using:" -ForegroundColor Yellow
    Write-Host "    .\choco-align.ps1 -Install -DryRun   (To test)" -ForegroundColor Cyan
    Write-Host "    .\choco-align.ps1 -Install           (To execute)" -ForegroundColor Cyan
}
elseif ($Install) {
    Show-Banner
    Write-Host "[*] Action Selected: Install packages.config" -ForegroundColor Yellow
    Invoke-ChocoInstall -ConfigPath $ConfigPath -DryRun:$DryRun
}
else {
    # No options selected: display help/usage
    Show-Banner
    Write-Host "Usage Description:" -ForegroundColor White
    Write-Host "  Step 1: Scan local apps and generate editable mappings CSV" -ForegroundColor Gray
    Write-Host "    .\choco-align.ps1 -GenerateMap" -ForegroundColor Green
    Write-Host "    (Use -OnlineSearch to perform slow, accurate online matching)" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Step 2: Review and edit 'choco-mappings.csv' manually" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Step 3: Generate the standard packages.config XML from mappings" -ForegroundColor Gray
    Write-Host "    .\choco-align.ps1 -GenerateConfig" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Step 4: Install/restore packages from packages.config" -ForegroundColor Gray
    Write-Host "    .\choco-align.ps1 -Install [-DryRun]" -ForegroundColor Green
    Write-Host ""
    Write-Host "Additional Parameters:" -ForegroundColor White
    Write-Host "  -CsvPath <file.csv>     Set custom CSV mappings file path" -ForegroundColor Gray
    Write-Host "  -ConfigPath <file.config> Set custom packages.config file path" -ForegroundColor Gray
    Write-Host ""
}
