fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'FiveM Platform Foundation'
description 'P0: NUI Loading screen'
version '1.0.0'

loadscreen 'html/index.html'
loadscreen_manual_shutdown 'yes'

files {
  'html/index.html',
  'html/style.css',
  'html/script.js',
  'config.json',
}

client_scripts {
  'client.lua',
}
