fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'vanguard-jobs'
author 'Rover'
description 'Vanguard Jobs - team jobs (delivery, recycling) from a Job Center NPC'
version '0.1.1'

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
}

dependencies {
    'qb-core',
}
