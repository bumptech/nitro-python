from pynitro import NitroSocket, NitroFrame
import time

ns = NitroSocket()
ns.connect('tcp://127.0.0.1:7723')

ns.send(NitroFrame("you are my sunshine!"))
fr = ns.recv()
print fr.data
ns.send(NitroFrame("you make me happy"))
fr = ns.recv()
print fr.data

time.sleep(4)
