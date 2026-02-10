fx_version 'cerulean'
game 'gta5'

name 'core_session'
description 'JCRP Session Manager — login flow, character UI, hydration pipeline'
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
    'oxmysql',
    'core_boot',
    'core_identity',
    'core_characters',
    'core_state',
}
