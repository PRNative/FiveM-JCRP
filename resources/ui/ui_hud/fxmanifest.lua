fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'FiveM Platform Foundation'
description 'P1: HUD - cash, bank, hunger, thirst, job, street'
version '1.0.0'

ui_page 'html/index.html'

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
  'ox_lib',
  'core_session',
  'system_money',
  'system_jobs',
  'system_status',
}

provides {
  'ui_hud',
}
