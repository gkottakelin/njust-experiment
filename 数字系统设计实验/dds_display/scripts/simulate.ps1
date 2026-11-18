param([string]$VivadoBin = 'D:\vivado\2025.2\Vivado\bin')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
Push-Location -LiteralPath $projectRoot
try {
    $sourceFiles = @(Get-ChildItem -LiteralPath (Join-Path $projectRoot 'rtl') -Filter '*.v' | ForEach-Object FullName)
    $testbench = Join-Path $projectRoot 'sim\tb_dds_display.sv'
    & (Join-Path $VivadoBin 'xvlog.bat') -sv @sourceFiles $testbench
    if ($LASTEXITCODE -ne 0) { throw 'Verilog compilation failed' }
    & (Join-Path $VivadoBin 'xelab.bat') work.tb_dds_display -s tb_dds_display_sim -debug typical
    if ($LASTEXITCODE -ne 0) { throw 'Simulation elaboration failed' }
    & (Join-Path $VivadoBin 'xsim.bat') tb_dds_display_sim -runall -log functional_simulation.log
    if ($LASTEXITCODE -ne 0) { throw 'Simulation process failed' }
    $simLog = Get-Content -LiteralPath 'functional_simulation.log' -Raw
    if ($simLog -match 'Fatal:' -or $simLog -notmatch 'PASS: all 256 K values') {
        throw 'Simulation assertions did not pass; see functional_simulation.log'
    }
} finally {
    Pop-Location
}
