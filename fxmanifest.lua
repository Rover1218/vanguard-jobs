fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'vanguard-jobs'
author 'Rover'
description 'Vanguard Jobs - team jobs (delivery, recycling) with a Job Center and a tablet Job Portal'
version '0.1.0'

ui_page 'html/index.html'

shared_scripts {
    'config.lua',
    'shared/rules.lua',
    'shared/teamstore.lua',
}

client_scripts {
    'bridge/client.lua',
    'client/main.lua',
    'client/center.lua',
    'client/run.lua',
    'client/tablet.lua',
}

server_scripts {
    'bridge/server.lua',
    'server/router.lua',
    'server/center.lua',
    'server/teams.lua',
    'server/runs.lua',
    'server/main.lua',
}

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/tablet/jobs.js',
    'html/tablet/jobs.svg',
}

dependencies {
    'qb-core',
}
