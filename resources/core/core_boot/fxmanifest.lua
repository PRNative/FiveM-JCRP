fx_version 'cerulean'
game 'gta5'

lua54 'yes'
server_only 'yes'

name 'core_boot'
description 'P0: DB health + config + migrations runner (startup gate)'
author 'JCRP'
version '0.1.0'

dependency 'oxmysql'

files {
  'config/*.json',
  'migrations/*.sql',
  'migrations/migrations.json',
}

server_scripts {
  '@oxmysql/lib/MySQL.lua',
  'server/*.lua',
}

