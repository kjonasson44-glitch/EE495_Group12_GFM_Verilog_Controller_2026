onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -format Analog-Step -height 84 -max -32688.0 -min -32768.0 -radix decimal /srf_pll_tb/q_in
add wave -noupdate -format Analog-Step -height 84 -max 416896422.0 -min 416896342.0 -radix decimal /srf_pll_tb/freq_out
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 2} {0 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 292
configure wave -valuecolwidth 181
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits us
update
WaveRestoreZoom {0 ns} {110250105 ns}
