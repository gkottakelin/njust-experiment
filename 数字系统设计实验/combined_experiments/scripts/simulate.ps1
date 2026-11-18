param(
    [string]$VivadoBin='D:\vivado\2025.2\Vivado\bin',
    [ValidateSet('all','integration','precision','interpolation','signal_path','waveform_meter','waveforms')][string]$Suite='all',
    [switch]$SkipCompilation
)
$ErrorActionPreference='Stop'
$projectRoot=Split-Path $PSScriptRoot -Parent
Push-Location -LiteralPath $projectRoot
try {
    $sourceFiles=@(Get-ChildItem -LiteralPath 'rtl' -Filter '*.v' | ForEach-Object FullName)
    $testFiles=@(Get-ChildItem -LiteralPath 'sim' -Filter '*.sv' | ForEach-Object FullName)
    if(-not $SkipCompilation){
        & (Join-Path $VivadoBin 'xvlog.bat') -sv @sourceFiles @testFiles
        if($LASTEXITCODE -ne 0){throw 'Compilation failed'}
    }
    $tests=@()
    if($Suite -in @('all','precision')){$tests+='tb_meter_precision'}
    if($Suite -in @('all','interpolation')){$tests+='tb_interpolation'}
    if($Suite -in @('all','integration')){$tests+='tb_combined'}
    if($Suite -in @('all','signal_path')){$tests+='tb_signal_path'}
    if($Suite -in @('all','waveform_meter')){$tests+='tb_waveform_meter'}
    if($Suite -in @('all','waveforms')){$tests+='tb_waveform_translation'}
    foreach($test in $tests){
        & (Join-Path $VivadoBin 'xelab.bat') "work.$test" -s "${test}_sim" -debug typical
        if($LASTEXITCODE -ne 0){throw "Elaboration failed: $test"}
        $log="output/${test}.log"
        & (Join-Path $VivadoBin 'xsim.bat') "${test}_sim" -runall -log $log
        if($LASTEXITCODE -ne 0){throw "Simulation failed: $test"}
        $txt=Get-Content -LiteralPath $log -Raw
        if($txt -match 'Fatal:' -or $txt -notmatch 'PASS:'){throw "Assertion failed: $test"}
    }
    $patterns=@()
    if($tests -contains 'tb_meter_precision'){$patterns+='meter_precision.csv'}
    if($tests -contains 'tb_combined'){$patterns+='combined_case_*.csv'}
    if($tests -contains 'tb_signal_path'){$patterns+='signal_path_case_*.csv'}
    if($tests -contains 'tb_waveform_meter'){$patterns+='waveform_meter.csv'}
    if($tests -contains 'tb_waveform_translation'){$patterns+=@('waveform_cases.csv','waveform_input_*.csv','waveform_output_*.csv')}
    foreach($pattern in $patterns){Get-ChildItem -LiteralPath '.' -Filter $pattern -File | ForEach-Object {
        Move-Item -LiteralPath $_.FullName -Destination (Join-Path 'output' $_.Name) -Force
    }}
}finally{Pop-Location}
