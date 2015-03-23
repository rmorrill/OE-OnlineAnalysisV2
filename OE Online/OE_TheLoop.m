function OE_TheLoop(chanList, fid, eid, numchans, stim_vals, var_list, offline, spikefiles)

% Astra Bryant/Ryan Morrill 

% Last updated by RJM 03/23/15 

%Fetch key variables
%fid = evalin('base','fid');
%eid = evalin('base','eid');

%prealocate
ttlinfo=[];
spikes_per_trial=[];
trial_start_times=[];
%spikes_per_trial=cell(numchans,1);

% text(5, 10, 'press C to select new channel to plot');

% RJM these globals are a fairly sloppy way of doing this
global KEY_IS_PRESSED
KEY_IS_PRESSED = 0;
%set(usershutdownhandle, 'KeyPressFcn', @myKeyPressFcn)

global PLOT_SELECTED
PLOT_SELECTED = 0;
%set(usershutdownhandle,'KeyPressFcn', @secondKeyPressFcn)

global CHANNEL_SELECTED
CHANNEL_SELECTED = 0;
%set(usershutdownhandle, 'KeyPressFcn', @thirdKeyPressFcn)

%Make figure that, when selected, allows a press of the shift key to halt
%the while loop

% order channel list
chanNums = regexp(chanList, '(?<=CH)\d{1,2}', 'match');
[chanNums_sort, chanSort_idx] = sort(cellfun(@(x)str2double(x), chanNums));
maxchans = max(chanNums_sort);


changefig=figure('Name', 'Shutdown Controller');
set(changefig,'Position', [0, 100, 350, 150]);
axis([0 175 0 60]);
changeax = gca;
set(gca,'XTick',[],'YTick',[]);
text(5, 50, 'press SHIFT to halt plotting');
text(5,35, 'press TAB to select new plotting options');
text(50, 22, 'Channel:');
ch_text_hand = uicontrol(changefig, 'Style','text', 'Position', [150 15 40 40], 'String', '', 'FontSize', 22);
fwdbutton = uicontrol(changefig, 'Style', 'pushbutton', 'Position', [220 20 30 30], 'String', '>', 'Callback', {@fwdButtonPress, ch_text_hand, maxchans});
backbutton = uicontrol(changefig, 'Style', 'pushbutton', 'Position', [100 20 30 30], 'String', '<', 'Callback', {@backButtonPress, ch_text_hand, maxchans}) ;
set(changefig, 'KeyPressFcn', @changeFigKeyPress)



% disp('Pausing for 2 seconds to make sure stimuli have started playing');
% pause(2)
filesize = getfilesize(fid{1}, offline);

%% Start the Loop!

while ~KEY_IS_PRESSED
    %% Initialize figures and choose which channel gets data pulled. If all channels are accessed, data reading takes over 6 seconds
    %But keeping it in the loop
    
    if ~PLOT_SELECTED
        
        std_var_list = {'Time', 'Time (zoom)'};
        %std_var_list = {'Time'};
        z_var_list = {'Firing rate'}; % Removed variance because it's not an active option yet.
        %z_var_list = {'Firing rate', 'Variance'}; % Removed variance because it's not an active option yet.
        fighand = figure;
        set(fighand, 'Position', [800 100 150 600], 'menubar', 'none')
        x_hand = uicontrol(fighand, 'Style', 'listbox', 'Position', [10 480 130 80], 'FontSize', 12, 'String', [var_list std_var_list], 'Value', 2);
        uicontrol('Style', 'text', 'String', 'X axis', 'Position', [5 563 100 20]);
        %y_hand = uicontrol(fighand, 'Style', 'listbox', 'Position', [10 265 130 160], 'FontSize', 12, 'String', [var_list std_var_list]);
        y_hand = uicontrol(fighand, 'Style', 'listbox', 'Position', [10 365 130 80], 'FontSize', 12, 'String', [var_list]);
        uicontrol('Style', 'text', 'String', 'Y axis', 'Position', [5 448 100 20]);
        z_hand = uicontrol(fighand, 'Style', 'listbox', 'Position', [10 250 130 80], 'FontSize', 12, 'String', z_var_list);
        uicontrol('Style', 'text', 'String', 'Z axis (heat)', 'Position', [5 333 100 20]);
        
        tstart_hand= uicontrol('Style', 'edit', 'String', '0', 'Position', [20 185 50 30]);
        tstop_hand=uicontrol('Style', 'edit', 'String', '100', 'Position', [90 185 50 30]);
        uicontrol('Style','text','String','Heat Map Time Window: Start/End', 'Position',[5 220 140 25])
        
        startpad_hand= uicontrol('Style', 'edit', 'String', '50', 'Position', [20 120 50 30]);
        stoppad_hand=uicontrol('Style', 'edit', 'String', '50', 'Position', [90 120 50 30]);
        uicontrol('Style', 'text','String', 'Pre/Post-Stim Padding', 'Position', [5 155 140 25]);
        
        
        c_hand = uicontrol('Style', 'popupmenu', 'Position', [20 67 100 30], 'FontSize', 12, 'String', chanList(chanSort_idx));
        sorted_hand = uicontrol('Style', 'checkbox', 'Position', [5 40 140 20], 'String', 'Use only sorted units', 'Value', 1);
        uicontrol('Style', 'PushButton', 'String', 'New plot', 'Position', [25 5 100 30], ...
            'FontSize', 14, 'Callback', 'uiresume(gcbf)');
        disp('Waiting for user to select plot type');
        
        uiwait(gcf);
        disp('Plot type selected');
        PLOT_SELECTED = 1;
        CHANNEL_SELECTED = 1;
        spikes_per_trial=[];
        ttlinfo=[];
        trial_start_times=[];
        
        
        %% Initialize the plots here.
        %Which channel is being plotted
        x_list = get(x_hand, 'String');
        y_list = get(y_hand, 'String');
        z_list = get(z_hand, 'String');
        
        x_sel = x_list{get(x_hand, 'Value')};
        y_sel = y_list{get(y_hand, 'Value') };
        if strcmp(x_sel, y_sel)
            fprintf('\nSame parameter selected for x and y, try again. Will exit now.\n');
            close(fighand);
            break
        end
        
        
        z_sel = z_list{get(z_hand, 'Value')};
        
        sortedFlag = get(sorted_hand, 'Value');
        
        c_list = get(c_hand, 'String');
        c_val = get(c_hand, 'Value');
        c_sel = c_list{c_val};
        currchan = chanNums_sort(c_val);
        
        set(ch_text_hand, 'String', num2str(currchan));
        %cpi_one = find(strcmp(chanList, c_sel)); % cpi = channel plotting index. Use this to index the spikes_per_trial and trial_count array.
        % account for sorting:
        cpi = chanSort_idx(c_val);
        disp(['Reading spikes from ' spikefiles{cpi} ' NOTE: this file is zero-indexed']);
        channel_plot = regexp(c_sel,'_CH','split');
        channel_plot = str2num(channel_plot{1,2}); %use this for labeling
        
        %Figure out time window for plotting
        start_sel=str2num(get(tstart_hand,'String'));
        stop_sel=str2num(get(tstop_hand,'String'));
        
        timewindow=[start_sel/1000 stop_sel/1000];
        
        startpad_sel=str2num(get(startpad_hand,'String'));
        stoppad_sel=str2num(get(stoppad_hand,'String'));
        
        
        if strmatch('Time', x_sel)
            timewindow_padding=[startpad_sel/1000 stoppad_sel/1000];
        else
            timewindow_padding = [0 0];
        end
        
        duration= ((timewindow(2)-timewindow(1))+ (timewindow_padding(1)+timewindow_padding(2))); %Only used by PSTH plot
        
        
        %Move location of stimulus-file reader (eid) and spike file reader (fid) to beginning of the
        %file - recapture previous data.
        fseek(eid,0,'bof');
        fseek(fid{cpi}, 0, 'bof');
        
        if ~isempty(strmatch(x_sel,'Time','exact')) | ~isempty(strmatch(x_sel,'Time (zoom)', 'exact'))
            y_idx = strmatch(y_sel,var_list,'exact');
            y_prms = stim_vals{y_idx};
            
            % get number of levels for the var
            uniq_y = unique(y_prms);
            nr_uniq_y = numel(uniq_y);
            yx = [y_prms'];
            
        else
            x_idx = strmatch(x_sel,var_list,'exact');
            y_idx = strmatch(y_sel,var_list,'exact');
            x_prms = stim_vals{x_idx};
            y_prms = stim_vals{y_idx};
            
            % get number of levels for each plotting var
            uniq_x = unique(x_prms);
            uniq_y = unique(y_prms);
            nr_uniq_x = numel(uniq_x);
            nr_uniq_y = numel(uniq_y);
            
            yx = [y_prms' x_prms'];
        end
        
        close(fighand);
        
        % This closes the output figures, in case this is not the first time
        % through the figure-selection loop.
        if exist('psth_fig_handle')
            close (psth_fig_handle)
            clear psth_fig_handle
        end
        if exist('heat_fig_handle')
            close (heat_fig_handle)
            clear heat_fig_handle
        end
        
    end
    
    if ~CHANNEL_SELECTED
        %[selection, ok] = listdlg('PromptString', 'Select a channel', 'SelectionMode','single', 'ListString',chanList);
        %cpi = selection; %cpi = channel plotting index. Use this to index the spikes_per_trial and trial_count array.
        
        currchan = str2double(get(ch_text_hand, 'String'));
        cpi = chanSort_idx(currchan);
        fprintf('\nSWITCHING CHANNELS TO CH %i\n', currchan);
        fprintf('\nReading spikes from %s NOTE: this file is zero-indexed\n', spikefiles{cpi});
        
        %Move location of stimulus-file reader (eid) and spike file reader (fid) to beginning of the
        %file - recapture previous data.
        fseek(eid,0,'bof');
        fseek(fid{cpi}, 0, 'bof');
        
        channel_plot= currchan;
        %         channel_plot=regexp(chanList{selection},'_CH','split');
        %         channel_plot = str2num(channel_plot{1,2}); %Use this for labeling
        CHANNEL_SELECTED = 1;
        spikes_per_trial=[];
        ttlinfo=[];
        trial_start_times=[];
        
        % This closes the output figures, in case this is not the first time
        % through the channel-selection loop.
        if exist('psth_fig_handle')
            close (psth_fig_handle)
            clear psth_fig_handle
        end
        if exist('heat_fig_handle')
            close (heat_fig_handle)
            clear heat_fig_handle
        end
    end
    
    %%  Fetch Data!
    figure(changefig);
    
    %Fetch stimulus timing using the ADC channel. Structure of output
    %array: each row is a stimulus event, column 1= stim on time , column 2 =
    %stim off time. In real time.
    %need to restart the eid when i switch channels...
    [ttlinfo, specialcase]= OEstims(eid, offline); %this generates a list of only the new stimulus onset times.
    assignin('base', 'ttlinfo_a_2', ttlinfo);
    
    if size(ttlinfo,1)>numel(stim_vals{1});
        disp('Number of trials that have elapsed is greater that total number of possible trials. Assume multiple runs per recording. Ignoring previous completed runs.');
        ttlinfo=ttlinfo(numel(stim_vals{1})+1:end,:);
        % ttlinfo = ttlinfo(1:1400,:); % RJM REMOVE THIS LATER
    end
    
    if strmatch(specialcase,'cutoffending')
        %keyboard
        ttlinfo(:,1)=ttlinfo(:,1)-timewindow_padding(1); %add user-specified padding before audio onset
        %ttlinfo(:,1)=ttlinfo(:,1)-.15; %add 150 ms padding before audio onset
        ttlinfo((1:(end-1)),2)=ttlinfo((1:(end-1)),2)+timewindow_padding(2); %add user-specified padding after audio offset to all except cutoffending trial
        trial_start_times=vertcat(trial_start_times, ttlinfo(:,1));
    elseif strmatch(specialcase,'cutoffstart')
        ttlinfo((2:end),1)=ttlinfo((2:end),1)-timewindow_padding(1); %add 150 ms padding before audio onset to all but cuttoff start
        ttlinfo(:,2)=ttlinfo(:,2)+timewindow_padding(2);
        trial_start_times=vertcat(trial_start_times, ttlinfo((2:end),1));
    else
        % RJM don't do this automatically
        ttlinfo(:,1)=ttlinfo(:,1)-timewindow_padding(1); %add 150 ms padding before audio onset
        ttlinfo(:,2)=ttlinfo(:,2)+timewindow_padding(2); %add 150 ms padding after audio offset
        trial_start_times=vertcat(trial_start_times, ttlinfo(:,1));
    end
    
    %%Duration moved up to UI region
    %automatically detecting the duration of the window (for plotting the
    %histogram, isn't working so well b/c of the cut off trials. It'd be
    %nice if that information could get passed in with the ZMQ information.
    %Otherwise, I'm hardwiring this.
    % 	if size(ttlinfo,1)>1
    % 	duration=(ttlinfo(2,2)-ttlinfo(2,1)); %duration of trial, assumes more than one tria
    % 	elseif size(ttlinfo,1)==1
    % 		duration=(ttlinfo(1,2)-ttlinfo(1,1)); %
    % 	end
    %%
    
    disp(strcat('Number of trials since last data pull: ', num2str(size(ttlinfo,1))))
    if numel(ttlinfo)<1
        disp('No new trials, assume acquisition has halted')
        break
    end
    
    %Fetch timestamps of spikes that occured during a time window
    %defined by the trial triggers Output: structure
    %array, each stimulus presentation event, with vector of spike times
    %occuring during the time bin describes in ttlinfo. With subsequent
    %itertions of the loop, new trials will be concatinated to the
    %structure array. NOTE: The spike times are in real time, they are not
    %yet normalized to the start of each time window.
    spikes_per_trial=vertcat(spikes_per_trial, OEread(fid{cpi},ttlinfo, offline, sortedFlag)');
    % RJM spikes_per_trial contains spike times, NOT numbers (i.e. is not a
    % spike count
    if all(cellfun(@isempty,spikes_per_trial)) %if there are absolutely no spikes at all
        disp('No spikes in any bin. If actively acquiring, try restarting in a few moments')
		user_resp = questdlg('No spikes found on this channel, would you like to shutdown loop?',  'Shutdown', 'Yes', 'No', 'No');
		if strcmp(user_resp, 'Yes')
			break
		end
	end
    
    
    %eval(['spikes_per_trial{' num2str(x) '}= vertcat(spikes_per_trial{' num2str(x) '}, ctranspose(OEread(fid{x},ttlinfo)));']);
    %disp(strcat('fetched spikes from channel_', num2str(x)));
    
    %If file was read before the ongoing trial ended, save the spikes from
    %that trial, for now
    if strmatch(specialcase,'cutoffending')
        if ~isempty(spikes_per_trial)
            holdingpartialtrial=spikes_per_trial{end};
            spikes_per_trial(end)=[];
        end
    end
    
    %If the trial started before the file read start position, its because
    %the last iteration of the loop the trial hadn't ended, therefore add
    %onto the first trial the spikes detected in the last iteration.
    if strmatch(specialcase,'cutoffstart')
        if ~isempty(spikes_per_trial)
            spikes_per_trial{size(spikes_per_trial,1)-(size(ttlinfo,1))+1}=horzcat(holdingpartialtrial, spikes_per_trial{size(spikes_per_trial,1)-(size(ttlinfo,1))+1});
        end
    end
    %
    trialcount=numel(spikes_per_trial);
    
    
    
    %     assignin('base', 'spikes_per_trial_A', spikes_per_trial);
    %     assignin('base', 'ttlinfo', ttlinfo);
    
    disp(strcat('Running total of trials: ', num2str(trialcount)));
    
    %% Plot data
    %if this is the first time through data gathering, send up a GUI. If
    %not the first time, don't query user, but if at any time the user hits
    %a key, send up the gui and replot.
    
    
    
    %Now that the appropriate channel has been selected, to the plotting
    %computations only on that channel. Remember that the spikes_per_trial
    %is in the same order of the chanList, not increasing numerical values.
    %If we don't take this into account, we'll be indexing to the wrong
    %place.
    
    totaltrialno=length(yx);
    
    
    
    %% Plotting. plots generated depend on the choices made in the GUIs
    %only plot if there are any spikes to actually plot...
    
    %Automatically detecting presence of logically varied stimuli (e.g.
    %visual stimulus on/off or opto stim on/off
    
    if  ~isempty(strmatch('vis_stim',var_list,'exact')) %are visual stimuli being varied on/off: this in going to break hard if we're parametrically varying light stimuli....
        v_inx = strmatch('vis_stim',var_list,'exact');
        v_prms = stim_vals{v_inx};
       % v_prms = v_prms(1:trialcount); 
        v_sel='vis_stim';
    else
        v_prms = zeros(1,totaltrialno);
        v_sel='';
    end
    
    if ~isempty(strmatch('light',var_list,'exact')) %are opto stimuli being varied on/off
        o_inx = strmatch('light',var_list,'exact');
        o_prms = stim_vals{o_inx};
       % o_prms = o_prms(1:trialcount); 
        o_sel='light';
    else
        o_prms =  zeros(1,totaltrialno);
        o_sel='';
    end
    
    vo = [v_prms' o_prms'];
    
    if ~isempty(vo) && ~all(all(vo == 0))
        multiplot = 1; 
    else
        multiplot = 0; 
    end
    
    %vo_sel = {o_sel v_sel}; 
    
    scrnsize=get(0,'screensize');
    
    
    if ~isequal(size(find(cellfun('isempty', spikes_per_trial)>0),1), size(spikes_per_trial,1))
        %% Making a PSTH
        if strmatch('Time', x_sel) % PLOT A PSTH
            %this will match any x_sel containing 'Time', including 'Time' and 'Time (zoom)'
            %disp('Time selected, make a histogram');
            
            %Normalize spike times to the start of each bin.
            %             for i=1:trialcount
            %                 if numel(spikes_per_trial{i})>0
            %                     %disp(strcat({'start time of trial '}, num2str(i),{': '},num2str(trial_start_times(i))));
            %                     %disp(strcat({'time of first spike in trial '}, num2str(i),{': '},num2str(spikes_per_trial{i}(1))));
            %                     norm_spikes_per_trial{i}=spikes_per_trial{i}-trial_start_times(i);
            %
            %                     %norm_spikes_per_trial{i}=spikes_per_trial{i}-spikes_per_trial{i}(1);
            %                     %disp(strcat({'relative timing of first spike: '}, num2str(norm_spikes_per_trial{i}(1))));
            %                     % 				if (norm_spikes_per_trial{i}(1))>1
            %                     % 					keyboard
            %                     % 				end
            %                 end
            %             end
            
            if multiplot
                [B,~,J] = unique(vo, 'rows'); % J contains indices that group by stimulus paramaters
                disp(sprintf('%d logically varied conditions automatically detected',size(B,1)));
                logical_vars=size(B,1);
                ind=J(1:size(spikes_per_trial,1));
                for x=1:size(B, 1)
                    sort_spt{x,:}= spikes_per_trial(find(ind==x)); % sort_spt = sorted spikes per trial
                    sort_xy{x,:}=yx(find(J==x))
                    
                end
            else
                sort_spt=spikes_per_trial;
            end
            
            if ~exist('psth_fig_handle')
                %If it doesn't already exist, then create it - otherwise use
                %the old one  
                if multiplot
                    for y=1:logical_vars
                        if logical_vars==2;
                            psth_fig_handle(y)=figure('Position',[(50+((round(scrnsize(3)*.45)+50)*(y-1))), (scrnsize(4)-round(scrnsize(4)*.45)-100), round(scrnsize(3)*.45), round(scrnsize(4)*.45)]);
                            
                        elseif logical_vars==4
                            if y<3
                                psth_fig_handle(y)=figure('Position',[(50+((round(scrnsize(3)*.40)+50)*(y-1))), (scrnsize(4)-(round(round(scrnsize(4)*.40)*2.2))-100), round(scrnsize(3)*.40), round(scrnsize(4)*.40)]);
                                
                            else
                                psth_fig_handle(y)=figure('Position',[(50+((round(scrnsize(3)*.40)+50)*(y-3))), (scrnsize(4)-round(scrnsize(4)*.40)-100), round(scrnsize(3)*.40), round(scrnsize(4)*.40)]);
                            end
                        end
                    end
                    
                    %PSTH_fig_handle(y)=subplot(2,2,y)
                else
                    psth_fig_handle=figure('Position',[50, (scrnsize(4)-round(scrnsize(4)*.8)-100), round(scrnsize(3)*.8), round(scrnsize(4)*.8)]);
                    
                end
                
                
                %axis([00 900 0 1800]);
                for y=1:size(psth_fig_handle,2)
                    figure(psth_fig_handle(y))
                    for x=1:nr_uniq_y
                        if nr_uniq_y<=4
                            eval(['subhandle{' num2str(y) ',' num2str(x) '}= subplot(nr_uniq_y, 1,x);']);
                        else
                            eval(['subhandle{' num2str(y) ',' num2str(x) '}= subplot(4, ceil(nr_uniq_y/4),x);']);
                        end
                    end
                end
            end
            
            
            if multiplot
                for y=1:logical_vars
                    PsthPlot(duration, timewindow_padding, channel_plot, sort_spt{y}, psth_fig_handle(y), subhandle(y,:), sort_xy{y}, x_sel, y_sel, v_sel, o_sel, B(y,:))
                    
                end
            else
                PsthPlot(duration, timewindow_padding, channel_plot, sort_spt, psth_fig_handle, subhandle, yx, x_sel, y_sel, v_sel, o_sel, [0 0])
                
            end
        else % PLOT A HEATMAP TYPE FIGURE
            if ~exist('heat_fig_handle')
                %If it doesn't already exist, then create it - otherwise use
                %the old one
                if multiplot
                    
                    [A,~,K]=unique(vo,'rows');
                    disp(sprintf('%d logically varied conditions automatically detected',size(A,1)));
                    logical_vars=size(A,1);
                    
                    for y=1:logical_vars
                        if logical_vars==2;
                            heat_fig_handle(y)=figure('Position', [(50+((round(scrnsize(3)*.45)+50)*(y-1))), (scrnsize(4)-round(scrnsize(4)*.45)-100), round(scrnsize(3)*.45), round(scrnsize(4)*.45)]);
                        elseif logical_vars==4
                            if y<3
                                heat_fig_handle(y)=figure('Position', [(50+((round(scrnsize(3)*.40)+50)*(y-1))), (scrnsize(4)-(round(round(scrnsize(4)*.40)*2.2))-100), round(scrnsize(3)*.40), round(scrnsize(4)*.40)]);
                            else
                                heat_fig_handle(y)=figure('Position', [(50+((round(scrnsize(3)*.40)+50)*(y-3))), (scrnsize(4)-round(scrnsize(4)*.40)-100), round(scrnsize(3)*.40), round(scrnsize(4)*.40)]);
                            end
                        end
                    end
                    
                    
                else
                    heat_fig_handle=figure('Position', [50, (scrnsize(4)-round(scrnsize(4)*.6)-100), round(scrnsize(3)*.6), round(scrnsize(4)*.6)]);
                end
            end
            
            %%% RJM EDIT
            % This should not be hard-coded, as the window time can be
            % changed by user
            %  shiftedtimewindow=timewindow+.15; % (compensates for padding added around line 190 - right after ttl pulses called)
            %%% RJM EDIT
            
            % RJM do all of this earlier, why not?
            %             for i=1:trialcount
            %                 if numel(spikes_per_trial{i})>0
            %                     %disp(strcat({'start time of trial '}, num2str(i),{': '},num2str(trial_start_times(i))));
            %                     %disp(strcat({'time of first spike in trial '}, num2str(i),{': '},num2str(spikes_per_trial{i}(1))));
            %                    % norm_spikes_per_trial{i}=spikes_per_trial{i}-trial_start_times(i);
            %                    % wind_spikes_per_trial{i}=norm_spikes_per_trial{i}(find(norm_spikes_per_trial{i}>shiftedtimewindow(1) & norm_spikes_per_trial{i}<shiftedtimewindow(2)));
            %                     %norm_spikes_per_trial{i}=spikes_per_trial{i}-spikes_per_trial{i}(1);
            %                     %disp(strcat({'relative timing of first spike: '}, num2str(norm_spikes_per_trial{i}(1))));
            %                     % 				if (norm_spikes_per_trial{i}(1))>1
            %                     % 					keyboard
            %                     % 				end
            %                 else wind_spikes_per_trial{i}=[];
            %                 end
            %             end
            
            % special for heatmap plot - can determine time window of
            % analysis
            for i = 1:trialcount
                spikes_per_trial{i}= spikes_per_trial{i}(spikes_per_trial{i}>timewindow(1) & spikes_per_trial{i}<timewindow(2));
            end
            spike_data = cellfun(@numel, spikes_per_trial);
            spike_data_padded=nan(totaltrialno,1);
            spike_data_padded(1:trialcount)=spike_data;
            
            if multiplot
                for x=1:logical_vars
                    input_spikes=spike_data_padded;
                   % input_spikes(find(K~=x))=0; % RJM this means we're
                   % feeding zeros in, which will be confused for a data 
                   cond_len = length(find(K==x)); 
                   input_spikes(find(K~=x)) = NaN; % RJM instead use NaNs
                   HeatPlot(input_spikes,yx, y_idx, x_idx, nr_uniq_x, nr_uniq_y, uniq_x, uniq_y, y_sel, x_sel, channel_plot, heat_fig_handle(x),A(x,:), timewindow, cond_len)
                    
                end
            else
                input_spikes=spike_data_padded;
                % assignin('base', 'input_spikes', input_spikes);
                %HeatPlot(input_spikes,xy, y_idx, x_idx, nr_uniq_x, nr_uniq_y, uniq_x, uniq_y, y_sel, x_sel, channel_plot, heat_fig_handle,[0 0], shiftedtimewindow)
                HeatPlot(input_spikes,yx, y_idx, x_idx, nr_uniq_x, nr_uniq_y, uniq_x, uniq_y, y_sel, x_sel, channel_plot, heat_fig_handle,[0 0], timewindow, length(input_spikes))
            end
        end
    end
    figure(changefig);
    
    pause(1)
    
    %% Will automatically halt data scraping/plotting if the size of the
    %spike file isn't getting bigger.
    %if getfilesize(fid{1})==filesize
    %	disp('Acqusision Halted, no new spikes to PSTHify')
    %	break
    if totaltrialno==(trialcount+1) || offline
        disp('All Trials Analyzed')
        break
    elseif offline<1
        filesize = getfilesize(fid{1},offline);
        disp('Waiting 2 seconds, getting more data')
        pause(2)
        % 		if getfilesize(fid{1},offline)==filesize
        % 			disp('Acqusision Halted')
        % 			break
        % 		end
        
    end
    
    
    if KEY_IS_PRESSED
        disp('loop ended by user')
    end
    
    
end

for x=1:size(fid,2)
    fclose(fid{x});
end
%close all
close(changefig);


end

function fwdButtonPress(hObject, event, ch_text_hand, maxchans)
global CHANNEL_SELECTED
%disp('Button pressed');
currchan = str2double(get(ch_text_hand, 'String'));
if currchan ~= maxchans
    set(ch_text_hand, 'String', num2str(currchan+1))
else % wrap around to 1
    set(ch_text_hand, 'String', '1');
end
CHANNEL_SELECTED = 0;

end

function backButtonPress(hObject, event, ch_text_hand, maxchans)
global CHANNEL_SELECTED
%disp('Button pressed')
currchan = str2double(get(ch_text_hand, 'String'));
if currchan > 1
    set(ch_text_hand, 'String', num2str(currchan-1))
else
    set(ch_text_hand, 'String', num2str(maxchans));
end
CHANNEL_SELECTED = 0;
end


function changeFigKeyPress(hObject, event)
global PLOT_SELECTED
global KEY_IS_PRESSED
global CHANNEL_SELECTED
if(strcmp(event.Key, 'tab'))
    PLOT_SELECTED = 0;
    CHANNEL_SELECTED=0;
    disp('Tab key pressed: On next loop will query user for new plotting parameters')
end

if(strcmp(event.Key, 'c'))
    CHANNEL_SELECTED = 0;
    disp('C key pressed: On next loop will query user for new channel to plot in histogram')
end

if(strcmp(event.Key, 'shift'))
    KEY_IS_PRESSED = 1;
    disp('Shift key pressed')
end

end



function filesize = getfilesize(fid, offline)
fposition=ftell(fid);
fseek(fid,0,'eof');
filesize = ftell(fid);
if offline > 0
    fseek(fid,0,'bof'); %returns the position to start of file
else
    fseek(fid,fposition,'bof'); %returns the position to where it was when the code was entered.
end

end