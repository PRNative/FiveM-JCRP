fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'FiveM Platform Foundation'
description 'P2: Apartments, instanced interiors, stash'
version '0.1.0'

shared_scripts {
  '@ox_lib/init.lua',
}

server_scripts {
  'server.lua',
}

dependencies {
  'oxmysql',
  'ox_lib',
  'core_boot',
  'core_session',
  'system_inventory',
}

provides {
  'system_apartments',
}
