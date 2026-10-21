require "KnoxAirSupport_Shared"

---@class KnoxAirSupportEventType
---@field id string
---@field name string
---@field crateName string
---@field clan string
---@field weight integer

--- Picks a random event type using the configured weights.
---@param eventTypeId string|nil
---@return KnoxAirSupportEventType
function KnoxAirSupport.PickEventType(eventTypeId)
    if eventTypeId then
        for _, eventType in ipairs(KnoxAirSupport.EVENT_TYPES) do
            if eventType.id == eventTypeId then return eventType end
        end
    end

    local total = 0
    for _, eventType in ipairs(KnoxAirSupport.EVENT_TYPES) do
        total = total + eventType.weight
    end

    local roll = ZombRand(total)
    for _, eventType in ipairs(KnoxAirSupport.EVENT_TYPES) do
        roll = roll - eventType.weight
        if roll < 0 then return eventType end
    end
    return KnoxAirSupport.EVENT_TYPES[1]
end

--- Returns the display name of an event type.
---@param eventTypeId string
---@return string
function KnoxAirSupport.GetEventTypeName(eventTypeId)
    for _, eventType in ipairs(KnoxAirSupport.EVENT_TYPES) do
        if eventType.id == eventTypeId then return eventType.name end
    end
    return "Supply Crate"
end
