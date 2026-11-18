param([string]$VivadoBin = 'D:\vivado\2025.2\Vivado\bin')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
Push-Location -LiteralPath $projectRoot
try {
    New-Item -ItemType Directory -Path 'output' -Force | Out-Null
    & (Join-Path $VivadoBin 'xvlog.bat') -sv rtl/clock_divider_top.v sim/tb_clock_divider.sv
    if ($LASTEXITCODE -ne 0) { throw 'Verilog compilation failed' }
    & (Join-Path $VivadoBin 'xelab.bat') work.tb_clock_divider -s tb_clock_divider_sim -debug typical
    if ($LASTEXITCODE -ne 0) { throw 'Simulation elaboration failed' }
    & (Join-Path $VivadoBin 'xsim.bat') tb_clock_divider_sim -runall -log functional_simulation.log
    if ($LASTEXITCODE -ne 0) { throw 'Simulation process failed' }
    $simLog = Get-Content -LiteralPath 'functional_simulation.log' -Raw
    if ($simLog -match 'Fatal:' -or $simLog -notmatch 'PASS: 10 MHz period=100 ns') {
        throw 'Simulation assertions did not pass; see functional_simulation.log'
    }
    Move-Item -LiteralPath 'simulation_edges.csv' -Destination 'output\simulation_edges.csv' -Force
} finally {
    Pop-Location
}
