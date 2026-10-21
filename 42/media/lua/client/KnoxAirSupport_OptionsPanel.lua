require "KnoxAirSupport_Shared"
require "KnoxAirSupport_Integrations"

---@class KnoxAirSupportOptionsRow
---@field type "toggle"|"int"
---@field key string
---@field label string
---@field fallback string
---@field min integer|nil
---@field max integer|nil
---@field step integer|nil

---@class KnoxAirSupportOptionsPanel : ISPanel
KnoxAirSupportOptionsPanel = ISPanel:derive("KnoxAirSupportOptionsPanel")

local PADDING = 14
local ROW_HEIGHT = 30
local BUTTON_HEIGHT = 22

---@type KnoxAirSupportOptionsRow[]
local ROWS = {
    { type = "toggle", key = "int_bandits", label = "IGUI_KnoxAirSupport_Int_Bandits", fallback = "Bandits guardians (NPCs)" },
    { type = "toggle", key = "int_alife", label = "IGUI_KnoxAirSupport_Int_ALife", fallback = "Project A-Life guardians" },
    { type = "toggle", key = "int_zombies", label = "IGUI_KnoxAirSupport_Int_Zombies", fallback = "Zombies when there are no bandits" },
    { type = "toggle", key = "int_marz", label = "IGUI_KnoxAirSupport_Int_Marz", fallback = "Guns of Marz weapons" },
    { type = "toggle", key = "int_snake", label = "IGUI_KnoxAirSupport_Int_Snake", fallback = "Snake weapons and accessories" },
    { type = "int", key = "eventFrequency", label = "IGUI_KnoxAirSupport_Frequency", fallback = "Event frequency (min)", min = 1, max = 1440, step = 15 },
    { type = "int", key = "spawnRadius", label = "IGUI_KnoxAirSupport_SpawnRadius", fallback = "Spawn radius (tiles)", min = 10, max = 600, step = 10 },
    { type = "int", key = "guardianCount", label = "IGUI_KnoxAirSupport_Guardians", fallback = "Number of guardians", min = 0, max = 30, step = 1 },
    { type = "int", key = "lootQuantity", label = "IGUI_KnoxAirSupport_LootQuantity", fallback = "Items per crate", min = 1, max = 60, step = 1 },
    { type = "int", key = "crateCapacity", label = "IGUI_KnoxAirSupport_CrateCapacity", fallback = "Crate capacity (slots)", min = 10, max = 200, step = 5 },
    { type = "int", key = "priorityChance", label = "IGUI_KnoxAirSupport_PriorityChance", fallback = "Priority accessory chance (%)", min = 0, max = 100, step = 5 },
    { type = "int", key = "despawnTimer", label = "IGUI_KnoxAirSupport_DespawnTimer", fallback = "Crate lifetime (min, 0 = forever)", min = 0, max = 720, step = 15 },
    { type = "toggle", key = "mapMarker", label = "IGUI_KnoxAirSupport_MapMarker", fallback = "Map marker" },
    { type = "toggle", key = "sound", label = "IGUI_KnoxAirSupport_Sound", fallback = "Landing sound" },
}

--- Translates a key, falling back to a literal when the key is missing.
---@param key string
---@param fallback string
---@return string
local function T(key, fallback)
    local value = nil
    local ok, result = pcall(function() return getText(key) end)
    if ok then value = result end
    if value == nil or value == "" or value == key then return fallback end
    return value
end

--- Creates a new options panel.
---@param player IsoPlayer
---@return KnoxAirSupportOptionsPanel
function KnoxAirSupportOptionsPanel:new(player)
    local width = 480
    local height = 150 + #ROWS * ROW_HEIGHT

    local x = (getCore():getScreenWidth() - width) / 2
    local y = (getCore():getScreenHeight() - height) / 2

    local o = ISPanel.new(self, x, y, width, height)
    o.player = player
    o.rows = {}
    return o
end

--- Builds the widgets of the panel.
---@return nil
function KnoxAirSupportOptionsPanel:createChildren()
    local y = 46

    for _, spec in ipairs(ROWS) do
        local row = { spec = spec, y = y }
        local key = spec.key

        if spec.type == "toggle" then
            local button = ISButton:new(self.width - PADDING - 80, y, 80, BUTTON_HEIGHT,
                "", self, function() self:onToggle(key) end)
            self:addChild(button)
            row.button = button
        else
            local minus = ISButton:new(self.width - PADDING - 130, y, 30, BUTTON_HEIGHT,
                "-", self, function() self:onChange(key, -spec.step) end)
            self:addChild(minus)

            local plus = ISButton:new(self.width - PADDING - 30, y, 30, BUTTON_HEIGHT,
                "+", self, function() self:onChange(key, spec.step) end)
            self:addChild(plus)

            row.minusButton = minus
            row.plusButton = plus
        end

        self.rows[#self.rows + 1] = row
        y = y + ROW_HEIGHT
    end

    local closeButton = ISButton:new(self.width - PADDING - 100, self.height - 34, 100, BUTTON_HEIGHT,
        T("IGUI_KnoxAirSupport_Close", "Close"), self, function() self:onClose() end)
    self:addChild(closeButton)
    self.closeButton = closeButton
end

--- Initialises the panel.
---@return nil
function KnoxAirSupportOptionsPanel:initialise()
    ISPanel.initialise(self)
    self:createChildren()
    self:refresh()
end

--- Returns the configuration shown by the panel.
---@return table<string,any>
function KnoxAirSupportOptionsPanel:getConfig()
    if KnoxAirSupport_Client and KnoxAirSupport_Client.config then
        return KnoxAirSupport_Client.config
    end
    return KnoxAirSupport.ConfigFromSandbox()
end

--- Sends a configuration change to the server.
---@param key string
---@param value any
---@return nil
function KnoxAirSupportOptionsPanel:sendValue(key, value)
    local config = self:getConfig()
    config[key] = value
    self:refresh()
    KnoxAirSupport.SendToServer(KnoxAirSupport.CMD_CONFIG_SET, { key = key, value = value })
end

--- Toggles a boolean setting.
---@param key string
---@return nil
function KnoxAirSupportOptionsPanel:onToggle(key)
    local config = self:getConfig()
    local value = config[key] and false or true
    self:sendValue(key, value)
end

--- Changes a numeric setting.
---@param key string
---@param delta number
---@return nil
function KnoxAirSupportOptionsPanel:onChange(key, delta)
    for _, spec in ipairs(ROWS) do
        if spec.key == key then
            local config = self:getConfig()
            local current = tonumber(config[key]) or 0
            local value = KnoxAirSupport.Clamp(current + delta, spec.min, spec.max)
            self:sendValue(key, value)
            return
        end
    end
end

--- Closes the panel.
---@return nil
function KnoxAirSupportOptionsPanel:onClose()
    self:close()
    if KnoxAirSupport_Client then
        KnoxAirSupport_Client.panel = nil
    end
end

--- Handles the key presses of the panel.
---@param key integer
---@return boolean|nil
function KnoxAirSupportOptionsPanel:onKeyPress(key)
    if key == Keyboard.KEY_ESCAPE then
        self:onClose()
        return true
    end
end

--- Updates the widgets with the current configuration.
---@return nil
function KnoxAirSupportOptionsPanel:refresh()
    local config = self:getConfig()

    for _, row in ipairs(self.rows or {}) do
        local spec = row.spec
        local value = config[spec.key]

        if spec.type == "toggle" then
            if row.button then
                row.button.title = value and T("IGUI_KnoxAirSupport_On", "ON")
                                         or T("IGUI_KnoxAirSupport_Off", "OFF")
            end
        else
            if row.minusButton then
                row.minusButton:setEnable((tonumber(value) or 0) > spec.min)
            end
            if row.plusButton then
                row.plusButton:setEnable((tonumber(value) or 0) < spec.max)
            end
        end
    end
end

--- Draws the panel.
---@return nil
function KnoxAirSupportOptionsPanel:render()
    ISPanel.render(self)

    local config = self:getConfig()

    self:drawText(T("IGUI_KnoxAirSupport_PanelTitle", "KNOX AIR SUPPORT"), PADDING, 14, 1, 0.85, 0.2, 1, UIFont.Medium)
    self:drawText(T("IGUI_KnoxAirSupport_SectionIntegrations", "Integrations and settings"), PADDING, 34, 0.75, 0.75, 0.75, 1, UIFont.Small)

    for _, row in ipairs(self.rows or {}) do
        local spec = row.spec
        local value = config[spec.key]
        local label = T(spec.label, spec.fallback)
        local note = ""

        if spec.key == "int_bandits" or spec.key == "int_marz" or spec.key == "int_snake"
            or spec.key == "int_alife" then
            local integrationId = spec.key:match("int_(.+)")
            if not KnoxAirSupport.Integrations.IsAvailable(integrationId) then
                note = "  (" .. T("IGUI_KnoxAirSupport_NotInstalled", "mod not installed") .. ")"
            end
        end

        if spec.key == "int_alife" and config.int_bandits
            and KnoxAirSupport.Integrations.IsAvailable("bandits") then
            note = "  (" .. T("IGUI_KnoxAirSupport_LowerPriority", "only used without Bandits") .. ")"
        end

        self:drawText(label .. note, PADDING, row.y + 4, 0.9, 0.9, 0.9, 1, UIFont.Normal)

        if spec.type == "int" then
            self:drawText(tostring(value), self.width - PADDING - 85, row.y + 4, 1, 1, 1, 1, UIFont.Normal)
        end
    end

    self:drawText(T("IGUI_KnoxAirSupport_PanelHint", "Right click a character or the crate to open this panel."),
        PADDING, self.height - 34, 0.65, 0.65, 0.65, 1, UIFont.Small)
end
