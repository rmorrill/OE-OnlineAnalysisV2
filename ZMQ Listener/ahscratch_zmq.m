%%
context = zmq_ctx_new()
socket = zmq_socket(context,'ZMQ_SUB')
zmq_setsockopt(socket, 'ZMQ_SUBSCRIBE', ''); 
%socket = zmq_socket(context,'ZMQ_PULL');
% address = 'tcp://169.230.189.202:5555';
address = 'tcp://169.230.189.136:5556'
zmq_bind(socket, address)
% zmq_connect(socket, address)

%%
result  = zmq_recv(socket,'ZMQ_DONTWAIT')
disp(result)

%%
    zmq_disconnect(socket, address)
    zmq_close(socket)
    
    zmq_ctx_shutdown(context)
    zmq_ctx_term(context)
