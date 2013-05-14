from pynitro import NitroSocket, NitroFrame
import time
import select

ns = NitroSocket(want_eventfd=True)
ns.bind("tcp://127.0.0.1:7723")

select.select([ns], [], [])
fr = ns.recv(NitroSocket.NOWAIT)
print fr
print fr.data
ns.send(NitroFrame("my only sunshine"))
select.select([ns], [], [])
fr = ns.recv(NitroSocket.NOWAIT)
print fr
print fr.data
ns.send(NitroFrame("when skies are gray"))
time.sleep(4)
