require "KnoxAirSupport_Shared"

---@class KnoxAirSupportIntegrations
KnoxAirSupport.Integrations = KnoxAirSupport.Integrations or {}

---@type table<string, table<string, any>>
local pools = nil

--- Checks whether an item script is a weapon.
---@param item Item
---@return boolean
local function itemIsWeapon(item)
    local ok, result = pcall(function() return item:isItemType(ItemType.WEAPON) end)
    if ok then return result and true or false end
    local category = item:getDisplayCategory()
    return category == "Weapon" or category == "WeaponCrafted"
end

--- Checks whether an item script is a weapon part or attachment.
---@param item Item
---@return boolean
local function itemIsWeaponPart(item)
    local ok, result = pcall(function() return item:isItemType(ItemType.WEAPON_PART) end)
    if ok then return result and true or false end
    local category = item:getDisplayCategory()
    return category == "WeaponPart" or category == "WeaponAttachment"
end

--- Checks whether an item script is a clothing accessory.
---@param item Item
---@return boolean
local function itemIsAccessory(item)
    local ok, result = pcall(function() return item:isItemType(ItemType.CLOTHING) end)
    if ok and not result then return false end
    local category = item:getDisplayCategory()
    return category == "Accessory" or category == "ProtectiveGear"
end

--- Scans the loaded scripts once and builds the item pools of every supported mod.
---@return table<string, table<string, any>>
function KnoxAirSupport.Integrations.Detect()
    if pools then return pools end

    pools = {
        marz = { weapons = {}, parts = {}, suppressors = {}, available = false },
        snake = { weapons = {}, accessories = {}, available = false },
        bandits = { available = false },
    }

    local ok, items = pcall(function() return getScriptManager():getAllItems() end)
    if not ok or not items then
        print(KnoxAirSupport.TAG .. " WARNING: could not read the script manager, mod loot integrations disabled")
        return pools
    end

    for i = 0, items:size() - 1 do
        local item = items:get(i)
        local module = item:getModuleName() or ""
        local full = item:getFullName()

        local modId = ""
        local idOk, idValue = pcall(function() return item:getModID() end)
        if idOk and idValue then modId = idValue end

        local isMarz = (modId:lower():find("marz") ~= nil)
            or (module:lower():find("marz") ~= nil)

        local isSnake = (modId:lower():find("snake") ~= nil)
            or (modId:upper():find("SMP_") ~= nil)
            or (module == "SCM")

        if isMarz then
            pools.marz.available = true
            if itemIsWeapon(item) then
                table.insert(pools.marz.weapons, full)
            elseif itemIsWeaponPart(item) then
                table.insert(pools.marz.parts, full)
                if full:lower():find("suppressor") then
                    table.insert(pools.marz.suppressors, full)
                end
            end
        elseif isSnake then
            pools.snake.available = true
            if itemIsWeapon(item) then
                table.insert(pools.snake.weapons, full)
            elseif itemIsAccessory(item) then
                table.insert(pools.snake.accessories, full)
            end
        end
    end

    pools.bandits.available = (BanditServer ~= nil and BanditServer.Spawner ~= nil)

    print(KnoxAirSupport.TAG .. " Integrations detected - GunsOfMarz: "
        .. (pools.marz.available and (#pools.marz.weapons .. " weapons") or "not installed")
        .. " | Snake: " .. (pools.snake.available and (#pools.snake.weapons .. " weapons / " .. #pools.snake.accessories .. " accessories") or "not installed"))

    return pools
end

--- Checks whether an integration can be used right now.
---@param id string
---@return boolean
function KnoxAirSupport.Integrations.IsAvailable(id)
    if id == "alife" then
        return (ProjectALife ~= nil) and true or false
    end

    if id == "bandits" then
        return (BanditServer ~= nil and BanditServer.Spawner ~= nil) and true or false
    end

    local detected = KnoxAirSupport.Integrations.Detect()
    local entry = detected[id]
    if not entry then return false end
    return entry.available and true or false
end

--- Gets one of the item pools of an integration.
---@param id string
---@param poolName string
---@return string[]
function KnoxAirSupport.Integrations.GetPool(id, poolName)
    local detected = KnoxAirSupport.Integrations.Detect()
    local entry = detected[id]
    if not entry then return {} end
    return entry[poolName] or {}
end

--- Counts the items an integration can contribute.
---@param id string
---@return integer
function KnoxAirSupport.Integrations.GetItemCount(id)
    local detected = KnoxAirSupport.Integrations.Detect()
    local entry = detected[id]
    if not entry then return 0 end
    local total = 0
    for _, list in pairs(entry) do
        if type(list) == "table" then total = total + #list end
    end
    return total
end

--- Builds the weighted pool of priority loot.
---@return table[]
function KnoxAirSupport.Integrations.GetPriorityPool()
    local detected = KnoxAirSupport.Integrations.Detect()
    local pool = {}

    for _, item in ipairs(detected.marz.suppressors) do
        pool[#pool + 1] = { item = item, weight = 3 }
    end
    for _, item in ipairs(detected.marz.parts) do
        if not item:lower():find("suppressor") then
            pool[#pool + 1] = { item = item, weight = 1 }
        end
    end
    for _, item in ipairs(detected.snake.accessories) do
        pool[#pool + 1] = { item = item, weight = 1 }
    end

    return pool
end

--- Picks one item of the priority pool honouring the weights.
---@param pool table[]
---@return string|nil
function KnoxAirSupport.Integrations.PickPriority(pool)
    if not pool or #pool == 0 then return nil end

    local total = 0
    for _, entry in ipairs(pool) do
        total = total + (entry.weight or 1)
    end
    if total <= 0 then return pool[1].item end

    local roll = ZombRand(total)
    for _, entry in ipairs(pool) do
        roll = roll - (entry.weight or 1)
        if roll < 0 then return entry.item end
    end
    return pool[#pool].item
end
