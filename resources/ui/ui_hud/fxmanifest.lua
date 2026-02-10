fx_version 'cerulean'
game 'gta5'

name 'ui_hud'
description 'UI HUD - Player heads-up display'
author 'JCRP'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua'
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
    'core_session',
    'system_money',
    'system_jobs',
    'system_status'
}
