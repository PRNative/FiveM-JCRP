fx_version 'cerulean'
game 'gta5'

name 'system_permissions'
description 'JCRP Permissions & Admin — roles, admin commands, audit'
author 'JCRP Team'
version '1.0.0'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    '@core_boot/shared/utils.lua',
    'server/main.lua',
    'server/commands.lua',
}

dependencies {
    'oxmysql',
    'core_boot',
    'core_identity',
    'core_session',
}
