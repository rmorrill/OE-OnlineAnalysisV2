function [var_list,stim_vals] = parse_ZMQ_msg(tr_seq_str)

i = regexp(tr_seq_str, 'TrialSeq', 'end');
if isempty(i)
    %errordlg('Error: messages sent, but no TrialSeq key found');
    return
end

tr_seq_str = tr_seq_str(i+1:end);
var_list = regexp(tr_seq_str, '[A-Za-z_]{3,}', 'match');

% std_var_list = {'Time'};
% z_var_list = {'Firing rate', 'Variance'};

var_end_inds = regexp(tr_seq_str, '[A-Za-z_]{3,}', 'end');

numVars = numel(var_list);

stim_vals = cell(numVars, 1);

for k = 1:numVars
    if k == numVars
        stim_vals{k,1} = str2double(regexp(tr_seq_str(var_end_inds(k)+1:end), '\s\d+', 'match'));
    else
        stim_vals{k,1} = str2double(regexp(tr_seq_str(var_end_inds(k):var_end_inds(k+1)), '\s\d+', 'match'));
    end
    disp([var_list{k} ' : ' num2str(stim_vals{k,1})]);
end