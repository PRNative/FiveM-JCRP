fx_version 'cerulean'
game 'gta5'

name 'core_characters'
description 'JCRP Character System — 3-slot character CRUD, identity storage'
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
    'core_identity',
}
