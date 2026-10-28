local ROLE = {}

local otaCodes = {
    "BRAVO",
    "DELTA",
    "SIGMA",
    "NOVA",
    "VECTOR",
    "ECHO",
    "OMEGA"
}

local subclasses = {
    {
        id = "rifleman",
        name = "Rifleman",
        model = "models/player/combine_soldier.mdl",
        gun = "tfa_bs_mp7",
        ammoType = "Pistol",
        ammo = 160,
        nade = "mur_m67",
        armor = "classII_armor",
        armorValue = 50
    },
    {
        id = "shotgunner",
        name = "Shotgunner",
        model = "models/player/combine_soldier.mdl",
        gun = "tfa_bs_spas",
        ammoType = "Buckshot",
        ammo = 32,
        nade = "mur_flashbang",
        armor = "classI_armor",
        armorValue = 35,
        walk = 80,
        run = 190
    },
    {
        id = "elite",
        name = "Elite",
        model = "models/player/combine_super_soldier.mdl",
        gun = "tfa_bs_ar2",
        ammoType = "AR2",
        ammo = 150,
        nade = "mur_m67",
        armor = "classIII_armor",
        armorValue = 75,
        hp = 125
    }
}

local function giveGun(ply, wep, ammo, ammoType)
    ply:GiveWeapon(wep)

    if ammo and ammoType then
        ply:GiveAmmo(ammo, ammoType, true)
    end
end

local function giveStuff(ply)
    ply:GiveWeapon("tfa_bs_usp")
    ply:GiveAmmo(36, "Pistol", true)
    ply:GiveWeapon("tfa_bs_baton")
    ply:GiveWeapon("mur_loot_bandage")
    ply:GiveWeapon("mur_loot_medkit")
    ply:GiveWeapon("mur_baterringram")
    ply:GiveWeapon("mur_radio")
end

local function giveArmor(ply, subclass)
    ply:SetArmor(subclass.armorValue or 0)

    timer.Simple(0, function()
        if not IsValid(ply) then return end
        ply:EquipArmor(subclass.armor)
        ply:SetArmorHidden("body", true)
        ply:SetArmorNoDrop("body", true)
    end)
end

local function setStats(ply, subclass)
    ply:SetWalkSpeed(subclass.walk or 70)
    ply:SetRunSpeed(subclass.run or 180)

    if subclass.hp then
        ply:SetMaxHealth(subclass.hp)
        ply:SetHealth(subclass.hp)
    end
end

local function getRandomSubclass()
    return table.Random(subclasses)
end

local function getCombineCount()
    local count = 0

    for _, ply in ipairs(player.GetAll()) do
        if ply:GetNW2String("Class") == "CombineSoldier" then
            count = count + 1
        end
    end

    return math.max(count, 1)
end

local function makeOtaName()
    local code = table.Random(otaCodes)
    local number = math.random(1, getCombineCount())

    return string.format("OTA-%s-%d", code, number)
end

local function setupMode20Soldier(ply, subclass)
    ply:SetNW2String("Mode20CombineSubclass", subclass.id)
    ply:SetNW2String("Mode20CombineSubclassName", subclass.name)
    ply:SetModel(subclass.model)
    ply:SetPlayerColor(Color(35, 35, 165):ToVector())

    giveGun(ply, subclass.gun, subclass.ammo, subclass.ammoType)
    ply:GiveWeapon(subclass.nade)
    giveStuff(ply)
    giveArmor(ply, subclass)
    setStats(ply, subclass)
end

local function setupDefaultSoldier(ply)
    ply:SetNW2String("Mode20CombineSubclass", "")
    ply:SetNW2String("Mode20CombineSubclassName", "")
    ply:SetPlayerColor(Color(35, 35, 165):ToVector())

    local roll = math.random(1, 4)

    if roll == 1 then
        giveGun(ply, "tfa_bs_spas", 24, "Buckshot")
    elseif roll == 2 then
        giveGun(ply, "tfa_bs_ar2", 120, "AR2")
    else
        giveGun(ply, "tfa_bs_mp7", 120, "Pistol")
    end

    giveStuff(ply)
    ply:SetArmor(50)
    ply:SetWalkSpeed(70)
    ply:SetRunSpeed(180)
end

ROLE.name = "CombineSoldier"
ROLE.team = 1
ROLE.flashlight = true
ROLE.models = {"models/player/combine_soldier.mdl", "models/player/combine_super_soldier.mdl"}
ROLE.male = true

ROLE.langName = "combinesoldier"
ROLE.color = Color(50, 150, 255)
ROLE.desc = "combinesoldier_desc"
ROLE.getName = function()
    return makeOtaName()
end

ROLE.onSpawn = function(ply)
    if MuR.Gamemode == 20 then
        setupMode20Soldier(ply, getRandomSubclass())
        return
    end

    setupDefaultSoldier(ply)
end

MuR:RegisterRole(ROLE)
