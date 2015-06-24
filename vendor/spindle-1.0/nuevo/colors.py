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
15: (Fore.WHITE, Style.NORMAL),
#8: (Fore.orange
#9: (Fore.brown
#10: (Fore.RED, BRIGHT
}

for x in c64p.keys():
  print c64p[x][0] + c64p[x][1] + "Hello"


