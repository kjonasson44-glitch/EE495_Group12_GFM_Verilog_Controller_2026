onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -format Analog-Step -height 84 -max 24575.999999999996 -min -24496.0 -radix decimal /volt_cont_tb/adc_in_a
add wave -noupdate -format Analog-Step -height 84 -max 24576.0 -radix decimal /volt_cont_tb/u_volt_ctrl/V_input
add wave -noupdate -radix decimal /volt_cont_tb/u_inverter/modulator/pwm_u
add wave -noupdate -format Analog-Step -height 84 -max 131070.99999999999 -min -131071.0 -radix decimal /volt_cont_tb/u_inverter/modulator/a_fin
add wave -noupdate -format Analog-Step -height 84 -max 16384.0 -min 8203.0 -radix decimal /volt_cont_tb/u_volt_ctrl/V_output
add wave -noupdate -format Analog-Step -height 84 -max 4089.9999999999995 -min -8365.0 -radix decimal /volt_cont_tb/u_volt_ctrl/integral_acc
add wave -noupdate -format Analog-Step -height 84 -max 8197.9999999999982 -min -16384.0 -radix decimal /volt_cont_tb/u_volt_ctrl/error
add wave -noupdate -format Analog-Step -height 84 -max 8180.9999999999982 -min -16707.0 -radix decimal /volt_cont_tb/u_volt_ctrl/pi_out
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 2} {442773238 ns} 0}
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
WaveRestoreZoom {0 ns} {645759723 ns}
