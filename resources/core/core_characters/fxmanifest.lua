fx_version 'cerulean'
game 'gta5'

name 'core_characters'
description 'Core Characters - Character creation and management system'
author 'JCRP'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/migrations.lua',
    'server/main.lua'
}

client_scripts {
    'client/main.lua'
}

dependencies {
    'oxmysql',
    'ox_lib',
    'core_boot',
    'core_identity'
}
