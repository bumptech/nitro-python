import thread
import pynitro
from time import sleep

from pynitro import NitroSocket, NitroFrame

def backend():
    s = NitroSocket()
    s.bind("tcp://127.0.0.1:4444")

    while True:
        fr = s.recv()
        out = NitroFrame("mega" + fr.data)
        s.reply(fr, out)

def proxy_down(f, b):
    while True:
        fr = f.recv()
        b.relay_fw(fr, fr)

def proxy_up(f, b):
    while True:
        fr = b.recv()
        f.relay_bk(fr, fr)

done = 0
def sender(uniq):
    global done
    s = NitroSocket()
    s.connect("tcp://127.0.0.1:4445")

    for x in xrange(100000):
        fr = NitroFrame(uniq + str(x))
        s.send(fr)
        fr = s.recv()
        assert(fr.data == "mega" + uniq + str(x))

    print uniq, "done!"
    done += 1

proxy_sock_f = NitroSocket()
proxy_sock_b = NitroSocket()
proxy_sock_f.bind("tcp://127.0.0.1:4445")
proxy_sock_b.connect("tcp://127.0.0.1:4444")

thread.start_new_thread(backend, ())
sleep(0.5)
thread.start_new_thread(proxy_down, (proxy_sock_f, proxy_sock_b))
thread.start_new_thread(proxy_up, (proxy_sock_f, proxy_sock_b))
sleep(0.5)
map(lambda id: thread.start_new_thread(sender, (id,)),
    ["dog", "cat", "mouse", "rat"])

while done < 4:
    sleep(0.2)

print ".. All finished"
