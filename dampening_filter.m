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
f_grid_actual = ones(1, N_sim) * 60.0; 
f_grid_actual(t_vec >= 0.5) = 60.0; % 1 Hz step
theta_grid = cumtrapz(t_vec, 2*pi * f_grid_actual);
v_a = 2*cos(theta_grid); 
v_b = 2*cos(theta_grid - 2*pi/3); 
v_c = 2*cos(theta_grid - 4*pi/3);

% --- Sweep Parameters ---
% CHANGE THIS to sweep D, Kp, etc.
param_sweep = [0.05, 0.1, 0.2]; 
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
    D_sim = 0.5; % Keep others constant
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
    f_nco_center = 60.0; % Your center freq

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
title(['Full scale PLL Response Sweep: Full scaled Coefficients - Varying ', sweep_label]);

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


%% Multt-Parameter Sweep: Testing J Sens - With D and Q
clear; clc; close all;

% --- Constant Simulation Parameters ---
Fs_sim = 720;
Ts_sim = 1/Fs_sim;
t_sim_final = 240; % Reduced for faster multi-run plotting
t_vec = 0:Ts_sim:t_sim_final;
N_sim = length(t_vec);

% --- Define the Input Grid (Common to all runs) ---
f_grid_actual = ones(1, N_sim) * 60.0; 
f_grid_actual(t_vec >= 0.5) = 60.0; % 1 Hz step (currently kept at 60)
theta_grid = cumtrapz(t_vec, 2*pi * f_grid_actual);
v_a = cos(theta_grid); 
v_b = cos(theta_grid - 2*pi/3); 
v_c = cos(theta_grid - 4*pi/3);

% --- Sweep Parameters ---
% CHANGE THIS to sweep D, Kp, etc.
param_sweep = [0.05, 0.1, 0.2]; 
sweep_label = 'J';

% --- Pre-allocate Storage ---
f_out_history = zeros(length(param_sweep), N_sim);
q_out_history = zeros(length(param_sweep), N_sim);
d_out_history = zeros(length(param_sweep), N_sim); % Added pre-allocation for d
num_z_all = cell(length(param_sweep),1);
den_z_all = cell(length(param_sweep),1);

% ========================================================
% ================= OUTER SWEEP LOOP =====================
% ========================================================
for p = 1:length(param_sweep)
    
    % Update the specific variable for this run
    J_fixed = param_sweep(p); 
    D_sim = 0.25; % Keep others constant
    Kp = 40; Ki = 1000;
    
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
    f_nco_center = 60.0; % Your center freq
    
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
        
        % Calculate q and d
        q_val = beta * cos_nco + alpha * sine_nco;
        d_val = alpha * cos_nco - beta * sine_nco; % Added d_val calculation
        
        % IPLL Filter
        x_in = -q_val;
        y_out = (b0*x_in + b1*x_z1 + b2*x_z2) - (a1*y_z1 + a2*y_z2);
        
        % Updates
        x_z2 = x_z1; x_z1 = x_in;
        y_z2 = y_z1; y_z1 = y_out;
        
        % Store History
        f_out_history(p, k) = f_nco_center + y_out;
        q_out_history(p, k) = q_val;
        d_out_history(p, k) = d_val; % Store d_val history
        
        theta_nco = mod(theta_nco + 2*pi*f_out_history(p, k)*Ts_sim, 2*pi);
    end
end

% ========================================================
% ================= PLOTTING ALL RUNS ====================
% ========================================================
figure();
set(gcf, 'Color', 'w');

% Subplot 1: Frequency Tracking
subplot(3,1,1); % Changed to 3,1,1
plot(t_vec, f_grid_actual, 'k--', 'LineWidth', 2); hold on;
plot(t_vec, f_out_history', 'LineWidth', 1.5); 
grid on; ylabel('Freq (Hz)');
title(['Full scale PLL Response Sweep: Full scaled Coefficients - Varying ', sweep_label]);

% Dynamic Legend Generation
leg_entries = cell(1, length(param_sweep) + 1);
leg_entries{1} = 'Grid Input';
for i = 1:length(param_sweep)
    leg_entries{i+1} = sprintf('%s = %.4f', sweep_label, param_sweep(i));
end
legend(leg_entries, 'Location', 'best');

% Subplot 2: Phase Error (Q)
subplot(3,1,2); % Changed to 3,1,2
plot(t_vec, q_out_history', 'LineWidth', 1.2);
grid on; ylabel('Q Value (Error)');

% Subplot 3: D Value
subplot(3,1,3); % Added 3,1,3 for D
plot(t_vec, d_out_history', 'LineWidth', 1.2);
grid on; ylabel('D Value');
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
