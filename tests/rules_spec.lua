local T = require('tests.lib.t')
dofile(ROOT .. '/shared/rules.lua')

local BONUS = { [1] = 100, [2] = 115, [3] = 130, [4] = 150 }
local JOB = { payPerStop = 200, routeBonus = 300 }

T.describe('Rules.teamBonus', function()
    T.it('reads the bonus for the team size', function()
        T.eq(Rules.teamBonus(BONUS, 1), 100)
        T.eq(Rules.teamBonus(BONUS, 4), 150)
    end)
    T.it('falls back to 100% for sizes without an entry', function()
        T.eq(Rules.teamBonus(BONUS, 0), 100)
        T.eq(Rules.teamBonus(BONUS, 9), 100)
        T.eq(Rules.teamBonus(nil, 2), 100)
    end)
end)

T.describe('Rules.payout', function()
    T.it('pays every stop plus the route bonus when all stops are done', function()
        T.eq(Rules.payout(JOB, 5, 5, 1, BONUS), 1300) -- 5 * 200 + 300
    end)
    T.it('applies the team bonus to each member', function()
        T.eq(Rules.payout(JOB, 5, 5, 2, BONUS), 1495) -- 1300 * 1.15
        T.eq(Rules.payout(JOB, 5, 5, 4, BONUS), 1950) -- 1300 * 1.5
    end)
    T.it('pays only finished stops without the route bonus when quitting early', function()
        T.eq(Rules.payout(JOB, 3, 5, 1, BONUS), 600)
        T.eq(Rules.payout(JOB, 3, 5, 3, BONUS), 780) -- 600 * 1.3
    end)
    T.it('pays nothing for no stops', function()
        T.eq(Rules.payout(JOB, 0, 5, 4, BONUS), 0)
        T.eq(Rules.payout(JOB, 0, 0, 1, BONUS), 0)
    end)
    T.it('rounds down to whole dollars', function()
        T.eq(Rules.payout({ payPerStop = 101, routeBonus = 0 }, 1, 2, 2, BONUS), 116) -- 116.15
    end)
end)

T.describe('Rules.pickStops', function()
    local LIST = { 'a', 'b', 'c', 'd', 'e' }
    local function sequence(...)
        local values, i = { ... }, 0
        return function() i = i + 1; return values[i] end
    end

    T.it('picks the requested number of different stops', function()
        -- random(n) returns the index to take from what is left
        local picked = Rules.pickStops(LIST, 3, sequence(2, 1, 3))
        T.eq(picked, { 'b', 'a', 'e' })
    end)
    T.it('never picks more stops than there are', function()
        T.eq(#Rules.pickStops(LIST, 9, function() return 1 end), 5)
    end)
    T.it('does not change the original list', function()
        Rules.pickStops(LIST, 3, function() return 1 end)
        T.eq(LIST, { 'a', 'b', 'c', 'd', 'e' })
    end)
end)

T.describe('Rules.wholeNumber', function()
    T.it('accepts whole numbers in range only', function()
        T.eq(Rules.wholeNumber(3, 1, 4), 3)
        T.eq(Rules.wholeNumber(0, 1, 4), nil)
        T.eq(Rules.wholeNumber(2.5, 1, 4), nil)
        T.eq(Rules.wholeNumber('3', 1, 4), nil)
        T.eq(Rules.wholeNumber(0 / 0, 1, 4), nil)
    end)
end)
