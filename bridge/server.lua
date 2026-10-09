-- Vanguard Jobs - server bridge (QBCore today; the only file that knows the framework).

Bridge = {}

local QBCore = exports['qb-core']:GetCoreObject()

local function player(src)
    return QBCore.Functions.GetPlayer(src)
end

--- True once the player has a character loaded.
function Bridge.loaded(src)
    return player(src) ~= nil
end

function Bridge.name(src)
    local p = player(src)
    local info = p and p.PlayerData.charinfo
    if info then
        local name = ('%s %s'):format(info.firstname or '', info.lastname or ''):gsub('^%s+', ''):gsub('%s+$', '')
        if name ~= '' then return name end
    end
    return GetPlayerName(src) or 'Unknown'
end

--- Takes amount from cash, else bank. Returns the account it came from, or nil.
function Bridge.takeMoney(src, amount, reason)
    local p = player(src)
    if not p then return nil end
    for _, account in ipairs({ 'cash', 'bank' }) do
        if (p.PlayerData.money[account] or 0) >= amount and p.Functions.RemoveMoney(account, amount, reason) ~= false then
            return account
        end
    end
    return nil
end

function Bridge.addMoney(src, account, amount, reason)
    local p = player(src)
    if not p then return false end
    return p.Functions.AddMoney(account, amount, reason) ~= false
end

--- Vehicle keys (qb-vehiclekeys). Given on the server: its client route only works within 7.5 m.
function Bridge.giveKeys(src, plate)
    if GetResourceState('qb-vehiclekeys') ~= 'started' then return end
    local ok, err = pcall(function() exports['qb-vehiclekeys']:GiveKeys(src, plate) end)
    if not ok then print(('[vanguard-jobs] could not give keys for %s: %s'):format(plate, err)) end
end

function Bridge.removeKeys(src, plate)
    if GetResourceState('qb-vehiclekeys') ~= 'started' then return end
    pcall(function() exports['qb-vehiclekeys']:RemoveKeys(src, plate) end)
end

function Bridge.notify(src, message, kind)
    TriggerClientEvent('QBCore:Notify', src, message, kind or 'primary', 5000)
end
