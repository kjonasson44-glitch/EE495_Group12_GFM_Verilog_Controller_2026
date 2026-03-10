%{
%% Parameters
N = 1024;               % Total samples
bits = 18;              % 18-bit signed
max_val = 2^(bits-1)-1; % 131071 (Full scale)
n = 1;                  % Frequency multiplier for the ramp functions

% Time/Phase vectors
t = 0:N-1;
theta_3phase = (2*pi*t)/N;   % Full circle for 3-phase
theta_ramp = linspace(0, pi, N); % Linear ramp from 0 to pi

%% 1. Three-Phase Sinusoids (2pi/3 separation)
sig_A = max_val * sin(theta_3phase);
sig_B = max_val * sin(theta_3phase - 2*pi/3);
sig_C = max_val * sin(theta_3phase - 4*pi/3);

%% 2. Sine and Cosine of Ramping Theta (0 to pi)
% This calculates sin(n*theta) and cos(n*theta) directly
sig_sine_ramp = max_val * sin(n * theta_ramp);
sig_cos_ramp  = max_val * cos(n * theta_ramp);

%% 3. Quantization and Hex File Export
signals = {sig_A, sig_B, sig_C, sig_sine_ramp, sig_cos_ramp};
filenames = {'phase_a.hex', 'phase_b.hex', 'phase_c.hex', 'sine_ramp.hex', 'cosine_ramp.hex'};

for i = 1:length(signals)
    % Quantize to signed integers
    data = round(signals{i});
    
    % Clamp to avoid overflow
    data(data > max_val) = max_val;
    data(data < -2^(bits-1)) = -2^(bits-1);
    
    % Convert to 18-bit two's complement hex (5 hex digits)
    % mod(data, 2^18) handles the negative number mapping for hex conversion
    hex_vals = dec2hex(mod(data, 2^bits), 5);
    
    % Write to file
    fid = fopen(filenames{i}, 'w');
    for row = 1:N
        fprintf(fid, '%s\n', hex_vals(row, :));
    end
    fclose(fid);
end

fprintf('Generated 5 files: %s\n', strjoin(filenames, ', '));
%}



%{
%% Parameters
N = 1024;               
bits = 18;              
max_val = 2^(bits-1)-1; 

t = (0:N-1)';           % Time index (column vector)
fs = 1;                 % Normalized sampling frequency

%% 1. Three-Phase Sinusoids (Fixed Frequency)
f_fixed = 1/N;          % 1 cycle per buffer
theta_fixed = 2*pi * f_fixed * t;
sig_A = max_val * sin(theta_fixed);
sig_B = max_val * sin(theta_fixed - 2*pi/3);
sig_C = max_val * sin(theta_fixed - 4*pi/3);

%% 2. Sine and Cosine with Ramping Frequency (Chirp)
% To ramp frequency from f_start to f_end:
% phase(t) = 2*pi * (f_start*t + (k/2)*t^2) where k is the sweep rate
f_start = 0; 
f_end = 0.5; % This goes up to the Nyquist frequency (pi radians/sample)

% Quadratic phase formula for linear frequency ramp
theta_chirp = 2*pi * (f_start*t + ((f_end - f_start)/(2*N)) * t.^2);

sig_sine_ramp = max_val * sin(theta_chirp);
sig_cos_ramp  = max_val * cos(theta_chirp);

%% 3. Export to Hex (Same logic as before)
signals = {sig_A, sig_B, sig_C, sig_sine_ramp, sig_cos_ramp};
filenames = {'phase_a.hex', 'phase_b.hex', 'phase_c.hex', 'sine_ramp.hex', 'cosine_ramp.hex'};

for i = 1:length(signals)
    data = round(signals{i});
    data = max(min(data, max_val), -2^(bits-1)); % Clamp
    
    hex_vals = dec2hex(mod(data, 2^bits), 5);
    
    fid = fopen(filenames{i}, 'w');
    for row = 1:N
        fprintf(fid, '%s\n', hex_vals(row, :));
    end
    fclose(fid);
end

% Plotting for verification
subplot(2,1,1); plot(sig_A); title('3-Phase (Fixed Freq)');
subplot(2,1,2); plot(sig_sine_ramp); title('Chirp (Ramping Freq)');
%}


%{
%% Parameters TESTING THETA_PLL = THETA_GRID (y_out should be constant
% also y out should be 0 if it's q)
N = 1024;               
bits = 16;              
max_val = 2^(bits-1)-1; 

t = (0:N-1)';           % Time index (column vector)
fs = 1;                 % Normalized sampling frequency

%% 1. Three-Phase Sinusoids (Fixed Frequency)
f_fixed = 1/N;          % 1 cycle per buffer
theta_fixed = 2*pi * f_fixed * t;
sig_A = max_val * sin(theta_fixed);
sig_B = max_val * sin(theta_fixed - 2*pi/3);
sig_C = max_val * sin(theta_fixed - 4*pi/3);

%% 2. Sine and Cosine with Ramping Frequency (Chirp)
% To ramp frequency from f_start to f_end:
% phase(t) = 2*pi * (f_start*t + (k/2)*t^2) where k is the sweep rate
f_start = 0; 
f_end = 0.5; % This goes up to the Nyquist frequency (pi radians/sample)

% Quadratic phase formula for linear frequency ramp
theta_chirp = 2*pi * (f_start*t + ((f_end - f_start)/(2*N)) * t.^2);

sig_sine_ramp = max_val * sin(theta_fixed);
sig_cos_ramp  = max_val * cos(theta_fixed);

%% 3. Export to Hex (Same logic as before)
signals = {sig_A, sig_B, sig_C, sig_sine_ramp, sig_cos_ramp};
filenames = {'phase_a.hex', 'phase_b.hex', 'phase_c.hex', 'sine_ramp.hex', 'cosine_ramp.hex'};

for i = 1:length(signals)
    data = round(signals{i});
    data = max(min(data, max_val), -2^(bits-1)); % Clamp
    
    hex_vals = dec2hex(mod(data, 2^bits), 4);
    
    fid = fopen(filenames{i}, 'w');
    for row = 1:N
        fprintf(fid, '%s\n', hex_vals(row, :));
    end
    fclose(fid);
end

% Plotting for verification
subplot(2,1,1); plot(sig_A); title('3-Phase (Fixed Freq)');
subplot(2,1,2); plot(sig_sine_ramp); title('Chirp (Ramping Freq)');

%% EXPORT 2 
% signals = {sig_sine_ramp, sig_cos_ramp};
% filenames = {'sine_ramp.hex', 'cosine_ramp.hex'};
% 
% for i = 1:length(signals)
%     data = round(signals{i});
%     data = max(min(data, max_val), -2^(17)); % Clamp
% 
%     hex_vals = dec2hex(mod(data, 2^bits), 5);
% 
%     fid = fopen(filenames{i}, 'w');
%     for row = 1:N
%         fprintf(fid, '%s\n', hex_vals(row, :));
%     end
%     fclose(fid);
% end
% 
% subplot(2,1,2); plot(sig_sine_ramp); title('Chirp (Ramping Freq)');
%}

%% Parameters TESTING HOOKUP BETWEEN NCO AND DQZ (fcw = 60hz, Va_f = 60hz, Va_samp_rate = 720 Hz)
% q should be constantish, hopefully close to 0 if there is little phase
% offset between sampling and delay for nco or something
% Target: 60 Hz Grid Frequency sampled at 720 Hz
% Ratio: 60 / 720 = 1/12 (The wave repeats every 12 samples)

N = 512;               % Buffer size
bits = 16;              % 16-bit signed
max_val = 2^(bits-1)-1; % 32767

% Physical Parameters
fs = 720;               % Sampling rate (Hz)
f_grid = 60;            % Grid frequency (Hz)

% Time/Phase calculation
n = (0:N-1)';           % Sample index
% Phase increment per sample = 2*pi * (f_grid / fs)
theta_fixed = 2*pi * (f_grid / fs) * n; 

%% 1. Three-Phase Sinusoids (Fixed 60Hz)
% Note: These will repeat exactly every 12 samples.
sig_A = max_val * sin(theta_fixed);
sig_B = max_val * sin(theta_fixed - 2*pi/3);
sig_C = max_val * sin(theta_fixed - 4*pi/3);

%% 2. DQ Frame Reference (NCO Emulation)
% For the test to work (Output D=constant, Q=0), the NCO must 
% generate sine/cosine matching the input frequency exactly.
sig_sine_ref = max_val * sin(theta_fixed);
sig_cos_ref  = max_val * cos(theta_fixed);

%% 3. Export to Hex
% We output the Reference Sine/Cos into the 'ramp' files 
% so the testbench uses fixed frequency for everything.
signals = {sig_A, sig_B, sig_C, sig_sine_ref, sig_cos_ref};
filenames = {'phase_a.hex', 'phase_b.hex', 'phase_c.hex', 'sine_ramp.hex', 'cosine_ramp.hex'};

for i = 1:length(signals)
    data = round(signals{i});
    
    % Clamp logic to prevent overflow wrapping
    data = max(min(data, max_val), -2^(bits-1));
    
    % Convert to 16-bit hex (4 digits)
    hex_vals = dec2hex(mod(data, 2^bits), 4);
    
    fid = fopen(filenames{i}, 'w');
    for row = 1:N
        fprintf(fid, '%s\n', hex_vals(row, :));
    end
    fclose(fid);
end

fprintf('Files generated. Signal is 60Hz sampled at 720Hz (12 samples/cycle).\n');

%% 4. Calculate Verilog FCW for you
% The NCO accumulator is 32-bit.
% It needs to overflow at the same rate the phase advances.
% Phase step per sample = 1/12 of a circle.
fcw_val = (2^32) * (f_grid / fs);
fprintf('Verilog FCW (theta) should be set to: %10.0f\n', fcw_val);

% Plotting for verification
figure;
subplot(2,1,1); 
plot(sig_A(1:48)); % Plot just 4 cycles (48 samples)
title('Phase A (First 4 cycles)');
grid on;

subplot(2,1,2); 
plot(sig_sine_ref(1:48)); 
title('Reference Sine (Matches Phase A)');
grid on;







%{
Now we wanna do some step up step down stuff 
%}


%{
Now we wanna do some ramp up ramp down stuff 
%}


%{
Now we wanna simulate what the frequency actually looks like in a grid
*as it responds to a disturbance. 

1. The grid frequency oscillates around the nominal freq of 60 Hz
2. When a disturbance happens, first the inertial/primary response is observed
meaning that the frequency drops fairly rapidly (we can just assume
linearly for now)
This drop will at max fall to only about 1 hz below the normal frequency
the pit of this drop is called the nadir, and occurs at around 5 seconds
after the incident
3. Following the inertial response is the primary response, which lasts 
around 20 seconds
During the primary response, the frequency curves back upwards, not to 
the full nominal frequency, but about half way up from the nadir. 
The primary response is not linear, but we can model it as a ramp up to a
flat plane after about halfway through the primary response, so at about 10
seconds through. Meaning it reaches this plane at about halfway through the
primary response




4. Finally the secondary response, which lasts several minutes, which could
be modeled similarly to the primary, but on the order of minutes. We are
not going to model the secondary response however, as it is too slow for 
modelsim, and would take too long to run. 

%}

%% 5. Frequency Step Simulation
% Jump from 60Hz to 58Hz at N/150
clear;
N = 3001;               % Buffer size
bits = 16;              % 16-bit signed
max_val = 2^(bits-1)-1; % 32767

% Physical Parameters
fs = 720;               % Sampling rate (Hz)
f_grid = 60;            % Grid frequency (Hz)

% Time/Phase calculation
n = (0:N-1)';           % Sample index
% Phase increment per sample = 2*pi * (f_grid / fs)
theta_fixed = 2*pi * (f_grid / fs) * n; 
f_step = ones(N, 1) * 60;
f_step(N/150:end) = 59.5; 
phase_step = zeros(N, 1);
for n = 2:N
    phase_step(n) = phase_step(n-1) + 2*pi * (f_step(n)/fs);
end
sig_A_step = max_val * sin(phase_step);

%% 6. Frequency Ramp Simulation
% Linear ramp from 60Hz to 62Hz over the whole buffer
f_ramp = linspace(60, 62, N)';
phase_ramp = zeros(N, 1);
for n = 2:N
    phase_ramp(n) = phase_ramp(n-1) + 2*pi * (f_ramp(n)/fs);
end
sig_A_ramp = max_val * sin(phase_ramp);

%% 7. Grid Disturbance Simulation (Frequency Event)
% Model: 60Hz -> Nadir (59Hz) -> Settling (59.5Hz)
% Note: Your N=1024 at 720Hz is only ~1.4 seconds of data.
% To see a 20s response, you'd need N=14,400. 
% I will scale the timing down so the event fits in your N=1024 buffer.

clear;
N = 2048;               % Buffer size
bits = 16;              % 16-bit signed
max_val = 2^(bits-1)-1; % 32767

% Physical Parameters
fs = 720;               % Sampling rate (Hz)
f_grid = 60;            % Grid frequency (Hz)

% Time/Phase calculation
n = (0:N-1)';           % Sample index

t = (0:N-1)'/fs; 
f_grid_sim = ones(N, 1) * 60;

% Scaling the 20s event to fit in ~1.4s for ModelSim visibility
idx_start = round(0.1 * N);
idx_nadir = round(0.2 * N);
idx_settle = round(0.8 * N);

% 1. Inertial Drop (60 -> 59 Hz)
f_grid_sim(idx_start:idx_nadir) = linspace(60, 59, idx_nadir - idx_start + 1);
% 2. Primary Response (59 -> 59.5 Hz)
f_grid_sim(idx_nadir:idx_settle) = linspace(59.5, 59.75, idx_settle - idx_nadir + 1);
% 3. Post-Disturbance Plane
f_grid_sim(idx_settle:end) = 59.75;

phase_grid = zeros(N, 1);
for n = 2:N
    phase_grid(n) = phase_grid(n-1) + 2*pi * (f_grid_sim(n)/fs);
end
sig_A_grid = max_val * sin(phase_grid);

%% 8. Export Dynamic Files
% Let's export the Grid Disturbance signals specifically
dyn_signals = {sig_A_step, max_val*sin(phase_step - 2*pi/3), max_val*sin(phase_step - 4*pi/3)};
dyn_filenames = {'grid_a.hex', 'grid_b.hex', 'grid_c.hex'};

for i = 1:length(dyn_signals)
    data = round(dyn_signals{i});
    data = max(min(data, max_val), -2^(bits-1));
    hex_vals = dec2hex(mod(data, 2^bits), 4);
    fid = fopen(dyn_filenames{i}, 'w');
    for row = 1:N
        fprintf(fid, '%s\n', hex_vals(row, :));
    end
    fclose(fid);
end

%% Plotting Dynamic Responses
figure;
subplot(3,1,1);
plot(t, f_grid_sim);
title('Frequency Profile (Hz) - Grid Disturbance');
ylabel('Hz'); grid on;

subplot(3,1,2);
plot(t, sig_A_grid);
title('Resulting Phase A Signal');
grid on;

subplot(3,1,3);
% Plotting the 'beat' or phase error against a fixed 60Hz ref to see the shift
plot(t, sig_A_grid - sig_A); 
title('Phase Deviation from Nominal 60Hz');
xlabel('Time (s)'); grid on;

fprintf('Dynamic hex files (grid_a,b,c.hex) generated.\n');

%% 9. Export Frequency Reference
% We need to convert the frequency profile (Hz) into the 32-bit FCW 
% that the Verilog NCO expects to see.
% Formula: FCW = (f_sim / f_clk) * 2^32
% Note: Use your system clock (25MHz), not the sample rate.
f_system_clk = 720; 
fcw_ref = (f_grid_sim ./ f_system_clk) .* (2^32);

fid = fopen('freq_ref.hex', 'w');
for row = 1:N
    % Convert to 32-bit hex
    val = round(fcw_ref(row));
    hex_val = dec2hex(val, 8); % 8 digits for 32-bit
    fprintf(fid, '%s\n', hex_val);
end
fclose(fid);
fprintf('freq_ref.hex generated for unit-matching verification.\n');


%% 10. Hardware Verification Plot (with Smoothing)
% Load the hardware data
t = (0:N-1)'/fs; 
fid = fopen('IPLL_B0_58235_STEP.txt', 'r');
fid2 = fopen('MATH_IPLL_J_0125_I_04.txt', 'r');
% Seems like J does nothing
if (fid ~= -1) && (fid2 ~= -1)
    hw_hex = textscan(fid, '%s');
    fclose(fid);

    hw_hex2 = textscan(fid2, '%s');
    fclose(fid2);
    
    % Convert Hex strings to Decimal
    hw_fcw = uint32(hex2dec(hw_hex{1}));
    hw_fcw2 = uint32(hex2dec(hw_hex2{1}));

    % Convert FCW back to Hz for the plot
    % Note: Use the frequency the NCO thinks it is clocked at (720 Hz)
    f_hw_raw = (double(hw_fcw) * 720) / (2^32);
    f_hw_raw2 = (double(hw_fcw2) * 720) / (2^32);

    % --- SMOOTHING LOGIC ---
    % Average over 12 samples (one full 60Hz cycle at 720Hz sampling)
    window_size = 12; 
    f_hw = movmean(f_hw_raw, window_size);
    f_hw2 = movmean(f_hw_raw2, window_size);
    % -----------------------

    % Determine the shortest length to avoid "index out of bounds"
    len_to_plot = min([length(t), length(f_hw), length(f_hw2), 400]);
    
    figure;
    subplot(2,1,1);
    
    % Use the shortest available data length
    len = min([length(t), length(f_hw), length(f_hw2), 900]);
    
    % Plot the lines
    plot(t(1:len), f_step(1:len), 'k--', 'LineWidth', 1.5); hold on;
    plot(t(1:len), f_hw(1:len), 'r', 'LineWidth', 1.2);
    plot(t(1:len), f_hw2(1:len), 'g', 'LineWidth', 1.2);
    
    % --- AXIS TUNING ---
    % Set Y-Axis to 0.1 Hz increments
    % We'll zoom from 58.5 to 60.5 to see the disturbance clearly
    y_min = 58; y_max = 60;
    ylim([y_min y_max]);
    set(gca, 'YTick', y_min:0.1:y_max); 
    
    % Set X-Axis to 5 second increments
    % Note: If your simulation is only 1.4s long, this might only show 0 and 5.
    % If you want finer detail for a short sim, change 5 to 0.2 or 0.5.
    x_max = t(len);
    set(gca, 'XTick', 0:5:x_max); 
    
    title('IPLL Frequency Tracking Comparison');
    legend('Reference', 'B0 58235', 'Math IPLL', 'J -60000');
    ylabel('Frequency (Hz)'); 
    grid on;
    grid minor; % Adds smaller lines for better visibility
    
    % Calculate Error
    subplot(2,1,2);
    error = f_grid_sim(1:len) - f_hw(1:len);
    plot(t(1:len), error, 'b');
    
    % Apply same X-axis scaling to the error plot
    set(gca, 'XTick', 0:5:x_max);
    ylim([-0.5 0.5]); % Zoom in on error
    set(gca, 'YTick', -0.5:0.1:0.5);
    
    title('Tracking Error (Hz)');
    ylabel('Error (Hz)'); xlabel('Time (s)');
    grid on;
else
    disp('Hardware output file not found. Run the simulation first.');
end

%% 10. Hardware Verification Plot (with Smoothing)
% Load the hardware data
t = (0:N-1)'/fs; 
fid = fopen('MATH_IPLL_J_0125_I_04.txt', 'r');

if (fid ~= -1)
    hw_hex = textscan(fid, '%s');
    fclose(fid);

    
    % Convert Hex strings to Decimal
    hw_fcw = uint32(hex2dec(hw_hex{1}));


    % Convert FCW back to Hz for the plot
    % Note: Use the frequency the NCO thinks it is clocked at (720 Hz)
    f_hw_raw = (double(hw_fcw) * 720) / (2^32);

    % --- SMOOTHING LOGIC ---
    % Average over 12 samples (one full 60Hz cycle at 720Hz sampling)
    window_size = 12; 
    f_hw = movmean(f_hw_raw, window_size);
    % -----------------------

    % Determine the shortest length to avoid "index out of bounds"
    len_to_plot = min([length(t), length(f_hw), 900]);
    
    figure;
    subplot(2,1,1);
    
    % Use the shortest available data length
    len = min([length(t), length(f_hw), 900]);
    
    % Plot the lines
    plot(t(1:len), f_step(1:len), 'k--', 'LineWidth', 1.5); hold on;
    plot(t(1:len), f_hw(1:len), 'r', 'LineWidth', 1.2);

    % --- AXIS TUNING ---
    % Set Y-Axis to 0.1 Hz increments
    % We'll zoom from 58.5 to 60.5 to see the disturbance clearly
    y_min = 59.5; y_max = 60;
    ylim([y_min y_max]);
    set(gca, 'YTick', y_min:0.1:y_max); 
    
    % Set X-Axis to 5 second increments
    % Note: If your simulation is only 1.4s long, this might only show 0 and 5.
    % If you want finer detail for a short sim, change 5 to 0.2 or 0.5.
    x_max = t(len);
    set(gca, 'XTick', 0:5:x_max); 
    
    title('IPLL Frequency Tracking Comparison');
    legend('Reference', 'Normal Type 1 SRF PLL');
    ylabel('Frequency (Hz)'); 
    grid on;
    grid minor; % Adds smaller lines for better visibility
    
    % Calculate Error
    subplot(2,1,2);
    error = f_grid_sim(1:len) - f_hw(1:len);
    plot(t(1:len), error, 'b');
    
    % Apply same X-axis scaling to the error plot
    set(gca, 'XTick', 0:5:x_max);
    ylim([-0.5 0.5]); % Zoom in on error
    set(gca, 'YTick', -0.5:0.1:0.5);
    
    title('Tracking Error (Hz)');
    ylabel('Error (Hz)'); xlabel('Time (s)');
    grid on;
else
    disp('Hardware output file not found. Run the simulation first.');
end


%% 10. Hardware Verification Plot (9 Files with Smoothing)

% 1. Define your file list and corresponding Legend labels
filenames = {
    'f_out_hardware_J_00.txt', ...
    'f_out_hardware_J_FULLPOS_60000.txt', ...
    'f_out_hardware_J_FULLPOS_30000.txt', ...
    'f_out_hardware_J_FULLPOS_15000.txt', ...
    'f_out_hardware_J_FULLPOS_1500.txt', ...
    'f_out_hardware_J_NEG_60000.txt', ...
    'f_out_hardware_J_NEG_30000.txt', ...
    'f_out_hardware_J_NEG_15000.txt', ...
    'f_out_hardware_J_NEG_1500.txt'
};

labels = {'Reference', '0 Inertia', 'J +60000', 'J +30000', ...
          'J +15000', 'J +1500', 'J -60000', 'J -30000', 'J -15000', 'J -1500'};

% 2. Initialize variables
num_files = length(filenames);
data_cell = cell(1, num_files);
min_len = 900; % Default max points to plot
window_size = 12; 

figure('Color', 'w');
subplot(2,1,1); hold on;

% 3. Loop through files, process, and plot
colors = lines(num_files); % Generates a distinct color map

for i = 1:num_files
    fid = fopen(filenames{i}, 'r');
    if fid ~= -1
        raw_hex = textscan(fid, '%s');
        fclose(fid);
        
        % Convert Hex -> Dec -> Hz
        hw_dec = uint32(hex2dec(raw_hex{1}));
        f_raw = (double(hw_dec) * 720) / (2^32);
        
        % Smooth and store
        f_smooth = movmean(f_raw, window_size);
        data_cell{i} = f_smooth;
        
        % Update minimum length to avoid indexing errors
        min_len = min([min_len, length(t), length(f_smooth)]);
    else
        fprintf('Warning: Could not find %s\n', filenames{i});
    end
end

% 4. Plot Frequency Tracking
% Plot the Reference (Simulation) line first
plot(t(1:min_len), f_grid_sim(1:min_len), 'k--', 'LineWidth', 2);

for i = 1:num_files
    if ~isempty(data_cell{i})
        plot(t(1:min_len), data_cell{i}(1:min_len), 'Color', colors(i,:), 'LineWidth', 1.2);
    end
end

% Formatting Subplot 1
y_min = 59.5; y_max = 60.5; % Adjusted range to see more data
ylim([y_min y_max]);
set(gca, 'YTick', y_min:0.1:y_max); 
ylabel('Frequency (Hz)');
title('IPLL Frequency Tracking Comparison (9 Samples)');
legend(labels, 'Location', 'northeastoutside');
grid on; grid minor;

% 5. Plot Tracking Error (Example: Error of File 1 vs Reference)
subplot(2,1,2);
for i = 1:num_files
    if ~isempty(data_cell{i})
        error = f_grid_sim(1:min_len) - data_cell{i}(1:min_len);
        plot(t(1:min_len), error, 'Color', colors(i,:)); hold on;
    end
end

% Formatting Subplot 2
ylim([-0.5 0.5]);
set(gca, 'YTick', -0.5:0.1:0.5);
ylabel('Error (Hz)'); xlabel('Time (s)');
title('Tracking Error (Hz)');
grid on;


%% Constant 60Hz Generator for Seamless TB Looping
clear;
N = 1200;               % Exactly 100 cycles (12 samples/cycle)
bits = 16;              
max_val = 2^(bits-1)-1; 
fs = 720;               
f_grid = 60;            

n = (0:N-1)';           
theta = 2*pi * (f_grid / fs) * n; 

% Generate 3-Phase Signals
sig_A = max_val * sin(theta);
sig_B = max_val * sin(theta - 2*pi/3);
sig_C = max_val * sin(theta - 4*pi/3);

% Export to Hex
signals = {sig_A, sig_B, sig_C};
filenames = {'grid_a.hex', 'grid_b.hex', 'grid_c.hex'};

for i = 1:length(signals)
    data = round(signals{i});
    data = max(min(data, max_val), -2^(bits-1)); % Clamp
    hex_vals = dec2hex(mod(data, 2^bits), 4);
    
    fid = fopen(filenames{i}, 'w');
    for row = 1:N
        fprintf(fid, '%s\n', hex_vals(row, :));
    end
    fclose(fid);
end
fprintf('Generated seamlessly looping 60Hz hex files.\n');
