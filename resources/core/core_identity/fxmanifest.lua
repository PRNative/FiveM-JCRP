fx_version 'cerulean'
game 'gta5'

name 'core_identity'
description 'Core Identity - Account management and ban system'
author 'JCRP'
version '1.0.0'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/migrations.lua',
    'server/main.lua'
}

dependencies {
    'oxmysql',
    'core_boot'
}
