// load sid music

.var music = LoadSid("/home/mica/Projects/c64demo/resources/jeff_donald.sid")
.pc = music.location
.fill music.size, music.getData(i)