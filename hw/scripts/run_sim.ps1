# Run a testbench under xsim.
#
# Testbenches are written before the RTL they exercise and are expected to pass
# before anything goes near the board.
#
# Usage:
#   pwsh hw/scripts/run_sim.ps1                # runs every *_tb.sv
#   pwsh hw/scripts/run_sim.ps1 -Tb blink_tb   # runs one

param(
    [string]$Tb = "",
    [string]$VivadoBin = "C:\AMDDesignTools\2025.2\Vivado\bin"
)

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$rtlDir   = Join-Path $repoRoot 'hw\rtl'
$tbDir    = Join-Path $repoRoot 'hw\tb'
$workDir  = Join-Path $repoRoot 'hw\sim'

New-Item -ItemType Directory -Force -Path $workDir | Out-Null

$tbFiles = if ($Tb) {
    @(Join-Path $tbDir "$Tb.sv")
} else {
    Get-ChildItem $tbDir -Filter '*_tb.sv' | ForEach-Object { $_.FullName }
}

if ($tbFiles.Count -eq 0) { Write-Host "No testbenches found in $tbDir"; exit 0 }

# top.sv instantiates the generated BD wrapper, which does not exist outside a
# built project, so it is excluded from unit simulation.
$rtlFiles = Get-ChildItem $rtlDir -Filter '*.sv' |
            Where-Object { $_.Name -ne 'top.sv' } |
            ForEach-Object { $_.FullName }

$failed = @()
Push-Location $workDir
try {
    foreach ($tbFile in $tbFiles) {
        $name = [System.IO.Path]::GetFileNameWithoutExtension($tbFile)
        Write-Host ""
        Write-Host "==== $name ===="

        & "$VivadoBin\xvlog.bat" -sv @rtlFiles $tbFile 2>&1 |
            Select-String -Pattern '^ERROR' | ForEach-Object { Write-Host $_ }

        & "$VivadoBin\xelab.bat" -debug typical $name -s "${name}_sim" 2>&1 |
            Select-String -Pattern '^ERROR' | ForEach-Object { Write-Host $_ }

        $out = & "$VivadoBin\xsim.bat" "${name}_sim" -runall 2>&1
        $out | Select-String -Pattern 'PASSED|FAILED|FAIL:|^Error' | ForEach-Object { Write-Host $_ }

        if ($out -match 'FAILED') { $failed += $name }
    }
}
finally { Pop-Location }

Write-Host ""
if ($failed.Count -gt 0) {
    Write-Host "FAILED: $($failed -join ', ')"
    exit 1
}
Write-Host "All testbenches passed."
