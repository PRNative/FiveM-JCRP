fx_version 'cerulean'
game 'gta5'

name 'system_status'
description 'JCRP Status System — hunger, thirst, stress with configurable decay'
author 'JCRP Team'
version '1.0.0'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    '@core_boot/shared/utils.lua',
    'server/main.lua',
}

client_scripts {
    '@core_boot/shared/utils.lua',
    'client/main.lua',
}

dependencies {
    'oxmysql',
    'core_boot',
    'core_session',
}
