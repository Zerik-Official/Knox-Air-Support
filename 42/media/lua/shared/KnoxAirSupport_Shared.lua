KnoxAirSupport = KnoxAirSupport or {}

KnoxAirSupport.MOD_ID = "KnoxAirSupport"
KnoxAirSupport.TAG = "[KnoxAirSupport]"

-- Network commands
KnoxAirSupport.CMD_EVENT_START   = "EventStart"
KnoxAirSupport.CMD_EVENT_SPAWNED = "EventSpawned"
KnoxAirSupport.CMD_EVENT_END     = "EventEnd"

-- Bandits clan UUIDs
KnoxAirSupport.CLANS = {
    ARMY      = "a2dec2f0-c76d-4640-8a71-733a547a1ebc",
    REDNECKS  = "f6e2ca8c-311e-4ee2-9fe6-1c9e14dbcd11",
    ROBBERS   = "f8aa0e8c-92ee-4dce-99e8-e4cc3a5a8fbe",
    BUTCHERS  = "8db5a57f-b0a9-4b04-9228-beeadd2db2fa",
    HIKERS    = "6e319aac-4480-4367-aa9a-5d4bf2ced9d1",
    CANNIBALS = "b7d3a430-e966-48e8-97fa-9078c8d848a4",
    LEGION    = "49facd22-4067-4ebd-9196-9bf6951a435c",
    CRIMINALS = "1eb2f74a-8d09-4346-8ba4-3a02665647e5",
    SPORT     = "f06e063f-551c-4fd5-aa19-bc15185c2371",
}

-- Event types (array for deterministic weighted selection)
KnoxAirSupport.EVENT_TYPES = {
    { id = "military", name = "Military Supply Drop", crateName = "Military Supply Crate", clan = KnoxAirSupport.CLANS.ARMY, weight = 30 },
    { id = "survival", name = "Survival Rations", crateName = "Survival Rations", clan = KnoxAirSupport.CLANS.HIKERS, weight = 30 },
    { id = "bandit", name = "Raider Stash", crateName = "Raider Stash", clan = KnoxAirSupport.CLANS.ROBBERS, weight = 25 },
    { id = "elite", name = "Elite Supply Cache", crateName = "Elite Supply Cache", clan = KnoxAirSupport.CLANS.LEGION, weight = 15 },
}

print(KnoxAirSupport.TAG .. " Shared module loaded")
