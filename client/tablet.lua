-- Vanguard Jobs - "Jobs" tile on ph-tablet (only when ph-tablet is running). Tapping it closes the
-- tablet and opens the Job Portal (html/tablet/jobs.js -> NUI callback 'openPortal').

local RESOURCE = GetCurrentResourceName()
local NUI_BASE = ('https://cfx-nui-%s/html/tablet/'):format(RESOURCE)

local function register()
    if GetResourceState('ph-tablet') ~= 'started' then return end
    local ok, err = pcall(function()
        exports['ph-tablet']:registerApp({
            id = 'vanguard-jobs', name = 'Jobs', order = 45,
            icon = NUI_BASE .. 'jobs.svg', entryUrl = NUI_BASE .. 'jobs.js',
        })
    end)
    if not ok then print(('[vanguard-jobs] could not add the Jobs tile to ph-tablet: %s'):format(tostring(err))) end
end

AddEventHandler('onClientResourceStart', function(name)
    if name == RESOURCE or name == 'ph-tablet' then register() end
end)
