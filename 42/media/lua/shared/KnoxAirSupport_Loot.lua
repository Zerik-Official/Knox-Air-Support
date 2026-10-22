require "KnoxAirSupport_Shared"
require "KnoxAirSupport_Integrations"

---@class KnoxAirSupportLootCategory
---@field id string
---@field min integer
---@field max integer
---@field items string[]
---@field condition integer|nil

---@class KnoxAirSupportLoot
KnoxAirSupport.Loot = KnoxAirSupport.Loot or {}

---@type table<string, KnoxAirSupportLootCategory[]>
KnoxAirSupport.Loot.DROP_CATEGORIES = {
    food = {
        {
            id = "canned_boxes", min = 0, max = 2,
            items = {
                "Base.CannedSardines_Box", "Base.CannedChili_Box", "Base.CannedCornedBeef_Box",
                "Base.CannedCarrots_Box", "Base.CannedPeas_Box", "Base.CannedTomato_Box",
                "Base.CannedBolognese_Box", "Base.CannedPotato_Box", "Base.CannedCorn_Box",
                "Base.CannedMushroomSoup_Box", "Base.CannedMilk_Box", "Base.CannedPeaches_Box",
                "Base.CannedPineapple_Box", "Base.CannedFruitBeverage_Box",
            },
        },
        {
            id = "canned_single", min = 0, max = 2,
            items = {
                "Base.CannedSardines", "Base.CannedChili", "Base.CannedCornedBeef",
                "Base.CannedCorn", "Base.CannedPeas", "Base.CannedCarrots",
                "Base.CannedTomato", "Base.CannedBolognese", "Base.CannedPotato",
                "Base.CannedMushroomSoup", "Base.CannedFruitBeverage", "Base.CannedMilk",
                "Base.CannedPeaches", "Base.CannedPineapple",
            },
        },
        {
            id = "dry_food", min = 1, max = 3,
            items = {
                "Base.Rice", "Base.BouillonCube", "Base.Pasta", "Base.Cereal",
                "Base.Crackers", "Base.GrahamCrackers", "Base.Sugar", "Base.SugarCubes",
                "Base.Salt", "Base.SeasoningSalt", "Base.RefriedBeans", "Base.Blackbeans",
                "Base.DriedWhiteBeans", "Base.DriedKidneyBeans", "Base.DriedBlackBeans",
                "Base.CookiesSugar", "Base.CrispyRiceSquare", "Base.CandyPackage",
            },
        },
    },
    medical = {
        {
            id = "medical_core", min = 1, max = 3,
            items = {
                "Base.Antibiotics", "Base.AntibioticsBox", "Base.Bandage", "Base.BandageBox",
                "Base.AlcoholWipes", "Base.AlcoholedCottonBalls", "Base.AlcoholBandage",
                "Base.Needle", "Base.Needle_Brass", "Base.SutureNeedleHolder", "Base.SutureNeedle",
                "Base.SutureNeedleBox", "Base.Disinfectant", "Base.AdhesiveBandageBox",
                "Base.BandageDirty", "Base.HotWaterBottle",
            },
        },
        {
            id = "medical_pills", min = 0, max = 2,
            items = {
                "Base.Pills", "Base.PillsBeta", "Base.PillsVitamins", "Base.PillsAntiDep",
                "Base.PillsSleepingTablets", "Base.Hat_SurgicalMask",
                "Base.FirstAidKit_Military", "Base.FirstAidKit",
            },
        },
    },
    tools = {
        {
            id = "hand_tools", min = 1, max = 3,
            items = {
                "Base.Hammer", "Base.HammerForged", "Base.BallPeenHammer", "Base.Saw",
                "Base.SmallSaw", "Base.GardenSaw", "Base.Screwdriver", "Base.Screwdriver_Old",
                "Base.Wrench", "Base.PipeWrench", "Base.Crowbar", "Base.Shovel",
                "Base.Axe", "Base.Sledgehammer", "Base.CircularSawblade", "Base.HacksawBlade",
                "Base.Pliers", "Base.Multitool", "Base.Jack",
            },
        },
        {
            id = "hardware", min = 1, max = 3,
            items = {
                "Base.NailsBox", "Base.NailsCarton", "Base.Screws", "Base.ScrewsBox",
                "Base.ScrewsCarton", "Base.MetalPipe", "Base.IronBar", "Base.AluminumScrap",
                "Base.SheetMetal", "Base.Wire", "Base.DuctTape", "Base.Rope",
                "Base.Bucket", "Base.Battery",
            },
        },
        {
            id = "workshop", min = 0, max = 2,
            items = {
                "Base.BlowTorch", "Base.WeldingMask", "Base.WeldingRods", "Base.PropaneTank",
                "Base.Lantern_Propane", "Base.CanteenMilitary", "Base.Toolbox",
                "Base.Paintbrush",
            },
        },
    },
    weapons = {
        {
            id = "melee", min = 0, max = 2,
            items = {
                "Base.Machete", "Base.Katana", "Base.HuntingKnife", "Base.HuntingKnifeForged",
                "Base.FightingKnife", "Base.BreadKnife", "Base.Handiknife", "Base.CrudeKnife",
                "Base.CrudeShortSword", "Base.CrudeSword", "Base.BaseballBat",
                "Base.BaseballBat_Metal", "Base.Crowbar", "Base.Machete_Crude",
                "Base.MacheteForged", "Base.MacheteKnife",
            },
        },
        {
            id = "firearms", min = 0, max = 2,
            items = {
                "Base.Pistol", "Base.Pistol2", "Base.Pistol3", "Base.Revolver",
                "Base.Revolver_Long", "Base.Shotgun", "Base.ShotgunSawnoff",
                "Base.DoubleBarrelShotgun", "Base.HuntingRifle", "Base.VarmintRifle",
                "Base.AssaultRifle", "Base.AssaultRifle2", "Base.DoubleBarrelShotgun",
            },
        },
        {
            id = "ammunition", min = 1, max = 3,
            items = {
                "Base.Bullets9mmBox", "Base.Bullets45Box", "Base.Bullets38Box", "Base.308Box",
                "Base.Bullets357Box", "Base.556Box", "Base.ShotgunShellsBox", "Base.9mmClip",
                "Base.45Clip", "Base.556Clip", "Base.Bullets44Box", "Base.Bullets9mmCarton",
                "Base.Bullets45Carton", "Base.Bullets38Carton", "Base.Bullets357Carton",
                "Base.308Carton", "Base.556Carton", "Base.ShotgunShellsCarton",
            },
        },
        {
            id = "military_ammo_boxes", min = 0, max = 2,
            items = {
                "Base.Bag_AmmoBox_9mm", "Base.Bag_AmmoBox_308", "Base.Bag_AmmoBox_45",
                "Base.Bag_AmmoBox_44", "Base.Bag_AmmoBox_38", "Base.Bag_AmmoBox_ShotgunShells",
                "Base.Bag_AmmoBox", "Base.Bag_ProtectiveCaseBulkyAmmo_9mm",
                "Base.Bag_ProtectiveCaseBulkyAmmo_308", "Base.Bag_ProtectiveCaseBulkyAmmo_45",
            },
        },
        {
            id = "weapon_parts", min = 0, max = 2,
            items = {
                "Base.x2Scope", "Base.x4Scope", "Base.x8Scope", "Base.Laser",
                "Base.TritiumSights", "Base.RecoilPad", "Base.ChokeTubeFull",
                "Base.ChokeTubeImproved", "Base.Magazine", "Base.Magazine_Military",
            },
        },
        {
            id = "accessories", min = 0, max = 2,
            items = {
                "Base.Gloves_LeatherGloves", "Base.Gloves_FingerlessLeatherGloves",
                "Base.Gloves_LeatherGlovesBlack", "Base.Gloves_FingerlessGloves",
                "Base.Gloves_Dish", "Base.Gloves_Surgical", "Base.Gloves_HuntingCamo",
                "Base.HolsterAnkle", "Base.HolsterDouble", "Base.HolsterShoulder",
                "Base.FirstAidKit_Military", "Base.Magazine_Military",
            },
        },
        {
            id = "military_gear", min = 0, max = 2, condition = 100,
            items = {
                "Base.Bag_ALICEpack_Army", "Base.Bag_ALICEpack_DesertCamo", "Base.Bag_Military",
                "Base.Bag_Satchel_Military", "Base.Bag_ProtectiveCaseMilitary",
                "Base.Vest_BulletArmy", "Base.Vest_BulletSWAT", "Base.Vest_BulletPolice",
                "Base.Vest_BulletCivilian", "Base.Hat_BeretArmy", "Base.Hat_Army",
                "Base.Hat_RiotHelmet", "Base.Jacket_ArmyOliveDrab", "Base.Trousers_ArmyService",
                "Base.Shoes_ArmyBoots", "Base.ElbowPad_Left_Military",
                "Base.Kneepad_Left_Military", "Base.GreaveBodyArmour_Left_Army",
                "Base.GreaveBodyArmour_Right_Army",
            },
        },
        {
            id = "gas_protection", min = 0, max = 1, condition = 100,
            items = {
                "Base.Hat_GasMask", "Base.Hat_NBCmask", "Base.Hat_ImprovisedGasMask",
                "Base.GasmaskFilter", "Base.GasmaskFilterCrafted", "Base.RespiratorFilters",
            },
        },
    },
}

--- Builds the effective category list for an event type and a configuration.
---@param eventTypeId string
---@param config table<string,any>
---@return KnoxAirSupportLootCategory[]
function KnoxAirSupport.Loot.BuildCategories(eventTypeId, config)
    local categories = {}
    local base = KnoxAirSupport.Loot.DROP_CATEGORIES[eventTypeId]
    if base then
        for _, category in ipairs(base) do
            categories[#categories + 1] = category
        end
    end

    if config.int_marz and KnoxAirSupport.Integrations.IsAvailable("marz") then
        local weapons = KnoxAirSupport.Integrations.GetPool("marz", "weapons")
        local parts = KnoxAirSupport.Integrations.GetPool("marz", "parts")
        local ammo = KnoxAirSupport.Integrations.GetPool("marz", "ammo")
        if #weapons > 0 then
            categories[#categories + 1] = { id = "marz_weapons", min = 0, max = 2, items = weapons }
        end
        if #parts > 0 then
            categories[#categories + 1] = { id = "marz_parts", min = 0, max = 2, items = parts }
        end
        if #ammo > 0 then
            categories[#categories + 1] = { id = "marz_ammo", min = 0, max = 2, items = ammo }
        end
    end

    if config.int_snake and KnoxAirSupport.Integrations.IsAvailable("snake") then
        local weapons = KnoxAirSupport.Integrations.GetPool("snake", "weapons")
        local accessories = KnoxAirSupport.Integrations.GetPool("snake", "accessories")
        if #weapons > 0 then
            categories[#categories + 1] = { id = "snake_weapons", min = 0, max = 2, items = weapons }
        end
        if #accessories > 0 then
            categories[#categories + 1] = { id = "snake_accessories", min = 0, max = 3, items = accessories }
        end
    end

    return categories
end

--- Picks a number of unique random entries from a list.
---@param items string[]
---@param count integer
---@return string[]
function KnoxAirSupport.Loot.PickUnique(items, count)
    local picked = {}
    if not items or #items == 0 or count <= 0 then return picked end

    local indices = {}
    for i = 1, #items do indices[i] = i end
    for i = #indices, 2, -1 do
        local j = ZombRand(i) + 1
        indices[i], indices[j] = indices[j], indices[i]
    end

    for pick = 1, count do
        picked[pick] = items[indices[pick]]
    end
    return picked
end

--- Fills a container with the categories of an event type.
--- The amount of items is random between the configured minimum and maximum, and
--- the categories are rolled until that amount is reached. Every item type can
--- appear twice at most, so the crate keeps some variety.
---@param container ItemContainer
---@param eventTypeId string
---@param config table<string,any>
---@return integer
function KnoxAirSupport.Loot.FillContainer(container, eventTypeId, config)
    local categories = KnoxAirSupport.Loot.BuildCategories(eventTypeId, config)
    local minItems = math.max(1, math.floor(tonumber(config.lootQuantityMin) or 8))
    local maxItems = math.max(minItems, math.floor(tonumber(config.lootQuantity) or 20))
    local capacity = math.max(minItems, math.floor(tonumber(config.crateCapacity) or 50))
    if maxItems > capacity then maxItems = capacity end

    local target = ZombRand(minItems, maxItems + 1)
    local copies = {}
    local added = 0
    local rounds = 0

    while added < target and rounds < 12 do
        rounds = rounds + 1
        local progress = false

        for _, category in ipairs(categories) do
            if added >= target then break end

            local available = {}
            for _, itemType in ipairs(category.items) do
                if (copies[itemType] or 0) < 2 then available[#available + 1] = itemType end
            end
            if #available == 0 then
                for _, itemType in ipairs(category.items) do available[#available + 1] = itemType end
            end

            local low = math.max(1, category.min)
            local count = ZombRand(low, category.max + 1)
            if count > #available then count = #available end

            for _, itemType in ipairs(KnoxAirSupport.Loot.PickUnique(available, count)) do
                if added >= target then break end
                local item = container:AddItem(itemType)
                if item then
                    added = added + 1
                    progress = true
                    copies[itemType] = (copies[itemType] or 0) + 1
                    if category.condition and item.setCondition then
                        pcall(function() item:setCondition(category.condition) end)
                    end
                end
            end
        end

        if not progress then break end
    end

    return added
end
