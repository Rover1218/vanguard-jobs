-- Vanguard Jobs - a job run on the player's side: stop blip + route, [E] take / drop prompts,
-- carrying a box or bag, the on-screen tracker, and keys for the leader.

Run = { view = nil, carrying = false, prop = nil, blip = nil, blipKey = nil, busy = false }

local LOAD_TIMEOUT_MS = 3000
local PROMPT_REACH = 2.2  -- metres; the server allows a little more (Config.StopReach / VehicleReach)
local REAR_GAP = 0.8      -- metres behind the vehicle's back where you take / throw
local ACCENT = { r = 16, g = 185, b = 129 }

local function loadWithTimeout(request, isLoaded)
    request()
    local giveUp = GetGameTimer() + LOAD_TIMEOUT_MS
    while not isLoaded() and GetGameTimer() < giveUp do Wait(10) end
    return isLoaded()
end

local function loadAnim(dict)
    return loadWithTimeout(function() RequestAnimDict(dict) end, function() return HasAnimDictLoaded(dict) end)
end

local function playCarry(carry)
    if loadAnim(carry.dict) then
        TaskPlayAnim(PlayerPedId(), carry.dict, carry.clip, 8.0, -8.0, -1, 49, 0, false, false, false)
    end
end

--- jobId = the run the unit was taken for; nothing is attached if that run ended while loading.
local function startCarry(jobId)
    local job = Config.Jobs[jobId]
    local carry = job.carry
    local model = GetHashKey(carry.prop)
    local hasAnim = loadAnim(carry.dict)
    local hasModel = loadWithTimeout(function() RequestModel(model) end, function() return HasModelLoaded(model) end)
    if not Run.view or Run.view.jobId ~= jobId then
        SetModelAsNoLongerNeeded(model)
        return
    end

    local ped = PlayerPedId()
    if hasAnim then TaskPlayAnim(ped, carry.dict, carry.clip, 8.0, -8.0, -1, 49, 0, false, false, false) end
    if hasModel then
        local c = GetEntityCoords(ped)
        Run.prop = CreateObject(model, c.x, c.y, c.z + 0.2, true, true, false)
        AttachEntityToEntity(Run.prop, ped, GetPedBoneIndex(ped, carry.bone), carry.pos.x, carry.pos.y, carry.pos.z,
            carry.rot.x, carry.rot.y, carry.rot.z, true, true, false, true, 1, true)
        SetModelAsNoLongerNeeded(model)
    end
    Run.carrying = true
end

local function stopCarry()
    if Run.prop and DoesEntityExist(Run.prop) then DeleteEntity(Run.prop) end
    Run.prop = nil
    if Run.carrying and not IsPedInAnyVehicle(PlayerPedId(), false) then ClearPedTasks(PlayerPedId()) end
    Run.carrying = false
end

local function clearBlip()
    if Run.blip then RemoveBlip(Run.blip) end
    Run.blip, Run.blipKey = nil, nil
end

local function setBlip(coords, label)
    Run.blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(Run.blip, 1)
    SetBlipColour(Run.blip, 2)
    SetBlipScale(Run.blip, 0.9)
    SetBlipRoute(Run.blip, true)
    SetBlipRouteColour(Run.blip, 2)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(label)
    EndTextCommandSetBlipName(Run.blip)
end

local function workVehicle(view)
    if view.vehicle and NetworkDoesEntityExistWithNetworkId(view.vehicle) then return NetToVeh(view.vehicle) end
    return nil
end

local function rearOf(vehicle)
    local min = GetModelDimensions(GetEntityModel(vehicle))
    return GetOffsetFromEntityInWorldCoords(vehicle, 0.0, min.y - REAR_GAP, 0.0)
end

function Run.update(view)
    Run.view = view
    if not view then
        stopCarry()
        clearBlip()
        SendNUIMessage({ action = 'tracker' })
        return
    end
    if not view.carrying and Run.carrying then stopCarry() end

    local key = ('%s:%d'):format(view.phase, view.stopIndex)
    if key ~= Run.blipKey then
        clearBlip()
        if view.phase == 'stop' and view.stop then
            setBlip(vector3(view.stop.x, view.stop.y, view.stop.z), ('%s - stop %d'):format(view.label, view.stopIndex))
        elseif view.phase == 'return' and Client.center then
            setBlip(Client.center.parking.xyz, 'Return to the Job Center')
        end
        Run.blipKey = key
    end
    SendNUIMessage({ action = 'tracker', tracker = view })
end

function Run.take()
    if Run.busy or not Run.view then return end
    Run.busy = true
    local jobId = Run.view.jobId
    local result = Client.request('takeUnit')
    Run.busy = false
    if not result.ok then return ClientBridge.notify(result.message, 'error') end
    startCarry(jobId)
end

function Run.drop()
    if Run.busy then return end
    Run.busy = true
    local result = Client.request('dropUnit')
    Run.busy = false
    if not result.ok then return ClientBridge.notify(result.message, 'error') end
    stopCarry()
end

function Run.release()
    stopCarry()
    Client.request('releaseUnit')
end

local function marker(coords, scale)
    DrawMarker(1, coords.x, coords.y, coords.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, scale, scale, 0.5,
        ACCENT.r, ACCENT.g, ACCENT.b, 110, false, false, 2, false, nil, nil, false)
end

-- Prompts, markers and carrying while on a run.
CreateThread(function()
    while true do
        local sleep = 500
        local view = Run.view
        local ped = PlayerPedId()

        -- never keep a box / bag in a car, after dying or once the run is over
        if Run.carrying and not view then
            stopCarry()
        elseif Run.carrying and (IsPedInAnyVehicle(ped, false) or IsEntityDead(ped)) then
            Run.release()
        end

        if view and view.phase == 'stop' and not IsPedInAnyVehicle(ped, false) then
            local job = Config.Jobs[view.jobId]
            local pos = GetEntityCoords(ped)
            local stopPos = view.stop and vector3(view.stop.x, view.stop.y, view.stop.z) or nil
            local vehicle = workVehicle(view)
            local rear = vehicle and rearOf(vehicle) or nil
            -- the vehicle only counts once it is parked at the stop (the server checks the same)
            if rear and stopPos and #(GetEntityCoords(vehicle) - stopPos) > Config.VehicleStopReach then rear = nil end
            local places = { stop = stopPos, vehicle = rear }

            if stopPos and #(pos - stopPos) < 45.0 then
                sleep = 0
                marker(stopPos, 1.4)
            end
            if rear and #(pos - rear) < 20.0 then
                sleep = 0
                marker(rear, 1.0)
            end

            if Run.carrying then
                sleep = 0
                DisableControlAction(0, 21, true) -- sprint
                DisableControlAction(0, 22, true) -- jump
                DisableControlAction(0, 23, true) -- enter vehicle
                DisableControlAction(0, 24, true) -- attack
                DisableControlAction(0, 25, true) -- aim
                if not IsEntityPlayingAnim(ped, job.carry.dict, job.carry.clip, 3) then playCarry(job.carry) end

                local target = places[job.drop]
                if target and #(pos - target) <= PROMPT_REACH then
                    ClientBridge.drawText3d(target + vector3(0.0, 0.0, 1.0),
                        job.drop == 'stop' and ('[E] Deliver %s'):format(job.unit) or ('[E] Throw %s in'):format(job.unit))
                    if IsControlJustReleased(0, Config.PromptKey) then Run.drop() end
                end
                if IsDisabledControlJustReleased(0, Config.DropCarryKey) or IsControlJustReleased(0, Config.DropCarryKey) then
                    Run.release()
                end
            else
                local source = places[job.pickup]
                local left = view.unitsTotal - view.unitsDone - view.inFlight
                if source and left > 0 and #(pos - source) <= PROMPT_REACH then
                    sleep = 0
                    ClientBridge.drawText3d(source + vector3(0.0, 0.0, 1.0), ('[E] Take %s (%d left)'):format(job.unit, left))
                    if IsControlJustReleased(0, Config.PromptKey) then Run.take() end
                end
            end
        elseif view and view.phase == 'return' and Client.center then
            local parking = Client.center.parking.xyz
            if #(GetEntityCoords(ped) - parking) < 60.0 then
                sleep = 0
                marker(parking, 4.0)
            end
        end
        Wait(sleep)
    end
end)

-- The leader's new work vehicle: full tank, wheels on the ground. (Keys come from the server.)
RegisterNetEvent('vanguard-jobs:vehicle', function(netId)
    local giveUp = GetGameTimer() + 10000
    while not NetworkDoesEntityExistWithNetworkId(netId) and GetGameTimer() < giveUp do Wait(100) end
    if not NetworkDoesEntityExistWithNetworkId(netId) then return end
    local vehicle = NetToVeh(netId)
    SetVehicleOnGroundProperly(vehicle)
    ClientBridge.fillFuel(vehicle)
end)

RegisterNetEvent('vanguard-jobs:dropped', stopCarry)

RegisterNetEvent('vanguard-jobs:runEnded', function()
    Run.update(nil)
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    stopCarry()
    clearBlip()
end)
