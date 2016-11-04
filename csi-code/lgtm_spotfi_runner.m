%%
% The MIT License (MIT)
% Copyright (c) 2016 Ethan Gaebel <egaebel@vt.edu>
% 
% Permission is hereby granted, free of charge, to any person obtaining a 
% copy of this software and associated documentation files (the "Software"), 
% to deal in the Software without restriction, including without limitation 
% the rights to use, copy, modify, merge, publish, distribute, sublicense, 
% and/or sell copies of the Software, and to permit persons to whom the 
% Software is furnished to do so, subject to the following conditions:
% 
% The above copyright notice and this permission notice shall be included 
% in all copies or substantial portions of the Software.
% 
% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS 
% OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE 
% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING 
% FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER 
% DEALINGS IN THE SOFTWARE.
%

function spotfi_file_runner(input_file_name)
    %% DEBUG AND OUTPUT VARIABLES-----------------------------------------------------------------%%
    globals_init()
    
    global DEBUG_BRIDGE_CODE_CALLING SIMULATION
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Get the full path to the currently executing file and change the
    % pwd to the folder this file is contained in...
    [current_directory, ~, ~] = fileparts(mfilename('fullpath'));
    cd(current_directory);
    % Paths for the csitool functions provided
    path('../../linux-80211n-csitool-supplementary/matlab', path);
    if DEBUG_BRIDGE_CODE_CALLING
        fprintf('The path: %s\n', path)
        fprintf('The pwd: %s\n', pwd)
    end
    if ~DEBUG_BRIDGE_CODE_CALLING
        close all
        clc
    end
    
    %% main
    if SIMULATION
        if ~exist('test-data/simulation_tmp.mat')
            generate_simulation_data(['test-data/' name_base], 4000);
        end
        name_base = 'simulation_tmp';
    else   
        name_base = 'los-test-desk-left';
    end

    data_file = ['test-data/' name_base];
    top_aoas = run(data_file);
    
    save(['test-output/' name_base]);
    if DEBUG_BRIDGE_CODE_CALLING
        fprintf('Done Running!\n')
    end
end

%% Output the array of top_aoas to the given file as doubles
% top_aoas         -- The angle of arrivals selected as the most likely.
% output_file_name -- The name of the file to write the angle of arrivals to.
function output_top_aoas(top_aoas, output_file_name)
    output_file = fopen(output_file_name, 'wb');
    if (output_file < 0)
        error('Couldn''t open file %s', output_file_name);
    end
    top_aoas
    for ii = 1:size(top_aoas, 1)
        fprintf(output_file, '%g ', top_aoas(ii, 1));
    end
    fprintf(output_file, '\n');
    fclose(output_file);
end

% function globals_init
%     %% DEBUG AND OUTPUT VARIABLES-----------------------------------------------------------------%%
%     %% Debug Controls
%     global DEBUG_PATHS
%     global DEBUG_PATHS_LIGHT
%     global NUMBER_OF_PACKETS_TO_CONSIDER
%     global DEBUG_BRIDGE_CODE_CALLING
%     global SIMULATION
%     DEBUG_PATHS = false;
%     DEBUG_PATHS_LIGHT = false;
%     NUMBER_OF_PACKETS_TO_CONSIDER = 10; % Set to -1 to ignore this variable's value
%     DEBUG_BRIDGE_CODE_CALLING = false;
%     SIMULATION = true; % always create new simulation testcase
%     
%     
%     %% Output controls
%     global OUTPUT_AOAS
%     global OUTPUT_TOFS
%     global OUTPUT_AOA_MUSIC_PEAK_GRAPH
%     global OUTPUT_TOF_MUSIC_PEAK_GRAPH
%     global OUTPUT_AOA_TOF_MUSIC_PEAK_GRAPH
%     global OUTPUT_SELECTIVE_AOA_TOF_MUSIC_PEAK_GRAPH
%     global OUTPUT_AOA_VS_TOF_PLOT
%     global OUTPUT_SUPPRESSED
%     global OUTPUT_PACKET_PROGRESS
%     global OUTPUT_FIGURES_SUPPRESSED
%     OUTPUT_AOAS = false;
%     OUTPUT_TOFS = false;
%     OUTPUT_AOA_MUSIC_PEAK_GRAPH = false;%true;
%     OUTPUT_TOF_MUSIC_PEAK_GRAPH = false;%true;
%     OUTPUT_AOA_TOF_MUSIC_PEAK_GRAPH = false;
%     OUTPUT_SELECTIVE_AOA_TOF_MUSIC_PEAK_GRAPH = 0;%0;
%     OUTPUT_AOA_VS_TOF_PLOT = false;
%     OUTPUT_SUPPRESSED = true;
%     OUTPUT_PACKET_PROGRESS = false;
%     OUTPUT_FIGURES_SUPPRESSED = false; % Set to true when running in deployment from command line
%     
%     
%     
%     
%     
%     
%     
%     %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% end

%% Runs the SpotFi test over the passed in data files which each contain CSI data for many packets
% data_files -- a cell array of file paths to data files
function output_top_aoas = run(data_file)
    %% DEFINE VARIABLE-----------------------------------------------------------------%%
    % Flow Controls
    global AOA_EST_MODE
    
    % Debug Controls
    global NUMBER_OF_PACKETS_TO_CONSIDER
    
    % Output controls
    global OUTPUT_SUPPRESSED
    global SIMULATION
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    global d channel_frequency f_delta
    % Set physical layer parameters (frequency, subfrequency spacing, and antenna spacing
    %antenna_distance = 0.1;
    % frequency = 5 * 10^9;
    % frequency = 5.785 * 10^9;
    %frequency = 5.32 * 10^9;
    % TODO actually 312.5kHz for 2.4G
    %sub_freq_delta = (40 * 10^6) / 30;

    % Read data file in
    if ~OUTPUT_SUPPRESSED
        fprintf('\n\nRunning on data file: %s\n', data_file)
    end
    if ~SIMULATION
        csi_trace = read_bf_file([data_file '.dat']);
    else
        load(data_file);
    end

    % Extract CSI information for each packet
    if ~OUTPUT_SUPPRESSED
        fprintf('Have CSI for %d packets\n', length(csi_trace))
    end

    % Set the number of packets to consider, by default consider all
    num_packets = length(csi_trace);
    if NUMBER_OF_PACKETS_TO_CONSIDER ~= -1
        num_packets = NUMBER_OF_PACKETS_TO_CONSIDER;
    end
    if ~OUTPUT_SUPPRESSED
        fprintf('Considering CSI for %d packets\n', num_packets)
    end
    %% TODO: Remove after testing
    fprintf('csi_trace\n')
    csi_trace
    csi_trace{1}
    
    fprintf('num_packets: %d\n', num_packets)
    sampled_csi_trace = csi_sampling(csi_trace, num_packets, ...
            1, length(csi_trace));
    if strcmp(AOA_EST_MODE, 'SPOTFI')
        output_top_aoas = spotfi(sampled_csi_trace);
    elseif strcmp(AOA_EST_MODE, 'MUSIC')
        for i = 1:num_packets
            tmp_csi = squeeze(sampled_csi_trace{i}.csi);
            aoa_possibility = musicAOA(tmp_csi(:,1));
            [~, output_top_aoas(1,:)] = sort(aoa_possibility, 'descend');
        end
        mean_aoa = mean(output_top_aoas(:,1));
    end
            
end