import os
import sys
from math import *
import time
import struct
from colorama import Fore, Back, Style

c64p = { 0: (Fore.BLACK, Style.DIM),
         1: (Fore.WHITE, Style.BRIGHT),
         2: (Fore.RED, Style.DIM),
         3: (Fore.CYAN, Style.DIM),
         4: (Fore.MAGENTA, Style.DIM),
         5: (Fore.GREEN, Style.DIM),
         6: (Fore.BLUE, Style.DIM),
         7: (Fore.YELLOW, Style.BRIGHT),
         8: (Fore.RED, Style.BRIGHT),
         9: (Fore.YELLOW, Style.NORMAL),
        10: (Fore.MAGENTA, Style.BRIGHT),
        11: (Fore.BLACK, Style.BRIGHT),
        12: (Fore.WHITE, Style.DIM),
        13: (Fore.GREEN, Style.BRIGHT),
        14: (Fore.BLUE, Style.BRIGHT),
        15: (Fore.WHITE, Style.NORMAL) }

def show_mtx(m):
  #os.system("clear")
  #sys.stderr.write("\x1b[2J\x1b[H")

  for y in range(len(m)):
    for x in range(len(m)):
      cols = c64p[m[x][y] % len(c64p)]
      sys.stdout.write( cols[0] + cols[1] + chr(219).decode('cp437')) #str(m[x][y]).zfill(2),
      sys.stdout.write( cols[0] + cols[1] + chr(219).decode('cp437')) #str(m[x][y]).zfill(2),
    print ""

mtx_size = 16
m = [[0 for y in range(mtx_size)] for x in range(mtx_size)]
mr = [[0 for y in range(mtx_size)] for x in range(mtx_size)]

c = """x......x
.x....x.
..x..x..
...xx...
...xx...
..x..x..
.x....x.
x......x"""

c = """........
...xx...
...xx...
...xx...
..xxxx..
.xx..xx.
.x....x.
........"""

#y = 0
#for l in c.split("\n"):
#  for x in range(8):
#    m[x][y] = 0 if l[x] == "." else 1
#  y += 1

for y in range(len(m)):
  for x in range(len(m)):
    if y < len(m) / 2.0:
      if len(m)/2.0 - 2 < x < len(m)/2.0 + 1:
        m[x][y] = 1
    else:
      if x == y:
        m[x][y] = 1
      if x == len(m)-1-y:
        m[x][y] = 1
      if x == y+1:
        m[x][y] = 1
      if x == len(m)-1-y-1:
        m[x][y] = 1


show_mtx(m)
print Fore.WHITE + Style.BRIGHT

mystr = ""
for x in range(10):
  mystr += "".join(str(x) for x in range(10))
print mystr

#for k in range(1,90):
#  alpha = 8*pi / k
alpha = pi / 6.0
if alpha:
  for y in range(len(m)):
    for x in range(len(m)):
      x_coord = len(m)/2 - x
      y_coord = len(m)/2 - y
      new_x = int(round(x_coord * cos(alpha) - y_coord * sin(alpha))) + len(m)/2
      new_y = int(round(x_coord * sin(alpha) + y_coord * cos(alpha))) + len(m)/2

   #   print x_coord, y_coord, "(", m[x][y], ")", "=>", new_x, new_y
     
      if (m[x][y] == 1) and (new_x >= 0) and (new_y >= 0) and (new_x < len(m)) and (new_y < len(m)):
        mr[new_x][new_y] = 1

  time.sleep(0.5)
  show_mtx(mr)
  mr = [[0 for y in range(len(m))] for x in range(len(m))]



#for y in range(8):
#  b = ""
#  for x in range(8):
#    if x in [3,4] and 1 <= y <= 3:
#      m[x][y] = 1
#    elif (x in [2,3] or x in [4,5]) and y == 4:
#      m[x][y] = 1
#    elif (x in [1,2] or x in [5,6]) and y == 5:
#      m[x][y] = 1
#    elif (x in [0,1] or x in [6,7]) and y == 6:
#      m[x][y] = 1
#    else:
#      m[x][y] = 0

print Fore.WHITE + Style.BRIGHT
