-- Vanguard Jobs - client bridge (QBCore today): keys, fuel, notifications, 3D text.

ClientBridge = {}

local QBCore = exports['qb-core']:GetCoreObject()

function ClientBridge.notify(message, kind)
    if message then QBCore.Functions.Notify(message, kind or 'primary', 5000) end
end

--- Keys for the work vehicle (qb-vehiclekeys), so the G engine key works.
function ClientBridge.giveKeys(vehicle)
    TriggerEvent('vehiclekeys:client:SetOwner', QBCore.Functions.GetPlate(vehicle))
end

function ClientBridge.fillFuel(vehicle)
    SetVehicleFuelLevel(vehicle, 100.0)
    for _, resource in ipairs({ 'qb-fuel', 'LegacyFuel', 'ps-fuel', 'cdn-fuel' }) do
        if GetResourceState(resource) == 'started' then
            pcall(function() exports[resource]:SetFuel(vehicle, 100.0) end)
            return
        end
    end
end

function ClientBridge.drawText3d(coords, text)
    SetDrawOrigin(coords.x, coords.y, coords.z, 0)
    SetTextScale(0.34, 0.34)
    SetTextFont(4)
    SetTextCentre(true)
    SetTextOutline()
    SetTextColour(255, 255, 255, 235)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function() TriggerServerEvent('vanguard-jobs:hello') end)
