fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'FiveM Platform Foundation'
description 'P0: Spawn selection (last location, predefined, new char default)'
version '1.0.0'

shared_scripts {
  '@ox_lib/init.lua',
}

server_scripts {
  'server.lua',
}

client_scripts {
  'client.lua',
}

dependencies {
  'oxmysql',
  'ox_lib',
  'core_boot',
  'core_state',
}

provides {
  'core_spawn',
}
