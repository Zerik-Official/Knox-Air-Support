require "KnoxAirSupport_Shared"

-- Item categories with min/max per drop
KnoxAirSupport.LOOT_CATEGORIES = {
    {
        id = "weapons", min = 1, max = 3,
        items = {
            "Base.Pistol", "Base.Revolver", "Base.HuntingRifle", "Base.Shotgun",
            "Base.AssaultRifle", "Base.Crowbar", "Base.Axe", "Base.Machete",
            "Base.BaseballBat", "Base.HuntingKnife",
        },
    },
    {
        id = "ammo", min = 1, max = 3,
        items = {
            "Base.Bullets9mmBox", "Base.Bullets38Box", "Base.308Box",
            "Base.556Box", "Base.ShotgunShellsBox", "Base.45Box",
        },
    },
    {
        id = "medical", min = 0, max = 2,
        items = {
            "Base.Bandage", "Base.AlcoholWipes", "Base.Disinfectant",
            "Base.Antibiotics", "Base.Needle", "Base.SutureNeedleHolder",
        },
    },
    {
        id = "food", min = 0, max = 2,
        items = {
            "Base.Cereal", "Base.Rice", "Base.Pasta", "Base.BeefJerky",
            "Base.PeanutButter", "Base.CannedBeans", "Base.CannedChili",
            "Base.CannedCornedBeef", "Base.CannedSardines", "Base.CannedTomato",
            "Base.CannedBolognese", "Base.CannedCarrots", "Base.CannedPeas",
        },
    },
    {
        id = "misc", min = 1, max = 2,
        items = {
            "Base.DuctTape", "Base.NailsBox", "Base.BatteryBox",
            "Base.FlashLight_AngleHead", "Base.HandTorch", "Base.Wire",
            "Base.BarbedWire", "Base.Tarp", "Base.Canteen",
            "Base.Bag_BigHikingBag", "Base.Bag_ALICEpack_Army",
        },
    },
    {
        id = "special", min = 0, max = 1,
        items = {
            "Base.Katana", "Base.Sledgehammer", "Base.Sledgehammer2",
            "Base.Vest_BulletSWAT",
        },
    },
}

print(KnoxAirSupport.TAG .. " Loot module loaded")
