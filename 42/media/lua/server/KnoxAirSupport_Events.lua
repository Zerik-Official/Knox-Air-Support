require "KnoxAirSupport_Shared"

local TAG = KnoxAirSupport.TAG

-- Pick a random event type weighted by probability
function KnoxAirSupport.PickEventType()
    local total = 0
    for _, et in ipairs(KnoxAirSupport.EVENT_TYPES) do
        total = total + et.weight
    end
    local r = ZombRand(total)
    for _, et in ipairs(KnoxAirSupport.EVENT_TYPES) do
        r = r - et.weight
        if r < 0 then return et end
    end
    return KnoxAirSupport.EVENT_TYPES[1]
end

-- Analyze loot in a container and determine clan + crate name
function KnoxAirSupport.AnalyzeContainer(container)
    if not container then return nil, "Supply Crate" end
    local items = container:getItems()
    if not items or items:size() == 0 then return nil, "Supply Crate" end

    local hasMilitary, hasFirearm = false, false
    local food, medical, special = 0, 0, 0

    for i = 0, items:size() - 1 do
        local t = items:get(i):getFullType()
        if t:find("AssaultRifle") or t:find("Bullets") or t == "Base.556Box" then
            hasMilitary = true
        end
        if t:find("Pistol") or t:find("Shotgun") or t:find("Revolver") or t:find("Rifle") then
            hasFirearm = true
        end
        if t:find("Canned") or t:find("Rice") or t:find("Pasta") or t:find("Cereal") or t:find("Jerky") then
            food = food + 1
        end
        if t:find("Bandage") or t:find("Antibiotic") or t:find("Disinfectant") or t:find("Suture") then
            medical = medical + 1
        end
        if t == "Base.Katana" or t == "Base.Sledgehammer" or t == "Base.Sledgehammer2" then
            special = special + 1
        end
    end

    if special > 0 then
        return KnoxAirSupport.CLANS.LEGION, "Elite Supply Cache"
    elseif hasMilitary then
        return KnoxAirSupport.CLANS.ARMY, "Military Supply Crate"
    elseif medical > food and medical > 0 then
        return KnoxAirSupport.CLANS.BUTCHERS, "Medical Supply Crate"
    elseif food > medical then
        return ZombRand(2) == 0 and KnoxAirSupport.CLANS.HIKERS or KnoxAirSupport.CLANS.CANNIBALS, "Survival Rations"
    elseif hasFirearm then
        return ZombRand(2) == 0 and KnoxAirSupport.CLANS.ROBBERS or KnoxAirSupport.CLANS.CRIMINALS, "Raider Stash"
    else
        return ZombRand(2) == 0 and KnoxAirSupport.CLANS.REDNECKS or KnoxAirSupport.CLANS.SPORT, "Supply Crate"
    end
end

print(TAG .. " Events module loaded")
