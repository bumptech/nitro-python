from pynitro import NitroSocket, NitroFrame
import time

ns = NitroSocket()
ns.bind("tcp://127.0.0.1:7723")

fr = ns.recv()
print fr
print fr.data
ns.send(NitroFrame("my only sunshine"))
fr = ns.recv()
print fr
print fr.data
ns.send(NitroFrame("when skies are gray"))
time.sleep(4)
