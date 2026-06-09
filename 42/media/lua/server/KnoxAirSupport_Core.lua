require "KnoxAirSupport_Shared"
require "KnoxAirSupport_Loot"
require "KnoxAirSupport_Events"
require "KnoxAirSupport_Spawning"

local TAG = KnoxAirSupport.TAG

if isClient() then return end

local IS_SP_MODE = not isClient() and not isServer()

local activeEvent = nil
local lastEventTime = 0

-- Pick a valid spawn square near given coordinates
local function findSpawnSquare(x, y)
    for radius = 0, 30 do
        for ox = -radius, radius do
            for oy = -radius, radius do
                if math.abs(ox) == radius or math.abs(oy) == radius or radius == 0 then
                    local sq = getCell():getGridSquare(x + ox, y + oy, 0)
                    if sq and sq:isFree(false) and not sq:isWaterSquare() then
                        return sq, x + ox, y + oy
                    end
                end
            end
        end
    end
    return nil, x, y
end

-- Spawn the drop: crate + guardians (or zombies as fallback)
local function spawnDrop(eventType, x, y)
    local sq, sx, sy = findSpawnSquare(x, y)
    if not sq then
        print(TAG .. " No valid spawn square found at " .. x .. "," .. y)
        return false
    end

    local crate = KnoxAirSupport.SpawnCrate(sq)
    if not crate then return false end

    local clanId, crateName = KnoxAirSupport.AnalyzeContainer(crate:getContainer())
    crate:setName(crateName)

    local hasGuardians = KnoxAirSupport.SpawnGuardians(sx, sy, clanId)
    if not hasGuardians then
        KnoxAirSupport.SpawnZombies(sx + ZombRand(6, 12) * (ZombRand(2) == 0 and -1 or 1),
                                    sy + ZombRand(6, 12) * (ZombRand(2) == 0 and -1 or 1), 15)
    end

    print(TAG .. " === DROP COMPLETE === (" .. sx .. ", " .. sy .. ") type=" .. eventType.name)
    return true
end

-- Start a new drop event (pass eventTypeId to force a specific type)
local function startEvent(eventTypeId)
    local eventType
    if eventTypeId then
        for _, et in ipairs(KnoxAirSupport.EVENT_TYPES) do
            if et.id == eventTypeId then eventType = et; break end
        end
    end
    if not eventType then eventType = KnoxAirSupport.PickEventType() end

    -- Find a position near a player
    local player = getSpecificPlayer(0)
    if not player then
        local players = getOnlinePlayers()
        if players and players:size() > 0 then player = players:get(0) end
    end
    if not player then
        print(TAG .. " No players online, skipping drop")
        return
    end

    local px, py = player:getX(), player:getY()
    local minDist, maxDist = 200, 800
    local angle = ZombRand(360) * 0.01745
    local dist = minDist + ZombRand(maxDist - minDist)
    local dx = math.floor(px + math.cos(angle) * dist)
    local dy = math.floor(py + math.sin(angle) * dist)

    activeEvent = {
        eventType = eventType,
        x = dx, y = dy,
        startTime = getTimestampMs(),
    }

    print(TAG .. " === EVENT STARTED === type=" .. eventType.name .. " at (" .. dx .. ", " .. dy .. ")")

    if spawnDrop(eventType, dx, dy) then
        activeEvent.spawned = true
    else
        activeEvent = nil
    end
end

-- End the current event
local function endEvent()
    if not activeEvent then return end
    activeEvent = nil
    lastEventTime = getTimestampMs()
    print(TAG .. " === EVENT ENDED ===")
end

-- Global function for Lua console testing:
--   KnoxAirSupport.ForceDrop()          -- random type
--   KnoxAirSupport.ForceDrop("military")
--   KnoxAirSupport.ForceDrop("survival")
--   KnoxAirSupport.ForceDrop("bandit")
--   KnoxAirSupport.ForceDrop("elite")
function KnoxAirSupport.ForceDrop(eventTypeId)
    if activeEvent then
        print(TAG .. " An event is already active, ending it first")
        endEvent()
    end
    startEvent(eventTypeId)
end

-- OnEveryMinute: check if it's time for a new drop
local function onEveryMinute()
    if not activeEvent then
        local elapsed = (getTimestampMs() - lastEventTime) / 60000
        if elapsed >= 180 then
            startEvent()
        end
    else
        -- Despawn after 45 minutes
        local elapsed = (getTimestampMs() - activeEvent.startTime) / 60000
        if elapsed >= 45 then
            endEvent()
        end
    end
end

Events.OnEveryMinute.Add(onEveryMinute)

print(TAG .. " Core module loaded")
