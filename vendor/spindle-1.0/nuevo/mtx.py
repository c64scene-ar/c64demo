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
  changes = {} 
  for y in range(25):
    for x in range(40):
      if m1[x][y] != m2[x][y]:
        if m2[x][y] not in changes.keys():
          changes[m2[x][y]] = []
        changes[m2[x][y]].append(x + y * 40)
  return changes

def apply_palette(m):
  p = [1,1,15,15,10,10,12,12,4,4,4,4,11,11,0,0]
  for y in range(25):
    for x in range(40):
      #m[x][y] = m[x][y] if m[x][y] < 16 else 0 
      #m[x][y] = m[x][y] if m[x][y] < 16 else 0 
      m[x][y] = p[m[x][y]] if m[x][y] < 16 else p[15] 


#def serialize(changes):
#  ret = struct.pack("<H", len(changes))
#  for c in changes:
#    ret += struct.pack("<H", c[0])
#    ret += struct.pack("<B", c[1])
#  return ret

def serialize(changes, offset):
  code = ""
  for color in changes.keys():
    code += "\xa9" + chr(color)
    for pos in changes[color]:
      code += "\x8d" + struct.pack("<H", offset + pos) # STA pos
  return code


def encode(input_string):
    count = 1
    prev = ''
    lst = []
    for character in input_string:
        if character != prev:
            if prev:
                entry = (prev,count)
                lst.append(entry)
                #print lst
            count = 1
            prev = character
        else:
            count += 1
    else:
        entry = (character,count)
        lst.append(entry)

    return lst
 
def add_swap(n):
  ret = "\xa9"
  if n % 2 == 0:
    ret += "\x18"
  else:
    ret += "\x38"
  ret += "\x8D\x18\xD0" # STA $d018
  return ret 


def add_until_raster0():
  wait_loop = "\xA6\xFA\xE8\x86\xFA\xE0\xff\xD0\xF7\xA4\xFB" #\xC8\x84\xFB\xC0\x02\xD0\xEE"
  wait_loop += "\xa9\x00\xcd\x12\xd0\xd0\xf9" # wait until rasterline == 0
  return wait_loop

def draw_bar(m, x1, x2, y, col):
  for x in range(x1, x2):
    m[x][y] = col

def draw_bars(m, y):
  if y in [0,1,2,3,4]:
    draw_bar(m, 0, 6, y, 11)
    draw_bar(m, 6, 34, y, 5)
    draw_bar(m, 34, 40, y, 11)
  if y == 3:
    draw_bar(m, 0, 10, y, 11)
    draw_bar(m, 10, 30, y, 5)
    draw_bar(m, 30, 40, y, 11)
  if y == 4:
    draw_bar(m, 0, 10, y, 11)
    draw_bar(m, 10, 30, y, 5)
    draw_bar(m, 30, 40, y, 11)
  if y == 5:
    draw_bar(m, 0, 10, y, 11)
    draw_bar(m, 10, 30, y, 5)
    draw_bar(m, 30, 40, y, 11)
  if y == 6:
    draw_bar(m, 0, 10, y, 11)
    draw_bar(m, 10, 30, y, 5)
    draw_bar(m, 30, 40, y, 11)
  if y == 7:
    draw_bar(m, 0, 10, y, 11)
    draw_bar(m, 10, 30, y, 5)
    draw_bar(m, 30, 40, y, 11)
  if y == 8:
    draw_bar(m, 0, 10, y, 11)
    draw_bar(m, 10, 30, y, 5)
    draw_bar(m, 30, 40, y, 11)
  if y == 9:
    draw_bar(m, 0, 10, y, 11)
    draw_bar(m, 10, 30, y, 5)
    draw_bar(m, 30, 40, y, 11)












m_empty = [[0 for y in range(25)] for x in range(40)] 
full_changes = ""

j = 0
matrices = []
for i in range(0, 25):
  m = [[0 for y in range(25)] for x in range(40)] 
#  do_circle(m, cos(i/10.0)*10+20, sqrt(i/10.0)*10+10, abs(tan(i/50.0)) * 10)
#  do_circle(m, cos(i/10.0)*10+20, sin(i/10.0)*10+10, abs(tan(i/10.0)) * 10)
#  do_circle(m, cos(i/10.0)*10+20, sin(i/10.0)*10+10, 10) # abs(atan((i-10)/50.0)) * 10)
  #do_circle(m, sin(i/10.0)*10+20, cos(i/10.0)*10+10, abs(atan(i/50.0)) * 10)
  #do_circle(m, cos(i/10.0)*10+20, sin(i/10.0)*10+10, abs(cos(i/50.0)) * 10)
#  do_circle(m, 9, 9, 10)
  for asd in range(25):
    draw_bars(m, asd)
 

  #apply_palette(m)
  if True or i % 2 == 0:
    matrices.append(m)
    show_mtx(m)
    if j > 1:
      changes = cmp_mtx(matrices[j - 2], m)
    else:
      changes = cmp_mtx(m_empty, m)
    screen_addr = 0x400 if j % 2 == 0 else 0xc00
    full_changes += add_until_raster0()
    full_changes += serialize(changes, screen_addr)
    full_changes += add_swap(j)
    j += 1
    #time.sleep(0.1)


print Fore.WHITE + Style.NORMAL + "Effect table len: ", len(full_changes)
#print  full_changes.encode("hex")

fh = open("fx.bin", "wb")
fh.write(full_changes)
fh.close()




