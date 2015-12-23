import sys
import struct

def find_addr(start):
  # http://codebase64.org/doku.php?id=base:vicii_memory_organizing
  # https://www.c64-wiki.com/index.php/Bank_Switching
  # http://static1.squarespace.com/static/511651d6e4b0a31c035e30aa/t/51699707e4b0e454d771ddd6/1365874440449/memory_map.png

  blacklist = [ ( 0x0000, 0x3000),   # spindle, music, zero page vars, code
                ( 0x4000, 0x5800),   # 0x800 * 2 (charset size) + 0x400 * 2 (screen size) for double buffering
                ( 0x9000, 0xa000),   # charset (from VIC)
                ( 0xd000, 0xe000) ]  # char gen, i/o, color

  j = 0x400
  start += j
  while any([bs[0] <= start < bs[1] for bs in blacklist]):
    start += j

  return start
 
def split_data(name, data, w, addr):
  n = 0
  screen_tbl = []
  for j in range(0, w, 40):
    sc_data = []
    for i in range(j, len(data), w):
      sc_data.append(data[i:i+40])
    sc_data = "".join(sc_data)

    addr = find_addr(addr)
    if addr is None:
      print "Cannot fit the " + name + " RAM at", i, "petscii too big?"
      sys.exit(0)

    sc_data = struct.pack("<H", addr) + data[i:i+w]
    fh = open("split/" + name + "-" + str(n) + ".c64", "wb")
    fh.write(sc_data)
    fh.close()
    n += 1
    screen_tbl.append("$" + hex(addr)[2:])

  print name + "_tbl: .word " + ",".join(screen_tbl)

  return addr
        
screen_ram = open("screen-0.c64").read()
color_ram = open("color-0.c64").read()
w, h = map(int, open("imagedata.c64").read().split(","))

addr = split_data("screen", screen_ram, w, 0)
addr = split_data("color", color_ram, w, addr)

print "idiv25timesw: .byt " + ",".join(str(i/25*w) for i in range (255))
print "idiv40: .byt " + ",".join(str(i / 40) for i in range (255))
print "imod25: .byt " + ",".join(str(i % 25) for i in range (255))
print "imod40: .byt " + ",".join(str(i % 40) for i in range (255))
print "viewport_x: .byt 0"
print "viewport_y: .byt 0"
