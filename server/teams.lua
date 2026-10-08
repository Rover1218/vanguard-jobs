-- Vanguard Jobs - teams (create / join / leave / kick) and the portal state each player sees.

Teams = { store = TeamStore.new(Config.MaxTeamSize) }

local store = Teams.store

local function memberView(team)
    local list = {}
    for _, member in ipairs(team.members) do
        list[#list + 1] = { id = member, name = Bridge.name(member), leader = member == team.leader }
    end
    return list
end

local function jobsView()
    local list = {}
    for _, id in ipairs(Config.JobOrder) do
        local job = Config.Jobs[id]
        if job then
            list[#list + 1] = {
                id = id, label = job.label, description = job.description, icon = job.icon,
                stops = job.stops, payPerStop = job.payPerStop, routeBonus = job.routeBonus,
                unit = job.unit, units = job.units, vehicle = job.vehicle,
            }
        end
    end
    return list
end

--- Everything the portal shows for one player.
function Teams.stateFor(src)
    local team = store:teamOf(src)
    local state = {
        me = src,
        maxSize = Config.MaxTeamSize,
        bonus = Config.TeamBonus,
        deposit = Config.Deposit,
        jobs = jobsView(),
        center = Config.Center.label,
    }
    if team then
        state.team = { id = team.id, leader = team.leader, members = memberView(team), busy = team.busy }
        state.isLeader = team.leader == src
        state.run = Runs.view(team, src)
    else
        state.openTeams = {}
        for _, open in ipairs(store:openTeams()) do
            state.openTeams[#state.openTeams + 1] = { id = open.id, leader = Bridge.name(open.leader), size = #open.members }
        end
    end
    return state
end

function Teams.push(team)
    for _, member in ipairs(team.members) do
        TriggerClientEvent('vanguard-jobs:state', member, Teams.stateFor(member))
    end
end

--- Players without a team refresh their list of open teams when it changes.
local function announceTeamsChanged()
    TriggerClientEvent('vanguard-jobs:teamsChanged', -1)
end

--- Removes a player from their team (leave, kick, disconnect, logout).
function Teams.remove(src, reason)
    local team = store:teamOf(src)
    if not team then return end
    Runs.memberLeft(team, src)
    local result = store:leave(src)

    if result.disbanded then
        Runs.abort(team)
    else
        if result.newLeader then
            Runs.leaderChanged(team, result.newLeader)
            Bridge.notify(result.newLeader, 'You are now the team leader', 'primary')
        end
        for _, member in ipairs(team.members) do
            Bridge.notify(member, ('%s %s the team'):format(Bridge.name(src), reason), 'primary')
        end
        Teams.push(team)
    end
    TriggerClientEvent('vanguard-jobs:state', src, Teams.stateFor(src))
    announceTeamsChanged()
end

Router.on('state', function(src)
    return Router.ok(nil, Teams.stateFor(src))
end)

Router.on('createTeam', function(src)
    local team, err = store:create(src)
    if not team then return Router.fail(err) end
    Teams.push(team)
    announceTeamsChanged()
    return Router.ok('Team created - others can join from their Job Portal')
end)

Router.on('joinTeam', function(src, data)
    local id = Rules.wholeNumber(data.teamId, 1, 2 ^ 31)
    local team, err = store:join(src, id)
    if not team then return Router.fail(err) end
    for _, member in ipairs(team.members) do
        if member ~= src then Bridge.notify(member, ('%s joined your team'):format(Bridge.name(src)), 'success') end
    end
    Teams.push(team)
    announceTeamsChanged()
    return Router.ok('You joined the team')
end)

Router.on('leaveTeam', function(src)
    if not store:teamOf(src) then return Router.fail('You are not in a team') end
    Teams.remove(src, 'left')
    return Router.ok('You left the team')
end)

Router.on('kick', function(src, data)
    local target = Rules.wholeNumber(data.target, 1, 2 ^ 31)
    local team = store:teamOf(src)
    if not team or team.leader ~= src then return Router.fail('Only the team leader can do that') end
    if not target or target == src or store:teamOf(target) ~= team then return Router.fail('That player is not in your team') end
    Teams.remove(target, 'was removed from')
    Bridge.notify(target, 'You were removed from the team', 'error')
    return Router.ok('Player removed')
end)

AddEventHandler('playerDropped', function()
    Teams.remove(source, 'left')
end)

-- qb-core fires this on the server when a character logs out. It is not a net event in this
-- resource, so clients can't trigger it here; the argument is the player's server id.
AddEventHandler('QBCore:Server:OnPlayerUnload', function(src)
    src = tonumber(src)
    if src then Teams.remove(src, 'left') end
end)
