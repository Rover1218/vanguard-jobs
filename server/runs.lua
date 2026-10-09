-- Vanguard Jobs - job runs. The server owns every step: which stop is next, who carries what,
-- whether a box / bag was really taken and dropped (distance checks), and the pay at the end.

Runs = {}

local VEHICLE_WAIT_MS = 3000
local carrying = {} -- server id -> team id (one unit at a time)

local function random(n) return math.random(n) end

local function job(run) return Config.Jobs[run.jobId] end

local function vehicleWord(def) return def.vehicle == 'trash2' and 'truck' or 'van' end

local function vehicleCoords(run)
    if not run.vehicle or not DoesEntityExist(run.vehicle) then return nil end
    return GetEntityCoords(run.vehicle)
end

local function distanceTo(src, point)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or not point then return math.huge end
    return #(GetEntityCoords(ped) - point)
end

local function carriedBy(team)
    local count = 0
    for _, teamId in pairs(carrying) do
        if teamId == team.id then count = count + 1 end
    end
    return count
end

local function stopsDone(run)
    return run.phase == 'return' and #run.stops or run.index - 1
end

--- What one member's portal and tracker show about the run.
function Runs.view(team, src)
    local run = team.run
    if not run then return nil end
    local def = job(run)
    local stop = run.stops[run.index]
    local stopList = {}
    for index, entry in ipairs(run.stops) do
        stopList[index] = { done = index < run.index or run.phase == 'return', units = entry.units }
    end
    return {
        jobId = run.jobId, label = def.label, icon = def.icon, unit = def.unit, units = def.units,
        pickup = def.pickup, drop = def.drop, phase = run.phase,
        stopIndex = math.min(run.index, #run.stops), totalStops = #run.stops, stops = stopList,
        unitsDone = stop and stop.done or 0, unitsTotal = stop and stop.units or 0,
        inFlight = carriedBy(team), carrying = carrying[src] == team.id,
        stop = stop and { x = stop.coords.x, y = stop.coords.y, z = stop.coords.z } or nil,
        vehicle = run.net,
        earned = Rules.payout(def, stopsDone(run), #run.stops, #team.members, Config.TeamBonus),
        fullPay = Rules.payout(def, #run.stops, #run.stops, #team.members, Config.TeamBonus),
    }
end

local function ended(team, members)
    for _, member in ipairs(members) do
        if carrying[member] then carrying[member] = nil end
        TriggerClientEvent('vanguard-jobs:runEnded', member)
    end
end

local function giveKeys(run, src)
    run.keyHolders[src] = true
    Bridge.giveKeys(src, run.plate)
end

--- Removes the work vehicle and takes its keys back.
local function deleteVehicle(run)
    for holder in pairs(run.keyHolders or {}) do Bridge.removeKeys(holder, run.plate) end
    if run.vehicle and DoesEntityExist(run.vehicle) then DeleteEntity(run.vehicle) end
end

--- Ends a run. completed = brought back after every stop (route bonus); otherwise only done stops pay.
--- forceRefund = give the deposit back wherever the vehicle is (the server is stopping the job, not the team).
function Runs.finish(team, completed, forceRefund)
    local run = team.run
    if not run then return end
    local def = job(run)
    local done = stopsDone(run)
    local pay = Rules.payout(def, done, completed and #run.stops or math.huge, #team.members, Config.TeamBonus)

    for _, member in ipairs(team.members) do
        if pay > 0 then
            Bridge.addMoney(member, 'bank', pay, ('vanguard-jobs %s'):format(run.jobId))
            Bridge.notify(member, ('%s paid: $%d for %d stop(s)%s'):format(def.label, pay, done, completed and ' + route bonus' or ''), 'success')
        else
            Bridge.notify(member, ('%s ended - no stops were finished'):format(def.label), 'error')
        end
    end

    -- deposit back when the vehicle is returned to the Job Center
    local coords = vehicleCoords(run)
    if forceRefund or (coords and #(coords - Center.parking().xyz) <= Config.Center.returnDistance) then
        -- the payer loses the refund to the leader once they leave the team (see Runs.memberLeft)
        local payer = run.depositPayer or team.leader
        Bridge.addMoney(payer, run.depositAccount or 'bank', Config.Deposit, 'vanguard-jobs deposit')
        Bridge.notify(payer, ('$%d vehicle deposit refunded'):format(Config.Deposit), 'success')
    end

    print(('[vanguard-jobs] team %d finished %s: %d/%d stops, $%d each to %d member(s)%s'):format(
        team.id, run.jobId, done, #run.stops, pay, #team.members, completed and ', completed' or ''))
    deleteVehicle(run)
    team.run = nil
    Teams.store:setBusy(team.id, false)
    ended(team, team.members)
    Teams.push(team)
end

--- The team broke up mid-run: nobody is left to pay; just clean up.
function Runs.abort(team)
    if not team.run then return end
    deleteVehicle(team.run)
    team.run = nil
end

function Runs.memberLeft(team, src)
    if carrying[src] then carrying[src] = nil end
    if not team.run then return end
    -- server ids are reused after a disconnect, so never refund to an id that left
    if team.run.depositPayer == src then team.run.depositPayer = nil end
    TriggerClientEvent('vanguard-jobs:runEnded', src)
end

function Runs.leaderChanged(team, leader)
    if team.run then giveKeys(team.run, leader) end
end

-- ---------------------------------------------------------------------------
-- Start
-- ---------------------------------------------------------------------------

--- A plate of its own for every work vehicle (keys are per plate): DELI4821, RECY0397...
local function newPlate(def)
    return ('%s%04d'):format(def.plate:sub(1, 4):upper(), math.random(0, 9999))
end

local function spawnVehicle(def)
    local parking = Center.parking()
    local vehicle = CreateVehicleServerSetter(joaat(def.vehicle), 'automobile', parking.x, parking.y, parking.z + 0.5, parking.w)
    local waitUntil = GetGameTimer() + VEHICLE_WAIT_MS
    while not DoesEntityExist(vehicle) and GetGameTimer() < waitUntil do Wait(0) end
    if not DoesEntityExist(vehicle) then return nil end
    local plate = newPlate(def)
    SetVehicleNumberPlateText(vehicle, plate)
    return vehicle, plate
end

--- Takes the deposit and spawns the vehicle. Yields while the vehicle appears, so the caller
--- re-checks the team afterwards. Returns vehicle, account, plate or nil, message.
local function prepare(src, def)
    local account = Bridge.takeMoney(src, Config.Deposit, 'vanguard-jobs deposit')
    if not account then return nil, ('You need $%d for the vehicle deposit'):format(Config.Deposit) end
    local vehicle, plate = spawnVehicle(def)
    if not vehicle then
        Bridge.addMoney(src, account, Config.Deposit, 'vanguard-jobs deposit refund')
        return nil, 'The work vehicle could not be spawned - try again'
    end
    return vehicle, account, plate
end

--- The caller's team, or a new team of one when they start alone (solo = true).
local function teamForStart(src)
    local team = Teams.store:teamOf(src)
    if team then return team, false end
    local created, err = Teams.store:create(src)
    if not created then return nil, err end
    Teams.store:setBusy(created.id, true) -- keep it off the open-teams list while the vehicle spawns
    return created, true
end

Router.on('startJob', function(src, data)
    local jobId = type(data.job) == 'string' and data.job or ''
    local def = Config.Jobs[jobId]
    if not def then return Router.fail('Pick a job') end
    if Center.distance(src, Center.ped()) > Config.Center.startDistance then
        return Router.fail(('Start the job at the %s'):format(Config.Center.label))
    end
    local team, solo = teamForStart(src)
    if not team then return Router.fail(solo) end
    if team.leader ~= src then return Router.fail('Only the team leader can start a job') end
    if team.run or team.starting then return Router.fail('Your team is already working') end

    team.starting = true
    local vehicle, account, plate = prepare(src, def)
    team.starting = nil
    if not vehicle then
        if solo then Teams.remove(src, 'left') end -- undo the team of one
        return Router.fail(account)
    end
    -- the team may have changed while the vehicle spawned
    if Teams.store:teamOf(src) ~= team or team.leader ~= src then
        DeleteEntity(vehicle)
        Bridge.addMoney(src, account, Config.Deposit, 'vanguard-jobs deposit refund')
        return Router.fail('Your team changed - start the job again')
    end

    local stops = {}
    for index, point in ipairs(Rules.pickStops(def.locations, def.stops, random)) do
        stops[index] = { coords = point.xyz, units = math.random(def.unitsMin, def.unitsMax), done = 0 }
    end
    team.run = {
        jobId = jobId, stops = stops, index = 1, phase = 'stop',
        vehicle = vehicle, net = NetworkGetNetworkIdFromEntity(vehicle), plate = plate, keyHolders = {},
        depositPayer = src, depositAccount = account,
    }
    Teams.store:setBusy(team.id, true)
    giveKeys(team.run, src)
    TriggerClientEvent('vanguard-jobs:vehicle', src, team.run.net)
    for _, member in ipairs(team.members) do
        Bridge.notify(member, ('%s started - your %s (%s) is in the Job Center parking'):format(def.label, vehicleWord(def), plate), 'success')
    end
    TriggerClientEvent('vanguard-jobs:teamsChanged', -1)
    Teams.push(team)
    Router.log(src, ('started %s with %d member(s)'):format(jobId, #team.members))
    return Router.ok()
end)

-- ---------------------------------------------------------------------------
-- Boxes and bags
-- ---------------------------------------------------------------------------

--- The caller's team and the stop they are working on, or nil + message.
local function working(src)
    local team = Teams.store:teamOf(src)
    local run = team and team.run
    if not run then return nil, 'Your team is not on a job' end
    if run.phase ~= 'stop' then return nil, 'All stops are done - drive back to the Job Center' end
    return team, run, job(run), run.stops[run.index]
end

local function near(src, run, def, place)
    if place == 'vehicle' then
        local coords = vehicleCoords(run)
        if not coords then return false, 'The work vehicle is gone - the leader can cancel the job' end
        -- boxes / bags only move between the vehicle and the stop it is parked at
        if #(coords - run.stops[run.index].coords) > Config.VehicleStopReach then
            return false, ('Park the %s at the stop first'):format(vehicleWord(def))
        end
        return distanceTo(src, coords) <= Config.VehicleReach, ('Go to the back of the %s'):format(vehicleWord(def))
    end
    return distanceTo(src, run.stops[run.index].coords) <= Config.StopReach, 'Go to the marked stop'
end

Router.on('takeUnit', function(src)
    local team, run, def, stop = working(src)
    if not team then return Router.fail(run) end
    if carrying[src] then return Router.fail(('You are already carrying a %s'):format(def.unit)) end
    if stop.done + carriedBy(team) >= stop.units then
        return Router.fail(('All %s for this stop are already taken'):format(def.units))
    end
    local close, why = near(src, run, def, def.pickup)
    if not close then return Router.fail(why) end
    carrying[src] = team.id
    Teams.push(team)
    return Router.ok(nil, { jobId = run.jobId })
end)

Router.on('dropUnit', function(src)
    local team, run, def, stop = working(src)
    if not team then return Router.fail(run) end
    if carrying[src] ~= team.id then return Router.fail(('You are not carrying a %s'):format(def.unit)) end
    local close, why = near(src, run, def, def.drop)
    if not close then return Router.fail(why) end

    carrying[src] = nil
    stop.done = stop.done + 1
    local message = ('%s %d / %d'):format((def.units:gsub('^%l', string.upper)), stop.done, stop.units)
    if stop.done >= stop.units then
        run.index = run.index + 1
        if run.index > #run.stops then
            run.phase = 'return'
            message = 'Route done - drive back to the Job Center and press Finish'
        else
            message = ('Stop done - head to stop %d / %d'):format(run.index, #run.stops)
        end
        for _, member in ipairs(team.members) do Bridge.notify(member, message, 'success') end
    end
    Teams.push(team)
    TriggerClientEvent('vanguard-jobs:dropped', src)
    return Router.ok(message)
end)

-- Put down what you carry (X): the unit goes back to where it came from.
Router.on('releaseUnit', function(src)
    local team = Teams.store:teamOf(src)
    if not carrying[src] then return Router.ok() end
    carrying[src] = nil
    if team then Teams.push(team) end
    return Router.ok()
end)

-- ---------------------------------------------------------------------------
-- Finish / cancel
-- ---------------------------------------------------------------------------

Router.on('finishJob', function(src)
    local team = Teams.store:teamOf(src)
    local run = team and team.run
    if not run then return Router.fail('Your team is not on a job') end
    if team.leader ~= src then return Router.fail('The team leader presses Finish') end
    if run.phase ~= 'return' then return Router.fail(('Finish all stops first (%d / %d)'):format(run.index - 1, #run.stops)) end
    if Center.distance(src, Center.ped()) > Config.Center.startDistance * 3 then
        return Router.fail(('Come back to the %s to finish'):format(Config.Center.label))
    end
    local coords = vehicleCoords(run)
    if not coords or #(coords - Center.parking().xyz) > Config.Center.returnDistance then
        return Router.fail('Park the work vehicle at the Job Center first')
    end
    Runs.finish(team, true)
    return Router.ok()
end)

Router.on('cancelJob', function(src)
    local team = Teams.store:teamOf(src)
    if not team or not team.run then return Router.fail('Your team is not on a job') end
    if team.leader ~= src then return Router.fail('Only the team leader can cancel the job') end
    Runs.finish(team, false)
    return Router.ok()
end)
