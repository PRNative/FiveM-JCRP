fx_version 'cerulean'
game 'gta5'

name 'core_boot'
description 'JCRP Platform Boot — DB connectivity, migration runner, config loader'
author 'JCRP Team'
version '1.0.0'

-- Must start before everything else
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'shared/utils.lua',
    'server/config.lua',
    'server/migrations.lua',
    'server/boot.lua',
}

shared_scripts {
    'shared/utils.lua',
}

dependencies {
    'oxmysql',
}
