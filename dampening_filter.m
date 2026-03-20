clear; clc; close all;

% Parameters
Ki = 1000;      
Kp = 40;       
Fs = 720;     
Ts = 1/Fs;
t_final = 10; % Define the 10-second window

% --- Comparison for Damping D ---
J_fixed = 0.1;  % Through sheer experimental observation, J must be negative 
% (for it to track properly)
D_values = [1.2, 0.3, 0.01]; 
% With small inertia, and large dampening, the responses are not good

% High vals of damp and low vals of J seem to give the responses we want
% J does not seem to effect the gain whatsoever - great! That literally is
% good
% Storage for discrete coefficients

% max J is 0.9 
num_z_all = cell(length(D_values),1);
den_z_all = cell(length(D_values),1);

% Initialize figures
figure(3); clf; 
figure(4); clf; 

colors_d = lines(length(D_values));

for i = 1:length(D_values)
    D = D_values(i);
    
    % 1. Define G(s) using your updated coefficients
    num_s = [Kp, Ki];
    den_s = [J_fixed*Kp, (J_fixed*Ki + (D)*Kp + 1), (D)*Ki];
    Gs = tf(num_s, den_s);
    
    % 2. Discretize using Tustin
    Gz = c2d(Gs, Ts, 'tustin');

    % Extract discrete numerator and denominator
    [num_z, den_z] = tfdata(Gz, 'v');

    % Store them
    num_z_all{i} = num_z;
    den_z_all{i} = den_z;

    % Normalize so a0 = 1
    num_z = num_z / den_z(1);
    den_z = den_z / den_z(1);

    num_z_all{i} = num_z;
    den_z_all{i} = den_z;

    fprintf('\nD = %.2f\n', D);
    fprintf('Numerator:   ');
    disp(num_z);
    fprintf('Denominator: ');
    disp(den_z);

    NB = 20;  % B Coeffs - -2s20
    NA = 16;  % A Coeffs - 2s16 

    scaled_num = round(num_z * 2^NB);
    scaled_den = round(den_z * 2^NA);

    fprintf('Numerator Verilog (B0, B1, B2):   ');
    disp(scaled_num);
    fprintf('Denominator Verilog (A0 - ignore, A1, A2): ');
    disp(scaled_den);
    
    % 3. Frequency Domain Plotting (Bode)
    figure(3);
    [mag, phase, w] = bode(Gz);
    mag_db = 20*log10(squeeze(mag));
    phase_deg = squeeze(phase);
    freq_hz = w / (2*pi);
    
    subplot(2,1,1);
    semilogx(freq_hz, mag_db, 'Color', colors_d(i,:), 'LineWidth', 1.5); hold on;
    ylabel('Magnitude (dB)'); grid on;
    title('Bode Plot Comparison: Varying Damping D');
    
    subplot(2,1,2);
    semilogx(freq_hz, phase_deg, 'Color', colors_d(i,:), 'LineWidth', 1.5); hold on;
    ylabel('Phase (deg)'); xlabel('Frequency (Hz)'); grid on;
    
    % 4. Time Domain Plotting - Forced to 10 Seconds
    figure(4);
    % Passing t_final ensures the simulation runs the full 10s
    [y, t] = step(Gz, t_final); 
    plot(t, y, 'Color', colors_d(i,:), 'LineWidth', 1.5); hold on;

    % 4. Time Domain Plotting - Forced to 10 Seconds
    figure(5);

    t = 0:Ts:t_final;          % Time vector
    u = 0.5 * ones(size(t));   % 0.5 step input

    [y, t] = lsim(Gz, u, t);   % Simulate response

    plot(t, y, 'Color', colors_d(i,:), 'LineWidth', 1.5); hold on;
end

% Add legends and formatting
figure(3);
subplot(2,1,1);
legend(arrayfun(@(d) sprintf('D = %.2f', d), D_values, 'UniformOutput', false));

figure(4);
grid on;
title('Step Response Comparison (10s Duration)');
xlabel('Time (s)'); ylabel('Amplitude');
xlim([0 t_final]); % Ensure the axis matches our 10s window
legend(arrayfun(@(d) sprintf('D = %.2f', d), D_values, 'UniformOutput', false));

figure(5);
grid on;
title('Step 0.5 Response Comparison (10s Duration)');
xlabel('Time (s)'); ylabel('Amplitude');
xlim([0 t_final]); % Ensure the axis matches our 10s window
legend(arrayfun(@(d) sprintf('D = %.2f', d), D_values, 'UniformOutput', false));



%% 11. Sinusoidal Response (q as a sinusoid) Simulation
clear; clc; close all;

% Parameters
Ki = 1000;      
Kp = 40;       
Fs = 720;     
Ts = 1/Fs;
t_final = 3; 

% --- Controllable Input Parameters ---
f_in = 4.0;                % Sinusoid frequency (Hz)
% Why is it that a 1hz difference between pll and grid 
% creates a 4hz sinusoid in q? 
dc_offset = 0.0;           % <--- ADJUST THIS for DC Offset
amplitude = 0.25;           % Sinusoid peak amplitude

t_sine = 0:Ts:t_final;     
% Combined Input: Sinusoid + DC Offset
u_sine = dc_offset + amplitude * sin(2*pi*f_in*t_sine); 

% --- Comparison for Damping D ---
J_fixed = 0.3;  % Seems to scale the gain of sinusoids significantly
% J_fixed = [-0.5, 0.3, 


% Should try J = 0.03 and D = 2.0, I think that will work

% We should tesst J - 0.05, with D
D_values = [2.0, 1.2, 1.5]; 
colors_d = lines(length(D_values));

figure(7); clf; hold on;

for i = 1:length(D_values)
    D = D_values(i);
    num_s = [Kp, Ki];
    den_s = [J_fixed*Kp, (J_fixed*Ki + D*Kp + 1), D*Ki];
    Gs = tf(num_s, den_s);
    Gz = c2d(Gs, Ts, 'tustin');
    
    % Simulate response
    [y_sine, t_out] = lsim(Gz, u_sine, t_sine);
    plot(t_out, y_sine, 'Color', colors_d(i,:), 'LineWidth', 1.5);
end

% Plot the input signal for reference
plot(t_sine, u_sine, 'k--', 'LineWidth', 1.2, 'DisplayName', 'Input (Ref)');
grid on;
title(sprintf('Sinusoidal Response (%.1f Hz) with %.1f DC Offset', f_in, dc_offset));
xlabel('Time (s)'); ylabel('Amplitude');
legend([arrayfun(@(d) sprintf('D = %.2f', d), D_values, 'UniformOutput', false), 'Input Reference']);

%% 13. Full Non-Linear Closed-Loop Simulation (DQZ + IPLL)
clear; clc; close all;
figure(8); clf;
figure(9); clf; % New figure for internal signal plotting


% As I suspected - sine and cos are differently aligned here. 
% Obviously this is of interest to us. 


% What happens if I switch va and such to cos? This is what gives us an
% error. 


% What happens if I switch the nco - should see fuckery with current vals,
% and workery with previous vals - nco gives us different stuff. 

% --- Simulation Parameters ---
Fs_sim = 720;
Ts_sim = 1/Fs_sim;
t_sim_final = 10; % 10 seconds to see the full lock dynamics
t_vec = 0:Ts_sim:t_sim_final;
N_sim = length(t_vec);

% --- Define the Input Grid (What the PLL is trying to track) ---
% Let's create a frequency step. Starts at 60Hz, jumps to 59Hz at 0.5s.
f_grid_nominal = 61;
f_grid_actual = ones(1, N_sim) * 60; 
f_grid_actual(t_vec >= 0.5) = 60; % 1 Hz drop at t=0.5s

% Integrate frequency to get the grid phase angle (theta_grid)
theta_grid = zeros(1, N_sim);
for k = 2:N_sim
    theta_grid(k) = theta_grid(k-1) + 2*pi * f_grid_actual(k) * Ts_sim;
end

% Generate the 3-Phase Input Signals (Normalized to amplitude 1)
v_a = cos(theta_grid); % Changing to cos aligns cos nco with thingy, changing to sin aligns with sin nco
v_b = cos(theta_grid - 2*pi/3); % Looks like all our hex files use sin - so why are we aligning with cos?
v_c = cos(theta_grid - 4*pi/3); % Inputs as sin while we start assuming cos makes q really high off the start. 
% But our q is 0? 

% Using q = asin + bcos - are they actually sin and cos though?
% --- Initialize Loop Variables ---
% J to 0.006 and D to 0.3 ~= J 0.03 and D 2.0
J_fixed = 0.01; % More J = more oscillation - longer to capture
D_sim = 0.9; % D > 1 breaks the thing
Kp = 40;
Ki = 1000;
num_s_sim = [Kp, Ki];
den_s_sim = [J_fixed*Kp, (J_fixed*Ki + D_sim*Kp + 1), D_sim*Ki];
Gs_sim = tf(num_s_sim, den_s_sim);
Gz_sim = c2d(Gs_sim, Ts_sim, 'tustin');
[num_z_sim, den_z_sim] = tfdata(Gz_sim, 'v');

% Normalize coefficients
num_z_sim = num_z_sim / den_z_sim(1);
den_z_sim = den_z_sim / den_z_sim(1);
b0 = num_z_sim(1); b1 = num_z_sim(2); b2 = num_z_sim(3);
a1 = den_z_sim(2); a2 = den_z_sim(3);

% Storage arrays for plotting
q_out_arr = zeros(1, N_sim);
f_err_arr = zeros(1, N_sim);
f_out_arr = zeros(1, N_sim);
theta_nco_arr = zeros(1, N_sim);

% NEW: Storage arrays for internal signals
sine_nco_arr = zeros(1, N_sim);
cos_nco_arr  = zeros(1, N_sim);
alpha_arr    = zeros(1, N_sim);
beta_arr     = zeros(1, N_sim);

% State variables for the IPLL Filter (delays)
x_z1 = 0; x_z2 = 0;
y_z1 = 0; y_z2 = 0;

% NCO Variables
f_nco_center = 61.0;
theta_nco = 0; 

% ========================================================
% ================= SAMPLE-BY-SAMPLE LOOP ================
% ========================================================
for k = 1:N_sim
    
    % 1. ----- NCO (Sine/Cosine Generation) -----
    sine_nco = sin(theta_nco);
    cos_nco = cos(theta_nco);
    
    % Record NCO states
    theta_nco_arr(k) = theta_nco;
    sine_nco_arr(k) = sine_nco;
    cos_nco_arr(k) = cos_nco;
    
    % 2. ----- DQZ Transform (Phase Detector) -----
    alpha = (2/3)*v_a(k) - (1/3)*(v_b(k) + v_c(k));
    beta  = (1/sqrt(3))*(v_c(k) - v_b(k)); % Note: your c-b logic
    
    % Record Clarke outputs
    alpha_arr(k) = alpha;
    beta_arr(k) = beta;
    
    % Park Transform
    d_val = alpha * cos_nco - beta * sine_nco;
    q_val = beta * cos_nco + alpha * sine_nco;
    
    q_out_arr(k) = q_val;
    
    % 3. ----- IPLL Filter (Loop Filter) -----
    x_in = -q_val; % In our filter - we are assuming the input is cos
    % 
    
    % Direct Form I computation
    y_out = ((b0*x_in + b1*x_z1 + b2*x_z2)*1 - (a1*y_z1 + a2*y_z2)); % If you divide the num by two here, and have sin as input, 0.2 and 0.3 brick it, but that doesn't explain how 0.03 and 2.0 worked!
    % oddly, if you multiply the num by two here, and use J = 0.02 and D =
    % 2.0, then you get the expected output
    % My best current guess is that the numerator is twice what it should
    % be

    % If the numerator isnt twice:
    % 

    % We did our scaling assuming the gain was 1/D, which it is, 
    
    % Update delays
    x_z2 = x_z1;
    x_z1 = x_in;
    y_z2 = y_z1;
    y_z1 = y_out;
    
    f_err_arr(k) = y_out;
    
    % 4. ----- Update Frequency Output -----
    f_out_arr(k) = f_nco_center + y_out;
    
    % 5. ----- Integrate NCO Phase for next sample -----
    theta_nco = theta_nco +  2*pi*f_out_arr(k) * Ts_sim;
    theta_nco = mod(theta_nco, 2*pi); 
end

% ========================================================
% ================= PLOTTING =============================
% ========================================================

% --- Figure 8: PLL Tracking Performance ---
figure(8);
subplot(3,1,1);
plot(t_vec, f_grid_actual, 'k--', 'LineWidth', 1.5); hold on;
plot(t_vec, f_out_arr, 'b', 'LineWidth', 1.5);
grid on; title('Frequency Tracking: f_{grid} vs f_{nco}');
ylabel('Frequency (Hz)');
legend('Grid Freq (Input)', 'NCO Freq (IPLL Output)');
xlim([0 t_sim_final]);

subplot(3,1,2);
plot(t_vec, q_out_arr, 'r', 'LineWidth', 1.2);
grid on; title('Phase Error (q value)');
ylabel('Amplitude');
xlim([0 t_sim_final]);

subplot(3,1,3);
phase_diff = unwrap(theta_grid) - unwrap(theta_nco_arr);
plot(t_vec, phase_diff, 'm', 'LineWidth', 1.5);
grid on; title('Phase Angle Difference (\theta_{grid} - \theta_{nco})');
xlabel('Time (s)'); ylabel('Radians');
xlim([0 t_sim_final]);

% --- Figure 9: Internal Signals (Zoomed In) ---

figure(9);
% Zoom window (First 100ms to clearly see 60Hz waves)
x_zoom = [0 0.1]; 

subplot(2,1,1);
plot(t_vec, v_a, 'k', 'LineWidth', 2); hold on;
plot(t_vec, alpha_arr, 'r--', 'LineWidth', 1.5);
plot(t_vec, beta_arr, 'b--', 'LineWidth', 1.5);
grid on; 
title('Stationary Frame: Grid Phase A (v_a) vs Clarke Outputs (\alpha, \beta)');
ylabel('Amplitude');
legend('v_a (Grid A)', '\alpha', '\beta');
xlim(x_zoom);

subplot(2,1,2);
plot(t_vec, sine_nco_arr, 'r', 'LineWidth', 1.5); hold on;
plot(t_vec, cos_nco_arr, 'b', 'LineWidth', 1.5);
grid on; 
title('Rotating Frame (NCO Outputs)');
xlabel('Time (s)'); ylabel('Amplitude');
legend('sine_{nco}', 'cos_{nco}');
xlim(x_zoom);

%% Multi-Parameter Sweep: Testing J sensitivity
%clear; clc; close all;

% --- Constant Simulation Parameters ---
Fs_sim = 720;
Ts_sim = 1/Fs_sim;
t_sim_final = 5; % Reduced for faster multi-run plotting
t_vec = 0:Ts_sim:t_sim_final;
N_sim = length(t_vec);

% --- Define the Input Grid (Common to all runs) ---
f_grid_actual = ones(1, N_sim) * 60; 
f_grid_actual(t_vec >= 0.5) = 60.0; % 1 Hz step
theta_grid = cumtrapz(t_vec, 2*pi * f_grid_actual);
v_a = 0.25*cos(theta_grid); 
v_b = 0.25*cos(theta_grid - 2*pi/3); 
v_c = 0.25*cos(theta_grid - 4*pi/3);

% --- Sweep Parameters ---
% CHANGE THIS to sweep D, Kp, etc.
param_sweep = 0.25*[0.05, 0.1, 0.2]; 
sweep_label = 'J';

% --- Pre-allocate Storage ---
f_out_history = zeros(length(param_sweep), N_sim);
q_out_history = zeros(length(param_sweep), N_sim);

num_z_all = cell(length(param_sweep),1);
den_z_all = cell(length(param_sweep),1);

% ========================================================
% ================= OUTER SWEEP LOOP =====================
% ========================================================
for p = 1:length(param_sweep)
    
    % Update the specific variable for this run
    J_fixed = param_sweep(p); 
    D_sim = 0.25*0.9; % Keep others constant
    Kp =40; Ki = 1000;
    
    % --- Re-calculate Coefficients for THIS run ---
    num_s = [Kp, Ki];
    den_s = [J_fixed*Kp, (J_fixed*Ki + (D_sim)*Kp + 1), (D_sim)*Ki];
    Gz = c2d(tf(num_s, den_s), Ts_sim, 'tustin');
    [num_z, den_z] = tfdata(Gz, 'v');
    
    b0 = num_z(1); b1 = num_z(2); b2 = num_z(3);
    a1 = den_z(2); a2 = den_z(3);

    % --- Reset Simulation States ---
    x_z1 = 0; x_z2 = 0; y_z1 = 0; y_z2 = 0;
    theta_nco = 0;
    f_nco_center = 61.0; % Your center freq

    % Store them
    num_z_all{p} = num_z;
    den_z_all{p} = den_z;

    % Normalize so a0 = 1
    num_z = num_z / den_z(1);
    den_z = den_z / den_z(1);

    num_z_all{p} = num_z;
    den_z_all{p} = den_z;

    fprintf('\nJ = %.5f\n D = %.5f\n', J_fixed, D_sim);
    fprintf('Numerator:   ');
    disp(num_z);
    fprintf('Denominator: ');
    disp(den_z);

    NB = 20;  % B Coeffs - -2s20
    NA = 16;  % A Coeffs - 2s16 

    scaled_num = round(num_z * 2^NB);
    scaled_den = round(den_z * 2^NA);

    fprintf('Numerator Verilog (B0, B1, B2):   ');
    disp(scaled_num);
    fprintf('Denominator Verilog (A0 - ignore, A1, A2): ');
    disp(scaled_den);

    % --- Sample-by-Sample Loop ---
    for k = 1:N_sim
        % NCO
        sine_nco = sin(theta_nco);
        cos_nco = cos(theta_nco);
        
        % DQZ/Park
        alpha = (2/3)*v_a(k) - (1/3)*(v_b(k) + v_c(k));
        beta  = (1/sqrt(3))*(v_c(k) - v_b(k));
        q_val = beta * cos_nco + alpha * sine_nco;
        
        % IPLL Filter
        x_in = -q_val;
        y_out = (b0*x_in + b1*x_z1 + b2*x_z2) - (a1*y_z1 + a2*y_z2);
        
        % Updates
        x_z2 = x_z1; x_z1 = x_in;
        y_z2 = y_z1; y_z1 = y_out;
        
        f_out_history(p, k) = f_nco_center + y_out;
        q_out_history(p, k) = q_val;
        
        theta_nco = mod(theta_nco + 2*pi*f_out_history(p, k)*Ts_sim, 2*pi);
    end
end

% ========================================================
% ================= PLOTTING ALL RUNS ====================
% ========================================================
figure();
set(gcf, 'Color', 'w');

% Subplot 1: Frequency Tracking
subplot(2,1,1);
plot(t_vec, f_grid_actual, 'k--', 'LineWidth', 2); hold on;
plot(t_vec, f_out_history', 'LineWidth', 1.5); % Note the transpose (')
grid on; ylabel('Freq (Hz)');
title(['Quarter scale PLL Response Sweep: Quater scaled Varying ', sweep_label]);

% Dynamic Legend Generation
leg_entries = cell(1, length(param_sweep) + 1);
leg_entries{1} = 'Grid Input';
for i = 1:length(param_sweep)
    leg_entries{i+1} = sprintf('%s = %.4f', sweep_label, param_sweep(i));
end
legend(leg_entries, 'Location', 'best');

% Subplot 2: Phase Error (Q)
subplot(2,1,2);
plot(t_vec, q_out_history', 'LineWidth', 1.2);
grid on; ylabel('Q Value (Error)');
xlabel('Time (s)');


%% Multi-Parameter Sweep: Testing D sensitivity
clear; clc; close all;

% --- Constant Simulation Parameters ---
Fs_sim = 720;
Ts_sim = 1/Fs_sim;
t_sim_final = 5; % Reduced for faster multi-run plotting
t_vec = 0:Ts_sim:t_sim_final;
N_sim = length(t_vec);

% --- Define the Input Grid (Common to all runs) ---
f_grid_actual = ones(1, N_sim) * 60; 
f_grid_actual(t_vec >= 0.5) = 59.0; % 1 Hz step
theta_grid = cumtrapz(t_vec, 2*pi * f_grid_actual);
v_a = cos(theta_grid); 
v_b = cos(theta_grid - 2*pi/3); 
v_c = cos(theta_grid - 4*pi/3);

% --- Sweep Parameters ---
% CHANGE THIS to sweep D, Kp, etc.
param_sweep = [0.0, 0.0001, 0.001, 0.01, 0.1, 0.5, 1.2]; 
sweep_label = 'D';

% --- Pre-allocate Storage ---
f_out_history = zeros(length(param_sweep), N_sim);
q_out_history = zeros(length(param_sweep), N_sim);

% ========================================================
% ================= OUTER SWEEP LOOP =====================
% ========================================================
for p = 1:length(param_sweep)
    
    % Update the specific variable for this run
    J_fixed = 0.1; 
    D_sim = param_sweep(p); % Keep others constant
    Kp =40; Ki = 1000;
    
    % --- Re-calculate Coefficients for THIS run ---
    num_s = [Kp, Ki];
    den_s = [J_fixed*Kp, (J_fixed*Ki + D_sim*Kp + 1), D_sim*Ki];
    Gz = c2d(tf(num_s, den_s), Ts_sim, 'tustin');
    [num_z, den_z] = tfdata(Gz, 'v');
    
    b0 = num_z(1); b1 = num_z(2); b2 = num_z(3);
    a1 = den_z(2); a2 = den_z(3);

    % --- Reset Simulation States ---
    x_z1 = 0; x_z2 = 0; y_z1 = 0; y_z2 = 0;
    theta_nco = 0;
    f_nco_center = 60.0; % Your center freq

    % --- Sample-by-Sample Loop ---
    for k = 1:N_sim
        % NCO
        sine_nco = sin(theta_nco);
        cos_nco = cos(theta_nco);
        
        % DQZ/Park
        alpha = (2/3)*v_a(k) - (1/3)*(v_b(k) + v_c(k));
        beta  = (1/sqrt(3))*(v_c(k) - v_b(k));
        q_val = beta * cos_nco + alpha * sine_nco;
        
        % IPLL Filter
        x_in = -q_val;
        y_out = (b0*x_in + b1*x_z1 + b2*x_z2) - (a1*y_z1 + a2*y_z2);
        
        % Updates
        x_z2 = x_z1; x_z1 = x_in;
        y_z2 = y_z1; y_z1 = y_out;
        
        f_out_history(p, k) = f_nco_center + y_out;
        q_out_history(p, k) = q_val;
        
        theta_nco = mod(theta_nco + 2*pi*f_out_history(p, k)*Ts_sim, 2*pi);
    end
end

% ========================================================
% ================= PLOTTING ALL RUNS ====================
% ========================================================
figure(10);
set(gcf, 'Color', 'w');

% Subplot 1: Frequency Tracking
subplot(2,1,1);
plot(t_vec, f_grid_actual, 'k--', 'LineWidth', 2); hold on;
plot(t_vec, f_out_history', 'LineWidth', 1.5); % Note the transpose (')
grid on; ylabel('Freq (Hz)');
title(['PLL Response Sweep: Varying ', sweep_label]);

% Dynamic Legend Generation
leg_entries = cell(1, length(param_sweep) + 1);
leg_entries{1} = 'Grid Input';
for i = 1:length(param_sweep)
    leg_entries{i+1} = sprintf('%s = %.4f', sweep_label, param_sweep(i));
end
legend(leg_entries, 'Location', 'best');

% Subplot 2: Phase Error (Q)
subplot(2,1,2);
plot(t_vec, q_out_history', 'LineWidth', 1.2);
grid on; ylabel('Q Value (Error)');
xlabel('Time (s)');

%% 5. Frequency Step Simulation
% Input 59 Hz to see how it responds
clear;
N = 1200;               % Buffer size
bits = 16;              % 16-bit signed
max_val = 2^(bits-1)-1; % 32767

% Physical Parameters
fs = 720;               % Sampling rate (Hz)
f_grid = 60;            % Grid frequency (Hz)

% Time/Phase calculation
n = (0:N-1)';           % Sample index
% Phase increment per sample = 2*pi * (f_grid / fs)
theta_fixed = 2*pi * (f_grid / fs) * n; 
f_step = ones(N, 1) * 59;
f_step(N/150:end) = 59; 
phase_step = zeros(N, 1);
for n = 2:N
    phase_step(n) = phase_step(n-1) + 2*pi * (f_step(n)/fs);
end
sig_A_step = max_val * sin(phase_step);


%% 8. Export Dynamic Files
% This will export to your home page probably - you have to move files 
% into project directory where you run testbench
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

%% 10. Hardware Verification Plot (with Smoothing)
% Load the hardware data
t = (0:N-1)'/fs; 
fid = fopen('MATH_CF_61_LONG_D09_J02.txt', 'r');
fid2 = fopen('MATH_CF_61_LONG_D09_J01.txt', 'r');

fid4 = fopen('MATH_CF_61_LONG_D12_J01.txt', 'r');
fid5 = fopen('MATH_CF_61_LONG_D12_J005.txt', 'r');
fid3 = fopen('SRF_CF_61_LONG.txt', 'r');

if (fid ~= -1) && (fid2 ~= -1)
    hw_hex = textscan(fid, '%s');
    fclose(fid);

    hw_hex2 = textscan(fid2, '%s');
    fclose(fid2);

    hw_hex3 = textscan(fid3, '%s');
    fclose(fid3);

    hw_hex4 = textscan(fid4, '%s');
    fclose(fid4);

    hw_hex5 = textscan(fid5, '%s');
    fclose(fid5);
    
    % Convert Hex strings to Decimal
    hw_fcw = uint32(hex2dec(hw_hex{1}));
    hw_fcw2 = uint32(hex2dec(hw_hex2{1}));
    hw_fcw3 = uint32(hex2dec(hw_hex3{1}));
    hw_fcw4 = uint32(hex2dec(hw_hex4{1}));
    hw_fcw5 = uint32(hex2dec(hw_hex5{1}));

    % Convert FCW back to Hz for the plot
    % Note: Use the frequency the NCO thinks it is clocked at (720 Hz)
    f_hw_raw = (double(hw_fcw) * 720) / (2^32);
    f_hw_raw2 = (double(hw_fcw2) * 720) / (2^32);
    f_hw_raw3 = (double(hw_fcw3) * 720) / (2^32);
    f_hw_raw4 = (double(hw_fcw4) * 720) / (2^32);
    f_hw_raw5 = (double(hw_fcw5) * 720) / (2^32);

    % --- SMOOTHING LOGIC ---
    % Average over 12 samples (one full 60Hz cycle at 720Hz sampling)
    window_size = 12; 
    f_hw = movmean(f_hw_raw, window_size) - 1;
    f_hw2 = movmean(f_hw_raw2, window_size) - 1;
    f_hw3 = movmean(f_hw_raw3, window_size) - 1;
    f_hw4 = movmean(f_hw_raw4, window_size) - 1;
    f_hw5 = movmean(f_hw_raw5, window_size) - 1;
    % -----------------------

    % Determine the shortest length to avoid "index out of bounds"
    len_to_plot = min([length(t), length(f_hw), length(f_hw2), length(f_hw3), length(f_hw4), length(f_hw5)]);
    
    figure();
    
    % Use the shortest available data length
    len = min([length(t), length(f_hw), length(f_hw2), length(f_hw3), length(f_hw4), length(f_hw5)]);
    
    % Plot the lines
    plot(t(1:len), f_step(1:len), 'k--', 'LineWidth', 1.5); hold on;
    plot(t(1:len), f_hw(1:len), 'r', 'LineWidth', 1.2);
    plot(t(1:len), f_hw2(1:len), 'g', 'LineWidth', 1.2);
    plot(t(1:len), f_hw4(1:len), 'y', 'LineWidth', 1.2);
    plot(t(1:len), f_hw5(1:len), 'm', 'LineWidth', 1.2);
    plot(t(1:len), f_hw3(1:len), 'b', 'LineWidth', 1.2);
    
    title('IPLL Frequency Tracking Comparison (ipll nominal f = 61 Hz)');
    legend('Reference', 'D 0.9 J 0.2', 'D 0.9 J 0.1', 'D 1.2 J 0.1', 'D 1.2 J 0.05', 'Typical SRF PLL');
    ylabel('Frequency (Hz)'); 
    grid on;
    grid minor; % Adds smaller lines for better visibility
   
else
    disp('Hardware output file not found. Run the simulation first.');
end

%% 10. Grid Forming vs Grid Following before hookup
% Load the hardware data
clear;
N = 1200;               % Buffer size
bits = 16;              % 16-bit signed
max_val = 2^(bits-1)-1; % 32767

% Physical Parameters
fs = 720;               % Sampling rate (Hz)
f_grid = 60;            % Grid frequency (Hz)
t = (0:N-1)'/fs; 
% Phase increment per sample = 2*pi * (f_grid / fs) 
f_step = ones(N, 1) * 59;
f_step(N/150:end) = 59; 
phase_step = zeros(N, 1);
for n = 2:N
    phase_step(n) = phase_step(n-1) + 2*pi * (f_step(n)/fs);
end
sig_A_step = max_val * sin(phase_step);

fid = fopen('DQZ_TO_SPVM_59HZ_IPLL.txt', 'r');
fid2 = fopen('DQZ_TO_SPVM_59HZ_SRF.txt', 'r');

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
    len_to_plot = min([length(t), length(f_hw), length(f_hw2)]);
    
    figure();
    
    % Use the shortest available data length
    len = min([length(t), length(f_hw), length(f_hw2)]);
    
    % Plot the lines
    plot(t(1:len), f_step(1:len), 'k--', 'LineWidth', 1.5); hold on;
    plot(t(1:len), f_hw(1:len), 'g', 'LineWidth', 1.2);
    plot(t(1:len), f_hw2(1:len), 'r', 'LineWidth', 1.2);

    
    title('Final IPLL Frequency Tracking Comparison (ipll nominal f = 60 Hz, input = 59 Hz)');
    legend('Reference', 'Grid Forming IPLL', 'Typical SRF PLL');
    ylabel('Frequency (Hz)'); 
    grid on;
    grid minor; % Adds smaller lines for better visibility
   
else
    disp('Hardware output file not found. Run the simulation first.');
end

%% 15. IPLL + Generator + Droop Control (Active Grid Participation)
clear; clc;

t_event = 6.0; % The time the load is added

% --- Simulation & Plant Parameters ---
Fs_sim = 720; Ts_sim = 1/Fs_sim;
t_sim_final = 10; t_vec = 0:Ts_sim:t_sim_final; N_sim = length(t_vec);

J_plant = 1.0; D_plant = 0.5; f_nom = 60.0;
f_gen_actual = 60.0; theta_gen = 0;

% --- Droop Controller Parameters ---
K_droop = 2.5; % The "strength" of the response. Higher = stiffer grid.
P_ref = 1.0;   % Nominal power setpoint

% --- IPLL (Your Genius Parameters) ---
J_ipll = 0.01; D_ipll = 0.9; Kp = 40; Ki = 1000;
Gz = c2d(tf([Kp, Ki], [J_ipll*Kp, (J_ipll*Ki + D_ipll*Kp + 1), D_ipll*Ki]), Ts_sim, 'tustin');
[num_z, den_z] = tfdata(Gz, 'v');
b0 = num_z(1); b1 = num_z(2); b2 = num_z(3);
a1 = den_z(2); a2 = den_z(3);

% --- Storage & States ---
f_gen_arr = zeros(1, N_sim); f_ipll_arr = zeros(1, N_sim);
p_mech_arr = zeros(1, N_sim);
x_z1 = 0; x_z2 = 0; y_z1 = 0; y_z2 = 0;
f_ipll_out = 60.0; theta_nco = 0;

% ========================================================
% ================= MAIN SIMULATION LOOP =================
% ========================================================
for k = 1:N_sim
    
    % 1. ----- DROOP CONTROLLER (The Brain) -----
    % The generator reacts to the frequency reported by the IPLL
    f_err_droop = f_ipll_out - f_nom;
    P_mech = P_ref - K_droop * f_err_droop; 
    
    % 2. ----- PHYSICAL GENERATOR (The Plant) -----
    P_elec = 1.0; 
    if t_vec(k) >= t_event, P_elec = 1.4; end % 40% Massive Load Step
    
    % Swing Equation
    df_dt = (P_mech - P_elec - D_plant*(f_gen_actual - f_nom)) / J_plant;
    f_gen_actual = f_gen_actual + df_dt * Ts_sim;
    theta_gen = theta_gen + 2*pi * f_gen_actual * Ts_sim;
    
    v_a = cos(theta_gen); v_b = cos(theta_gen - 2*pi/3); v_c = cos(theta_gen - 4*pi/3);
    
    % 3. ----- THE IPLL (The Sensor) -----
    sine_nco = sin(theta_nco); cos_nco = cos(theta_nco);
    alpha = (2/3)*v_a - (1/3)*(v_b + v_c);
    beta  = (1/sqrt(3))*(v_c - v_b);
    q_val = beta * cos_nco + alpha * sine_nco;
    
    x_in = -q_val;
    y_out = (b0*x_in + b1*x_z1 + b2*x_z2) - (a1*y_z1 + a2*y_z2);
    x_z2 = x_z1; x_z1 = x_in; y_z2 = y_z1; y_z1 = y_out;
    
    f_ipll_out = 60.0 + y_out;
    theta_nco = mod(theta_nco + 2*pi * f_ipll_out * Ts_sim, 2*pi);
    
    % Log
    f_gen_arr(k) = f_gen_actual;
    f_ipll_arr(k) = f_ipll_out;
    p_mech_arr(k) = P_mech;
end

% ========================================================
% ================= PLOTTING =============================
% ========================================================

idx_event = find(t_vec >= t_event, 1);

figure(); clf;
set(gcf, 'Color', 'w');

% --- Subplot 1: Frequency ---
subplot(3,1,1);
plot(t_vec, f_gen_arr, 'k', 'LineWidth', 2); hold on;
plot(t_vec, f_ipll_arr, 'r--', 'LineWidth', 1.5);

% Add the "Event" marker
xline(t_event, '--b', 'LineWidth', 1.5); % Vertical line
plot(t_event, f_gen_arr(idx_event), 'bo', 'MarkerFaceColor', 'b', 'MarkerSize', 8);
text(t_event + 0.1, 60.1, '\leftarrow Load Added (P_{elec} = 1.4)', 'Color', 'b', 'FontWeight', 'bold');

grid on; ylabel('Freq (Hz)'); 
title('System Frequency Response with Droop Control');
legend('Generator Speed', 'IPLL Estimate', 'Event Point');
ylim([min(f_gen_arr)-0.1, 60.2]);

% --- Subplot 2: Mechanical Power ---
subplot(3,1,2);
plot(t_vec, p_mech_arr, 'g', 'LineWidth', 2); hold on;
xline(t_event, '--b', 'LineWidth', 1.5);
grid on; ylabel('Power (P.U.)'); 
title('Mechanical Power Input (Droop Response)');

% --- Subplot 3: Estimation Error ---
subplot(3,1,3);
plot(t_vec, f_gen_arr - f_ipll_arr, 'm', 'LineWidth', 1.2); hold on;
xline(t_event, '--b', 'LineWidth', 1.5);
grid on; ylabel('Delta (Hz)'); 
title('Estimation Error (Physical Gen - PLL Estimate)');
xlabel('Time (s)');


%% SRF-PLL (Verilog Equivalent) + Generator + Droop Control
clear; clc;
t_event = 6.0; % The time the load is added

% --- Simulation & Plant Parameters ---
Fs_sim = 720; Ts_sim = 1/Fs_sim;
t_sim_final = 10; t_vec = 0:Ts_sim:t_sim_final; N_sim = length(t_vec);
J_plant = 1.0; D_plant = 0.5; f_nom = 60.0;
f_gen_actual = 60.0; theta_gen = 0;

% --- Droop Controller Parameters ---
K_droop = 2.5; % The "strength" of the response
P_ref = 1.0;   % Nominal power setpoint

% --- Verilog SRF-PLL Parameters ---
KP_int = 2000;
KI_int = 100;

% Corrected to 60.0 Hz (357913941). The Verilog had 363879174 (~61Hz).
CENTER_FREQ_int = 357913941; 

% Fixed-point scaling factor: Maps physical +/- 1.0 P.U. to an 18-bit signed integer
V_scale = 2^17 - 1; 

% --- Storage & States ---
f_gen_arr = zeros(1, N_sim); 
f_srf_arr = zeros(1, N_sim);
p_mech_arr = zeros(1, N_sim);

% SRF-PLL Internal States
integrator = 0; 
f_srf_out = 60.0; 
theta_nco = 0;

% ========================================================
% ================= MAIN SIMULATION LOOP =================
% ========================================================
for k = 1:N_sim
    
    % 1. ----- DROOP CONTROLLER (The Brain) -----
    % The generator reacts to the frequency reported by the SRF-PLL
    f_err_droop = f_srf_out - f_nom;
    P_mech = P_ref - K_droop * f_err_droop; 
    
    % 2. ----- PHYSICAL GENERATOR (The Plant) -----
    P_elec = 1.0; 
    if t_vec(k) >= t_event, P_elec = 1.4; end % 40% Massive Load Step
    
    % Swing Equation
    df_dt = (P_mech - P_elec - D_plant*(f_gen_actual - f_nom)) / J_plant;
    f_gen_actual = f_gen_actual + df_dt * Ts_sim;
    theta_gen = theta_gen + 2*pi * f_gen_actual * Ts_sim;
    
    v_a = cos(theta_gen); v_b = cos(theta_gen - 2*pi/3); v_c = cos(theta_gen - 4*pi/3);
    
    % 3. ----- THE SRF-PLL (Verilog Emulation) -----
    sine_nco = sin(theta_nco); cos_nco = cos(theta_nco);
    alpha = (2/3)*v_a - (1/3)*(v_b + v_c);
    beta  = (1/sqrt(3))*(v_c - v_b);
    q_val = beta * cos_nco + alpha * sine_nco;
    
    % Emulate hardware: Convert float q_val to 18-bit signed integer
    q_in = round(q_val * V_scale);
    
    % --- Verilog Discrete PI Logic ---
    prop_term = -q_in * KP_int;
    integrator = integrator + (-q_in * KI_int);
    pi_output = prop_term + integrator;
    
    freq_out_int = CENTER_FREQ_int + pi_output;
    
    % Emulate hardware: Convert 32-bit tuning word back to physical Hz
    f_srf_out = freq_out_int * (Fs_sim / 2^32);
    
    % Phase accumulator (NCO) update
    theta_nco = mod(theta_nco + 2*pi * f_srf_out * Ts_sim, 2*pi);
    
    % Log
    f_gen_arr(k) = f_gen_actual;
    f_srf_arr(k) = f_srf_out;
    p_mech_arr(k) = P_mech;
end

% ========================================================
% ================= PLOTTING =============================
% ========================================================
idx_event = find(t_vec >= t_event, 1);
figure(); clf;
set(gcf, 'Color', 'w');

% --- Subplot 1: Frequency ---
subplot(3,1,1);
plot(t_vec, f_gen_arr, 'k', 'LineWidth', 2); hold on;
plot(t_vec, f_srf_arr, 'r--', 'LineWidth', 1.5);
xline(t_event, '--b', 'LineWidth', 1.5); 
plot(t_event, f_gen_arr(idx_event), 'bo', 'MarkerFaceColor', 'b', 'MarkerSize', 8);
text(t_event + 0.1, 60.1, '\leftarrow Load Added (P_{elec} = 1.4)', 'Color', 'b', 'FontWeight', 'bold');
grid on; ylabel('Freq (Hz)'); 
title('System Frequency Response (Verilog SRF-PLL + Droop)');
legend('Generator Speed', 'SRF-PLL Estimate', 'Event Point');
ylim([min(f_gen_arr)-0.1, 60.2]);

% --- Subplot 2: Mechanical Power ---
subplot(3,1,2);
plot(t_vec, p_mech_arr, 'g', 'LineWidth', 2); hold on;
xline(t_event, '--b', 'LineWidth', 1.5);
grid on; ylabel('Power (P.U.)'); 
title('Mechanical Power Input (Droop Response)');

% --- Subplot 3: Estimation Error ---
subplot(3,1,3);
plot(t_vec, f_gen_arr - f_srf_arr, 'm', 'LineWidth', 1.2); hold on;
xline(t_event, '--b', 'LineWidth', 1.5);
grid on; ylabel('Delta (Hz)'); 
title('Estimation Error (Physical Gen - SRF-PLL Estimate)');
xlabel('Time (s)');


%% IPLL vs SRF-PLL Comparison Simulation
clear; clc;

% ========================================================
% ================= SIMULATION PARAMETERS ================
% ========================================================
t_event = 6.0; % The time the load is added
Fs_sim = 720; Ts_sim = 1/Fs_sim;
t_sim_final = 10; t_vec = 0:Ts_sim:t_sim_final; N_sim = length(t_vec);

% Physical Plant & Droop Parameters
J_plant = 1.0; D_plant = 0.5; f_nom = 60.0;
K_droop = 2.5; P_ref = 1.0;

% ========================================================
% ================= IPLL SETUP ===========================
% ========================================================
J_ipll = 0.2; D_ipll = 2; Kp = 40; Ki = 1000;
Gz = c2d(tf([Kp, Ki], [J_ipll*Kp, (J_ipll*Ki + D_ipll*Kp + 1), D_ipll*Ki]), Ts_sim, 'tustin');
[num_z, den_z] = tfdata(Gz, 'v');
b0 = num_z(1); b1 = num_z(2); b2 = num_z(3); a1 = den_z(2); a2 = den_z(3);

% IPLL States
f_gen_ipll = 60.0; theta_gen_ipll = 0;
x_z1 = 0; x_z2 = 0; y_z1 = 0; y_z2 = 0;
f_ipll_out = 60.0; theta_nco_ipll = 0;

% Arrays initialized at Nominal Frequency/Power
f_gen_ipll_arr = ones(1, N_sim) * 60.0; 
f_ipll_arr = ones(1, N_sim) * 60.0; 
p_mech_ipll_arr = ones(1, N_sim) * 1.0;

% ========================================================
% ================= SRF-PLL SETUP ========================
% ========================================================
KP_int = 2000; KI_int = 100;
CENTER_FREQ_int = 357913941; % 60Hz 
V_scale = 2^17 - 1; 

% SRF-PLL States
f_gen_srf = 60.0; theta_gen_srf = 0;
integrator_srf = 0; 
f_srf_out = 60.0; theta_nco_srf = 0;

% Arrays initialized at Nominal Frequency/Power
f_gen_srf_arr = ones(1, N_sim) * 60.0; 
f_srf_arr = ones(1, N_sim) * 60.0; 
p_mech_srf_arr = ones(1, N_sim) * 1.0;

% ========================================================
% ================= MAIN SIMULATION LOOP =================
% ========================================================
for k = 1:N_sim
    
    % Common Load Step
    P_elec = 1.0; 
    if t_vec(k) >= t_event, P_elec = 1.4; end 
    
    % --------------------------------------------------------
    % SYSTEM 1: IPLL + GENERATOR
    % --------------------------------------------------------
    % Droop Controller
    P_mech_ipll = P_ref - K_droop * (f_ipll_out - f_nom); 
    
    % Plant Swing Equation
    df_dt_ipll = (P_mech_ipll - P_elec - D_plant*(f_gen_ipll - f_nom)) / J_plant;
    f_gen_ipll = f_gen_ipll + df_dt_ipll * Ts_sim;
    theta_gen_ipll = theta_gen_ipll + 2*pi * f_gen_ipll * Ts_sim;
    
    % dq Transform & IPLL
    v_a = cos(theta_gen_ipll); v_b = cos(theta_gen_ipll - 2*pi/3); v_c = cos(theta_gen_ipll - 4*pi/3);
    sine_nco = sin(theta_nco_ipll); cos_nco = cos(theta_nco_ipll);
    alpha = (2/3)*v_a - (1/3)*(v_b + v_c); beta  = (1/sqrt(3))*(v_c - v_b);
    q_val_ipll = beta * cos_nco + alpha * sine_nco;
    
    x_in = -q_val_ipll;
    y_out = (b0*x_in + b1*x_z1 + b2*x_z2) - (a1*y_z1 + a2*y_z2);
    x_z2 = x_z1; x_z1 = x_in; y_z2 = y_z1; y_z1 = y_out;
    
    f_ipll_out = 60.0 + y_out;
    theta_nco_ipll = mod(theta_nco_ipll + 2*pi * f_ipll_out * Ts_sim, 2*pi);
    
    % --------------------------------------------------------
    % SYSTEM 2: SRF-PLL + GENERATOR
    % --------------------------------------------------------
    % Droop Controller
    P_mech_srf = P_ref - K_droop * (f_srf_out - f_nom); 
    
    % Plant Swing Equation
    df_dt_srf = (P_mech_srf - P_elec - D_plant*(f_gen_srf - f_nom)) / J_plant;
    f_gen_srf = f_gen_srf + df_dt_srf * Ts_sim;
    theta_gen_srf = theta_gen_srf + 2*pi * f_gen_srf * Ts_sim;
    
    % dq Transform & SRF-PLL
    v_a_s = cos(theta_gen_srf); v_b_s = cos(theta_gen_srf - 2*pi/3); v_c_s = cos(theta_gen_srf - 4*pi/3);
    sine_nco_s = sin(theta_nco_srf); cos_nco_s = cos(theta_nco_srf);
    alpha_s = (2/3)*v_a_s - (1/3)*(v_b_s + v_c_s); beta_s  = (1/sqrt(3))*(v_c_s - v_b_s);
    q_val_srf = beta_s * cos_nco_s + alpha_s * sine_nco_s;
    
    % Verilog emulation
    q_in = round(q_val_srf * V_scale);
    prop_term = -q_in * KP_int;
    integrator_srf = integrator_srf + (-q_in * KI_int);
    pi_output = prop_term + integrator_srf;
    
    freq_out_int = CENTER_FREQ_int + pi_output;
    f_srf_out = freq_out_int * (Fs_sim / 2^32);
    theta_nco_srf = mod(theta_nco_srf + 2*pi * f_srf_out * Ts_sim, 2*pi);
    
    % --------------------------------------------------------
    % LOGGING
    % --------------------------------------------------------
    f_gen_ipll_arr(k) = f_gen_ipll; f_ipll_arr(k) = f_ipll_out; p_mech_ipll_arr(k) = P_mech_ipll;
    f_gen_srf_arr(k) = f_gen_srf;   f_srf_arr(k) = f_srf_out;   p_mech_srf_arr(k) = P_mech_srf;
end

% ========================================================
% ================= PLOTTING =============================
% ========================================================
figure('Position', [100, 100, 800, 900]); clf;
set(gcf, 'Color', 'w');

% --- Subplot 1: Frequency ---
subplot(3,1,1);
plot(t_vec, f_gen_ipll_arr, 'b', 'LineWidth', 2); hold on;
plot(t_vec, f_ipll_arr, 'b--', 'LineWidth', 1.5);
plot(t_vec, f_gen_srf_arr, 'r', 'LineWidth', 2);
plot(t_vec, f_srf_arr, 'r--', 'LineWidth', 1.5);

xline(t_event, '--k', 'LineWidth', 1.5); 
grid on; ylabel('Freq (Hz)'); 
title('System Frequency Response Comparison');
legend('Gen Speed (IPLL Plant)', 'IPLL Estimate', 'Gen Speed (SRF Plant)', 'SRF-PLL Estimate', 'Location', 'Best');
ylim([min([f_gen_ipll_arr, f_gen_srf_arr])-0.1, 60.1]);

% --- Subplot 2: Mechanical Power ---
subplot(3,1,2);
plot(t_vec, p_mech_ipll_arr, 'b', 'LineWidth', 2); hold on;
plot(t_vec, p_mech_srf_arr, 'r', 'LineWidth', 2);
xline(t_event, '--k', 'LineWidth', 1.5);
grid on; ylabel('Power (P.U.)'); 
title('Mechanical Power Input (Droop Response)');
legend('IPLL Droop Cmd', 'SRF-PLL Droop Cmd', 'Location', 'Best');

% --- Subplot 3: Estimation Error ---
subplot(3,1,3);
plot(t_vec, f_gen_ipll_arr - f_ipll_arr, 'b', 'LineWidth', 1.5); hold on;
plot(t_vec, f_gen_srf_arr - f_srf_arr, 'r', 'LineWidth', 1.5);
xline(t_event, '--k', 'LineWidth', 1.5);
grid on; ylabel('Delta (Hz)'); 
title('Estimation Error (Physical Gen - PLL Estimate)');
legend('IPLL Error', 'SRF-PLL Error', 'Location', 'Best');
xlabel('Time (s)');

%% 16. IPLL + Generator + Droop Control (Active Grid Participation) Multiple D Plots
clear; clc;

t_event = 6.0; % The time the load is added

% --- Simulation & Plant Parameters ---
Fs_sim = 720; Ts_sim = 1/Fs_sim;
t_sim_final = 10; t_vec = 0:Ts_sim:t_sim_final; N_sim = length(t_vec);

J_plant = 1.0; D_plant = 0.5; f_nom = 60.0;
f_gen_actual = 60.0; theta_gen = 0;

% --- Droop Controller Parameters ---
K_droop = 2.5; % The "strength" of the response. Higher = stiffer grid.
P_ref = 1.0;   % Nominal power setpoint

% --- IPLL (Your Genius Parameters) ---
J_ipll = 0.000001; D_ipll = 0.5; Kp = 40; Ki = 1000;
Gz = c2d(tf([Kp, Ki], [J_ipll*Kp, (J_ipll*Ki + D_ipll*Kp + 1), D_ipll*Ki]), Ts_sim, 'tustin');
[num_z, den_z] = tfdata(Gz, 'v');
b0 = num_z(1); b1 = num_z(2); b2 = num_z(3);
a1 = den_z(2); a2 = den_z(3);

% --- Storage & States ---
f_gen_arr = zeros(1, N_sim); f_ipll_arr = zeros(1, N_sim);
p_mech_arr = zeros(1, N_sim);
x_z1 = 0; x_z2 = 0; y_z1 = 0; y_z2 = 0;
f_ipll_out = 60.0; theta_nco = 0;


% --- Add this: List of D_ipll values to test ---
D_ipll_list = [0.1, 0.5, 1.0, 2.0]; 
colors = lines(length(D_ipll_list)); % Distinct colors for each run
figure(1); clf; set(gcf, 'Color', 'w');

for d_idx = 1:length(D_ipll_list)
    D_ipll = D_ipll_list(d_idx);
    
    % --- IMPORTANT: Reset all state variables to initial conditions for each run ---
    f_gen_actual = 60.0; theta_gen = 0;
    x_z1 = 0; x_z2 = 0; y_z1 = 0; y_z2 = 0;
    f_ipll_out = 60.0; theta_nco = 0;

    Gz = c2d(tf([Kp, Ki], [J_ipll*Kp, (J_ipll*Ki + D_ipll*Kp + 1), D_ipll*Ki]), Ts_sim, 'tustin');
    [num_z, den_z] = tfdata(Gz, 'v');
    b0 = num_z(1); b1 = num_z(2); b2 = num_z(3);
    a1 = den_z(2); a2 = den_z(3);
        % ========================================================
        % ================= MAIN SIMULATION LOOP =================
        % ========================================================
    for k = 1:N_sim
        
        % 1. ----- DROOP CONTROLLER (The Brain) -----
        % The generator reacts to the frequency reported by the IPLL
        f_err_droop = f_ipll_out - f_nom;
        P_mech = P_ref - K_droop * f_err_droop; 
        
        % 2. ----- PHYSICAL GENERATOR (The Plant) -----
        P_elec = 1.0; 
        if t_vec(k) >= t_event, P_elec = 1.4; end % 40% Massive Load Step
        
        % Swing Equation
        df_dt = (P_mech - P_elec - D_plant*(f_gen_actual - f_nom)) / J_plant;
        f_gen_actual = f_gen_actual + df_dt * Ts_sim;
        theta_gen = theta_gen + 2*pi * f_gen_actual * Ts_sim;
        
        v_a = cos(theta_gen); v_b = cos(theta_gen - 2*pi/3); v_c = cos(theta_gen - 4*pi/3);
        
        % 3. ----- THE IPLL (The Sensor) -----
        sine_nco = sin(theta_nco); cos_nco = cos(theta_nco);
        alpha = (2/3)*v_a - (1/3)*(v_b + v_c);
        beta  = (1/sqrt(3))*(v_c - v_b);
        q_val = beta * cos_nco + alpha * sine_nco;
        
        x_in = -q_val;
        y_out = (b0*x_in + b1*x_z1 + b2*x_z2) - (a1*y_z1 + a2*y_z2);
        x_z2 = x_z1; x_z1 = x_in; y_z2 = y_z1; y_z1 = y_out;
        
        f_ipll_out = 60.0 + y_out;
        theta_nco = mod(theta_nco + 2*pi * f_ipll_out * Ts_sim, 2*pi);
        
        % Log
        f_gen_arr(k) = f_gen_actual;
        f_ipll_arr(k) = f_ipll_out;
        p_mech_arr(k) = P_mech;
    end
    % --- Add this right after the 'end' of the k-loop ---
    subplot(3,1,1);
    plot(t_vec, f_gen_arr, 'Color', colors(d_idx,:), 'LineWidth', 1.5, ...
        'DisplayName', sprintf('D_{ipll} = %.1f', D_ipll)); hold on;
    
    subplot(3,1,2);
    plot(t_vec, p_mech_arr, 'Color', colors(d_idx,:), 'LineWidth', 1.5); hold on;
    
    subplot(3,1,3);
    plot(t_vec, f_gen_arr - f_ipll_arr, 'Color', colors(d_idx,:), 'LineWidth', 1.2); hold on;
end

% ========================================================
% ================= PLOTTING =============================
% ========================================================


% --- Subplot 1: Frequency ---
subplot(3,1,1);
% Add this to define the index for the event marker
idx_event = find(t_vec >= t_event, 1); 

% Plotting remains the same, but we move the legend call down
grid on; ylabel('Freq (Hz)'); 

% Update the xline to include a DisplayName
xline(t_event, '--b', 'LineWidth', 1.5, 'DisplayName', 'Load Step Event'); 

% These markers won't show in legend unless you give them a DisplayName too
plot(t_event, f_gen_arr(idx_event), 'bo', 'MarkerFaceColor', 'b', 'MarkerSize', 8, 'HandleVisibility', 'off');

% Now show the legend (it will now pick up the D_ipll lines AND the xline)
legend('show', 'Location', 'best');

text(t_event + 0.1, 60, '\leftarrow Load Added (P_{elec} = 1.4)', 'Color', 'b', 'FontWeight', 'bold');
title('Generator Speed Comparison');

subplot(3,1,2); grid on; ylabel('Power (P.U.)');
title('Mechanical Power Input');

subplot(3,1,3); grid on; ylabel('Delta (Hz)'); xlabel('Time (s)');
title('Estimation Error');



%% 16. IPLL + Generator + Droop Control (Active Grid Participation) Multiple J Plots
clear; clc;

t_event = 6.0; % The time the load is added

% --- Simulation & Plant Parameters ---
Fs_sim = 720; Ts_sim = 1/Fs_sim;
t_sim_final = 10; t_vec = 0:Ts_sim:t_sim_final; N_sim = length(t_vec);

J_plant = 1.0; D_plant = 0.5; f_nom = 60.0;
f_gen_actual = 60.0; theta_gen = 0;

% --- Droop Controller Parameters ---
K_droop = 2.5; % The "strength" of the response. Higher = stiffer grid.
P_ref = 1.0;   % Nominal power setpoint

% --- IPLL (Your Genius Parameters) ---
J_ipll = 0.000001; D_ipll = 1.0; Kp = 40; Ki = 1000;
Gz = c2d(tf([Kp, Ki], [J_ipll*Kp, (J_ipll*Ki + D_ipll*Kp + 1), D_ipll*Ki]), Ts_sim, 'tustin');
[num_z, den_z] = tfdata(Gz, 'v');
b0 = num_z(1); b1 = num_z(2); b2 = num_z(3);
a1 = den_z(2); a2 = den_z(3);

% --- Storage & States ---
f_gen_arr = zeros(1, N_sim); f_ipll_arr = zeros(1, N_sim);
p_mech_arr = zeros(1, N_sim);
x_z1 = 0; x_z2 = 0; y_z1 = 0; y_z2 = 0;
f_ipll_out = 60.0; theta_nco = 0;


% --- Add this: List of D_ipll values to test ---
J_ipll_list = [0.0001, 0.001, 0.01, 0.1]; 
colors = lines(length(J_ipll_list)); % Distinct colors for each run
figure(1); clf; set(gcf, 'Color', 'w');

for d_idx = 1:length(J_ipll_list)
    J_ipll = J_ipll_list(d_idx);
    
    % --- IMPORTANT: Reset all state variables to initial conditions for each run ---
    f_gen_actual = 60.0; theta_gen = 0;
    x_z1 = 0; x_z2 = 0; y_z1 = 0; y_z2 = 0;
    f_ipll_out = 60.0; theta_nco = 0;

    Gz = c2d(tf([Kp, Ki], [J_ipll*Kp, (J_ipll*Ki + D_ipll*Kp + 1), D_ipll*Ki]), Ts_sim, 'tustin');
    [num_z, den_z] = tfdata(Gz, 'v');
    b0 = num_z(1); b1 = num_z(2); b2 = num_z(3);
    a1 = den_z(2); a2 = den_z(3);
        % ========================================================
        % ================= MAIN SIMULATION LOOP =================
        % ========================================================
    for k = 1:N_sim
        
        % 1. ----- DROOP CONTROLLER (The Brain) -----
        % The generator reacts to the frequency reported by the IPLL
        f_err_droop = f_ipll_out - f_nom;
        P_mech = P_ref - K_droop * f_err_droop; 
        
        % 2. ----- PHYSICAL GENERATOR (The Plant) -----
        P_elec = 1.0; 
        if t_vec(k) >= t_event, P_elec = 1.4; end % 40% Massive Load Step
        
        % Swing Equation
        df_dt = (P_mech - P_elec - D_plant*(f_gen_actual - f_nom)) / J_plant;
        f_gen_actual = f_gen_actual + df_dt * Ts_sim;
        theta_gen = theta_gen + 2*pi * f_gen_actual * Ts_sim;
        
        v_a = cos(theta_gen); v_b = cos(theta_gen - 2*pi/3); v_c = cos(theta_gen - 4*pi/3);
        
        % 3. ----- THE IPLL (The Sensor) -----
        sine_nco = sin(theta_nco); cos_nco = cos(theta_nco);
        alpha = (2/3)*v_a - (1/3)*(v_b + v_c);
        beta  = (1/sqrt(3))*(v_c - v_b);
        q_val = beta * cos_nco + alpha * sine_nco;
        
        x_in = -q_val;
        y_out = (b0*x_in + b1*x_z1 + b2*x_z2) - (a1*y_z1 + a2*y_z2);
        x_z2 = x_z1; x_z1 = x_in; y_z2 = y_z1; y_z1 = y_out;
        
        f_ipll_out = 60.0 + y_out;
        theta_nco = mod(theta_nco + 2*pi * f_ipll_out * Ts_sim, 2*pi);
        
        % Log
        f_gen_arr(k) = f_gen_actual;
        f_ipll_arr(k) = f_ipll_out;
        p_mech_arr(k) = P_mech;
    end
    % --- Add this right after the 'end' of the k-loop ---
    subplot(3,1,1);
    plot(t_vec, f_gen_arr, 'Color', colors(d_idx,:), 'LineWidth', 1.5, ...
        'DisplayName', sprintf('J_{ipll} = %.4f', J_ipll)); hold on;
    
    subplot(3,1,2);
    plot(t_vec, p_mech_arr, 'Color', colors(d_idx,:), 'LineWidth', 1.5); hold on;
    
    subplot(3,1,3);
    plot(t_vec, f_gen_arr - f_ipll_arr, 'Color', colors(d_idx,:), 'LineWidth', 1.2); hold on;
end

% ========================================================
% ================= PLOTTING =============================
% ========================================================


% --- Subplot 1: Frequency ---
subplot(3,1,1);
% Add this to define the index for the event marker
idx_event = find(t_vec >= t_event, 1); 

% Plotting remains the same, but we move the legend call down
grid on; ylabel('Freq (Hz)'); 

% Update the xline to include a DisplayName
xline(t_event, '--b', 'LineWidth', 1.5, 'DisplayName', 'Load Step Event'); 

% These markers won't show in legend unless you give them a DisplayName too
plot(t_event, f_gen_arr(idx_event), 'bo', 'MarkerFaceColor', 'b', 'MarkerSize', 8, 'HandleVisibility', 'off');

% Now show the legend (it will now pick up the D_ipll lines AND the xline)
legend('show', 'Location', 'best');

text(t_event + 0.1, 60, '\leftarrow Load Added (P_{elec} = 1.4)', 'Color', 'b', 'FontWeight', 'bold');
title('Generator Speed Comparison');

subplot(3,1,2); grid on; ylabel('Power (P.U.)');
title('Mechanical Power Input');

subplot(3,1,3); grid on; ylabel('Delta (Hz)'); xlabel('Time (s)');
title('Estimation Error');

%% Closed-Loop PI Controller Response to Step and Ramp Voltage Changes
clear; clc; close all;

% 1. Define System Parameters
V_nominal_rms = 120;                  % Nominal RMS Voltage
V_ref = V_nominal_rms * sqrt(2);      % Reference Peak Voltage (~170 Volts)

% PI Controller Gains
Kp = 0.1;  % Proportional gain
Ki = 3.0;  % Integral gain

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
    error_step(k) = V_step_input(k) - V_out_step(k-1);
    
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
plot(t, (170 - pi_out_ramp), 'm', 'LineWidth', 1.5);
title('170 - PI Controller Action (Kp*e + Ki*int(e))');
xlabel('Time (s)');
ylabel('Control Effort (V)');
grid on;

sgtitle('Closed-Loop Tracking Performance (System Output = PI Action + V_{ref})');

%{

Questions:
What does the adc read up to? 

What corresponds to 120 rms in inputs?

What is our current DC supply at? What does it output?

Should I scale the carrier? Probably.

Would we ever want to output more than 120 RMS? 

Like say we have an  inverse problem where we need to output more voltage
from the inverter, we wouldn't be able to do it, because our DC supply only
gives us 170 max anyway. 


Additionally, for startup, if our voltage is really low, the voltage
control will try to jack it up really high (assuming we have that allowed
in our DC supply) 

I say we should go forward by ensuring the voltage out of the inverter
never exceeds 125 VRMS. 



How to get amplitude output:

1. The Absolute Value Peak Detector (Simplest)

This is the digital equivalent of a diode and a capacitor.
 You take the absolute value of the incoming signal and keep track of 
the highest value seen. To allow the tracker to follow the amplitude when 
it decreases, you implement a "leak" (slow decay).

Logic Flow:

    Rectify the signal: abs_v = (vin[MSB]) ? -vin : vin;

    If abs_v > current_max, then current_max <= abs_v.

    Every N clock cycles, decrement current_max slightly (the decay).


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


Scale amplitude of carrier - or each peak individually - each peak is
probably better. 

But carrier is way easier. 

Carrier cannot be less than full scale 


Need to test what happens when you scale carrier vs when you scale outputs

Think I should just scale the sinusoids. It is way easier. 
Scale the sinusoids lower and it should lower the peak to peak voltage. 

Get amplitude of all three phases
Pass amplitudes through filter. 
Use output of filter to scale sinusoids being PWM - CANNOT BE MORE THAN
FULL SCALE - sinusoids should not have peak to peak greater than Carrier
max - will max us out at DC supply. 

How do I use the amplitude that it should be in order to control the
amplitude that actually comes out?


sin(wx)*1 - amplitude should be A, but it is 1. 
%}


%% Plotting

figure('Name', 'Closed-Loop PI Response', 'Position', [100, 100, 1000, 700]);

plot(t, V_ramp_input, 'k--', 'LineWidth', 1.5); hold on;
plot(t, (170 - pi_out_ramp), 'b', 'LineWidth', 1.5);
title('Tracking: Step Change');
ylabel('Voltage (V)');
legend('Potential Input', 'Filter Output', 'Location', 'best');
grid on;

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



%% Plot CSV's from signal tap

% Clear workspace and command window
clear; clc; close all;

% Define the filename
filename = 'Load_change.csv';

% Setup import options to handle the metadata at the top of the file
opts = detectImportOptions(filename);
opts.VariableNamingRule = 'preserve'; % Keeps exact column names

% Read the data
data = readtable(filename, opts);

% Extract the variables
% Note: Change 'Time' if your actual time column has a different header name
time_raw = data.time_unit; 
q_in = data.q_in;
freq_in = data.freq_in;

% Convert time from 1/720 seconds to actual seconds
time_actual = time_raw / 720;

% Create the figure
figure('Name', 'Load Change Analysis', 'Position', [100, 100, 800, 600]);

% --- Top Subplot: q_in ---
ax1 = subplot(2, 1, 1); % 2 rows, 1 column, 1st plot
plot(time_actual, q_in, 'b-', 'LineWidth', 1.5);
title('Input Q (q_{in})');
ylabel('q_{in}');
grid on;

% --- Bottom Subplot: freq_in ---
ax2 = subplot(2, 1, 2); % 2 rows, 1 column, 2nd plot
plot(time_actual, freq_in, 'r-', 'LineWidth', 1.5);
title('Input Frequency (freq_{in})');
xlabel('Time (seconds)');
ylabel('freq_{in}');
grid on;

% Link the x-axes so zooming on one zooms on the other identically
linkaxes([ax1, ax2], 'x');



%% 1. Load Data
filename = 'Load_change.csv';

% Skip the first 23 lines of metadata
opts = detectImportOptions(filename, 'NumHeaderLines', 23);
opts.VariableNamingRule = 'preserve'; 
raw_data = readtable(filename, opts);

% 2. Clean Headers and Import into Variables
% This converts "ipll:inst|q_in[17..0]" -> "ipll_inst_q_in_17__0_"
rawNames = raw_data.Properties.VariableNames;
validNames = matlab.lang.makeValidName(rawNames);

% Update the table with valid names
raw_data.Properties.VariableNames = validNames;

% Find the specific variables for Time, Q, and Freq
% We search for the "short" name within the "long" cleaned names
time_var = validNames{1}; 
q_var    = validNames{contains(validNames, 'q_in')};
f_var    = validNames{contains(validNames, 'freq_in')};

% Filter out initialization rows (where data is 'X')
is_valid = ~contains(string(raw_data.(q_var)), 'X');
data = raw_data(is_valid, :);

% 3. Convert and Scale Data
% Time: 1 unit = 1/720 seconds
time_s = data.(time_var) / 720;

% Binary Strings -> Decimal
% Use 2's complement logic if the signals are signed
q_raw = bin2dec(string(data.(q_var)));
q_in  = q_raw; 
q_in(q_in >= 2^17) = q_in(q_in >= 2^17) - 2^18; % Assumes 18-bit signed

f_raw = bin2dec(string(data.(f_var)));
freq_in = f_raw;
freq_in(freq_in >= 2^31) = freq_in(freq_in >= 2^31) - 2^32; % Assumes 32-bit signed

% 4. Plot Variable Names
figure('Color', 'w', 'Name', 'Signal Analysis');

% Subplot 1: q_in
ax1 = subplot(2,1,1);
plot(time_s, q_in, 'LineWidth', 1.5);
title(['Signal: ', strrep(q_var, '_', ' ')]); % Clean title for display
ylabel('Amplitude');
grid on;

% Subplot 2: freq_in
ax2 = subplot(2,1,2);
plot(time_s, freq_in, 'r', 'LineWidth', 1.5);
title(['Signal: ', strrep(f_var, '_', ' ')]);
xlabel('Time (seconds)');
ylabel('Frequency Value');
grid on;

% Link axes for synchronized zooming
linkaxes([ax1, ax2], 'x');