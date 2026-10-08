-- Vanguard Jobs - team membership. Pure (no game natives) so it can be tested; the server wraps it.
-- A team: { id, leader, members = { server ids in join order }, busy = on a job run }.

TeamStore = {}
TeamStore.__index = TeamStore

function TeamStore.new(maxSize)
    return setmetatable({ maxSize = maxSize, teams = {}, byPlayer = {}, nextId = 0 }, TeamStore)
end

function TeamStore:get(id)
    return id and self.teams[id] or nil
end

function TeamStore:teamOf(src)
    return self:get(self.byPlayer[src])
end

function TeamStore:create(src)
    if self.byPlayer[src] then return nil, 'You are already in a team' end
    self.nextId = self.nextId + 1
    local team = { id = self.nextId, leader = src, members = { src }, busy = false }
    self.teams[team.id] = team
    self.byPlayer[src] = team.id
    return team
end

function TeamStore:join(src, id)
    if self.byPlayer[src] then return nil, 'You are already in a team' end
    local team = self:get(id)
    if not team then return nil, 'That team no longer exists' end
    if team.busy then return nil, 'That team is already working' end
    if #team.members >= self.maxSize then return nil, 'That team is full' end
    team.members[#team.members + 1] = src
    self.byPlayer[src] = team.id
    return team
end

local function removeMember(team, src)
    for index, member in ipairs(team.members) do
        if member == src then
            table.remove(team.members, index)
            return true
        end
    end
    return false
end

--- Removes a player from their team. Returns { team, newLeader, disbanded } or nil if not in a team.
function TeamStore:leave(src)
    local team = self:teamOf(src)
    if not team then return nil end
    removeMember(team, src)
    self.byPlayer[src] = nil

    if #team.members == 0 then
        self.teams[team.id] = nil
        return { team = team, disbanded = true }
    end
    local newLeader = nil
    if team.leader == src then
        team.leader = team.members[1]
        newLeader = team.leader
    end
    return { team = team, newLeader = newLeader, disbanded = false }
end

function TeamStore:kick(leader, target)
    local team = self:teamOf(leader)
    if not team or team.leader ~= leader then return nil, 'Only the team leader can do that' end
    if target == leader then return nil, 'Use Leave to quit your own team' end
    if self.byPlayer[target] ~= team.id then return nil, 'That player is not in your team' end
    removeMember(team, target)
    self.byPlayer[target] = nil
    return true
end

function TeamStore:setBusy(id, busy)
    local team = self:get(id)
    if team then team.busy = busy end
end

--- Teams that can still be joined, oldest first.
function TeamStore:openTeams()
    local list = {}
    for _, team in pairs(self.teams) do
        if not team.busy and #team.members < self.maxSize then list[#list + 1] = team end
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end
