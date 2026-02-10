fx_version 'cerulean'
game 'gta5'

name 'core_session'
description 'Core Session - Login flow and session management'
author 'JCRP'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

client_scripts {
    'client/main.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}

dependencies {
    'oxmysql',
    'ox_lib',
    'core_boot',
    'core_identity',
    'core_characters',
    'core_state'
}
