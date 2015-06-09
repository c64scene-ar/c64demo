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
  sys.stderr.write("\x1b[2J\x1b[H")

  for y in range(25):
    for x in range(40):
      cols = c64p[m[x][y]]
      sys.stdout.write( cols[0] + cols[1] + chr(219).decode('cp437')) #str(m[x][y]).zfill(2),
      sys.stdout.write( cols[0] + cols[1] + chr(219).decode('cp437')) #str(m[x][y]).zfill(2),
    print ""

def do_circle(m, xc, yc, r):
  for y in range(25):
    for x in range(40):
      dist = sqrt((y-yc)**2 + (x-xc)**2)
      if dist < r:
        m[x][y] = int(dist)

def cmp_mtx(m1, m2):
  changes = []
  for y in range(25):
    for x in range(40):
      if m1[x][y] != m2[x][y]:
        changes.append(( x + y * 25, m2[x][y] ))
  return changes

def apply_palette(m):
  p = [1,1,15,15,10,10,12,12,4,4,4,4,11,11,0,0]
  for y in range(25):
    for x in range(40):
      #m[x][y] = m[x][y] if m[x][y] < 16 else 0 
      #m[x][y] = m[x][y] if m[x][y] < 16 else 0 
      m[x][y] = p[m[x][y]] if m[x][y] < 16 else p[16 - m[x][y]] 

def serialize(changes):
  ret = struct.pack("<H", len(changes))
  for c in changes:
    ret += struct.pack("<H", c[0])
    ret += struct.pack("<B", c[1])
  return ret

prev_m = [[0 for y in range(25)] for x in range(40)] 
full_changes = ""

for i in range(0, 200):
  m = [[15 for y in range(25)] for x in range(40)] 
  #do_circle(m, cos(i/10.0)*10+20, sqrt(i/10.0)*10+10, abs(tan(i/50.0)) * 10)
  do_circle(m, cos(i/10.0)*10+20, sin(i/10.0)*10+10, abs(tan(i/10.0)) * 10)
  #do_circle(m, cos(i/10.0)*10+20, sin(i/10.0)*10+10, abs(atan((i-10)/50.0)) * 10)
  do_circle(m, sin(i/10.0)*10+20, cos(i/10.0)*10+10, abs(atan(i/50.0)) * 10)
  #do_circle(m, cos(i/10.0)*10+20, sin(i/10.0)*10+10, abs(cos(i/50.0)) * 10)
  apply_palette(m)
  if i % 4 == 0:
    show_mtx(m)
    changes = cmp_mtx(prev_m, m)
    full_changes += serialize(changes)
    time.sleep(0.1)
  prev_m = m


print Fore.WHITE + Style.NORMAL + "Effect table len: ", len(full_changes)
#print  full_changes.encode("hex")


