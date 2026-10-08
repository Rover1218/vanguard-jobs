Config = {}

Config.Brand = { Title = 'VANGUARD', Subtitle = 'JOBS', Accent = '#10b981' }

Config.Command = 'jobs'                   -- /jobs opens the portal anywhere (team management)
Config.AdminAce = 'vanguard.jobs.admin'      -- server.cfg: add_ace group.admin vanguard.jobs.admin allow
Config.AdminCommand = 'jobcenter'         -- /jobcenter ped | /jobcenter parking (stand where it should go)

-- The Job Center: worker NPC, map icon and the parking spot where work vehicles appear.
-- Admins can move both in-game with /jobcenter; that is saved in data/center.json and wins over this.
Config.Center = {
    label = 'Job Center',
    pedModel = 'a_m_y_business_02',
    pedScenario = 'WORLD_HUMAN_CLIPBOARD',
    ped = vector4(-270.2, -956.4, 31.22, 205.0),
    parking = vector4(-286.0, -985.0, 31.08, 250.0),
    blip = { sprite = 408, colour = 17, scale = 0.85 },
    interactDistance = 2.0,  -- E at the NPC
    startDistance = 6.0,     -- the leader must stand this close to the NPC to start a job
    returnDistance = 35.0,   -- the vehicle must be this close to the parking spot to finish
}

Config.MaxTeamSize = 4
Config.TeamBonus = { [1] = 100, [2] = 115, [3] = 130, [4] = 150 } -- % of the pay each member gets
Config.Deposit = 250            -- paid by the leader when starting, refunded when the vehicle comes back
Config.StopReach = 4.0          -- metres from a stop to take / drop a box or bag
Config.VehicleReach = 7.0       -- metres from the work vehicle to take / drop a box or bag
Config.PromptKey = 38           -- E
Config.DropCarryKey = 73        -- X: put down what you are carrying (it goes back where it came from)

-- Job types. pickup / drop: where a unit (box, bag) is taken from and brought to: 'vehicle' or 'stop'.
-- carry: animation + prop while carrying one unit.
Config.Jobs = {
    delivery = {
        label = 'Delivery',
        description = 'Drive the box van to shops around the city and carry the boxes to their back doors.',
        icon = 'box',
        vehicle = 'boxville2',
        plate = 'DELIVERY',
        stops = 5,
        unitsMin = 2, unitsMax = 3,
        payPerStop = 350,
        routeBonus = 500,
        pickup = 'vehicle', drop = 'stop',
        unit = 'box', units = 'boxes',
        carry = {
            dict = 'anim@heists@box_carry@', clip = 'idle', prop = 'hei_prop_heist_box', bone = 60309,
            pos = vector3(0.025, 0.08, 0.255), rot = vector3(-145.0, 290.0, 0.0),
        },
        locations = { -- store back doors (same spots qb-shops uses for its deliveries)
            vector4(26.45, -1315.51, 29.62, 0.07),
            vector4(379.97, 357.3, 102.56, 26.42),
            vector4(-40.51, -1747.45, 29.29, 326.39),
            vector4(-702.89, -917.44, 19.21, 181.96),
            vector4(1160.62, -312.06, 69.28, 3.77),
            vector4(-1226.92, -901.82, 12.28, 213.26),
            vector4(-1468.29, -387.61, 38.79, 220.13),
            vector4(1129.73, -989.27, 45.97, 280.98),
            vector4(89.15, -1745.29, 30.09, 315.25),
            vector4(-660.61, -938.14, 21.83, 167.22),
            vector4(820.97, -2146.7, 28.71, 359.98),
            vector4(249.0, -50.64, 69.94, 60.71),
            vector4(-5.82, -1107.48, 29.0, 164.32),
            vector4(847.83, -1020.36, 27.88, 88.29),
            vector4(-1302.44, -385.23, 36.62, 303.79),
            vector4(-1162.13, -1568.57, 4.39, 328.52),
            vector4(-1674.18, -1073.7, 13.15, 333.56),
        },
    },

    recycling = {
        label = 'Recycling',
        description = 'Drive the recycling truck to bins around the city and throw the bags into the back.',
        icon = 'recycle',
        vehicle = 'trash2',
        plate = 'RECYCLE',
        stops = 5,
        unitsMin = 2, unitsMax = 4,
        payPerStop = 300,
        routeBonus = 500,
        pickup = 'stop', drop = 'vehicle',
        unit = 'bag', units = 'bags',
        carry = {
            dict = 'missfbi4prepp1', clip = '_bag_walk_garbage_man', prop = 'prop_cs_rub_binbag_01', bone = 57005,
            pos = vector3(0.12, 0.0, -0.05), rot = vector3(220.0, 120.0, 0.0),
        },
        locations = { -- city bins (same spots qb-garbagejob uses)
            vector4(-168.07, -1662.8, 33.31, 137.5),
            vector4(118.06, -1943.96, 20.43, 179.5),
            vector4(297.94, -2018.26, 20.49, 119.5),
            vector4(424.98, -1523.57, 29.28, 120.08),
            vector4(488.49, -1284.1, 29.24, 138.5),
            vector4(307.47, -1033.6, 29.03, 46.5),
            vector4(239.19, -681.5, 37.15, 178.5),
            vector4(543.51, -204.41, 54.16, 199.5),
            vector4(268.72, -25.92, 73.36, 90.5),
            vector4(267.03, 276.01, 105.54, 332.5),
            vector4(21.65, 375.44, 112.67, 323.5),
            vector4(-546.9, 286.57, 82.85, 127.5),
            vector4(-683.23, -169.62, 37.74, 267.5),
            vector4(-771.02, -218.06, 37.05, 277.5),
            vector4(-1057.06, -515.45, 35.83, 61.5),
            vector4(-1558.64, -478.22, 35.18, 179.5),
            vector4(-1350.0, -895.64, 13.36, 17.5),
            vector4(-1243.73, -1359.72, 3.93, 287.5),
            vector4(-845.87, -1113.07, 6.91, 253.5),
            vector4(-635.21, -1226.45, 11.8, 143.5),
            vector4(-587.74, -1739.13, 22.47, 339.5),
        },
    },
}

-- Order the jobs appear in the portal.
Config.JobOrder = { 'delivery', 'recycling' }
