function expt_ZMQ_listener(port)

savedir = 'C:\Users\hlab\Documents\Data\exptStimData\';  % for saving trial info

if ~isdir(savedir)
	mkdir(savedir)
end

% Socket to talk to server
context = zmq_ctx_new();
socket = zmq_socket(context, 'ZMQ_SUB');
disp('SUB socket opened');
fid = []; 
address = sprintf('tcp://169.230.189.202:%d', port);

finishup = onCleanup(@()cleanupFun(socket,address,context, fid));

zmq_connect(socket, address);


disp('Connection established');
disp('Setting subscribe options');
%topicfilter = 'EXP';
topicfilter = ''; 
zmq_setsockopt(socket, 'ZMQ_SUBSCRIBE', topicfilter);
zmq_setsockopt(socket, 'ZMQ_RCVTIMEO', 1000);
zmq_setsockopt(socket, 'ZMQ_MAXMSGSIZE', -1);

message = [];
olddatetime = []; 
while (1) % check for a message every 100ms
	try
		message = char(zmq_recv(socket));
		disp('*** Message received ***');
		% check for multi-part
		c = 1;
		while zmq_getsockopt(socket, 'ZMQ_RCVMORE')
			message_more{c} = zmq_recv(socket);
			c = c+1;
		end
		
		if exist('message_more', 'var');
			message = [message message_more{:}];
		end
		clear message_more
		disp(message);
		datetime = char(regexp(message, '\d{2}-\d{2}-\d{2}-\d{4}', 'match'));
		if ~isempty(datetime) %EXP header message received
			if ~isempty(fid) && ~strcmp(datetime, olddatetime) %if a new header has been received 
				disp('***CLOSING OLD FILE***');
				fclose(fid); % close and delete 
				fid = []; 
			end 
			if isempty(fid)
				disp('***WRITING TO NEW FILE***'); 
				fid = fopen(sprintf('%sexp%sall.txt', savedir, datetime), 'w+t');
				olddatetime = datetime;
			end
		end
		if ~isempty(fid)
			fwrite(fid, sprintf('\n%s\n', message), 'char*1'); 
		end
		[var_list,stim_vals] = parse_ZMQ_msg(message); 
		save([savedir 'exp' datetime 'stim.mat'], 'var_list', 'stim_vals'); 
		disp('Message saved'); 
		% save code
	catch me 
	end
	%tic; while toc < 0.1; end
	disp('Waiting...');
end

function cleanupFun(socket, address, context, fid)
try
	if ~isempty(fid)
		fclose(fid);
	end
catch me
end

zmq_disconnect(socket, address);
disp('*** Disconnect addr');
zmq_close(socket);
disp('*** Close socket');
zmq_ctx_shutdown(context);
disp('*** Shutdown context');
zmq_ctx_term(context);
