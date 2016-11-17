#!/usr/bin/python

import socket
import struct
import sys

address = sys.argv[1]
cmd = sys.argv[2]

sock = socket.socket()
sock.connect((address, 5353))

def send_raw(message_data):
    request = struct.pack("!BI", 3, len(message_data))
    sock.send(request)
    sock.send(message_data)

def send_message(message_str):
    message_data = message_str.encode('utf-8')
    send_raw(message_data)

def recv_size():
    request = struct.pack("!B", 2)
    sock.send(request)
    response = sock.recv(5)
    (cmd, l) = struct.unpack("!BI", response)
    return l

def recv_message():
    response = sock.recv(5)
    (cmd, l) = struct.unpack("!BI", response)
    data = sock.recv(l)
    return data.decode('utf-8')

def recv_index(i):
    request = struct.pack("!BI", 4, i)
    sock.send(request)
    return recv_message()

def subscribe():
    request = struct.pack("!B", 5)
    sock.send(request)

def recv_wait():
    request = struct.pack("!B", 6)
    sock.send(request)

if cmd == 'echo':
    send_message(sys.argv[3] + '\n')
elif cmd == 'cat':
    raw = sys.stdin.read()
    send_raw(raw)
elif cmd == 'tee':
    raw = sys.stdin.read()
    send_raw(raw)
    sys.stdout.write(raw)
elif cmd == 'recent':
    sz = recv_size()
    print(recv_index(sz - 1))
elif cmd == 'list':
    sz = recv_size()
    for i in range(sz):
        print(recv_index(i))
elif cmd == 'follow':
    subscribe()
    while True:
        recv_wait()
        print(recv_message())
elif cmd == 'wait':
    wait_of = sys.argv[3]
    subscribe()
    while True:
        recv_wait()
        if wait_of == recv_message().strip():
            break
