fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'FiveM Platform Foundation'
description 'P1: Job assignment, grades, duty'
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
  'core_session',
}

provides {
  'system_jobs',
}
