fx_version 'cerulean'
game 'gta5'

name 'admin_tools'
description 'JCRP Admin Tools — import/export characters, data migration utilities'
author 'JCRP Team'
version '1.0.0'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    '@core_boot/shared/utils.lua',
    'server/export.lua',
    'server/import.lua',
    'server/commands.lua',
}

dependencies {
    'oxmysql',
    'core_boot',
    'core_identity',
    'core_characters',
    'core_state',
    'core_session',
    'system_money',
    'system_inventory',
    'system_jobs',
    'system_status',
}
