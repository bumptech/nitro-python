import thread
import pynitro
from time import sleep

from pynitro import NitroSocket, NitroFrame

def listener():
    print 'one!'
    s = NitroSocket()
    s.connect("tcp://127.0.0.1:4444")
    s.sub("foo")

    print 'one!'

    while True:
        fr = s.recv()
        print fr.data

def listener2():
    s = NitroSocket()
    s.connect("tcp://127.0.0.1:4444")
    s.sub("fool")

    print 'two!'

    while True:
        fr = s.recv()
        print fr.data

def broadcaster():
    print 'three!'
    s = NitroSocket()
    s.bind("tcp://127.0.0.1:4444")
    s.sub("foo")
    sleep(0.4)

    print 'moving on!'

    assert s.pub("food", NitroFrame("hungry?")) == 1
    assert s.pub("fool", NitroFrame("silly?")) == 2
    assert s.pub("barn", NitroFrame("moo!")) == 0
    sleep(0.5)
    print " ~~ Everyone wins! ~~"

thread.start_new_thread(listener, ())
thread.start_new_thread(listener2, ())
broadcaster()
