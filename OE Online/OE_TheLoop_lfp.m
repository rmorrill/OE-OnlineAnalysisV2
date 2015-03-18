function OE_TheLoop_lfp(chanList, fid, eid, numchans, stim_vals, var_list, offline)
% Gloriously updated by Astra S. Bryant on Feb 25, 2015

ttlinfo=[];
waveforms=[];
stimforms=[];
trial_start_times=[];
waves=[];


%Make figure that, when selected, allows a press of the shift key to halt
%the while loop
usershutdownhandle=figure('Name', 'Shutdown Controller');
set(usershutdownhandle,'Position', [0, 100, 350, 75]);
axis([0 175 0 60]);
set(gca,'XTick',[],'YTick',[]);
text(5, 50, 'press SHIFT to halt plotting');
%text(5, 30, 'press TAB to select new plotting options');
text(5, 10, 'press C to select new channel to plot');

global KEY_IS_PRESSED
KEY_IS_PRESSED = 0;

global PLOT_SELECTED
PLOT_SELECTED = 0;

global CHANNEL_SELECTED
CHANNEL_SELECTED = 0;

set(usershutdownhandle, 'KeyPressFcn', @myKeyPressFcn)

disp('Pausing for 2 seconds to make sure stimuli have started playing');
pause(2)
filesize = getfilesize(fid{1}, offline);

%% Start the Loop!

while ~KEY_IS_PRESSED
    %% Initialize figures and choose which channel gets data pulled. If all channels are accessed, data reading takes over 6 seconds
    %But keeping it in the loop
    
    if ~PLOT_SELECTED
        
        %std_var_list = {'Time', 'Time (zoom)'};
        % 			std_var_list = {'Time'};
        %z_var_list = {'Firing rate'}; % Removed variance because it's not an active option yet.
        %z_var_list = {'Firing rate', 'Variance'}; % Removed variance because it's not an active option yet.
        fighand = figure;
        set(fighand, 'Position', [800 100 150 550], 'menubar', 'none')
        % 			x_hand = uicontrol(fighand, 'Style', 'listbox', 'Position', [10 440 130 80], 'FontSize', 12, 'String', [var_list std_var_list]);
        % 			uicontrol('Style', 'text', 'String', 'X axis', 'Position', [5 523 100 20]);
        % 			%y_hand = uicontrol(fighand, 'Style', 'listbox', 'Position', [10 265 130 160], 'FontSize', 12, 'String', [var_list std_var_list]);
        % 			y_hand = uicontrol(fighand, 'Style', 'listbox', 'Position', [10 325 130 80], 'FontSize', 12, 'String', [var_list]);
        % 			uicontrol('Style', 'text', 'String', 'Y axis', 'Position', [5 408 100 20]);
        % 			z_hand = uicontrol(fighand, 'Style', 'listbox', 'Position', [10 210 130 80], 'FontSize', 12, 'String', z_var_list);
        % 			uicontrol('Style', 'text', 'String', 'Z axis (heat)', 'Position', [5 293 100 20]);
        %
        tstart_hand= uicontrol('Style', 'edit', 'String', '0', 'Position', [20 145 50 30]);
        tstop_hand=uicontrol('Style', 'edit', 'String', '500', 'Position', [90 145 50 30]);
        uicontrol('Style','text','String','Heat Map Time Window: Start/End', 'Position',[5 180 140 25])
        
        startpad_hand= uicontrol('Style', 'edit', 'String', '150', 'Position', [20 80 50 30]);
        stoppad_hand=uicontrol('Style', 'edit', 'String', '150', 'Position', [90 80 50 30]);
        uicontrol('Style', 'text','String', 'Pre/Post-Stim Padding', 'Position', [5 115 140 25]);
        
        c_hand = uicontrol(fighand, 'Style', 'listbox', 'Position', [10 210 130 300], 'FontSize', 12, 'String', chanList);
        uicontrol('Style', 'text', 'String', 'Select a Channel', 'Position', [5 523 140 20]);
        
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
        waves=[];
		wavesforms=[];
        
        
        %% Initialize the plots here.
        %Which channel is being plotted
        % 			x_list = get(x_hand, 'String');
        % 			y_list = get(y_hand, 'String');
        % 			z_list = get(z_hand, 'String');
        %
        % 			x_sel = x_list{get(x_hand, 'Value')};
        % 			y_sel = y_list{get(y_hand, 'Value') };
        % 			z_sel = z_list{get(z_hand, 'Value')};
        if numel(stim_vals)==1
            y_sel = var_list{1};
            x_sel = 'Time';
            y_prms = stim_vals{1};
            % get number of levels for the var
            uniq_y = unique(y_prms);
            nr_uniq_y = numel(uniq_y);
            xy = [y_prms'];
        end
        
        c_list = get(c_hand, 'String');
        c_sel = c_list{get(c_hand, 'Value')};
        cpi = find(strcmp(chanList, c_sel)); % cpi = channel plotting index. Use this to index the spikes_per_trial and trial_count array.
        channel_plot = regexp(c_sel,'_CH','split');
        channel_plot = str2num(channel_plot{1,2}); %use this for labeling
        
        %Figure out time window for plotting
        start_sel=str2num(get(tstart_hand,'String'));
        stop_sel=str2num(get(tstop_hand,'String'));
        
        timewindow=[start_sel/1000 stop_sel/1000];
        
        startpad_sel=str2num(get(startpad_hand,'String'));
        stoppad_sel=str2num(get(stoppad_hand,'String'));
        
        timewindow_padding=[startpad_sel/1000 stoppad_sel/1000];
        duration= ((timewindow(2)-timewindow(1))+ (timewindow_padding(1)+timewindow_padding(2))); %Used to be hard wired, this is only used by PSTH plot
        
        
        
        %Move location of stimulus-file reader (eid) and spike file reader (fid) to beginning of the
        %file - recapture previous data.
        fseek(eid,0,'bof');
        fseek(fid{cpi}, 0, 'bof');
        
        % 			if ~isempty(strmatch(x_sel,'Time','exact')) | ~isempty(strmatch(x_sel,'Time (zoom)', 'exact'))
        % 				y_idx = strmatch(y_sel,var_list,'exact');
        % 				y_prms = stim_vals{y_idx};
        %
        % 				% get number of levels for the var
        % 				uniq_y = unique(y_prms);
        % 				nr_uniq_y = numel(uniq_y);
        % 				xy = [y_prms'];
        %
        % 			else
        % 				x_idx = strmatch(x_sel,var_list,'exact');
        % 				y_idx = strmatch(y_sel,var_list,'exact');
        % 				x_prms = stim_vals{x_idx};
        % 				y_prms = stim_vals{y_idx};
        %
        % 				% get number of levels for each plotting var
        % 				uniq_x = unique(x_prms);
        % 				uniq_y = unique(y_prms);
        % 				nr_uniq_x = numel(uniq_x);
        % 				nr_uniq_y = numel(uniq_y);
        %
        % 				xy = [x_prms' y_prms'];
        % 			end
        
        close(fighand);
        
        % 			% This closes the output figures, in case this is not the first time
        % 			% through the figure-selection loop.
        % 			if exist('psth_fig_handle')
        % 				close (psth_fig_handle)
        % 				clear psth_fig_handle
        % 			end
        % 			if exist('heat_fig_handle')
        % 				close (heat_fig_handle)
        % 				clear heat_fig_handle
        % 			end
        
    end
    
    if ~CHANNEL_SELECTED
        
        [selection, ok] = listdlg('PromptString', 'Select a channel', 'SelectionMode','single', 'ListString',chanList);
        cpi = selection; %cpi = channel plotting index. Use this to index the spikes_per_trial and trial_count array.
        
        if numel(stim_vals)==1
            y_sel = var_list{1};
            x_sel = 'Time';
            y_prms = stim_vals{1};
            % get number of levels for the var
            uniq_y = unique(y_prms);
            nr_uniq_y = numel(uniq_y);
            xy = [y_prms'];
        end
        
        %Move location of stimulus-file reader (eid) and spike file reader (fid) to beginning of the
        %file - recapture previous data.
        fseek(eid,0,'bof');
        fseek(fid{cpi}, 0, 'bof');
        
        channel_plot=regexp(chanList{selection},'_CH','split');
        channel_plot = str2num(channel_plot{1,2}); %Use this for labeling
        CHANNEL_SELECTED = 1;
        spikes_per_trial=[];
        ttlinfo=[];
        trial_start_times=[];
        waves=[];
		 wavesforms=[];
        
        % This closes the output figures, in case this is not the first time
        % through the channel-selection loop.
        if exist('psth_fig_handle')
            close (psth_fig_handle)
            clear psth_fig_handle
        end
        % 		if exist('heat_fig_handle')
        % 			close (heat_fig_handle)
        % 			clear heat_fig_handle
        % 		end
        
        
        
    end
    
    
    
    %%  Fetch Data!
    figure(usershutdownhandle);
    
    %Fetch stimulus timing using the ADC channel. Structure of output
    %array: each row is a stimulus event, column 1= stim on time , column 2 =
    %stim off time. In real time.
    %need to restart the eid when i switch channels...
    [ttlinfo, specialcase]= OEstims(eid, offline); %this generates a list of only the new stimulus onset times.
    if size(ttlinfo,1)>numel(stim_vals{1});
        disp('Number of trials that have elapsed is greater that total number of possible trials. Assume multiple runs per recording. Ignoring previous completed runs.');
        ttlinfo=ttlinfo(numel(stim_vals{1})+1:end,:);
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
    
    %Fetch traces during a time window
    %defined by the trial triggers Output: structure
    %array, each stimulus presentation event, with traces
    %occuring during the time bin describes in ttlinfo. With subsequent
    %itertions of the loop, new trials will be concatinated to the
    %structure array.
    
    [temp, sfq]=OEreadlfp(fid{cpi},ttlinfo, offline);
    waveforms=vertcat(waveforms, temp');
    
    %Fetch traces of the stimulus presentation
    % 	[temp, sfq]= OEreadlfp(eid, ttlinfo, offline); % will need new file identifiers once we add in the stimulus waveform
    % 	stimforms=vertcat(stimforms, temp');
    
    %If file was read before the ongoing trial ended, save the spikes from
    %that trial, for now
    if strmatch(specialcase,'cutoffending')
        if ~isempty(waveforms)
            holdingpartialtrial=waveforms{end};
            waveforms(end)=[];
        end
    end
    
    %If the trial started before the file read start position, its because
    %the last iteration of the loop the trial hadn't ended, therefore add
    %onto the first trial the spikes detected in the last iteration.
    if strmatch(specialcase,'cutoffstart')
        if ~isempty(waveforms)
            waveforms{size(waveforms,1)-(size(ttlinfo,1))+1}=horzcat(holdingpartialtrial, waveforms{size(waveforms,1)-(size(ttlinfo,1))+1});
        end
    end
    %
    trialcount=numel(waveforms);
    
    wavelength=min(cell2mat(cellfun(@length,waveforms,'UniformOutput',0)));
    
    for i=1:trialcount
        waves(i,1:wavelength)=waveforms{i}(1:wavelength);
    end
    
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
    
    totaltrialno=length(xy);
    
    
    
    %% Plotting. Exact plots generated depend on the choices made in the GUIs
    %only plot if there are any spikes to actually plot...
    
    %Automatically detecting presence of logically varied stimuli (e.g.
    %visual stimulus on/off or opto stim on/off
    if  ~isempty(strmatch('vis_stim',var_list,'exact')) %are visual stimuli being varied on/off: this in going to break hard if we're parametrically varying light stimuli....
        v_inx = strmatch('vis_stim',var_list,'exact');
        v_prms = stim_vals{v_inx};
        v_sel='vis_stim';
    else
        v_prms = [];
        v_sel='';
    end
    
    if ~isempty(strmatch('light',var_list,'exact')) %are opto stimuli being varied on/off
        o_inx = strmatch('light',var_list,'exact');
        o_prms = stim_vals{o_inx};
        o_sel='light';
    else
        o_prms =  [];
        o_sel='';
    end
    
    vo = [v_prms' o_prms'];
    
    
    scrnsize=get(0,'screensize');
    
    
    if ~isequal(size(find(cellfun('isempty', waveforms)>0),1), size(waveforms),1)
        %% Making an average LFP plot
        
        if ~isempty(vo)
            [B,~,J] = unique(vo, 'rows'); % J contains indices that group by stimulus paramaters
            disp(sprintf('%d logically varied conditions automatically detected',size(B,1)));
            logical_vars=size(B,1);
            ind=J(1:size(waves,2));
            for x=1:size(B, 1)
                sort_spt{x,:}= waves(find(ind==x));
                sort_xy{x,:}=xy(find(J==x));
                
            end
        else
            sort_spt=waves;
        end
        
        if ~exist('psth_fig_handle')
            %If it doesn't already exist, then create it - otherwise use
            %the old one
            
            
            if ~isempty(vo)
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
                psth_fig_handle=figure('Position',[50, (scrnsize(4)-round(scrnsize(4)*.6)-100), round(scrnsize(3)*.6), round(scrnsize(4)*.6)]);
                
            end
            
            
            %axis([00 900 0 1800]);
            for y=1:size(psth_fig_handle,2)
                figure(psth_fig_handle(y))
                for x=1:nr_uniq_y
                    if nr_uniq_y<=4
                        
                        eval(['subhandle{' num2str(y) ',' num2str(x) '}= subplot(nr_uniq_y, 1,x);']);
                        
                    else
                        eval(['subhandle{' num2str(y) ',' num2str(x) '}= subplot(4, round(nr_uniq_y/4),x);']);
                        
                        
                    end
                    
                end
                
            end
            
            
        end
        
        
        if ~isempty(vo)
            for y=1:logical_vars
                LFPavgPlot(duration, timewindow_padding, channel_plot, sort_spt{y}, psth_fig_handle(y), subhandle(y,:), sort_xy{y}, x_sel, y_sel, v_sel, o_sel, B(y,:),sfq)
                
            end
        else
            LFPavgPlot(duration, timewindow_padding, channel_plot, sort_spt, psth_fig_handle, subhandle, xy, x_sel, y_sel, v_sel, o_sel, [0 0], sfq)
            
            
            
        end
        
    end
    figure(usershutdownhandle);
    
    pause(1)
    
    %% Will automatically halt data scraping/plotting if the size of the
    %spike file isn't getting bigger.
    %if getfilesize(fid{1})==filesize
    %	disp('Acqusision Halted, no new spikes to PSTHify')
    %	break
    if totaltrialno==(trialcount+1)
        disp('All Trials Analyzed')
        break
    elseif offline<1
        filesize = getfilesize(fid{1},offline);
        disp('Waiting 2 seconds, getting more data')
        pause(4)
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
close(usershutdownhandle);


end



function myKeyPressFcn(hObject, event)
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