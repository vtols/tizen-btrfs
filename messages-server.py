#!/usr/bin/python3

import socket
import struct
import threading

class MessagesServer:
    def __init__(self):
        self.messages = []
        self.messages_lock = threading.Lock()
        self.new_message = None
        self.new_message_cv = threading.Condition()

    def put_message(self, message):
        with self.new_message_cv:
            self.messages.append(message)
            self.new_message = message
            self.new_message_cv.notify_all()

    def wait_message(self):
        wait_result = None
        with self.new_message_cv:
            self.new_message_cv.wait()
            wait_result = self.new_message
        return wait_result

    def get_message(self, index):
        result = None
        if index < len(self.messages):
            result = self.messages[index]
        return result

    def communicate(self, sock):
        def read_data(fmt):
            data = sock.recv(struct.calcsize(fmt))
            if data:
                return struct.unpack(fmt, data)

        def send_data(fmt, *data):
            sock.send(struct.pack(fmt, *data))

        waiter = None

        while True:
            # Read cmd
            cmd_data = read_data("!B")
            if not cmd_data:
                break
            (cmd, ) = cmd_data

            # Cmd 0 - echo
            if cmd == 0:
                send_data("!B", 0)
            # Cmd 1 - bye
            if cmd == 1:
                break
            # Cmd 2 - request queue size
            elif cmd == 2:
                send_data("!BI", 2, len(self.messages))
            # Cmd 3 - put message
            elif cmd == 3:
                # Read message size
                (message_size, ) = read_data("!I")
                # Read message
                data = sock.recv(message_size)
                self.put_message(data)
            # Cmd 4 - get message by index  
            elif cmd == 4:
                # Read index
                (message_index, ) = read_data("!I")
                message = self.get_message(message_index)
                if message:
                    send_data("!BI", 4, len(message))
                    sock.send(message)
                else:
                    send_data("!BI", 4, 0)
            # Cmd 5 - subscribe for new messages
            elif cmd == 5:
                waiter = MessageWait(self)
                waiter.start()
            # Cmd 6 - get if has new messages
            elif cmd == 6:
                message = waiter.get()
                if message:
                    send_data("!BI", 6, len(message))
                    sock.send(message)
                else:
                    send_data("!BI", 6, 0)
        if waiter:
            waiter.stop_waiting()
        sock.shutdown(socket.SHUT_RDWR)
        sock.close()

class ClientThread (threading.Thread):
    def __init__(self, server, socket):
        threading.Thread.__init__(self)
        self.server = server
        self.socket = socket

    def run(self):
        self.server.communicate(self.socket)

class MessageWait (threading.Thread):
    def __init__(self, server):
        threading.Thread.__init__(self)
        self.server = server
        self.go = True
        self.queue = []
        self.queue_sem = threading.Semaphore(value=0)

    def run(self):
        while self.go:
            self.queue.append(self.server.wait_message())
            self.queue_sem.release()

    def get(self):
        self.queue_sem.acquire()
        return self.queue.pop(0)

    def stop_waiting(self):
        self.go = False

def run_server(port):
    server = MessagesServer()
    server_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server_sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server_sock.bind(('', port))
    server_sock.listen(5)

    while True:
        (client_sock, client_addr) = server_sock.accept()
        #client_sock.settimeout(3)
        cl = ClientThread(server, client_sock)
        cl.start()

if __name__ == "__main__":
    run_server(5353)
