import os
from math import cos, sin, sqrt
import time

def show_mtx(m):
  os.system("clear")
  for y in range(25):
    for x in range(40):
      print m[x][y],
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
        changes.append(( x,y,m2[x][y] ))
  print changes, len(changes)

prev_m = [[0 for y in range(25)] for x in range(40)] 

for i in range(0, 40):
  m = [[0 for y in range(25)] for x in range(40)] 
  do_circle(m, cos(i)*i+20, sin(i)*i+10, 4)
  show_mtx(m)
  cmp_mtx(prev_m, m)
  prev_m = m
  time.sleep(0.1)
