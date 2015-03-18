%%
context = zmq_ctx_new()
%socket = zmq_socket(context,'ZMQ_REQ')
socket = zmq_socket(context, 'ZMQ_SUB');

zmq_setsockopt(socket, 'ZMQ_RCVTIMEO', 1000);
zmq_setsockopt(socket, 'ZMQ_SUBSCRIBE', '');
%socket = zmq_socket(context,'ZMQ_PULL');
% address = 'tcp://169.230.189.202:5555'; 
%address = 'tcp://localhost:5556'
%address = 'tcp://169.230.189.202:5559';
address = 'tcp://169.230.189.202:5564'; 
zmq_connect(socket, address);
%zmq_bind(socket, address)
%try
 %%
for i = 1:20
    %result =sscanf(char(zmq_recv(socket)));
    try
        result(i)  = zmq_recv(socket); 
        disp(char(result))
    catch me
    end
    % if ~isempty(result);
   
    %  disp(['time : ' num2str(cputime)]);
    %end
    
    % tic; while toc <0.01; end
end
%catch me

me
zmq_disconnect(socket, address);
zmq_close(socket);

zmq_ctx_shutdown(context);
zmq_ctx_term(context);
%end


