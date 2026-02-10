fx_version 'cerulean'
game 'gta5'

name 'core_state'
description 'Core State - Character state persistence system'
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
