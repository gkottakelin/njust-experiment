param(
    [string]$VivadoBin = 'D:\vivado\2025.2\Vivado\bin',
    [ValidateSet('all','integration','precision','frontend','production','robust','low_amplitude')][string]$Suite = 'all'
)
$ErrorActionPreference='Stop'
$projectRoot=Split-Path $PSScriptRoot -Parent
Push-Location -LiteralPath $projectRoot
try {
    $sourceFiles=@(Get-ChildItem -LiteralPath 'rtl' -Filter '*.v' | ForEach-Object FullName)
    $testFiles=@(Get-ChildItem -LiteralPath 'sim' -Filter '*.sv' | ForEach-Object FullName)
    & (Join-Path $VivadoBin 'xvlog.bat') -sv @sourceFiles @testFiles
    if($LASTEXITCODE -ne 0){throw 'Compilation failed'}
    $tests=@()
    if($Suite -eq 'all' -or $Suite -eq 'precision'){$tests+='tb_meter_precision'}
    if($Suite -eq 'all' -or $Suite -eq 'frontend'){$tests+='tb_frontend_display'}
    if($Suite -eq 'all' -or $Suite -eq 'integration'){$tests+='tb_integration'}
    if($Suite -eq 'production'){$tests+='tb_production'}
    if($Suite -eq 'all' -or $Suite -eq 'robust'){$tests+='tb_robust_crossing'}
    if($Suite -eq 'low_amplitude'){$tests+='tb_low_amplitude'}
    foreach($test in $tests){
        $snapshot="${test}_sim"
        $elaboration=@("work.$test",'-s',$snapshot,'-debug','typical')
        & (Join-Path $VivadoBin 'xelab.bat') @elaboration
        if($LASTEXITCODE -ne 0){throw "Elaboration failed: $test"}
        $log=if($Suite -eq 'production'){'output/tb_production.log'}else{"output/${test}.log"}
        & (Join-Path $VivadoBin 'xsim.bat') $snapshot -runall -log $log
        if($LASTEXITCODE -ne 0){throw "Simulation failed: $test"}
        $logText=Get-Content -LiteralPath $log -Raw
        if($logText -match 'Fatal:' -or $logText -notmatch 'PASS:'){throw "Assertion failed: $test"}
    }
    foreach($file in Get-ChildItem -LiteralPath '.' -Filter '*.csv' -File){
        Move-Item -LiteralPath $file.FullName -Destination (Join-Path 'output' $file.Name) -Force
    }
}finally{Pop-Location}
