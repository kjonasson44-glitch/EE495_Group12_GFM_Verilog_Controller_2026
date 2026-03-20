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

%% Plot V out (I think this is phase B) 
filename = "Plot_test.csv";
% 'preserve' keeps the exact column headers from Signal Tap
T = readtable(filename, 'VariableNamingRule', 'preserve'); 

% 1. Remove the first row 
% Signal Tap often exports an empty or duplicate header row that MATLAB reads as NaNs
T(1, :) = [];

% Extract Specific Variable
% 2. Define the exact name of the column you want to plot
targetVar = 'inverter_top:inst_inverter_top|spwm:modulator|nco_spvm:nco_i_19'; % Replace 'VA' with the actual column header (look in variables in T, 
% Note that sometimes the name from signal tap will not be the same as the
% header name in this csv - inconvienent - I know - but this is seemingly the only
% way

% Extract just that column using dynamic field indexing
hexData = T.(targetVar);

% Convert Hex to Decimal
% 3. Format the data for hex2dec
% Depending on whether the hex values had letters (A-F) in them, MATLAB 
% might have imported this column as numbers, cells, or strings.
if isnumeric(hexData)
    % If it accidentally read '15555555' as a base-10 integer, convert it back to a string
    hexData = num2str(hexData); 
elseif iscell(hexData)
    hexData = string(hexData);
end

% Convert the hex strings to standard double-precision decimals
decData = hex2dec(hexData);

% 4. Handle Signed Data (2's Complement)
% Hardware values are often signed. If this is 16-bit signed data, 
% you need to convert the upper half of the hex range into negative numbers.
% (If your data is strictly unsigned, you can comment this block out).
idx_negative = decData > 131072; 
decData(idx_negative) = decData(idx_negative) - 262144;

decData_real = decData/2^17;

% Plot the Data
figure;
plot(decData_real, 'b-', 'LineWidth', 1.5);
title(sprintf('Signal Tap Data: %s', targetVar), 'Interpreter', 'none');
xlabel('Sample Number');
ylabel('Decimal Value');
grid on;
% NOTE: THESE NUMBERS ARE RATIOS OF FULL SCALE - THEY DO NOT REPRESENT
% ACTUAL VOLTAGE - MERELY WHAT THE FPGA IS OUTPUTING 
% So this output is a percentage of whatever your DC supply is, essntially.


%% Plot V in
filename = "Plot_test.csv";
% 'preserve' keeps the exact column headers from Signal Tap
T = readtable(filename, 'VariableNamingRule', 'preserve'); 

% 1. Remove the first row 
% Signal Tap often exports an empty or duplicate header row that MATLAB reads as NaNs
T(1, :) = [];

% Extract Specific Variable
% 2. Define the exact name of the column you want to plot
targetVar = 'inverter_top:inst_inverter_top|spwm:modulator|nco_spvm:nco_i_19'; % Replace 'VA' with the actual column header (look in variables in T, 
% Note that sometimes the name from signal tap will not be the same as the
% header name in this csv - inconvienent - I know - but this is seemingly the only
% way

% Extract just that column using dynamic field indexing
hexData = T.(targetVar);

% Convert Hex to Decimal
% 3. Format the data for hex2dec
% Depending on whether the hex values had letters (A-F) in them, MATLAB 
% might have imported this column as numbers, cells, or strings.
if isnumeric(hexData)
    % If it accidentally read '15555555' as a base-10 integer, convert it back to a string
    hexData = num2str(hexData); 
elseif iscell(hexData)
    hexData = string(hexData);
end

% Convert the hex strings to standard double-precision decimals
decData = hex2dec(hexData);

% 4. Handle Signed Data (2's Complement)
% Hardware values are often signed. If this is 16-bit signed data, 
% you need to convert the upper half of the hex range into negative numbers.
% (If your data is strictly unsigned, you can comment this block out).
idx_negative = decData > 131072; 
decData(idx_negative) = decData(idx_negative) - 262144;

decData_real = decData/2^17;

% Plot the Data
figure;
plot(decData_real, 'b-', 'LineWidth', 1.5);
title(sprintf('Signal Tap Data: %s', targetVar), 'Interpreter', 'none');
xlabel('Sample Number');
ylabel('Decimal Value');
grid on;
% NOTE: THESE NUMBERS ARE RATIOS OF FULL SCALE - THEY DO NOT REPRESENT
% ACTUAL VOLTAGE - MERELY WHAT THE FPGA IS OUTPUTING 
% So this output is a percentage of whatever your DC supply is, essntially.


%% Plot ipll freq
filename = "Plot_test.csv";
% 'preserve' keeps the exact column headers from Signal Tap
T = readtable(filename, 'VariableNamingRule', 'preserve'); 

% 1. Remove the first row 
% Signal Tap often exports an empty or duplicate header row that MATLAB reads as NaNs
T(1, :) = [];

% Extract Specific Variable
% 2. Define the exact name of the column you want to plot
targetVar = 'inverter_top:inst_inverter_top|spwm:modulator|nco_spvm:nco_i_19'; % Replace 'VA' with the actual column header (look in variables in T, 
% Note that sometimes the name from signal tap will not be the same as the
% header name in this csv - inconvienent - I know - but this is seemingly the only
% way

% Extract just that column using dynamic field indexing
hexData = T.(targetVar);

% Convert Hex to Decimal
% 3. Format the data for hex2dec
% Depending on whether the hex values had letters (A-F) in them, MATLAB 
% might have imported this column as numbers, cells, or strings.
if isnumeric(hexData)
    % If it accidentally read '15555555' as a base-10 integer, convert it back to a string
    hexData = num2str(hexData); 
elseif iscell(hexData)
    hexData = string(hexData);
end

% Convert the hex strings to standard double-precision decimals
decData = hex2dec(hexData);

% 4. Handle Signed Data (2's Complement)
% Hardware values are often signed. If this is 16-bit signed data, 
% you need to convert the upper half of the hex range into negative numbers.
% (If your data is strictly unsigned, you can comment this block out).
idx_negative = decData > 131072; 
decData(idx_negative) = decData(idx_negative) - 262144;

decData_real = decData/2^17;

% Plot the Data
figure;
plot(decData_real, 'b-', 'LineWidth', 1.5);
title(sprintf('Signal Tap Data: %s', targetVar), 'Interpreter', 'none');
xlabel('Sample Number');
ylabel('Decimal Value');
grid on;
% NOTE: THESE NUMBERS ARE RATIOS OF FULL SCALE - THEY DO NOT REPRESENT
% ACTUAL VOLTAGE - MERELY WHAT THE FPGA IS OUTPUTING 
% So this output is a percentage of whatever your DC supply is, essntially.


%% Plot srf freq
filename = "Plot_test.csv";
% 'preserve' keeps the exact column headers from Signal Tap
T = readtable(filename, 'VariableNamingRule', 'preserve'); 

% 1. Remove the first row 
% Signal Tap often exports an empty or duplicate header row that MATLAB reads as NaNs
T(1, :) = [];

% Extract Specific Variable
% 2. Define the exact name of the column you want to plot
targetVar = 'inverter_top:inst_inverter_top|spwm:modulator|nco_spvm:nco_i_19'; % Replace 'VA' with the actual column header (look in variables in T, 
% Note that sometimes the name from signal tap will not be the same as the
% header name in this csv - inconvienent - I know - but this is seemingly the only
% way

% Extract just that column using dynamic field indexing
hexData = T.(targetVar);

% Convert Hex to Decimal
% 3. Format the data for hex2dec
% Depending on whether the hex values had letters (A-F) in them, MATLAB 
% might have imported this column as numbers, cells, or strings.
if isnumeric(hexData)
    % If it accidentally read '15555555' as a base-10 integer, convert it back to a string
    hexData = num2str(hexData); 
elseif iscell(hexData)
    hexData = string(hexData);
end

% Convert the hex strings to standard double-precision decimals
decData = hex2dec(hexData);

% 4. Handle Signed Data (2's Complement)
% Hardware values are often signed. If this is 16-bit signed data, 
% you need to convert the upper half of the hex range into negative numbers.
% (If your data is strictly unsigned, you can comment this block out).
idx_negative = decData > 131072; 
decData(idx_negative) = decData(idx_negative) - 262144;

decData_real = decData/2^17;

% Plot the Data
figure;
plot(decData_real, 'b-', 'LineWidth', 1.5);
title(sprintf('Signal Tap Data: %s', targetVar), 'Interpreter', 'none');
xlabel('Sample Number');
ylabel('Decimal Value');
grid on;
% NOTE: THESE NUMBERS ARE RATIOS OF FULL SCALE - THEY DO NOT REPRESENT
% ACTUAL VOLTAGE - MERELY WHAT THE FPGA IS OUTPUTING 
% So this output is a percentage of whatever your DC supply is, essntially.

%{
Steps to plot signal tap in matlab. 

1. Get values on signal tap. 

2. Turn all of your variables into hexadecimal - trust me.
^ to do this, you select the variable in signal tap, then right click, go
to bus format, and select hexidecimal. 

3. Export signal tap to a csv

4. Load csv here in matlab - worth inspecting what the columns look like 

5. Remove Nan column at top

6. Find header of variable you want to plot - may not be same as signal tap
name

7. extract that data 

8. turn hex back to decimal 

9. Determine wether that variable is signed (it will be 99% of the time) 

10. If it is signed, you must convert your values into signed, like so
above. Basically: Check if value > 2^(#bits - 1) (a 17:0 number has 18
bits , so 18 - 1 = 17), if it does, then perform new number = number - 2^(#
bits) (here this would just be 18, not 18-1 = 17)

11. Now your data is accurate, but it will be very large. You must now
devide by the signal format to get actually accurate results. Basically
just number/2^(decimal bits) - a 1s17 number has 17 decimal bits (so number/2^17), signal
formats are given in all verilog files.
freq out is 0s32 in most cases, that is 32 decimal bits
some coefficients are -2s20, which is 20 decimal bits (ignore the -2 for
now)


%}
