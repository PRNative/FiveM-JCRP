fx_version 'cerulean'
game 'gta5'

name 'ui_hud'
description 'JCRP HUD — displays money, job, status, street, voice'
author 'JCRP Team'
version '1.0.0'

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
}
