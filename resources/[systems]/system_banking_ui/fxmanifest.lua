fx_version 'cerulean'
game 'gta5'

name 'system_banking_ui'
description 'JCRP Banking UI — view balances, ledger, transfers'
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

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
}

dependencies {
    'core_boot',
    'core_session',
    'system_money',
}
