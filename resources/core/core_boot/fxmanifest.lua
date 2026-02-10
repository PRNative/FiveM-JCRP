fx_version 'cerulean'
game 'gta5'

name 'core_boot'
description 'Core Boot - Database migrations and server initialization'
author 'JCRP'
version '1.0.0'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/config.lua',
    'server/migrations.lua',
    'server/main.lua'
}

dependencies {
    'oxmysql'
}
