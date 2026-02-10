fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'FiveM Platform Foundation'
description 'P1: Hunger, thirst, stress persistence'
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
  'core_session',
}

provides {
  'system_status',
}
