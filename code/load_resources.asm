// load sid music

.var music = LoadSid("resources/jeff_donald.sid")
.pc = music.location
.fill music.size, music.getData(i)