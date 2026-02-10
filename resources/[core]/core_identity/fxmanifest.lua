fx_version 'cerulean'
game 'gta5'

name 'core_identity'
description 'JCRP Account Identity — resolve accounts, bans, audit logging'
author 'JCRP Team'
version '1.0.0'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    '@core_boot/shared/utils.lua',
    'server/main.lua',
}

dependencies {
    'oxmysql',
    'core_boot',
}
