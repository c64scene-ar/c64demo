// load sid music

.var music = LoadSid("res/jeff_donald.sid")
//.var music = LoadSid("res/demo.sid")
.pc = music.location
.fill music.size, music.getData(i)
