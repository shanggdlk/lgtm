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

function [top_aoas] = spotfi_file_runner(input_file_name)
    %% DEBUG AND OUTPUT VARIABLES-----------------------------------------------------------------%%
    globals_init()
    
    %flow control
    global SIMULATION SIMULAIION_ALWAYS_GENERATE_DATA AOA_EST_MODE
    SIMULATION = false;
    SIMULAIION_ALWAYS_GENERATE_DATA = true;
    AOA_EST_MODE = 'SPOTFI';%'MUSIC' 'SPOTFI';
    
    %debug control
    global DEBUG_BRIDGE_CODE_CALLING
    
    %output control
    
    %%
    % Get the full path to the currently executing file and change the
    % pwd to the folder this file is contained in...
    [current_directory, ~, ~] = fileparts(mfilename('fullpath'));
    cd(current_directory);
    % Paths for the csitool functions provided
    path('./Atheros_csi', path);
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
        name_base = 'simulation_tmp';
        if ~exist('test-data/simulation_tmp.mat') || SIMULAIION_ALWAYS_GENERATE_DATA
            generate_simulation_data(['test-data/' name_base], 4000);
        end
    else   
        name_base = '90';
    end

    data_file = ['test-data/' name_base];
    top_aoas = run(data_file);
    
    save(['test-output/' name_base]);
    if DEBUG_BRIDGE_CODE_CALLING
        fprintf('Done Running!\n')
    end
end

% %% Output the array of top_aoas to the given file as doubles
% % top_aoas         -- The angle of arrivals selected as the most likely.
% % output_file_name -- The name of the file to write the angle of arrivals to.
% function output_top_aoas(top_aoas, output_file_name)
%     output_file = fopen(output_file_name, 'wb');
%     if (output_file < 0)
%         error('Couldn''t open file %s', output_file_name);
%     end
%     top_aoas
%     for ii = 1:size(top_aoas, 1)
%         fprintf(output_file, '%g ', top_aoas(ii, 1));
%     end
%     fprintf(output_file, '\n');
%     fclose(output_file);
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
    global d channel_frequency f_delta n_antenna n_subcarrier
    % Set physical layer parameters (frequency, subfrequency spacing, and antenna spacing

    % Read data file in
    if ~OUTPUT_SUPPRESSED
        fprintf('\n\nRunning on data file: %s\n', data_file)
    end
    if ~SIMULATION
%         csi_trace = read_log_file([data_file '.dat']);
%         %get the true csi order
%         for i = 1:length(csi_trace)
%             tmp_csi = csi_trace{i}.csi(2,:,:);
%             csi_trace{i}.csi(2,:,:) = csi_trace{i}.csi(3,:,:);
%             csi_trace{i}.csi(3,:,:) = tmp_csi;
%         end
        csi_trace = cell(NUMBER_OF_PACKETS_TO_CONSIDER,1);
        for i = 1:NUMBER_OF_PACKETS_TO_CONSIDER
            csi_trace{i}.csi = zeros(n_antenna,n_subcarrier);
        end
        for i = 1:n_antenna
            tmp_trace = read_log_file([data_file '_' num2str(i)]);
            for j = 1:NUMBER_OF_PACKETS_TO_CONSIDER
                csi_trace{j}.csi(i,:) = tmp_trace{j}.csi(1,1,:);
            end
        end
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
%     fprintf('csi_trace\n')
%     csi_trace
%     csi_trace{1}
    
%     fprintf('num_packets: %d\n', num_packets)
    sampled_csi_trace = csi_sampling(csi_trace, num_packets, ...
            1, length(csi_trace));
    
    sanitized_csi = cell(NUMBER_OF_PACKETS_TO_CONSIDER,1);
    
    %% Sanitize
    csi1 = sampled_csi_trace{1}.csi;
    packet_one_phase_matrix = unwrap(angle(csi1), pi, 2);
    sanitized_csi{1}.csi = spotfi_algorithm_1(csi1);
    
    for i = 2:NUMBER_OF_PACKETS_TO_CONSIDER
        tmp_csi = sampled_csi_trace{i}.csi;
        sanitized_csi{i}.csi = spotfi_algorithm_1(tmp_csi, packet_one_phase_matrix);
    end   
       
    if strcmp(AOA_EST_MODE, 'SPOTFI')
        output_top_aoas = spotfi(sanitized_csi);
        disp(output_top_aoas(1));
    elseif strcmp(AOA_EST_MODE, 'MUSIC')
        for i = 1:num_packets
            aoa_possibility = musicAOA(sanitized_csi{i}.csi(:,1));
            [~, top_aoas(i,:)] = sort(aoa_possibility, 'descend');
        end
        output_top_aoas = transpose(top_aoas(:,1));
        disp(mean(output_top_aoas));
    end
            
end