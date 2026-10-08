-- Vanguard Jobs - pure rules shared by server, client and tests (no game natives in here).

Rules = {}

local function isFinite(value)
    return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end

--- Whole number within [min, max], else nil. Rejects strings, fractions, NaN and infinities.
function Rules.wholeNumber(value, min, max)
    if not isFinite(value) then return nil end
    local int = math.tointeger(value)
    if not int or int < min or int > max then return nil end
    return int
end

--- Team bonus percent for a team size (100 when the config has no entry).
function Rules.teamBonus(bonuses, size)
    return (type(bonuses) == 'table' and bonuses[size]) or 100
end

--- Pay for each team member: every finished stop, plus the route bonus when all stops are done,
--- times the team bonus. Rounded down to whole dollars.
function Rules.payout(job, stopsDone, totalStops, teamSize, bonuses)
    if stopsDone <= 0 then return 0 end
    local base = job.payPerStop * stopsDone
    if totalStops > 0 and stopsDone >= totalStops then base = base + job.routeBonus end
    return base * Rules.teamBonus(bonuses, teamSize) // 100
end

--- Picks `count` different entries from list in random order. random(n) returns 1..n.
function Rules.pickStops(list, count, random)
    local left = {}
    for index, entry in ipairs(list) do left[index] = entry end
    local picked = {}
    for _ = 1, math.min(count, #list) do
        picked[#picked + 1] = table.remove(left, random(#left))
    end
    return picked
end
