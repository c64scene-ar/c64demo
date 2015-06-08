import os
from math import *
import time
import struct

def show_mtx(m):
  os.system("clear")
  for y in range(25):
    for x in range(40):
      print str(m[x][y]).zfill(2),
    print ""

def do_circle(m, xc, yc, r):
  for y in range(25):
    for x in range(40):
      dist = sqrt((y-yc)**2 + (x-xc)**2)
      if dist < r:
        m[x][y] = int(dist)
  apply_palette(m)

def cmp_mtx(m1, m2):
  changes = []
  for y in range(25):
    for x in range(40):
      if m1[x][y] != m2[x][y]:
        changes.append(( x + y * 25, m2[x][y] ))
  return changes

def apply_palette(m):
  for y in range(25):
    for x in range(40):
      m[x][y] = m[x][y] #if m[x][y] < 5 else 5 

def serialize(changes):
  ret = struct.pack("<H", len(changes))
  for c in changes:
    ret += struct.pack("<H", c[0])
    ret += struct.pack("<B", c[1])
  return ret

prev_m = [[0 for y in range(25)] for x in range(40)] 
full_changes = ""

for i in range(0, 160):
  m = [[0 for y in range(25)] for x in range(40)] 
  #do_circle(m, cos(i/10.0)*10+20, sqrt(i/10.0)*10+10, abs(tan(i/50.0)) * 10)
  do_circle(m, cos(i/10.0)*10+20, sin(i/10.0)*10+10, abs(tan(i/50.0)) * 10)
  #do_circle(m, sin(i/10.0)*10+20, cos(i/10.0)*10+10, abs(atan(i/50.0)) * 10)
  #do_circle(m, cos(i/10.0)*10+20, sin(i/10.0)*10+10, abs(tan(i/50.0)) * 10)
  if i % 2 == 0:
    show_mtx(m)
    changes = cmp_mtx(prev_m, m)
    full_changes += serialize(changes)
    time.sleep(0.1)
  prev_m = m


print "Effect table len: ", len(full_changes)
print  full_changes.encode("hex")


