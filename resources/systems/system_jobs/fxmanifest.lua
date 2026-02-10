fx_version 'cerulean'
game 'gta5'

name 'system_jobs'
description 'System Jobs - Job assignment and management'
author 'JCRP'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'data/jobs.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/migrations.lua',
    'server/main.lua'
}

dependencies {
    'oxmysql',
    'ox_lib',
    'core_boot',
    'core_characters'
}
