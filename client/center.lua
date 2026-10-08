-- Vanguard Jobs - the Job Center NPC, its map icon and the [E] prompt that opens the portal.

local ped, blip = nil, nil
local MODEL_TIMEOUT_MS = 5000

local function removeCenter()
    if ped and DoesEntityExist(ped) then DeleteEntity(ped) end
    if blip then RemoveBlip(blip) end
    ped, blip = nil, nil
end

local function spawnPed(spot)
    local model = GetHashKey(Config.Center.pedModel)
    RequestModel(model)
    local giveUp = GetGameTimer() + MODEL_TIMEOUT_MS
    while not HasModelLoaded(model) and GetGameTimer() < giveUp do Wait(10) end
    if not HasModelLoaded(model) then return nil end

    local entity = CreatePed(4, model, spot.x, spot.y, spot.z - 1.0, spot.w, false, true)
    SetModelAsNoLongerNeeded(model)
    SetEntityInvincible(entity, true)
    SetBlockingOfNonTemporaryEvents(entity, true)
    FreezeEntityPosition(entity, true)
    TaskStartScenarioInPlace(entity, Config.Center.pedScenario, 0, true)
    return entity
end

RegisterNetEvent('vanguard-jobs:center', function(center)
    removeCenter()
    Client.center = {
        label = center.label,
        ped = vector4(center.ped.x, center.ped.y, center.ped.z, center.ped.w),
        parking = vector4(center.parking.x, center.parking.y, center.parking.z, center.parking.w),
    }
    ped = spawnPed(Client.center.ped)

    blip = AddBlipForCoord(center.ped.x, center.ped.y, center.ped.z)
    SetBlipSprite(blip, center.blip.sprite)
    SetBlipColour(blip, center.blip.colour)
    SetBlipScale(blip, center.blip.scale)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(center.label)
    EndTextCommandSetBlipName(blip)
end)

-- [E] Job Portal at the NPC
CreateThread(function()
    while true do
        local sleep = 750
        local center = Client.center
        if center and not Client.portalOpen then
            local position = GetEntityCoords(PlayerPedId())
            local distance = #(position - center.ped.xyz)
            if distance < 15.0 then sleep = 200 end
            if distance <= Config.Center.interactDistance and not IsPedInAnyVehicle(PlayerPedId(), false) then
                sleep = 0
                ClientBridge.drawText3d(center.ped.xyz + vector3(0.0, 0.0, 1.0), ('[E] %s'):format(center.label))
                if IsControlJustReleased(0, Config.PromptKey) then Client.openPortal() end
            end
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(name)
    if name == GetCurrentResourceName() then removeCenter() end
end)
