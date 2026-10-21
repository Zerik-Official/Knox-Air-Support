require "KnoxAirSupport_Shared"
require "KnoxAirSupport_Integrations"

---@class KnoxAirSupportClient
---@field config table<string,any>
---@field activeEvent table|nil
---@field panel KnoxAirSupportOptionsPanel|nil
KnoxAirSupport_Client = KnoxAirSupport_Client or {}

KnoxAirSupport_Client.config = KnoxAirSupport.ConfigFromSandbox()
KnoxAirSupport_Client.activeEvent = nil
KnoxAirSupport_Client.panel = nil

--- Handles the commands sent by the server.
---@param module string
---@param command string
---@param args table|nil
---@return nil
local function onServerCommand(module, command, args)
    if module ~= KnoxAirSupport.MOD_ID then return end
    args = args or {}

    if command == KnoxAirSupport.CMD_EVENT_START then
        KnoxAirSupport_Client.activeEvent = { x = args.x, y = args.y }
        print(KnoxAirSupport.TAG .. " Supply drop incoming at " .. args.x .. ", " .. args.y)

        local player = getPlayer()
        if player then
            pcall(function()
                HaloTextHelper.addTextWithArrow(player,
                    KnoxAirSupport.Translate("IGUI_KnoxAirSupport_DropIncoming", "Supply drop incoming!"), true, 255, 165, 0)
            end)
        end

    elseif command == KnoxAirSupport.CMD_EVENT_SPAWNED then
        KnoxAirSupport_Client.activeEvent = { x = args.x, y = args.y }
        print(KnoxAirSupport.TAG .. " Supply crate landed at " .. args.x .. ", " .. args.y)

        local player = getPlayer()
        if player then
            pcall(function()
                HaloTextHelper.addTextWithArrow(player,
                    KnoxAirSupport.Translate("IGUI_KnoxAirSupport_DropLanded", "The supply crate has landed."), true, 120, 220, 120)
            end)
        end

        if KnoxAirSupport_Client.config.sound then
            local square = getCell():getGridSquare(args.x, args.y, 0)
            if square then
                pcall(function()
                    getSoundManager():PlayWorldSound("Helicopter", false, square, 0, 150, 1.0, false)
                end)
            end
        end

    elseif command == KnoxAirSupport.CMD_EVENT_END then
        KnoxAirSupport_Client.activeEvent = nil
        print(KnoxAirSupport.TAG .. " Supply drop event ended")

        local player = getPlayer()
        if player then
            pcall(function()
                HaloTextHelper.addTextWithArrow(player,
                    KnoxAirSupport.Translate("IGUI_KnoxAirSupport_DropExpired", "The supply drop event has ended."), true, 150, 150, 150)
            end)
        end

    elseif command == KnoxAirSupport.CMD_CONFIG then
        for key, value in pairs(args) do
            KnoxAirSupport_Client.config[key] = value
        end
        if KnoxAirSupport_Client.panel then
            KnoxAirSupport_Client.panel:refresh()
        end
    end
end

KnoxAirSupport_Client.OnServerCommand = onServerCommand

---@type function|nil
local originalRender = nil

--- Draws the supply drop marker on the world map.
---@param self ISWorldMap
---@return nil
local function renderMapMarker(self)
    local event = KnoxAirSupport_Client.activeEvent
    if not event then return end
    if not KnoxAirSupport_Client.config.mapMarker then return end
    if not self.mapAPI then return end

    local uiX = self.mapAPI:worldToUIX(event.x, event.y)
    local uiY = self.mapAPI:worldToUIY(event.x, event.y)
    if not uiX or not uiY then return end

    local pulse = 0.6 + 0.4 * math.abs(math.sin(getTimestampMs() / 500))
    local red, green, blue = 1.0, 0.55, 0.1

    local size, gap, thickness = 14, 4, 2
    self.javaObject:DrawLine(nil, uiX - size, uiY, uiX - gap, uiY, thickness, red, green, blue, pulse)
    self.javaObject:DrawLine(nil, uiX + gap, uiY, uiX + size, uiY, thickness, red, green, blue, pulse)
    self.javaObject:DrawLine(nil, uiX, uiY - size, uiX, uiY - gap, thickness, red, green, blue, pulse)
    self.javaObject:DrawLine(nil, uiX, uiY + gap, uiX, uiY + size, thickness, red, green, blue, pulse)
    self:drawRect(uiX - 2, uiY - 2, 4, 4, pulse, red, green, blue)
    self:drawText(KnoxAirSupport.Translate("IGUI_KnoxAirSupport_MapLabel", "SUPPLY DROP"),
        uiX + size + 4, uiY - 6, red, green, blue, pulse, UIFont.Small)
end

--- Patches the world map render to draw the supply drop marker.
---@return nil
local function patchMapRender()
    if originalRender then return end
    if not ISWorldMap or not ISWorldMap.render then
        print(KnoxAirSupport.TAG .. " WARNING: ISWorldMap.render not found, map marker disabled")
        return
    end

    originalRender = ISWorldMap.render

    ISWorldMap.render = function(self, ...)
        originalRender(self, ...)
        pcall(function() renderMapMarker(self) end)
    end

    print(KnoxAirSupport.TAG .. " Map render patched")
end

--- Opens or closes the configuration panel.
---@return nil
function KnoxAirSupport_Client.OpenPanel()
    if KnoxAirSupport_Client.panel then
        KnoxAirSupport_Client.panel:close()
        KnoxAirSupport_Client.panel = nil
        return
    end

    require "KnoxAirSupport_OptionsPanel"

    local player = getPlayer()
    if not player then return end

    local panel = KnoxAirSupportOptionsPanel:new(player)
    panel:initialise()
    panel:addToUIManager()
    KnoxAirSupport_Client.panel = panel
end

--- Dismantles a crate and gives the materials to the player.
---@param object IsoObject|nil
---@return nil
local function dismantleCrate(object)
    if not object then return end
    local square = object:getSquare()
    if not square then return end
    KnoxAirSupport.SendToServer(KnoxAirSupport.CMD_DISMANTLE, {
        x = square:getX(),
        y = square:getY(),
        z = square:getZ(),
    })
end

--- Checks whether a world object is one of the supply crates.
---@param object IsoObject|nil
---@return boolean
local function isSupplyCrate(object)
    if not object then return false end

    local item = nil
    local itemOk, itemValue = pcall(function() return object.item end)
    if itemOk then item = itemValue end

    if item and item.getModData then
        local dataOk, modData = pcall(function() return item:getModData() end)
        if dataOk and modData and modData.knoxCrate then return true end
    end

    if object.getModData then
        local dataOk, modData = pcall(function() return object:getModData() end)
        if dataOk and modData and modData.knoxCrate then return true end
    end

    return false
end

--- Adds the mod entries to the world context menu.
---@param player IsoPlayer
---@param context ISContextMenu
---@param objects table[]
---@return nil
local function onFillWorldObjectContextMenu(player, context, objects)
    if not objects then return end

    local crate = nil
    local isCharacter = false

    for _, object in ipairs(objects) do
        if isSupplyCrate(object) then
            crate = object
            break
        end
        if object and object.isCharacter and object:isCharacter() then
            isCharacter = true
        end
    end

    if crate then
        context:addOption(KnoxAirSupport.Translate("IGUI_KnoxAirSupport_Dismantle", "Dismantle"),
            player, KnoxAirSupport_Client, dismantleCrate, crate)
    end

    if crate or isCharacter then
        context:addOption(KnoxAirSupport.Translate("IGUI_KnoxAirSupport_OpenPanel", "Knox Air Support: Settings"),
            player, KnoxAirSupport_Client, KnoxAirSupport_Client.OpenPanel)
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)

--- Prepares the client side of the mod.
---@return nil
local function onGameStart()
    patchMapRender()
    KnoxAirSupport.SendToServer(KnoxAirSupport.CMD_CONFIG_GET, {})
end

Events.OnGameStart.Add(onGameStart)
