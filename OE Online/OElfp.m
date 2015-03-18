function OElfp(varagin)
%% Collect and work with data being actively acquired with the open-ephys software
%Astra Bryant / Ryan Morrill 2015

%Pass in any value as varagin in order to run in offline mode. 

%button= questdlg('Run in Offline Mode?','','No');
% if strcmp(button, 'Yes')
% 	offline=2;
% elseif strcmp(button, 'No')
% 	offline = 0;
% elseif strcmp(button, 'Cancel')
% 	error('User Canceled Run')
% end


% if nargin>0
%     portnr=varagin(1);
% else
%     portnr=5557;
% end
% run OElfp(<insert arbitrary number here>) to run code in offline mode
% run OElfp to run code in online mode
if nargin>0
    offline=2;
else
	offline=0;
end

if offline>0
    disp('Offline Mode');
    %dirname = uigetdir('Z:\astra\OpenEphys sample data\', 'Select Data Directory');
    dirname = uigetdir('C:\Users\hlab\Documents\Data\', 'Select Data Directory');
    cd(dirname);
else
    %Search Data directory for the newest file folder
    basepath='C:\Users\hlab\Documents\Data\';
    d = dir(basepath);
    isub = [d(:).isdir];
    folds = d(isub);
    folds = folds(~ismember({folds.name}, {'.','..'}));
    [~, dx]=sort([folds.datenum]);
    sorted={folds(dx(:)).name}';
    newestfolder=sorted{end};
    if strmatch(newestfolder, 'exptStimData')
        newestfolder = sorted{end-1};
    end
    disp(strcat('Newest Folder:', newestfolder));
    
    dirname=fullfile(basepath,newestfolder);
    cd(dirname);
end

%find all .continuous files in the give directory.
dirData = dir(fullfile(dirname, '100_CH*.continuous'));
dirIndex = [dirData.isdir];
fileList = {dirData(~dirIndex).name}';
temp=regexp(fileList,'.*_CH\d*','match');
for i=1:length(temp)
    chanList(i)=temp{i};
end
chanList=chanList';


%Get spike files of all channels - don't need to do this for LFP
% for i=1:length(temp)    
% alsotemp=regexp(temp{i},'_CH','split');
% alsotemp=str2num(alsotemp{1,1}{1,2})-1; %.spikes naming convention starts with 0, .continuous naming convention starts with 1
% spikefile{i}=(strcat('SE', num2str(alsotemp),'.spikes'));
% end
numchans= size(chanList,1);

%Get stimulus timing file
timingfile=regexp(temp{1},'_CH','split');
ttlfile=strcat(timingfile{1,1}{1,1},'_ADC2.continuous');

%Generate file identifiers for all the continuous files
for x=1:numchans
    eval(['fid{' num2str(x) '}=fopen(fileList{x});']);
    if fid{x} == -1
        error(sprintf('Could not open continuous file %s in directory %s', spikefile{x}, dirname)); 
	return
    end
end
    
    eid=fopen(ttlfile);
if eid == -1
	error('Could not open ADC file %s in directory %s', ttlfile, dirname); 
	return
end


% assignin('base','fid',fid);
% assignin('base','eid',eid);


%Information about stimulus identity. Using ZeroMQ to import the
%information into the workspace. Produces an m-by-n array where m = total
%number of trials and n = number of stimulus variables.

%This loop is going to be useful if the system crashes after the ZMQ
%message has already been sent, and we thus need to reinitialize online plotting
%after stimulus presentation has started
% if exist('ZMQMessage.mat')>0
%     load(fullfile(dirname,'ZMQMessage'))
% else
% [var_list, stim_vals]=getZMQ_trialparams(portnr);
% %stim_vals = evalin('base','stim_vals');
% %var_list = evalin('base','var_list');
% save(fullfile(dirname,'ZMQMessage'),'var_list', 'stim_vals');
% end
%     

trial_info_dir = 'C:\Users\hlab\Documents\Data\exptStimData\';
if offline > 0 %added to help with offline debugging on Onyx
    %load(fullfile(dirname,'ZMQMessage'))
	[zmqfilename, zmq_dir] = uigetfile(trial_info_dir);
	addpath(genpath(zmq_dir)); 
	load(zmqfilename)
else

    contents = dir(trial_info_dir);
    
    % remove directories
    contents = contents(~[contents.isdir]);
    % remove txt files
    namecell = {contents.name};
    mat_inds = ~cellfun(@isempty,regexp(namecell, '\.mat'));
    contents = contents(mat_inds);
    [~,srtidx] = sort([contents.datenum]);
    stimfile = contents(srtidx(end)).name;
    
    if ~strcmp(stimfile(1:3), 'exp')
        error('Most recent file in %s is %s, does not seem like a stim sequence data file.',...
            trial_info_dir, stimfile);
        return
    end
    
    fprintf('Loading stimulus parametrs from %s\n', stimfile);
    
    load([trial_info_dir stimfile]);
	
	%If we aren't looping any variable... Need to get stimu
	if isempty (stim_vals)
		
	end
end

OE_TheLoop_lfp(chanList, fid, eid, numchans, stim_vals, var_list, offline)

end
% function OE_TheLoop_lfp(chanList, fid, eid, numchans, stim_vals, var_list, offline)
% 
% 
% 
% end
