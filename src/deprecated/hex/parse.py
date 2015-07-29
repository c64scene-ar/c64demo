fh = open("dick_3.64c", "rb")
#fh = open("blue_max_charset.64c", "rb")
data = fh.read()[2:]
fh.close()

def decode(b):
  return bin(ord(b))[2:].zfill(8)

i = 0
for b in data:
  print decode(b).replace("0", ".")
  if (i+1) % 8 == 0:
    print ""
  i += 1

print i
