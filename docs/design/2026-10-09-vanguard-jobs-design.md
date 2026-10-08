# Vanguard Jobs — design

Date: 2026-10-09 · Status: approved in chat · Resource / folder: `vanguard-jobs` (QBCore first, multi-framework later)

## Purpose

Team jobs for FiveM, built first for the Rover Development QBCore server. One **Job Center** NPC; pressing **E** opens a
tablet-style **Job Portal** where players form a team (1–4) and start a job together. First jobs:
**Delivery** and **Recycling**; more job types are added later as config + small client code.

Success: two friends meet at the Job Center, make a team in the portal, start Delivery, the van
spawns in the parking lot with keys for the leader, they drive the route, carry boxes to doors,
return the van and each get one bank payment that is higher than a solo run.

## Decisions (from the chat)

| Topic | Decision |
|---|---|
| Location | One Job Center (NPC + map icon + parking lot). Admins can move NPC and parking in-game. |
| Portal | Own tablet-style NUI, opened by E at the NPC, `/jobs`, or a **Jobs** tile on ph-tablet. No item needed. |
| Teams | Create / join open team / leave / kick, max 4. Leader starts jobs. Leader leaving hands over to the next member. |
| Vehicle | Spawns at the Job Center parking on start; **keys to the team leader**; full tank; job plate. |
| Delivery | Box van; 4–6 store back-door stops; at each stop members take boxes from the back of the van and carry them to the door. |
| Recycling | Recycling truck; 4–6 bin stops; members take bags from the bins and throw them into the back of the truck. |
| End of run | Drive back to the Job Center and press **Finish** in the portal. |
| Pay | **One bank payment per member at the end.** Amount = pay per completed stop × stops + route bonus (only when all stops done), × team bonus. Quitting early pays done stops without the bonus. |
| Team bonus | Every member gets: 1 player 100 %, 2 → 115 %, 3 → 130 %, 4 → 150 %. |
| Deposit | Leader pays a vehicle deposit on start; refunded when the vehicle is brought back to the Job Center. |
| Old job | `qb-recyclejob` disabled (moved to backups). |

## How a run works

Each job is defined by: vehicle model, stop list, stops per run, units (boxes/bags) per stop,
pay per stop, route bonus, and where a unit is **picked up** and **dropped**:

| Job | Pick up a unit at | Drop it at |
|---|---|---|
| Delivery | back of the vehicle | the stop (store door) |
| Recycling | the stop (bin) | back of the vehicle |

Run phases: `driving to stop N` → (units moved one by one, any member) → next stop → after the last
stop: `return to Job Center` → **Finish** → pay → vehicle removed.

A member can carry one unit at a time (carry animation + prop). The portal and a small on-screen
tracker show `Delivery · Stop 3/5 · Boxes 1/3`.

## Architecture

```
vanguard-jobs/
  fxmanifest.lua  config.lua
  shared/rules.lua       pure: team bonus, payout, random stop pick, input checks
  shared/teamstore.lua   pure: team membership (create/join/leave/kick/leader handover)
  bridge/server.lua      QBCore: identifier, name, bank money, notify
  bridge/client.lua      QBCore: vehicle keys, fuel, notify, [E] text
  server/router.lua      one request/response event, rate limit, pcall
  server/teams.lua       TeamStore instance + portal handlers (state/create/join/leave/kick)
  server/runs.lua        start/cancel/finish, units, vehicle spawn, payout
  server/center.lua      Job Center location (config + admin override saved to data/center.json)
  client/main.lua        requests, portal open/close, state updates
  client/center.lua      NPC, blip, [E] prompt, admin move commands
  client/run.lua         stop blips/waypoints, [E] take/drop, carry anims, tracker
  client/tablet.lua      ph-tablet "Jobs" tile (only if ph-tablet is running)
  html/                  portal (index.html, style.css, app.js) + tracker + tablet tile module
  tests/                 fengari specs for shared/*
```

**Server decides everything**: team membership, current stop, whether a unit was really taken and
dropped (player distance to the stop / to the vehicle's rear, checked server-side from the networked
vehicle), and the payout. Teams and runs live in memory (no database). Vehicle is spawned server-side
(`CreateVehicleServerSetter`) so the server knows it.

## Edge cases

- Leader disconnects → next member becomes leader; last member leaves → run cancelled, vehicle deleted.
- Member leaves mid-run → no pay for them; others continue.
- Vehicle destroyed / deleted → leader can **Cancel** (done stops paid, deposit lost).
- Joining a team that is on a run is not allowed; teams are full at 4.
- Taking a unit while already carrying, or dropping without carrying, is refused.

## Testing

- Automated (fengari): rules (team bonus, payout incl. early quit, stop picking), teamstore
  (create, join limits, leave with leader handover, kick rules, disband).
- Syntax checks for all Lua and the portal JS; browser preview of the portal with sample data.
- In-game test by Rover_Op: solo Delivery and Recycling run, then a 2-player team.
