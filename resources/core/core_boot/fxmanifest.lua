fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'FiveM Platform Foundation'
description 'P0: DB connectivity, migrations, config loader, startup gating'
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
}

provides {
  'core_boot',
}
