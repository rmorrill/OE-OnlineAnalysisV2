
    zmq_disconnect(socket, address);
    zmq_close(socket);

    zmq_ctx_shutdown(context);
    zmq_ctx_term(context);