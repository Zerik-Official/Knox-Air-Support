---@class KnoxAirSupport
---@field MOD_ID string
---@field TAG string
---@field CONFIG_TABLE string
---@field CONFIG_KEYS string[]
---@field INTEGRATIONS table[]
---@field CLANS table<string,string>
---@field EVENT_TYPES table[]
---@field DISMANTLE_REWARDS table[]
---@field Config table<string,any>
KnoxAirSupport = KnoxAirSupport or {}

KnoxAirSupport.MOD_ID = "KnoxAirSupport"
KnoxAirSupport.TAG = "[KnoxAirSupport]"
KnoxAirSupport.CONFIG_TABLE = "KnoxAirSupport"
KnoxAirSupport.CONFIG_VERSION = 2

---@type string
KnoxAirSupport.CMD_EVENT_START = "EventStart"
---@type string
KnoxAirSupport.CMD_EVENT_SPAWNED = "EventSpawned"
---@type string
KnoxAirSupport.CMD_EVENT_END = "EventEnd"
---@type string
KnoxAirSupport.CMD_CONFIG = "Config"
---@type string
KnoxAirSupport.CMD_CONFIG_GET = "ConfigGet"
---@type string
KnoxAirSupport.CMD_CONFIG_SET = "ConfigSet"
---@type string
KnoxAirSupport.CMD_FORCE_DROP = "ForceDrop"
---@type string
KnoxAirSupport.CMD_FORCE_HERE = "ForceDropHere"
---@type string
KnoxAirSupport.CMD_END_EVENT = "EndEvent"
---@type string
KnoxAirSupport.CMD_DISMANTLE = "Dismantle"

---@type string[]
KnoxAirSupport.CONFIG_KEYS = {
    "enabled",
    "eventFrequency",
    "despawnTimer",
    "minDistance",
    "maxDistance",
    "spawnRadius",
    "guardianCount",
    "lootQuantity",
    "lootQuantityMin",
    "crateCapacity",
    "priorityChance",
    "int_bandits",
    "int_marz",
    "int_snake",
    "int_zombies",
    "int_alife",
    "mapMarker",
    "sound",
}

---@type table[]
KnoxAirSupport.INTEGRATIONS = {
    { id = "bandits", cfgKey = "int_bandits", label = "IGUI_KnoxAirSupport_Int_Bandits" },
    { id = "marz", cfgKey = "int_marz", label = "IGUI_KnoxAirSupport_Int_Marz" },
    { id = "snake", cfgKey = "int_snake", label = "IGUI_KnoxAirSupport_Int_Snake" },
}

---@type table<string,string>
KnoxAirSupport.CLANS = {
    ARMY = "a2dec2f0-c76d-4640-8a71-733a547a1ebc",
    REDNECKS = "f6e2ca8c-311e-4ee2-9fe6-1c9e14dbcd11",
    ROBBERS = "f8aa0e8c-92ee-4dce-99e8-e4cc3a5a8fbe",
    BUTCHERS = "8db5a57f-b0a9-4b04-9228-beeadd2db2fa",
    HIKERS = "6e319aac-4480-4367-aa9a-5d4bf2ced9d1",
    CANNIBALS = "b7d3a430-e966-48e8-97fa-9078c8d848a4",
    LEGION = "49facd22-4067-4ebd-9196-9bf6951a435c",
    CRIMINALS = "1eb2f74a-8d09-4346-8ba4-3a02665647e5",
    SPORT = "f06e063f-551c-4fd5-aa19-bc15185c2371",
}

---@type table[]
KnoxAirSupport.EVENT_TYPES = {
    {
        id = "food",
        name = "Food Supply",
        crateNameKey = "IGUI_KnoxAirSupport_Crate_Food",
        crateName = "Food Supply Crate",
        clan = KnoxAirSupport.CLANS.HIKERS,
        weight = 30,
    },
    {
        id = "medical",
        name = "Medical Supply",
        crateNameKey = "IGUI_KnoxAirSupport_Crate_Medical",
        crateName = "Medical Supply Crate",
        clan = KnoxAirSupport.CLANS.BUTCHERS,
        weight = 25,
    },
    {
        id = "tools",
        name = "Tools and Utilities",
        crateNameKey = "IGUI_KnoxAirSupport_Crate_Tools",
        crateName = "Utility Supply Crate",
        clan = KnoxAirSupport.CLANS.SPORT,
        weight = 20,
    },
    {
        id = "weapons",
        name = "Weapons and Gear",
        crateNameKey = "IGUI_KnoxAirSupport_Crate_Weapons",
        crateName = "Weapons Supply Crate",
        clan = KnoxAirSupport.CLANS.ARMY,
        weight = 25,
    },
}

---@type table[]
KnoxAirSupport.DISMANTLE_REWARDS = {
    { type = "Base.Plank", min = 1, max = 3 },
    { type = "Base.Screws", min = 2, max = 6 },
    { type = "Base.MetalPipe", min = 2, max = 4 },
}

--- Reads a value from the mod sandbox options, falling back to a default.
---@param name string
---@param default any
---@return any
function KnoxAirSupport.GetSandboxVar(name, default)
    if SandboxVars and SandboxVars.KnoxAirSupport then
        local value = SandboxVars.KnoxAirSupport[name]
        if value ~= nil then return value end
    end
    return default
end

--- Builds the baseline configuration from the sandbox options.
---@return table<string,any>
function KnoxAirSupport.DefaultConfig()
    return {
        enabled = true,
        eventFrequency = 45,
        despawnTimer = 0,
        minDistance = 200,
        maxDistance = 800,
        spawnRadius = 120,
        guardianCount = 1,
        lootQuantity = 22,
        lootQuantityMin = 12,
        crateCapacity = 50,
        priorityChance = 30,
        int_bandits = true,
        int_marz = true,
        int_snake = true,
        int_zombies = true,
        int_alife = true,
        mapMarker = true,
        sound = true,
    }
end

--- Builds the effective configuration out of the sandbox options.
---@return table<string,any>
function KnoxAirSupport.ConfigFromSandbox()
    local config = KnoxAirSupport.DefaultConfig()
    config.enabled = KnoxAirSupport.GetSandboxVar("Enabled", config.enabled)
    config.eventFrequency = KnoxAirSupport.GetSandboxVar("EventFrequency", config.eventFrequency)
    config.despawnTimer = KnoxAirSupport.GetSandboxVar("DespawnTimer", config.despawnTimer)
    config.minDistance = KnoxAirSupport.GetSandboxVar("MinDistance", config.minDistance)
    config.maxDistance = KnoxAirSupport.GetSandboxVar("MaxDistance", config.maxDistance)
    config.spawnRadius = KnoxAirSupport.GetSandboxVar("SpawnRadius", config.spawnRadius)
    config.guardianCount = KnoxAirSupport.GetSandboxVar("GuardianCount", config.guardianCount)
    config.lootQuantity = KnoxAirSupport.Clamp(
        KnoxAirSupport.GetSandboxVar("LootQuantity", config.lootQuantity), 1, 50)
    config.lootQuantityMin = KnoxAirSupport.Clamp(
        KnoxAirSupport.GetSandboxVar("LootQuantityMin", config.lootQuantityMin), 1, 50)
    if config.lootQuantityMin > config.lootQuantity then
        config.lootQuantityMin = config.lootQuantity
    end
    config.crateCapacity = KnoxAirSupport.Clamp(
        KnoxAirSupport.GetSandboxVar("CrateCapacity", config.crateCapacity), 10, 50)
    config.priorityChance = KnoxAirSupport.GetSandboxVar("PriorityChance", config.priorityChance)
    config.int_bandits = KnoxAirSupport.GetSandboxVar("BanditsGuardians", config.int_bandits)
    config.int_marz = KnoxAirSupport.GetSandboxVar("GunsOfMarz", config.int_marz)
    config.int_snake = KnoxAirSupport.GetSandboxVar("SnakeLoot", config.int_snake)
    config.int_zombies = KnoxAirSupport.GetSandboxVar("SpawnZombies", config.int_zombies)
    config.int_alife = KnoxAirSupport.GetSandboxVar("ALifeGuardians", config.int_alife)
    config.mapMarker = KnoxAirSupport.GetSandboxVar("ShowMapMarker", config.mapMarker)
    config.sound = KnoxAirSupport.GetSandboxVar("PlaySound", config.sound)
    return config
end

--- Type of the crate item created by this mod.
---@type string
KnoxAirSupport.CRATE_ITEM = "KnoxAirSupport.KnoxSupplyCrate"

--- Checks whether an inventory item is one of the supply crates.
---@param item InventoryItem|nil
---@return boolean
function KnoxAirSupport.IsSupplyCrate(item)
    if not item then return false end

    if item.getFullType then
        local ok, fullType = pcall(function() return item:getFullType() end)
        if ok and fullType == KnoxAirSupport.CRATE_ITEM then return true end
    end

    if item.getModData then
        local ok, modData = pcall(function() return item:getModData() end)
        if ok and modData and modData.knoxCrate then return true end
    end

    return false
end

--- Clamps a numeric value into an inclusive range.
---@param value number
---@param min number
---@param max number
---@return number
function KnoxAirSupport.Clamp(value, min, max)
    local number = tonumber(value)
    if not number then return min end
    if number < min then return min end
    if number > max then return max end
    return math.floor(number)
end

--- Returns the current real time in milliseconds.
---
--- getTimestampMs follows the in game clock, so on short days it runs much
--- faster than real time. os.time is the wall clock, which is what the drop
--- interval needs.
---@return number
function KnoxAirSupport.RealTimeMs()
    local ok, seconds = pcall(function() return os.time() end)
    if ok and type(seconds) == "number" then return seconds * 1000 end
    return getTimestampMs()
end

--- Translates a key, falling back to a literal when the key is missing.
---@param key string
---@param fallback string
---@return string
function KnoxAirSupport.Translate(key, fallback)
    local value = nil
    local ok, result = pcall(function() return getText(key) end)
    if ok then value = result end
    if value == nil or value == "" or value == key then
        if fallback then return fallback end
        return key
    end
    return value
end

local IS_SP_MODE = not isClient() and not isServer()

KnoxAirSupport.IS_SP_MODE = IS_SP_MODE

--- Sends a command from the client to the server.
---@param command string
---@param args table|nil
---@return nil
function KnoxAirSupport.SendToServer(command, args)
    args = args or {}
    if IS_SP_MODE then
        if KnoxAirSupport_Server and KnoxAirSupport_Server.OnClientCommand then
            KnoxAirSupport_Server.OnClientCommand(KnoxAirSupport.MOD_ID, command, getSpecificPlayer(0), args)
        end
        return
    end
    local player = getSpecificPlayer(0)
    if player then
        sendClientCommand(player, KnoxAirSupport.MOD_ID, command, args)
    end
end

--- Sends a command from the server to a single player.
---@param player IsoPlayer|nil
---@param command string
---@param args table|nil
---@return nil
function KnoxAirSupport.SendToPlayer(player, command, args)
    args = args or {}
    if not player then return end
    if IS_SP_MODE then
        if KnoxAirSupport_Client and KnoxAirSupport_Client.OnServerCommand then
            KnoxAirSupport_Client.OnServerCommand(KnoxAirSupport.MOD_ID, command, args)
        end
        return
    end
    sendServerCommand(player, KnoxAirSupport.MOD_ID, command, args)
end

--- Sends a command from the server to every connected player.
---@param command string
---@param args table|nil
---@return nil
function KnoxAirSupport.Broadcast(command, args)
    args = args or {}
    if IS_SP_MODE then
        if KnoxAirSupport_Client and KnoxAirSupport_Client.OnServerCommand then
            KnoxAirSupport_Client.OnServerCommand(KnoxAirSupport.MOD_ID, command, args)
        end
        return
    end
    local players = getOnlinePlayers()
    if not players then return end
    for i = 0, players:size() - 1 do
        sendServerCommand(players:get(i), KnoxAirSupport.MOD_ID, command, args)
    end
end

--- Runs a callback for every relevant player.
---@param fn fun(player: IsoPlayer)
---@return nil
function KnoxAirSupport.ForEachPlayer(fn)
    if IS_SP_MODE then
        local player = getSpecificPlayer(0)
        if player then fn(player) end
        return
    end
    local players = getOnlinePlayers()
    if not players then return end
    for i = 0, players:size() - 1 do
        fn(players:get(i))
    end
end

--- Forces a supply drop of the given event type.
---@param eventTypeId string|nil
---@return nil
function KnoxAirSupport.ForceDrop(eventTypeId)
    KnoxAirSupport.SendToServer(KnoxAirSupport.CMD_FORCE_DROP, { eventType = eventTypeId })
end

--- Forces a supply drop at the position of the local player.
---@return nil
function KnoxAirSupport.ForceDropHere()
    KnoxAirSupport.SendToServer(KnoxAirSupport.CMD_FORCE_HERE, {})
end

--- Forces a food supply drop.
---@return nil
function KnoxAirSupport.ForceFoodDrop()
    KnoxAirSupport.ForceDrop("food")
end

--- Forces a medical supply drop.
---@return nil
function KnoxAirSupport.ForceMedicalDrop()
    KnoxAirSupport.ForceDrop("medical")
end

--- Forces a tools and utilities drop.
---@return nil
function KnoxAirSupport.ForceToolsDrop()
    KnoxAirSupport.ForceDrop("tools")
end

--- Forces a weapons and gear drop.
---@return nil
function KnoxAirSupport.ForceWeaponsDrop()
    KnoxAirSupport.ForceDrop("weapons")
end

--- Cancels the active event and removes its crate.
---@return nil
function KnoxAirSupport.EndEvent()
    KnoxAirSupport.SendToServer(KnoxAirSupport.CMD_END_EVENT, {})
end
