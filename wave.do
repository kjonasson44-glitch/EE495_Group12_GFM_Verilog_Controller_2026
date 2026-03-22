onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -format Analog-Step -height 84 -max 131070.99999999999 -min -131071.0 -radix decimal /dqz_to_pwm_tb/dqz_inst/cosine
add wave -noupdate -format Analog-Step -height 84 -max 32767.0 -min -32767.0 -radix decimal /dqz_to_pwm_tb/dqz_inst/a_in
add wave -noupdate -format Analog-Step -height 84 -max 357913941.0 -min 355967139.0 -radix decimal /dqz_to_pwm_tb/dqz_inst/freq_in
add wave -noupdate -format Analog-Step -height 84 -max 2147445894.0000002 -min -1810561835.0 -radix decimal /dqz_to_pwm_tb/dqz_inst/phase_acc_dqz
add wave -noupdate -format Analog-Step -height 84 -max 2147445894.0000002 -min -1810561835.0 -radix decimal /dqz_to_pwm_tb/inst_inverter_top/phase_acc_dqz
add wave -noupdate -format Analog-Step -height 84 -max 10307.0 -min 10251.0 -radix decimal /dqz_to_pwm_tb/inst_inverter_top/freq_in
add wave -noupdate -format Analog-Step -height 84 -max -22309.000000000004 -min -131071.0 -radix decimal /dqz_to_pwm_tb/inst_inverter_top/modulator/a_out
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 2} {190532 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 355
configure wave -valuecolwidth 244
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
WaveRestoreZoom {0 ns} {15206828 ns}
