// load sid music

.var music = LoadSid("src/res/jeff_donald.sid")
.pc = music.location
.fill music.size, music.getData(i)