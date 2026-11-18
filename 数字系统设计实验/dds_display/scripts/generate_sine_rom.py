"""Generate a self-contained synthesizable 256 x 8 unsigned sine ROM."""
from pathlib import Path
from math import sin, pi, floor

destination = Path(__file__).resolve().parents[1] / 'rtl' / 'sine_rom.v'
lines = ['`timescale 1ns / 1ps', '',
         '// Unsigned offset binary. End points: 128, 255, 128, 0.',
         'module sine_rom (input wire [7:0] phase, output wire [7:0] sample);',
         '    (* rom_style = "distributed" *) reg [7:0] sine_lut [0:255];',
         '    initial begin']
for phase in range(256):
    value = floor(127.5 + 127.5 * sin(2 * pi * phase / 256) + 0.5)
    lines.append(f"        sine_lut[{phase}] = 8'd{value};")
lines += ['    end', '    assign sample = sine_lut[phase];', 'endmodule', '']
destination.write_text('\n'.join(lines), encoding='ascii')
