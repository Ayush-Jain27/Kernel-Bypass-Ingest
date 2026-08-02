# Fetch the AUP-ZU3 board files into hw/board_files/.
#
# These are not committed. The upstream repository carries no LICENSE file, so
# redistributing its contents from this public repo would be presumptuous. This
# script makes the dependency reproducible instead: run it once after cloning.
#
# Usage:  pwsh hw/scripts/fetch_board_files.ps1

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$dest     = Join-Path $repoRoot 'hw\board_files'
$variant  = 'aup-zu3-8gb'   # the 4 GB and 8 GB boards are NOT interchangeable
$upstream = 'https://github.com/RealDigitalOrg/aup-zu3-bsp.git'

if (Test-Path (Join-Path $dest $variant)) {
    Write-Host "Board files already present at $dest\$variant"
    exit 0
}

$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("aup-zu3-bsp-" + [guid]::NewGuid().ToString('N').Substring(0,8))
Write-Host "Cloning $upstream ..."
git clone --depth 1 --quiet $upstream $tmp

try {
    $src = Join-Path $tmp "board-files\$variant"
    if (-not (Test-Path $src)) { throw "Variant '$variant' not found upstream" }

    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    Copy-Item $src -Destination $dest -Recurse -Force
    Write-Host "Installed board files to $dest\$variant"
    Write-Host ""
    Write-Host "Vivado picks these up via hw/scripts/board_repo.tcl, which the"
    Write-Host "project creation script sources. Nothing is written into the"
    Write-Host "Vivado install directory."
}
finally {
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
