require "KnoxAirSupport_Shared"
require "KnoxAirSupport_Loot"

local TAG = KnoxAirSupport.TAG

local CRATE_SPRITE = "constructedobjects_01_44"

-- Fill loot into a container from LOOT_CATEGORIES
local function fillLoot(container)
    local added = 0
    for _, cat in ipairs(KnoxAirSupport.LOOT_CATEGORIES) do
        local count = cat.min + ZombRand(cat.max - cat.min + 1)
        if count > #cat.items then count = #cat.items end
        if count > 0 then
            local idx = {}
            for i = 1, #cat.items do idx[i] = i end
            for i = #idx, 2, -1 do
                local j = ZombRand(i) + 1
                idx[i], idx[j] = idx[j], idx[i]
            end
            for pick = 1, count do
                if container:AddItem(cat.items[idx[pick]]) then
                    added = added + 1
                end
            end
        end
    end
    return added
end

-- Spawn the physical crate
function KnoxAirSupport.SpawnCrate(sq)
    local ok, err = pcall(function()
        local crate = IsoThumpable.new(getCell(), sq, CRATE_SPRITE, false, {})
        crate:setName("Supply Crate")
        crate:setMaxHealth(10000)
        crate:setHealth(10000)
        crate:setIsThumpable(false)
        sq:AddSpecialObject(crate)

        local container = ItemContainer.new()
        container:setType("crate")
        container:setCapacity(100)
        container:setExplored(false)
        crate:setContainer(container)

        fillLoot(container)
        crate:transmitCompleteItemToClients()

        print(TAG .. " Crate spawned at " .. sq:getX() .. ", " .. sq:getY()
            .. " | items=" .. container:getItems():size())
        return crate
    end)
    if not ok then
        print(TAG .. " ERROR spawning crate: " .. tostring(err))
    end
    return ok
end

-- Spawn guardians using Bandits mod API
function KnoxAirSupport.SpawnGuardians(x, y, clanId)
    if not clanId then return false end
    if not BanditServer or not BanditServer.Spawner then return false end

    local player = getSpecificPlayer(0)
    if not player then
        local players = getOnlinePlayers()
        if players and players:size() > 0 then player = players:get(0) end
    end
    if not player then return false end

    local size = 3 + ZombRand(3)
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
        print(TAG .. " Spawned " .. size .. " guardians (clan=" .. clanId .. ")")
    end)
    if not ok then
        print(TAG .. " ERROR spawning guardians: " .. tostring(err))
    end
    return ok
end

-- Spawn zombies as fallback when guardians aren't available
function KnoxAirSupport.SpawnZombies(x, y, count)
    if count <= 0 then count = 15 end
    local ok, err = pcall(function()
        addZombiesInOutfit(x, y, 0, count, nil, 50)
        print(TAG .. " Spawned " .. count .. " zombies at " .. x .. ", " .. y)
    end)
    if not ok then
        print(TAG .. " ERROR spawning zombies: " .. tostring(err))
    end
end

print(TAG .. " Spawning module loaded")
