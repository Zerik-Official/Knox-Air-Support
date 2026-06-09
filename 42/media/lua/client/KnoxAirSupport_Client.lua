require "KnoxAirSupport_Shared"

local function onServerCommand(module, command, args)
    if module ~= KnoxAirSupport.MOD_ID then return end

    if command == KnoxAirSupport.CMD_EVENT_START then
        print("[KnoxAirSupport] Supply drop incoming! Check your map.")
    elseif command == KnoxAirSupport.CMD_EVENT_SPAWNED then
        print("[KnoxAirSupport] Supply crate has landed at " .. args.x .. ", " .. args.y)
    elseif command == KnoxAirSupport.CMD_EVENT_END then
        print("[KnoxAirSupport] Supply drop event ended.")
    end
end

Events.OnServerCommand.Add(onServerCommand)

print("[KnoxAirSupport] Client module loaded")
