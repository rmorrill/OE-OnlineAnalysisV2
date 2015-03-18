function [waveforms, sfq] = OEreadlfp (eid, ttlinfo, offline)
EXIT_NOW=0;
%% Astra S Bryant
% This code is called by OEwrapper. It is used to query the spikes channel of
% an open-ephys recording to determine spike times
while EXIT_NOW<1;
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

timestamps=timestamps./info.header.sampleRate; %convert to seconds
sfq=info.header.sampleRate;
trialno=1;
for i=[1:size(ttlinfo,1)]
    %tempe=timestamps;
    tempe= datas(find( timestamps>=ttlinfo(i,1) &  timestamps<=ttlinfo(i,2)));
	waveforms{trialno}=tempe;
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