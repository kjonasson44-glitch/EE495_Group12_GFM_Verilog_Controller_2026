%% Closed-Loop PI Controller Response to Step and Ramp Voltage Changes
clear; clc; close all;

% 1. Define System Parameters
V_nominal_rms = 120;                  % Nominal RMS Voltage
V_ref = V_nominal_rms * sqrt(2);      % Reference Peak Voltage (~170 Volts)

% PI Controller Gains
Kp = 0.1;  % Proportional gain
Ki = 2;  % Integral gain

% Time vector setup
dt = 0.01;         % Simulation time step (seconds)
t = 0:dt:10;       % Simulate for 10 seconds
N = length(t);     % Number of samples

% 2. Scenario 1: Step Change
% Create the varying voltage input: starts at 170V, steps down to 140V at t=2s
V_step_input = V_ref * ones(1, N);
step_start = find(t >= 2, 1);
V_step_input(step_start:end) = 140; 

% Initialize variables for Closed-Loop
error_step = zeros(1, N);
pi_out_step = zeros(1, N);
V_out_step = zeros(1, N);
integral_acc = 0; 

% Initial Condition: Assume the system starts perfectly at the reference
V_out_step(1) = V_ref; 

% Run the Closed-Loop PI Controller
for k = 2:N
    % 1. Error = Input Voltage - Output of System (Negative Feedback)
    error_step(k) = V_step_input(k) - 170;
    
    % 2. Pass error through (Kp + Ki/s)
    integral_acc = integral_acc + (error_step(k) * dt);
    pi_out_step(k) = (Kp * error_step(k)) + (Ki * integral_acc);
    
    % 3. Add to Vreference (170V) to get final system output
    V_out_step(k) = pi_out_step(k) + V_ref;
end

% 3. Scenario 2: Ramp Up and Down
% Create the varying voltage input: starts at 170V, ramps to 190V, then back
V_ramp_input = V_ref * ones(1, N);

% Ramp up to 190V, then ramp back down
idx_up = (t >= 2 & t < 4);
V_ramp_input(idx_up) = V_ref + ((180 - V_ref) / 2) * (t(idx_up) - 2);
idx_down = (t >= 4 & t < 6);
V_ramp_input(idx_down) = 180 - ((180 - V_ref) / 2) * (t(idx_down) - 4);

% Initialize variables
error_ramp = zeros(1, N);
pi_out_ramp = zeros(1, N);
V_out_ramp = zeros(1, N);
integral_acc = 0; % Reset integral accumulator

% Initial Condition
V_out_ramp(1) = V_ref;

% Run the Closed-Loop PI Controller
for k = 2:N

    % 1. Error = Input Voltage - Output of System
    error_ramp(k) = V_ramp_input(k) - V_out_ramp(k-1); % Delayed output
    
    % 2. Pass error through (Kp + Ki/s)
    integral_acc = integral_acc + (error_ramp(k) * dt);
    pi_out_ramp(k) = (Kp * error_ramp(k)) + (Ki * integral_acc);
    
    % 3. Add to Vreference
    V_out_ramp(k) = pi_out_ramp(k) + V_ref;
end

% 4. Plotting the Results
figure('Name', 'Closed-Loop PI Response', 'Position', [100, 100, 1000, 700]);

% --- Step Change Plots ---
subplot(3, 2, 1);
plot(t, V_step_input, 'k--', 'LineWidth', 1.5); hold on;
plot(t, V_out_step, 'b', 'LineWidth', 1.5);
title('Tracking: Step Change');
ylabel('Voltage (V)');
legend('Target Input', 'System Output', 'Location', 'best');
grid on;

subplot(3, 2, 3);
plot(t, error_step, 'r', 'LineWidth', 1.5);
title('Error Signal (Input - Output)');
ylabel('Error (V)');
grid on;

subplot(3, 2, 5);
plot(t, (170 - pi_out_step), 'm', 'LineWidth', 1.5); % Subtract 170 from the output to get our actual amplitude 
title('170 - PI Controller Action (Kp*e + Ki*int(e))');
xlabel('Time (s)');
ylabel('Control Effort (V)');
grid on;

% --- Ramp Change Plots ---
subplot(3, 2, 2);
plot(t, V_ramp_input, 'k--', 'LineWidth', 1.5); hold on;
plot(t, V_out_ramp, 'b', 'LineWidth', 1.5);
title('Tracking: Ramp Up/Down');
ylabel('Voltage (V)');
legend('Target Input', 'System Output', 'Location', 'best');
grid on;

subplot(3, 2, 4);
plot(t, error_ramp, 'r', 'LineWidth', 1.5);
title('Error Signal (Input - Output)');
ylabel('Error (V)');
grid on;

subplot(3, 2, 6);
plot(t, (170 - pi_out_ramp)/204, 'm', 'LineWidth', 1.5);
title('170 - PI Controller Action (Kp*e + Ki*int(e))');
xlabel('Time (s)');
ylabel('Control Effort (V)');
grid on;

% Need a Vref that is actually VREF
% Need to change output scale  obviously 
% Need to add a scalar that can scale the difference properly

sgtitle('Closed-Loop Tracking Performance (System Output = PI Action + V_{ref})');

%% Closed-Loop PI Controller Response to Step, Ramp, and Sag/Swell Voltage Changes
clear; clc; close all;

% 1. Define System Parameters
V_nominal_rms = 120;                  % Nominal RMS Voltage
V_ref = V_nominal_rms * sqrt(2);      % Reference Peak Voltage (~169.7 Volts)

% PI Controller Gains
Kp = 0.1;  % Proportional gain
Ki = 2;  % Integral gain

% Time vector setup
dt = 0.01;         % Simulation time step (seconds)
t = 0:dt:10;       % Simulate for 10 seconds
N = length(t);     % Number of samples

% =========================================================================
% 2. Scenario 1: Step Change
% Starts at ~170V, steps down to 140V at t=2s
% =========================================================================
V_step_input = V_ref * ones(1, N);
step_start = find(t >= 2, 1);
V_step_input(step_start:end) = 140; 

error_step = zeros(1, N);
pi_out_step = zeros(1, N);
V_out_step = zeros(1, N);
integral_acc = 0; 
V_out_step(1) = V_ref; 

for k = 2:N
    error_step(k) = V_step_input(k) - V_out_step(k-1);
    integral_acc = integral_acc + (error_step(k) * dt);
    pi_out_step(k) = (Kp * error_step(k)) + (Ki * integral_acc);
    V_out_step(k) = pi_out_step(k) + V_ref;
end

% =========================================================================
% 3. Scenario 2: Ramp Up and Down
% Starts at ~170V, ramps to 180V, then back down to ~170V
% =========================================================================
V_ramp_input = V_ref * ones(1, N);
idx_up = (t >= 2 & t < 4);
V_ramp_input(idx_up) = V_ref + ((180 - V_ref) / 2) * (t(idx_up) - 2);
idx_down = (t >= 4 & t < 6);
V_ramp_input(idx_down) = 180 - ((180 - V_ref) / 2) * (t(idx_down) - 4);

error_ramp = zeros(1, N);
pi_out_ramp = zeros(1, N);
V_out_ramp = zeros(1, N);
integral_acc = 0; 
V_out_ramp(1) = V_ref;

for k = 2:N
    error_ramp(k) = V_ramp_input(k) - V_out_ramp(k-1); 
    integral_acc = integral_acc + (error_ramp(k) * dt);
    pi_out_ramp(k) = (Kp * error_ramp(k)) + (Ki * integral_acc);
    V_out_ramp(k) = pi_out_ramp(k) + V_ref;
end

% =========================================================================
% 4. Scenario 3: Voltage Sag and Swell (Lower and Higher)
% Starts at ~170V, sags to 130V, surges to 200V, returns to nominal
% =========================================================================
V_sag_swell_input = V_ref * ones(1, N);

% Sag down to 130V
idx_sag_down = (t >= 1 & t < 2);
V_sag_swell_input(idx_sag_down) = V_ref - (V_ref - 130) * (t(idx_sag_down) - 1);
% Hold Sag
idx_sag_hold = (t >= 2 & t < 4);
V_sag_swell_input(idx_sag_hold) = 130;
% Swell up to 200V (Ramping from 130 to 200 over 1 second)
idx_swell_up = (t >= 4 & t < 5);
V_sag_swell_input(idx_swell_up) = 130 + (200 - 130) * (t(idx_swell_up) - 4);
% Hold Swell
idx_swell_hold = (t >= 5 & t < 7);
V_sag_swell_input(idx_swell_hold) = 200;
% Return to nominal
idx_return = (t >= 7 & t < 8);
V_sag_swell_input(idx_return) = 200 - (200 - V_ref) * (t(idx_return) - 7);

error_ss = zeros(1, N);
pi_out_ss = zeros(1, N);
V_out_ss = zeros(1, N);
integral_acc = 0; 
V_out_ss(1) = V_ref;

for k = 2:N
    error_ss(k) = V_sag_swell_input(k) - V_out_ss(k-1); 
    integral_acc = integral_acc + (error_ss(k) * dt);
    pi_out_ss(k) = (Kp * error_ss(k)) + (Ki * integral_acc);
    V_out_ss(k) = pi_out_ss(k) + V_ref;
end

% =========================================================================
% 5. Plotting the Results
% =========================================================================
figure('Name', 'Closed-Loop PI Response', 'Position', [50, 100, 1400, 700]);

% --- Column 1: Step Change Plots ---
subplot(3, 3, 1);
plot(t, V_step_input, 'k--', 'LineWidth', 1.5); hold on;
plot(t, V_out_step, 'b', 'LineWidth', 1.5);
title('Tracking: Step Change');
ylabel('Voltage (V)');
legend('Target Input', 'System Output', 'Location', 'best');
grid on;

subplot(3, 3, 4);
plot(t, error_step, 'r', 'LineWidth', 1.5);
title('Error Signal');
ylabel('Error (V)');
grid on;

subplot(3, 3, 7);
plot(t, (170 - pi_out_step), 'm', 'LineWidth', 1.5);
title('Control Effort (170 - PI Action)');
xlabel('Time (s)');
ylabel('Effort (V)');
grid on;

% --- Column 2: Ramp Up/Down Plots ---
subplot(3, 3, 2);
plot(t, V_ramp_input, 'k--', 'LineWidth', 1.5); hold on;
plot(t, V_out_ramp, 'b', 'LineWidth', 1.5);
title('Tracking: Ramp Up/Down');
grid on;

subplot(3, 3, 5);
plot(t, error_ramp, 'r', 'LineWidth', 1.5);
title('Error Signal');
grid on;

subplot(3, 3, 8);
plot(t, (170 - pi_out_ramp), 'm', 'LineWidth', 1.5);
title('Control Effort (170 - PI Action)');
xlabel('Time (s)');
grid on;

% --- Column 3: Sag and Swell Plots ---
subplot(3, 3, 3);
plot(t, V_sag_swell_input, 'k--', 'LineWidth', 1.5); hold on;
plot(t, V_out_ss, 'b', 'LineWidth', 1.5);
title('Tracking: Sag and Swell');
grid on;

subplot(3, 3, 6);
plot(t, error_ss, 'r', 'LineWidth', 1.5);
title('Error Signal');
grid on;

subplot(3, 3, 9);
plot(t, (170 - pi_out_ss), 'm', 'LineWidth', 1.5);
title('Control Effort (170 - PI Action)');
xlabel('Time (s)');
grid on;

sgtitle('Closed-Loop Tracking Performance (System Output = PI Action + V_{ref})');

%{

module AmplitudeTracker (
    input wire clk,           // 25 MHz
    input wire rst_n,
    input wire signed [15:0] adc_in, 
    output reg [15:0] amplitude
);

    reg [15:0] abs_val;
    reg [19:0] decay_cnt;
    parameter DECAY_RATE = 20'd1000000; // Adjust for tracking speed

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            abs_val   <= 16'd0;
            amplitude <= 16'd0;
            decay_cnt <= 20'd0;
        end else begin
            // 1. Rectification (Absolute Value)
            abs_val <= (adc_in[15]) ? -adc_in : adc_in;

            // 2. Peak Capture
            if (abs_val > amplitude) begin
                amplitude <= abs_val;
                decay_cnt <= 20'd0; // Reset decay timer on new peak
            end 
            // 3. Slow Decay (allows tracking when amplitude drops)
            else begin
                if (decay_cnt >= DECAY_RATE) begin
                    if (amplitude > 0) amplitude <= amplitude - 1'b1;
                    decay_cnt <= 20'd0;
                end else begin
                    decay_cnt <= decay_cnt + 1'b1;
                end
            end
        end
    end
endmodule
%}

%% Plot
% --- Set default plotting properties for consistent quality ---
% This ensures large, clear fonts throughout the figure without setting them for each element.
set(groot, 'DefaultAxesFontSize', 14);     % Base font size for all axes elements
set(groot, 'DefaultTextInterpreter', 'tex'); % Allow simple LaTeX-like formatting (\mu, ^2, etc.)
set(groot, 'DefaultLegendInterpreter', 'tex');
set(groot, 'DefaultLineLineWidth', 2);     % Thicker lines by default for better visibility
set(groot, 'DefaultFigureColor', 'w');      % White figure background (crucial for slides)

% --- Create the Enhanced Figure ---
figure('Name', 'Closed-Loop PI Response', ...
       'Position', [100, 100, 1000, 700], ... % Larger, prominent figure size
       'Renderer', 'painters');            % High-quality vector rendering (good for zooming)

% --- Generate the Main Plot ---
% Use thicker lines and slightly different color/style combination for excellent contrast.
plot(t, V_ramp_input, 'Color', [0.2 0.2 0.2], ... % Very dark gray (looks cleaner than pure black)
                      'LineStyle', '--', ...
                      'LineWidth', 4.0);         % Significantly thicker line
hold on;
plot(t, (170 - pi_out_ramp), 'Color', [0 0.4470 0.7410], ... % Standard MATLAB vibrant blue (very distinct)
                             'LineStyle', '-', ...
                             'LineWidth', 4.0);

% --- Customize Axes and Labels ---
title('\bfTracking Performance: Step Change and PI Control', ... % Bolder title, more descriptive
      'FontSize',40, 'Interpreter', 'tex'); % Larger title font
ylabel('\bfVoltage (V)', 'FontSize', 20);    % Bold label, distinct from tick marks
xlabel('\bfTime (s)', 'FontSize', 20);        % Bold label, distinct from tick marks

% Make the overall axes box look cleaner and bolder
ax = gca; % Get current axes
ax.Box = 'off'; % Removes the outer box, making the plot less "boxed-in"
ax.LineWidth = 1.5; % Thicker axes lines
ax.TickDir = 'out'; % Makes ticks point outwards for better visibility
ax.FontWeight = 'bold'; % Make the numbers on the axis bold

% Customize the grid (subtle but present)
grid on;
ax.GridLineStyle = '-';
ax.GridColor = [0.8 0.8 0.8]; % Light gray grid lines (won't distract from data)
ax.GridAlpha = 0.5;          % Make the grid semi-transparent

% --- Add an Impactful Legend ---
% A bold, distinct legend helps the audience instantly identify the lines.
[hl, h_obj] = legend('\bfPotential Input (Target)', ...
                      '\bfFilter Output (Controlled)', ... % Bold legend text, clearer names
                      'FontSize', 14, ...
                      'Box', 'on', 'EdgeColor', [0.5 0.5 0.5], 'LineWidth', 1); % Optional box for legend emphasis

% (Optional) Further customize specific legend elements if needed (e.g., thicker legend lines)
% for i = 1:length(h_obj)
%     if strcmp(h_obj(i).Type, 'line')
%         h_obj(i).LineWidth = 3; % Make the legend lines even thicker than the plot lines
%     end
% end

hold off;

%% CSV files for amplitude testbench
N = 2048;               % Larger buffer to allow time for ramping
bits = 16;              % 16-bit signed
max_val = 2^(bits-1)-1; % 32767

% Physical Parameters
fs = 720;               % Sampling rate (Hz)
f_grid = 60;            % Grid frequency (Hz)

% Time/Phase calculation
n = (0:N-1)';           
theta_fixed = 2*pi * (f_grid / fs) * n; 

% Create the Amplitude Envelope
% Buffer is 2048 samples. 
% 1-512: Hold 16384
% 513-1024: Ramp 16384 -> 24576
% 1025-1536: Ramp 24576 -> 16384
% 1537-2048: Hold 16384
envelope = zeros(N, 1);
envelope(1:256) = 0;
envelope(257:512) = 16384;
envelope(513:1024) = linspace(16384, 24576, 512);
compile_down = linspace(24576, 16384, 512);
envelope(1025:1536) = compile_down;
envelope(1537:end) = 16384;

% 1. Three-Phase Sinusoids with Modulated Amplitude
sig_A = envelope .* sin(theta_fixed);
sig_B = envelope .* sin(theta_fixed - 2*pi/3);
sig_C = envelope .* sin(theta_fixed - 4*pi/3);

% 2. Export to Hex
signals = {sig_A, sig_B, sig_C};
filenames = {'phase_a_zero.hex', 'phase_b_zero.hex', 'phase_c_zero.hex'};

for i = 1:length(signals)
    data = round(signals{i});
    
    % Clamp logic to prevent overflow wrapping
    data = max(min(data, max_val), -2^(bits-1));
    
    % Convert to 16-bit hex (4 digits), using 2s complement for negatives
    hex_vals = dec2hex(mod(data, 2^bits), 4);
    
    fid = fopen(filenames{i}, 'w');
    for row = 1:N
        fprintf(fid, '%s\n', hex_vals(row, :));
    end
    fclose(fid);
end

fprintf('Files generated. 60Hz sampled at 720Hz with amplitude envelope.\n');
