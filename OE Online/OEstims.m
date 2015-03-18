function [stimsout, specialcase] = OEstims (eid, offline)

%% Astra S Bryant
% This code is called by OEwrapper. It is used to query the ADC channel of
% an open-ephys recording to determine the time when a stimulus was being
% played. The ADC channel in question carries the trial triggers. 

MAX_NUMBER_OF_SPIKES = 1e6;
NUM_HEADER_BYTES = 1024;
SAMPLES_PER_RECORD = 1024;
RECORD_SIZE = 8 + 16 + SAMPLES_PER_RECORD*2 + 10; % size of each continuous record in bytes

index = 0;
current_sample = 0;

filesize = getfilesize(eid, offline);

if ftell(eid)==0
    hdr = fread(eid, NUM_HEADER_BYTES, 'char*1');
    eval(char(hdr'));
    ignorefirst=1;
else
    fposition=ftell(eid);
    fseek(eid,0,'bof');
    hdr = fread(eid, NUM_HEADER_BYTES, 'char*1');
    eval(char(hdr'));
    fseek(eid,fposition,'bof'); %returns the position to where it was when the code was entered.
    ignorefirst=0;
end

info.header = header;

%num_channels = info.header.num_channels;
%num_samples = 40; % **NOT CURRENTLY WRITTEN TO HEADER**

current_spike = 0;


while ftell(eid) + RECORD_SIZE < filesize % at least one record remains
    
    go_back_to_start_of_loop = 0;
    
    index = index + 1;
    
    
    timestamp = fread(eid, 1, 'int64', 0, 'l');
    nsamples = fread(eid, 1, 'uint16',0,'l');
    recNum = fread(eid, 1, 'uint16');
    
    if nsamples ~= SAMPLES_PER_RECORD
        
        disp(['  Found corrupted record...searching for record marker.']);
        
        % switch to searching for record markers
        
        last_ten_bytes = zeros(size(RECORD_MARKER));
        
        for bytenum = 1:RECORD_SIZE*5
            
            byte = fread(eid, 1, 'uint8');
            
            last_ten_bytes = circshift(last_ten_bytes,-1);
            
            last_ten_bytes(10) = double(byte);
            
            if last_ten_bytes(10) == RECORD_MARKER(end);
                
                sq_err = sum((last_ten_bytes - RECORD_MARKER).^2);
                
                if (sq_err == 0)
                    disp(['   Found a record marker after ' int2str(bytenum) ' bytes!']);
                    go_back_to_start_of_loop = 1;
                    break; % from 'for' loop
                end
            end
        end
        
        % if we made it through the approximate length of 5 records without
        % finding a marker, abandon ship.
        if bytenum == RECORD_SIZE*5
            
            disp(['Loading failed at block number ' int2str(index) '. Found ' ...
                int2str(nsamples) ' samples.'])
            
            break; % from 'while' loop
            
        end
        
        
    end
    
    if ~go_back_to_start_of_loop
        
        block = fread(eid, nsamples, 'int16', 0, 'b'); % read in data
        
        fread(eid, 10, 'char*1'); % read in record marker and discard
        
        datas(current_sample+1:current_sample+nsamples) = block;
        
        current_sample = current_sample + nsamples;
        
        info.ts(index) = timestamp;
        info.nsamples(index) = nsamples;
        
        info.recNum(index) = recNum;
        
        
    end
    
end


% crop data to the correct size
datas = datas(1:current_sample);
info.ts = info.ts(1:index);
info.nsamples = info.nsamples(1:index);


info.recNum = info.recNum(1:index);


% convert to microvolts
datas = datas.*info.header.bitVolts;

timestamps = nan(size(datas));

current_sample = 0;



for record = 1:length(info.ts)
    
    ts_interp = info.ts(record):info.ts(record)+info.nsamples(record);
    
    timestamps(current_sample+1:current_sample+info.nsamples(record)) = ts_interp(1:end-1);
    
    current_sample = current_sample + info.nsamples(record);
end

%% New Triggers - QUAD CAPTURE

highthresh= 2.5;

hithreshxindex=find(diff(datas>highthresh));

if isempty(hithreshxindex)
    error('No new trial start triggers detected. Assume that experiment has finished. Aborting.');
end

stim_start=hithreshxindex(find(datas(hithreshxindex)<highthresh))+1;
stim_end=hithreshxindex(find(datas(hithreshxindex)>highthresh));
 



%% Old Triggers - EMU
% lowthresh= -1; highthresh= 0; %prebuffer=1.0*info.header.sampleRate;
% %buffer of 1s before end of stimulus presentation:
% 
% lothreshxindex=find(datas<lowthresh); 
% if isempty(lothreshxindex)
%     error('No trial triggers detected. Assume that experiment has finished. Aborting.'); %return
% end
% stim_end=lothreshxindex(find(diff(lothreshxindex)>5000));
% if ~isempty(stim_end)
% 	stim_end=[stim_end, lothreshxindex(end)];
% elseif isempty(stim_end)
% 	stim_end=lothreshxindex(1);
% end
% 
% hithreshxindex=find(datas>highthresh); 
% if isempty(hithreshxindex)
%     error('No new trial start triggers detected. Assume that experiment has finished. Aborting.'); %return
% end
% 
% 
% stim_start=hithreshxindex(find(diff(hithreshxindex)>5000)); 
% if ~isempty(stim_start)
% 	stim_start=[stim_start, hithreshxindex(end)];
% elseif isempty(stim_start)
% 	stim_start=hithreshxindex(1);
% end
%%

% % RJM 
% if ignorefirst>0
%     stim_start=stim_start(2:end);
%     stim_end=stim_end(2:end);
% end

%What happens if we read the file before a trial has finished (so there is
%an up deflection by not a down deflection. Need to reset location to that
%uppoint, and start from there. While matching the location of the spikes
%read location. 
if numel(stim_start) ~= numel(stim_end)
	%if ~isempty(stim_start) & ~isempty(stim_end) %this is hacky and may need some fixing....
    if stim_start(end)>stim_end(end) %if we have a trial trigger start, but not the trial trigger end, count to the end of the timestamps
        %stim_start(end)=[];
		stim_end=[stim_end, numel(timestamps)];
        specialcase='cutoffending';
        disp('Warning: the read section ended before the last trial ended');
    else %if we have a trial trigger end, but not the start, start the first bin at the start of the recording
        
		%stim_start=stim_start(2:end);
		stim_start=[1, stim_start];
        specialcase='cutoffstart';
        disp('Warning: the read section started after the first trial started');
	end
	%end
else
    specialcase='none';
end

stimsout(:,1)=timestamps(stim_start);
stimsout(:,2)=timestamps(stim_end);

%Convert times into real time
if (isfield(info.header,'sampleRate'))
    if ~ischar(info.header.sampleRate)
        stimsout = stimsout./info.header.sampleRate; % convert to seconds
    end
end

end

function filesize = getfilesize(eid, offline)
fposition=ftell(eid);
fseek(eid,0,'eof');
filesize = ftell(eid);

if offline > 0 
fseek(eid,0,'bof'); %returns the position to start of file
else
fseek(eid,fposition,'bof'); %returns the position to where it was when the code was entered.
end

end