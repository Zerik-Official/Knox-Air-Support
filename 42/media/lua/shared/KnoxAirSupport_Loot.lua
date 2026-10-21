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
            },
        },
        {
            id = "medical_pills", min = 0, max = 2,
            items = {
                "Base.Pills", "Base.PillsBeta", "Base.PillsVitamins", "Base.PillsAntiDep",
                "Base.PillsSleepingTablets", "Base.HotWaterBottle", "Base.Hat_SurgicalMask",
                "Base.FirstAidKit_Military",
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
            },
        },
        {
            id = "hardware", min = 1, max = 3,
            items = {
                "Base.NailsBox", "Base.NailsCarton", "Base.Screws", "Base.ScrewsBox",
                "Base.ScrewsCarton", "Base.MetalPipe", "Base.IronBar", "Base.AluminumScrap",
            },
        },
        {
            id = "workshop", min = 0, max = 2,
            items = {
                "Base.BlowTorch", "Base.WeldingMask", "Base.WeldingRods", "Base.PropaneTank",
                "Base.Lantern_Propane", "Base.CanteenMilitary",
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
                "Base.BaseballBat_Metal", "Base.Crowbar",
            },
        },
        {
            id = "firearms", min = 0, max = 2,
            items = {
                "Base.Pistol", "Base.Pistol2", "Base.Pistol3", "Base.Revolver",
                "Base.Revolver_Long", "Base.Shotgun", "Base.ShotgunSawnoff",
                "Base.DoubleBarrelShotgun", "Base.HuntingRifle", "Base.VarmintRifle",
                "Base.AssaultRifle", "Base.AssaultRifle2",
            },
        },
        {
            id = "ammunition", min = 1, max = 3,
            items = {
                "Base.Bullets9mmBox", "Base.Bullets45Box", "Base.Bullets38Box", "Base.308Box",
                "Base.Bullets357Box", "Base.556Box", "Base.ShotgunShellsBox", "Base.9mmClip",
                "Base.45Clip", "Base.556Clip",
            },
        },
        {
            id = "weapon_parts", min = 0, max = 2,
            items = {
                "Base.x2Scope", "Base.x4Scope", "Base.x8Scope", "Base.Laser",
                "Base.TritiumSights", "Base.RecoilPad", "Base.ChokeTubeFull",
                "Base.ChokeTubeImproved",
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
                "Base.GreaveBodyArmour_Right_Army", "Base.HolsterShoulder", "Base.HolsterDouble",
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
        if #weapons > 0 then
            categories[#categories + 1] = { id = "marz_weapons", min = 0, max = 2, items = weapons }
        end
        if #parts > 0 then
            categories[#categories + 1] = { id = "marz_parts", min = 0, max = 1, items = parts }
        end
    end

    if config.int_snake and KnoxAirSupport.Integrations.IsAvailable("snake") then
        local weapons = KnoxAirSupport.Integrations.GetPool("snake", "weapons")
        local accessories = KnoxAirSupport.Integrations.GetPool("snake", "accessories")
        if #weapons > 0 then
            categories[#categories + 1] = { id = "snake_weapons", min = 0, max = 1, items = weapons }
        end
        if #accessories > 0 then
            categories[#categories + 1] = { id = "snake_accessories", min = 0, max = 2, items = accessories }
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
---@param container ItemContainer
---@param eventTypeId string
---@param config table<string,any>
---@return integer
function KnoxAirSupport.Loot.FillContainer(container, eventTypeId, config)
    local categories = KnoxAirSupport.Loot.BuildCategories(eventTypeId, config)
    local maxItems = config.lootQuantity or 15
    local added = 0

    for _, category in ipairs(categories) do
        if added >= maxItems then break end

        local count = ZombRand(category.min, category.max)
        if count > #category.items then count = #category.items end
        if count > 0 then
            local picked = KnoxAirSupport.Loot.PickUnique(category.items, count)
            for _, itemType in ipairs(picked) do
                if added >= maxItems then break end
                local item = container:AddItem(itemType)
                if item then
                    added = added + 1
                    if category.condition and item.setCondition then
                        pcall(function() item:setCondition(category.condition) end)
                    end
                end
            end
        end
    end

    return added
end
