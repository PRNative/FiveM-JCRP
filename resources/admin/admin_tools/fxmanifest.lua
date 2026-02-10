fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'FiveM Platform Foundation'
description 'Admin import/export, character tools'
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
  'core_identity',
  'core_characters',
  'core_state',
  'core_session',
  'core_spawn',
  'system_money',
  'system_inventory',
  'system_jobs',
  'system_status',
  'system_permissions',
}

provides {
  'admin_tools',
}
