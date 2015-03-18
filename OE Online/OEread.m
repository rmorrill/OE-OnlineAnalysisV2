function [spikes_per_trial] = OEread (fid, ttlinfo, offline, sortedFlag)
EXIT_NOW=0;
%% Open Ephys, modified by Astra S Bryant
% This code is called by OEwrapper. It is used to query the spikes channel of
% an open-ephys recording to determine spike times
while EXIT_NOW<1;
MAX_NUMBER_OF_SPIKES = 1e6;
NUM_HEADER_BYTES = 1024;
%timestamps=zeros(1,MAX_NUMBER_OF_SPIKES);
filesize = getfilesize(fid, offline);

if ftell(fid)==0
    hdr = fread(fid, NUM_HEADER_BYTES, 'char*1');
    eval(char(hdr'));
else
    fposition=ftell(fid);
    fseek(fid,0,'bof');
    hdr = fread(fid, NUM_HEADER_BYTES, 'char*1');
    eval(char(hdr'));
    fseek(fid,fposition,'bof'); %returns the position to where it was when the code was entered.
    
end

info.header = header;

num_channels = info.header.num_channels;
num_samples = 40; % **NOT CURRENTLY WRITTEN TO HEADER** % RJM what does this mean? 

current_spike = 0;


while ftell(fid) + 512 < filesize % at least one record remains:
	try
    current_spike = current_spike + 1;
    fseek(fid,1,'cof');
           %a=ftell(fid); %for debugging the fseek positioning
           %disp(a)
    timestamps(current_spike) = fread(fid, 1, 'int64', 0, 'l');
	
    %disp(ftell(fid));
    secondskip=8+2+2+2;
    fseek(fid,secondskip,'cof');
    %       a=ftell(fid);  for debugging the fseek positioning
    %       disp(a)
    
    
    info.sortedId(current_spike) = fread(fid, 1, 'uint16',0,'l');
    lastskip= 2+2+(3*1)+(2*4)+(num_channels*num_samples*2)+(num_channels*4)+(num_channels*2)+2+2;
    fseek(fid,lastskip,'cof');
	catch
		current_spike=current_spike-1;
		disp(sprintf('Number of spikes detected: %d',current_spike))
		disp('Something funky in the .spike file; exiting early this may mean that subsequent calls are FUBRed');
		break
	end
end


if current_spike==0
	spikes_per_trial={};
	EXIT_NOW=1;
	break
end

if sortedFlag
    unsortedtimestamps = timestamps(1:current_spike);
    info.sortedId = info.sortedId(1:current_spike);
    timestamps=unsortedtimestamps(find(info.sortedId>0));
    disp(sprintf('%d percent of waveforms are sorted units', round((size(timestamps,2)/size(unsortedtimestamps,2))*100)));
else
    disp('Sorted units box not checked: all waveforms crossing threshold will be included in analysis');
end

if (isfield(info.header,'sampleRate'))
    if ~ischar(info.header.sampleRate)
        timestamps = timestamps./info.header.sampleRate; % convert to seconds
    end
end


trialno=1;
spikes_per_trial = cell(1, size(ttlinfo,1)); 
for i= 1:size(ttlinfo,1)
    %tempe=timestamps;
    spikes_per_trial{trialno}=timestamps(timestamps>ttlinfo(i,1) &  timestamps<ttlinfo(i,2))-ttlinfo(i,1);
    %norm_spikes_per_trial{trialno}=spikes_per_trial{trialno}-spikes_per_trial{trialno}(1);
    trialno=trialno+1;
end
EXIT_NOW=1;
%disp(ftell(fid))


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