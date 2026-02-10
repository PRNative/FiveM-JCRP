fx_version 'cerulean'
game 'gta5'

name 'core_spawn'
description 'Core Spawn - Spawn selection and positioning system'
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
    'ox_lib',
    'core_boot',
    'core_state',
    'core_session'
}
