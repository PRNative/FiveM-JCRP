fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'FiveM Platform Foundation'
description 'P0: Login flow, character select, session management'
version '1.0.0'

ui_page 'html/index.html'

shared_scripts {
  '@ox_lib/init.lua',
}

client_scripts {
  'client.lua',
}

server_scripts {
  'server.lua',
}

files {
  'html/index.html',
  'html/style.css',
  'html/script.js',
}

dependencies {
  'oxmysql',
  'ox_lib',
  'core_boot',
  'core_identity',
  'core_characters',
  'core_state',
  'core_spawn',
}

-- Optional: system_money for starter cash (not required for P0)

provides {
  'core_session',
}
