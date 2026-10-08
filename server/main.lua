-- Vanguard Jobs - start-up and hello.

local HELLO_COOLDOWN_MS = 2000
local lastHello = {}

RegisterNetEvent('vanguard-jobs:hello', function()
    local src = source
    local now = GetGameTimer()
    if lastHello[src] and now - lastHello[src] < HELLO_COOLDOWN_MS then return end
    lastHello[src] = now
    Center.broadcast(src)
    if Bridge.loaded(src) then TriggerClientEvent('vanguard-jobs:state', src, Teams.stateFor(src)) end
end)

AddEventHandler('playerDropped', function()
    lastHello[source] = nil
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    -- end every job: pay the stops already done, refund deposits, remove the vehicles
    for _, team in pairs(Teams.store.teams) do
        if team.run then
            local ok, err = pcall(Runs.finish, team, false, true)
            if not ok then print(('[vanguard-jobs] could not end team %d on stop: %s'):format(team.id, err)) end
            if team.run and team.run.vehicle and DoesEntityExist(team.run.vehicle) then DeleteEntity(team.run.vehicle) end
        end
    end
end)

CreateThread(function()
    Center.broadcast()
    print(('[vanguard-jobs] ready: %d job type(s), Job Center at %.1f, %.1f'):format(#Config.JobOrder, Center.ped().x, Center.ped().y))
end)
