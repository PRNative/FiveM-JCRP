fx_version 'cerulean'
game 'gta5'

name 'core_state'
description 'JCRP Character State — position, metadata persistence, dirty tracking'
author 'JCRP Team'
version '1.0.0'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    '@core_boot/shared/utils.lua',
    'server/main.lua',
}

dependencies {
    'oxmysql',
    'core_boot',
}
