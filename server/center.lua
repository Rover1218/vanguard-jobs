-- Vanguard Jobs - the Job Center: NPC spot and vehicle parking. Admins move them in-game with
-- /jobcenter ped | /jobcenter parking; the override is saved in data/center.json.

Center = {}

local RESOURCE = GetCurrentResourceName()
local FILE = 'data/center.json'

local current = { ped = Config.Center.ped, parking = Config.Center.parking }

local function toVec4(t)
    if type(t) ~= 'table' or not (tonumber(t.x) and tonumber(t.y) and tonumber(t.z)) then return nil end
    return vector4(t.x + 0.0, t.y + 0.0, t.z + 0.0, (tonumber(t.w) or 0.0) + 0.0)
end

local function fromVec4(v)
    return { x = v.x, y = v.y, z = v.z, w = v.w }
end

do
    local raw = LoadResourceFile(RESOURCE, FILE)
    local ok, saved = pcall(json.decode, raw or '')
    if ok and type(saved) == 'table' then
        current.ped = toVec4(saved.ped) or current.ped
        current.parking = toVec4(saved.parking) or current.parking
    end
end

function Center.ped() return current.ped end
function Center.parking() return current.parking end

function Center.distance(src, point)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return math.huge end
    return #(GetEntityCoords(ped) - point.xyz)
end

function Center.payload()
    return {
        label = Config.Center.label, ped = fromVec4(current.ped), parking = fromVec4(current.parking),
        blip = Config.Center.blip,
    }
end

function Center.broadcast(target)
    TriggerClientEvent('vanguard-jobs:center', target or -1, Center.payload())
end

RegisterCommand(Config.AdminCommand, function(src, args)
    if src == 0 or not IsPlayerAceAllowed(src, Config.AdminAce) then return end
    local what = args[1]
    if what ~= 'ped' and what ~= 'parking' then
        return Bridge.notify(src, ('Use /%s ped or /%s parking where you stand'):format(Config.AdminCommand, Config.AdminCommand), 'error')
    end
    local ped = GetPlayerPed(src)
    local vehicle = GetVehiclePedIsIn(ped, false)
    local entity = (what == 'parking' and vehicle ~= 0) and vehicle or ped
    local coords = GetEntityCoords(entity)
    current[what] = vector4(coords.x, coords.y, coords.z, GetEntityHeading(entity))

    SaveResourceFile(RESOURCE, FILE, json.encode({ ped = fromVec4(current.ped), parking = fromVec4(current.parking) }), -1)
    Center.broadcast()
    Router.log(src, ('moved the Job Center %s'):format(what))
    Bridge.notify(src, what == 'ped' and 'Job Center NPC moved here' or 'Job vehicles will now appear here', 'success')
end, false)
