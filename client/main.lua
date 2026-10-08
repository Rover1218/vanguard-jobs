-- Vanguard Jobs - client core: server requests, the Job Portal and the latest state.

Client = { state = nil, center = nil, portalOpen = false }

local REQUEST_TIMEOUT_MS = 10000
local TABLET_CLOSE_DELAY_MS = 400 -- ph-tablet releases the mouse before our portal takes it
local pending, nextId = {}, 0

--- Sends an action to the server and waits for { ok, message, data }.
function Client.request(action, data)
    nextId = nextId + 1
    local id = nextId
    local answer = promise.new()
    pending[id] = answer
    TriggerServerEvent('vanguard-jobs:request', id, action, data or {})
    SetTimeout(REQUEST_TIMEOUT_MS, function()
        if pending[id] then
            pending[id] = nil
            answer:resolve({ ok = false, message = 'The server did not answer' })
        end
    end)
    return Citizen.Await(answer)
end

RegisterNetEvent('vanguard-jobs:response', function(id, result)
    local answer = pending[id]
    if not answer then return end
    pending[id] = nil
    answer:resolve(type(result) == 'table' and result or { ok = false })
end)

function Client.openPortal()
    if Client.portalOpen then return end
    local result = Client.request('state')
    if not result.ok then return ClientBridge.notify(result.message, 'error') end
    Client.state = result.data
    Client.portalOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', state = result.data, brand = Config.Brand })
end

function Client.closePortal()
    Client.portalOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

RegisterNUICallback('close', function(_, cb)
    Client.closePortal()
    cb({})
end)

-- The portal forwards { action, data }; the server checks everything itself.
RegisterNUICallback('request', function(body, cb)
    if type(body) ~= 'table' or type(body.action) ~= 'string' then return cb({ ok = false }) end
    cb(Client.request(body.action, body.data))
end)

-- From the Jobs tile on ph-tablet.
RegisterNUICallback('openPortal', function(_, cb)
    cb({})
    SetTimeout(TABLET_CLOSE_DELAY_MS, Client.openPortal)
end)

RegisterNetEvent('vanguard-jobs:state', function(state)
    Client.state = state
    if Client.portalOpen then SendNUIMessage({ action = 'state', state = state }) end
    Run.update(state and state.run or nil)
end)

-- Someone made / filled / started a team: players browsing the open teams list refresh it.
RegisterNetEvent('vanguard-jobs:teamsChanged', function()
    if not Client.portalOpen or (Client.state and Client.state.team) then return end
    local result = Client.request('state')
    if result.ok and Client.portalOpen then
        Client.state = result.data
        SendNUIMessage({ action = 'state', state = result.data })
    end
end)

RegisterCommand(Config.Command, Client.openPortal, false)

CreateThread(function()
    while not NetworkIsSessionStarted() do Wait(500) end
    TriggerServerEvent('vanguard-jobs:hello')
end)

AddEventHandler('onResourceStop', function(name)
    if name == GetCurrentResourceName() and Client.portalOpen then SetNuiFocus(false, false) end
end)
