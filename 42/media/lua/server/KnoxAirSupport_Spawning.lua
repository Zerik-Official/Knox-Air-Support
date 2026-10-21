require "KnoxAirSupport_Shared"
require "KnoxAirSupport_Loot"
require "KnoxAirSupport_Integrations"

---@type string
local CRATE_ITEM = "KnoxAirSupport.KnoxSupplyCrate"

---@type integer
local alifeRequestCounter = 0

--- Finds the supply crate standing on a square.
---@param square IsoGridSquare
---@return IsoObject|nil, InventoryItem|nil
function KnoxAirSupport.FindCrateAt(square)
    if not square then return nil, nil end

    local objects = square:getObjects()
    if not objects then return nil, nil end

    for i = 0, objects:size() - 1 do
        local object = objects:get(i)
        if object then
            local item = nil
            local itemOk, itemValue = pcall(function() return object.item end)
            if itemOk then item = itemValue end

            if item and item.getModData then
                local dataOk, modData = pcall(function() return item:getModData() end)
                if dataOk and modData and modData.knoxCrate then
                    return object, item
                end
            end

            if object.getModData then
                local dataOk, modData = pcall(function() return object:getModData() end)
                if dataOk and modData and modData.knoxCrate then
                    return object, object
                end
            end
        end
    end

    return nil, nil
end

--- Finds a valid, walkable and dry tile around the given coordinates.
---@param x integer
---@param y integer
---@param maxRadius integer|nil
---@return IsoGridSquare|nil, integer, integer
function KnoxAirSupport.FindSpawnSquare(x, y, maxRadius)
    maxRadius = maxRadius or 25
    for radius = 0, maxRadius do
        for ox = -radius, radius do
            for oy = -radius, radius do
                if math.abs(ox) == radius or math.abs(oy) == radius or radius == 0 then
                    local square = getCell():getGridSquare(x + ox, y + oy, 0)
                    if square and square:isFree(false) and not square:isWaterSquare() then
                        return square, x + ox, y + oy
                    end
                end
            end
        end
    end
    return nil, x, y
end

--- Creates the supply crate on a square and fills it with the loot of an event type.
---@param square IsoGridSquare
---@param eventTypeId string
---@param config table<string,any>
---@return InventoryItem|nil
function KnoxAirSupport.SpawnCrate(square, eventTypeId, config)
    config = config or KnoxAirSupport.ConfigFromSandbox()

    local item = nil
    local ok, err = pcall(function()
        item = InventoryItemFactory.CreateItem(CRATE_ITEM)
        if not item then error("could not create " .. CRATE_ITEM) end

        local container = ItemContainer.new()
        container:setType("crate")
        container:setCapacity(KnoxAirSupport.Clamp(config.crateCapacity or 75, 10, 200))
        container:setExplored(false)
        item:setContainer(container)

        KnoxAirSupport.Loot.FillContainer(container, eventTypeId, config)

        local chance = tonumber(config.priorityChance) or 0
        if chance > 0 and ZombRand(100) < chance then
            local pool = KnoxAirSupport.Integrations.GetPriorityPool()
            local itemType = KnoxAirSupport.Integrations.PickPriority(pool)
            if itemType and container:AddItem(itemType) then
                print(KnoxAirSupport.TAG .. " Priority loot added: " .. itemType)
            end
        end

        pcall(function() item:getModData().knoxCrate = true end)

        square:AddWorldInventoryItem(item, 0, 0, 0)
    end)

    if not ok then
        print(KnoxAirSupport.TAG .. " ERROR spawning crate: " .. tostring(err))
        item = nil
    end

    if item then
        print(KnoxAirSupport.TAG .. " Crate spawned at " .. square:getX() .. ", " .. square:getY()
            .. " | type=" .. eventTypeId
            .. " | items=" .. (item:getContainer() and item:getContainer():getItems():size() or 0))
    end

    return item
end

--- Spawns the guardian NPCs with the Bandits mod api.
---@param x number
---@param y number
---@param clanId string|nil
---@param config table<string,any>
---@return boolean
function KnoxAirSupport.SpawnGuardians(x, y, clanId, config)
    config = config or KnoxAirSupport.ConfigFromSandbox()

    if not config.int_bandits then
        print(KnoxAirSupport.TAG .. " Bandits guardians disabled, skipping NPC spawn")
        return false
    end
    if not clanId then return false end
    if not BanditServer or not BanditServer.Spawner then
        print(KnoxAirSupport.TAG .. " Bandits mod not available in this save")
        return false
    end

    local player = nil
    KnoxAirSupport.ForEachPlayer(function(p) player = player or p end)
    if not player then return false end

    local size = config.guardianCount or 1
    if size <= 0 then
        print(KnoxAirSupport.TAG .. " Guardian count is 0, skipping NPC spawn")
        return false
    end

    local ok, err = pcall(function()
        BanditServer.Spawner.Clan(player, {
            cid = clanId,
            x = x + ZombRand(-5, 5),
            y = y + ZombRand(-5, 5),
            z = 0,
            size = size,
            program = "Defend",
            permanent = true,
        })
        print(KnoxAirSupport.TAG .. " Spawned " .. size .. " guardians (clan=" .. clanId .. ")")
    end)

    if not ok then
        print(KnoxAirSupport.TAG .. " ERROR spawning guardians: " .. tostring(err))
        return false
    end
    return true
end

--- Spawns the guardian NPCs with the Project A-Life api.
---@param x number
---@param y number
---@param count integer
---@param config table<string,any>
---@return boolean
function KnoxAirSupport.SpawnALifeGuardians(x, y, count, config)
    config = config or KnoxAirSupport.ConfigFromSandbox()

    if not config.int_alife then
        print(KnoxAirSupport.TAG .. " Project A-Life guardians disabled, skipping NPC spawn")
        return false
    end

    local service = ProjectALife and ProjectALife.DebugService
    if not service or type(service.spawnEncounter) ~= "function" then
        print(KnoxAirSupport.TAG .. " Project A-Life not available in this save")
        return false
    end

    local player = nil
    KnoxAirSupport.ForEachPlayer(function(p) player = player or p end)
    if not player then return false end

    local size = math.min(8, math.max(1, tonumber(count) or 1))
    if (tonumber(config.guardianCount) or 0) <= 0 then
        print(KnoxAirSupport.TAG .. " Guardian count is 0, skipping NPC spawn")
        return false
    end

    alifeRequestCounter = alifeRequestCounter + 1
    local args = {
        kind = "squad",
        count = size,
        x = math.floor(x),
        y = math.floor(y),
        z = 0,
        mode = "guard",
        anchor = true,
        playerStance = "hostile",
        hostileOverride = "hostile",
        respectGates = true,
        requestId = "knoxair:" .. tostring(getTimestampMs()) .. ":" .. tostring(alifeRequestCounter),
    }

    local ok, handled, reason, payload = pcall(function()
        return service.spawnEncounter(player, args, false)
    end)

    if not ok then
        print(KnoxAirSupport.TAG .. " ERROR spawning Project A-Life guardians: " .. tostring(handled))
        return false
    end

    if handled ~= true then
        print(KnoxAirSupport.TAG .. " Project A-Life refused the spawn: " .. tostring(reason))
        return false
    end

    local accepted = 0
    if type(payload) == "table" then accepted = tonumber(payload.accepted) or 0 end
    if accepted <= 0 then
        print(KnoxAirSupport.TAG .. " Project A-Life spawned 0 guardians"
            .. (reason and (" (" .. tostring(reason) .. ")") or ""))
        return false
    end

    print(KnoxAirSupport.TAG .. " Spawned " .. accepted .. " Project A-Life guardians at " .. x .. ", " .. y)
    return true
end

--- Spawns plain zombies as a fallback when no guardians are available.
---@param x number
---@param y number
---@param count integer
---@return nil
function KnoxAirSupport.SpawnZombies(x, y, count)
    if count <= 0 then count = 15 end
    local ok, err = pcall(function()
        addZombiesInOutfit(x, y, 0, count, nil, 50)
        print(KnoxAirSupport.TAG .. " Spawned " .. count .. " zombies at " .. x .. ", " .. y)
    end)
    if not ok then
        print(KnoxAirSupport.TAG .. " ERROR spawning zombies: " .. tostring(err))
    end
end

--- Removes a crate from the world and gives the dismantling materials to a player.
---@param squareX integer
---@param squareY integer
---@param squareZ integer
---@param player IsoPlayer|nil
---@return boolean
function KnoxAirSupport.DismantleCrate(squareX, squareY, squareZ, player)
    local square = getCell():getGridSquare(squareX, squareY, squareZ)
    if not square then return false end

    local object = KnoxAirSupport.FindCrateAt(square)
    if not object then return false end

    local items = {}
    for _, reward in ipairs(KnoxAirSupport.DISMANTLE_REWARDS) do
        local amount = ZombRand(reward.min, reward.max)
        for _ = 1, amount do
            items[#items + 1] = reward.type
        end
    end

    if player and player.getInventory then
        local inventory = player:getInventory()
        for _, itemType in ipairs(items) do
            inventory:AddItem(itemType)
        end
    end

    square:transmitRemoveItemFromSquare(object)
    print(KnoxAirSupport.TAG .. " Crate dismantled at " .. squareX .. ", " .. squareY)
    return true
end
