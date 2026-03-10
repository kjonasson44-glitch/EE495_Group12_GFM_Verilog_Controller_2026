onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -format Analog-Step -height 84 -max 357914000.0 -min 351733000.0 -radix decimal /dqz_to_pwm_tb/dut/freq_out
add wave -noupdate -format Analog-Step -height 84 -max 10307.0 -min 10129.0 -radix decimal /dqz_to_pwm_tb/inst_inverter_top/freq_in
add wave -noupdate -format Analog-Step -height 84 -max 20412.999999999996 -min -16113.0 -radix decimal /dqz_to_pwm_tb/q_out
add wave -noupdate -radix decimal /dqz_to_pwm_tb/inst_inverter_top/modulator/carrier_fcw
add wave -noupdate -format Analog-Step -height 84 -max 131068.0 -min -131068.0 -radix decimal /dqz_to_pwm_tb/dqz_inst/cosine
add wave -noupdate -radix binary /dqz_to_pwm_tb/inst_inverter_top/pwm_u
add wave -noupdate -format Analog-Step -height 84 -max 32767.0 -min -32767.0 -radix decimal /dqz_to_pwm_tb/dqz_inst/a_in
add wave -noupdate -format Analog-Step -height 84 -max 131070.99999999999 -min -131071.0 -radix decimal /dqz_to_pwm_tb/inst_inverter_top/modulator/a_out
add wave -noupdate -radix decimal /dqz_to_pwm_tb/inst_inverter_top/modulator/pwm_v
add wave -noupdate -format Analog-Step -height 84 -max 32767.0 -min -32767.0 -radix decimal /dqz_to_pwm_tb/dqz_inst/b_in
add wave -noupdate -format Analog-Step -height 84 -max 131070.99999999999 -min -131071.0 -radix decimal /dqz_to_pwm_tb/inst_inverter_top/modulator/b_out
add wave -noupdate -radix decimal /dqz_to_pwm_tb/inst_inverter_top/modulator/pwm_w
add wave -noupdate -format Analog-Step -height 84 -max 32767.0 -min -32767.0 -radix decimal /dqz_to_pwm_tb/dqz_inst/c_in
add wave -noupdate -format Analog-Step -height 84 -max 131070.99999999999 -min -131071.0 -radix decimal /dqz_to_pwm_tb/inst_inverter_top/modulator/c_out
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 2} {8680565 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 361
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
WaveRestoreZoom {0 ns} {100452218 ns}
