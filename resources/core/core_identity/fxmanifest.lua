fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'FiveM Platform Foundation'
description 'P0: Account resolution, bans, audit logging'
version '1.0.0'

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
}

provides {
  'core_identity',
}
