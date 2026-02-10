fx_version 'cerulean'
game 'gta5'

name 'core_spawn'
description 'JCRP Spawn System — spawn selection, last location, predefined spawns'
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

ui_page 'nui/index.html'

files {
    'nui/index.html',
    'nui/style.css',
    'nui/app.js',
}

dependencies {
    'core_boot',
    'core_state',
    'core_session',
}
