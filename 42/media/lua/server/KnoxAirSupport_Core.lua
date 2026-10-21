require "KnoxAirSupport_Shared"
require "KnoxAirSupport_Loot"
require "KnoxAirSupport_Integrations"
require "KnoxAirSupport_Events"
require "KnoxAirSupport_Spawning"

if isClient() then return end

---@class KnoxAirSupportServer
---@field config table<string,any>|nil
---@field activeEvent table|nil
KnoxAirSupport_Server = KnoxAirSupport_Server or {}

---@type integer
local lastEventEndTime = 0
---@type integer
local nextEventTime = 0
---@type integer
local tickCounter = 0
---@type integer
local noSquareWarnings = 0
---@type table[]
local crateList = {}

--- Reads the configuration stored in the save data.
---@return table<string,any>
local function readStoredConfig()
    local ok, modData = pcall(function() return ModData.get(KnoxAirSupport.CONFIG_TABLE) end)
    if not ok or not modData then return nil end

    local stored = {}
    for _, key in ipairs(KnoxAirSupport.CONFIG_KEYS) do
        local value = nil
        local readOk = pcall(function() value = modData[key] end)
        if readOk and value ~= nil then stored[key] = value end
    end
    return stored
end

--- Writes the configuration into the save data.
---@param config table<string,any>
---@return nil
local function writeStoredConfig(config)
    local ok, modData = pcall(function() return ModData.getOrCreate(KnoxAirSupport.CONFIG_TABLE) end)
    if not ok or not modData then return end
    for _, key in ipairs(KnoxAirSupport.CONFIG_KEYS) do
        pcall(function() modData[key] = config[key] end)
    end
    pcall(function() ModData.transmit(KnoxAirSupport.CONFIG_TABLE) end)
end

--- Returns the effective configuration of the server.
---@return table<string,any>
function KnoxAirSupport_Server.GetConfig()
    local config = KnoxAirSupport.ConfigFromSandbox()
    local stored = readStoredConfig()
    if stored then
        for key, value in pairs(stored) do
            config[key] = value
        end
    end
    KnoxAirSupport_Server.config = config
    return config
end

--- Stores a single configuration value and broadcasts the new configuration.
---@param key string
---@param value any
---@return table<string,any>
function KnoxAirSupport_Server.SetConfigValue(key, value)
    local config = KnoxAirSupport_Server.GetConfig()
    config[key] = value
    writeStoredConfig(config)
    KnoxAirSupport.Broadcast(KnoxAirSupport.CMD_CONFIG, config)
    print(KnoxAirSupport.TAG .. " Config updated: " .. key .. " = " .. tostring(value))
    return config
end

--- Counts the connected players.
---@return integer
local function countPlayers()
    local count = 0
    KnoxAirSupport.ForEachPlayer(function() count = count + 1 end)
    return count
end

--- Computes the centroid of every connected player.
---@return number|nil, number|nil, integer
local function playerCentroid()
    local sumX, sumY, count = 0, 0, 0
    KnoxAirSupport.ForEachPlayer(function(player)
        sumX = sumX + player:getX()
        sumY = sumY + player:getY()
        count = count + 1
    end)
    if count == 0 then return nil end
    return sumX / count, sumY / count, count
end

--- Removes a crate from the world.
---@param entry table
---@return nil
local function removeCrate(entry)
    if not entry or not entry.obj then return end
    local item = entry.obj
    local ok, err = pcall(function()
        local wrapper = nil
        if item.getWorldItem then
            local worldOk, worldValue = pcall(function() return item:getWorldItem() end)
            if worldOk then wrapper = worldValue end
        end
        if wrapper then
            local square = wrapper:getSquare()
            if square then
                square:transmitRemoveItemFromSquare(wrapper)
            else
                wrapper:removeFromWorld()
            end
        elseif item.removeFromWorld then
            item:removeFromWorld()
        end
        print(KnoxAirSupport.TAG .. " Crate despawned")
    end)
    if not ok then print(KnoxAirSupport.TAG .. " ERROR despawning crate: " .. tostring(err)) end
end

--- Ends the active event.
---@param keepCrate boolean|nil
---@return nil
local function endEvent(keepCrate)
    local event = KnoxAirSupport_Server.activeEvent
    if not event then return end

    if event.crateEntry and not keepCrate then
        removeCrate(event.crateEntry)
        for i = #crateList, 1, -1 do
            if crateList[i] == event.crateEntry then table.remove(crateList, i) end
        end
    end

    KnoxAirSupport_Server.activeEvent = nil
    lastEventEndTime = getTimestampMs()
    KnoxAirSupport.Broadcast(KnoxAirSupport.CMD_EVENT_END, {})
    print(KnoxAirSupport.TAG .. " === EVENT ENDED ===")
end

--- Pushes the next event one full frequency period ahead.
---@return nil
local function scheduleNextEvent()
    local config = KnoxAirSupport_Server.GetConfig()
    nextEventTime = getTimestampMs() + (config.eventFrequency * 60000)
end

--- Announces a new supply drop event.
---@param eventTypeId string|nil
---@param explicitX number|nil
---@param explicitY number|nil
---@return nil
local function startEvent(eventTypeId, explicitX, explicitY)
    local config = KnoxAirSupport_Server.GetConfig()
    if not config.enabled then
        print(KnoxAirSupport.TAG .. " Supply drops are disabled")
        return
    end

    local eventType = KnoxAirSupport.PickEventType(eventTypeId)

    local x, y
    if explicitX and explicitY then
        x, y = math.floor(explicitX), math.floor(explicitY)
    else
        local centerX, centerY = playerCentroid()
        if not centerX then
            print(KnoxAirSupport.TAG .. " No players online, skipping drop")
            return
        end
        local minDistance = config.minDistance
        local maxDistance = config.maxDistance
        if maxDistance <= minDistance then maxDistance = minDistance + 100 end
        local angle = ZombRand(360) * math.pi / 180
        local distance = minDistance + ZombRand(maxDistance - minDistance + 1)
        x = math.floor(centerX + math.cos(angle) * distance)
        y = math.floor(centerY + math.sin(angle) * distance)
    end

    KnoxAirSupport_Server.activeEvent = {
        x = x,
        y = y,
        eventType = eventType,
        startTime = getTimestampMs(),
        spawned = false,
        crateObj = nil,
    }

    print(KnoxAirSupport.TAG .. " === EVENT STARTED === " .. eventType.name .. " at (" .. x .. ", " .. y .. ")"
        .. " - waiting for a player to come within " .. config.spawnRadius .. " tiles")

    KnoxAirSupport.Broadcast(KnoxAirSupport.CMD_EVENT_START, {
        x = x,
        y = y,
        name = eventType.name,
        eventType = eventType.id,
    })
end

--- Materialises the crate once a player is close enough to the landing zone.
---@return nil
local function trySpawnDrop()
    local event = KnoxAirSupport_Server.activeEvent
    if not event or event.spawned then return end

    local config = KnoxAirSupport_Server.GetConfig()
    local square, squareX, squareY = KnoxAirSupport.FindSpawnSquare(event.x, event.y, 25)

    if not square then
        noSquareWarnings = noSquareWarnings + 1
        if noSquareWarnings % 30 == 1 then
            print(KnoxAirSupport.TAG .. " No valid landing tile near " .. event.x .. ", " .. event.y .. " - retrying")
        end
        return
    end

    local eventType = event.eventType or KnoxAirSupport.PickEventType()
    local crate = KnoxAirSupport.SpawnCrate(square, eventType.id, config)
    if not crate then
        print(KnoxAirSupport.TAG .. " ERROR: crate could not be created, retrying later")
        return
    end

    event.x, event.y = squareX, squareY
    event.crateObj = crate
    event.crateEntry = { obj = crate, spawnedAt = getTimestampMs(), x = squareX, y = squareY }
    event.spawned = true
    noSquareWarnings = 0
    crateList[#crateList + 1] = event.crateEntry

    crate:setName(KnoxAirSupport.Translate(eventType.crateNameKey, eventType.crateName))

    local hasGuardians = false
    if config.int_bandits then
        hasGuardians = KnoxAirSupport.SpawnGuardians(squareX, squareY, eventType.clan, config)
    else
        print(KnoxAirSupport.TAG .. " Bandits integration disabled")
    end

    if not hasGuardians and config.int_alife then
        hasGuardians = KnoxAirSupport.SpawnALifeGuardians(squareX, squareY, config.guardianCount, config)
    end

    if not hasGuardians then
        if config.int_zombies then
            KnoxAirSupport.SpawnZombies(squareX + ZombRand(6, 12), squareY + ZombRand(6, 12), 10)
        else
            print(KnoxAirSupport.TAG .. " No guardians and no zombies, leaving the crate alone")
        end
    end

    print(KnoxAirSupport.TAG .. " === DROP COMPLETE === (" .. squareX .. ", " .. squareY .. ") " .. eventType.crateName)

    KnoxAirSupport.Broadcast(KnoxAirSupport.CMD_EVENT_SPAWNED, {
        x = squareX,
        y = squareY,
        name = eventType.crateName,
    })
end

--- Spawns the crate as soon as a player walks close to the landing zone.
---@return nil
local function checkPlayerProximity()
    local event = KnoxAirSupport_Server.activeEvent
    if not event or event.spawned then return end

    local config = KnoxAirSupport_Server.GetConfig()
    local radius = config.spawnRadius
    local radiusSquared = radius * radius
    local handled = false

    KnoxAirSupport.ForEachPlayer(function(player)
        if handled then return end
        local deltaX = player:getX() - event.x
        local deltaY = player:getY() - event.y
        if (deltaX * deltaX + deltaY * deltaY) <= radiusSquared then
            handled = true
            trySpawnDrop()
        end
    end)
end

--- Runs the event schedule and the crate lifetime.
---@return nil
local function onEveryMinute()
    local config = KnoxAirSupport_Server.GetConfig()
    if not config.enabled then return end

    local now = getTimestampMs()

    local lifetime = tonumber(config.despawnTimer) or 0
    if lifetime > 0 then
        for i = #crateList, 1, -1 do
            local entry = crateList[i]
            if (now - entry.spawnedAt) / 60000 >= lifetime then
                removeCrate(entry)
                table.remove(crateList, i)
            end
        end
    end

    if now >= nextEventTime then
        if KnoxAirSupport_Server.activeEvent then
            endEvent(true)
        end
        startEvent()
        nextEventTime = now + (config.eventFrequency * 60000)
    end
end

--- Runs the proximity check and the schedule once per second.
---@return nil
local function onTick()
    tickCounter = tickCounter + 1
    if tickCounter % 30 == 0 then
        onEveryMinute()
        checkPlayerProximity()
    end
end

--- Handles the commands sent by the clients.
---@param module string
---@param command string
---@param player IsoPlayer|nil
---@param args table|nil
---@return nil
local function onClientCommand(module, command, player, args)
    if module ~= KnoxAirSupport.MOD_ID then return end
    args = args or {}

    if command == KnoxAirSupport.CMD_CONFIG_GET then
        local config = KnoxAirSupport_Server.GetConfig()
        KnoxAirSupport.SendToPlayer(player, KnoxAirSupport.CMD_CONFIG, config)

    elseif command == KnoxAirSupport.CMD_CONFIG_SET then
        local key = args.key
        if key then
            local value = args.value
            if key == "eventFrequency" then value = KnoxAirSupport.Clamp(value, 1, 1440)
            elseif key == "despawnTimer" then value = KnoxAirSupport.Clamp(value, 0, 720)
            elseif key == "minDistance" then value = KnoxAirSupport.Clamp(value, 10, 3000)
            elseif key == "maxDistance" then value = KnoxAirSupport.Clamp(value, 20, 4000)
            elseif key == "spawnRadius" then value = KnoxAirSupport.Clamp(value, 10, 600)
            elseif key == "guardianCount" then value = KnoxAirSupport.Clamp(value, 0, 30)
            elseif key == "lootQuantity" then value = KnoxAirSupport.Clamp(value, 1, 60)
            elseif key == "crateCapacity" then value = KnoxAirSupport.Clamp(value, 10, 200)
            elseif key == "priorityChance" then value = KnoxAirSupport.Clamp(value, 0, 100)
            elseif key == "enabled" or key == "int_bandits" or key == "int_marz"
                or key == "int_snake" or key == "int_zombies" or key == "int_alife"
                or key == "mapMarker" or key == "sound" then
                value = value and true or false
            end
            KnoxAirSupport_Server.SetConfigValue(key, value)
        end

    elseif command == KnoxAirSupport.CMD_FORCE_DROP then
        if KnoxAirSupport_Server.activeEvent then
            print(KnoxAirSupport.TAG .. " An event is already active, ending it first")
            endEvent()
        end
        startEvent(args.eventType)
        scheduleNextEvent()

    elseif command == KnoxAirSupport.CMD_FORCE_HERE then
        if KnoxAirSupport_Server.activeEvent then
            print(KnoxAirSupport.TAG .. " An event is already active, ending it first")
            endEvent()
        end
        local target = player
        if not target then target = getSpecificPlayer(0) end
        if not target then
            print(KnoxAirSupport.TAG .. " No player available for the drop")
            return
        end
        startEvent(nil, target:getX(), target:getY())
        scheduleNextEvent()

    elseif command == KnoxAirSupport.CMD_END_EVENT then
        endEvent()

    elseif command == KnoxAirSupport.CMD_DISMANTLE then
        local ok, done = pcall(function()
            return KnoxAirSupport.DismantleCrate(args.x, args.y, args.z, player)
        end)
        if not ok then
            print(KnoxAirSupport.TAG .. " ERROR dismantling crate: " .. tostring(done))
            return
        end
        if not done then
            print(KnoxAirSupport.TAG .. " Dismantle request ignored, no crate found")
        end
    end
end

KnoxAirSupport_Server.OnClientCommand = onClientCommand

--- Forces a supply drop of the given type from the server side.
---@param eventTypeId string|nil
---@return nil
KnoxAirSupport_Server.ForceDrop = function(eventTypeId)
    if KnoxAirSupport_Server.activeEvent then
        print(KnoxAirSupport.TAG .. " An event is already active, ending it first")
        endEvent()
    end
    startEvent(eventTypeId)
    scheduleNextEvent()
end

--- Forces a supply drop at the position of the local player from the server side.
---@return nil
KnoxAirSupport_Server.ForceDropHere = function()
    if KnoxAirSupport_Server.activeEvent then
        print(KnoxAirSupport.TAG .. " An event is already active, ending it first")
        endEvent()
    end
    local player = getSpecificPlayer(0)
    if not player then
        print(KnoxAirSupport.TAG .. " No local player")
        return
    end
    startEvent(nil, player:getX(), player:getY())
    scheduleNextEvent()
end

--- Ends the active event from the server side.
---@return nil
KnoxAirSupport_Server.EndEvent = function()
    endEvent()
end

--- Counts the crates that are still lying in the world.
---@return integer
KnoxAirSupport_Server.GetCrateCount = function()
    return #crateList
end

--- Loads the configuration and prepares the first event.
---@return nil
local function bootstrap()
    local config = KnoxAirSupport_Server.GetConfig()
    KnoxAirSupport.Integrations.Detect()
    lastEventEndTime = getTimestampMs()
    nextEventTime = lastEventEndTime + (config.eventFrequency * 60000)
    print(KnoxAirSupport.TAG .. " Server module loaded")
end

bootstrap()

if isServer() then
    Events.OnServerStarted.Add(bootstrap)
end

if Events.EveryOneMinute then
    Events.EveryOneMinute.Add(onEveryMinute)
else
    print(KnoxAirSupport.TAG .. " WARNING: Events.EveryOneMinute not available, using the tick instead")
end

if Events.OnTick then
    Events.OnTick.Add(onTick)
end
