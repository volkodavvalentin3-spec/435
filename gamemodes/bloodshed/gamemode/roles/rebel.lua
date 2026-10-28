local ROLE = {}

local medicModels = {
    "models/player/group03m/male_01.mdl",
    "models/player/group03m/male_02.mdl",
    "models/player/group03m/male_03.mdl",
    "models/player/group03m/male_04.mdl",
    "models/player/group03m/male_05.mdl",
    "models/player/group03m/male_06.mdl",
    "models/player/group03m/male_07.mdl",
    "models/player/group03m/male_08.mdl",
    "models/player/group03m/male_09.mdl",
    "models/player/group03m/female_01.mdl",
    "models/player/group03m/female_02.mdl",
    "models/player/group03m/female_03.mdl",
    "models/player/group03m/female_04.mdl",
    "models/player/group03m/female_05.mdl",
    "models/player/group03m/female_06.mdl"
}

local medicItems = {
    "mur_loot_bandage",
    "mur_loot_adrenaline",
    "mur_loot_ducttape",
    "mur_loot_tourniquet",
    "mur_loot_medkit",
    "mur_loot_surgicalkit",
    "mur_tranexamic",
    "mur_chemistry_basic"
}

local function giveMedicItems(ply)
    for _, class in ipairs(medicItems) do
        ply:GiveWeapon(class)
    end

    ply:SetModel(table.Random(medicModels))
    ply:SetNW2String("Mode20RebelClass", "medic")
    ply:SetNW2String("Mode20RebelClassName", "Medic")
end

local function getMedicLimit()
    local totalPlayers = #player.GetAll()

    if totalPlayers <= 9 then
        return 1
    end

    if totalPlayers <= 20 then
        return 2
    end

    return 2 + math.ceil((totalPlayers - 20) / 10)
end

local function shouldBeMedic(ply)
    if MuR.Gamemode ~= 20 then return false end

    local rebels = {}
    for _, target in ipairs(player.GetAll()) do
        if target:GetNW2String("Class") == "Rebel" then
            table.insert(rebels, target)
        end
    end

    if #rebels == 0 then return false end

    local seed = MuR.Mode20 and MuR.Mode20.RebelMedicSeed or "mode20"
    table.sort(rebels, function(a, b)
        local aKey = util.CRC(seed .. a:SteamID64())
        local bKey = util.CRC(seed .. b:SteamID64())
        return aKey < bKey
    end)

    local limit = math.min(getMedicLimit(), #rebels)
    for i = 1, limit do
        if rebels[i] == ply then
            return true
        end
    end

    return false
end

ROLE.name = "Rebel"
ROLE.team = 2
ROLE.flashlight = true
ROLE.models = {"models/player/group03/male_01.mdl", "models/player/group03/male_02.mdl", "models/player/group03/male_03.mdl", "models/player/group03/male_04.mdl", "models/player/group03/male_05.mdl", "models/player/group03/male_06.mdl", "models/player/group03/male_07.mdl", "models/player/group03/male_08.mdl", "models/player/group03/male_09.mdl"}
ROLE.male = true

ROLE.langName = "rebel"
ROLE.color = Color(255, 150, 50)
ROLE.desc = "rebel_desc"

ROLE.onSpawn = function(ply)
    ply:SetPlayerColor(Color(35,165,35):ToVector())
	ply:SetNW2String("Mode20RebelClass", "")
	ply:SetNW2String("Mode20RebelClassName", "")

    local isMedic = shouldBeMedic(ply)

    if math.random(1,4) == 1 then
        ply:GiveWeapon("tfa_bs_spas")
        ply:GiveAmmo(24, "Buckshot", true)
    elseif math.random(1,4) == 1 then
        ply:GiveWeapon("tfa_bs_mosin")
        ply:GiveAmmo(25, "SniperPenetratedRound", true)
    elseif math.random(1,4) == 1 then
        ply:GiveWeapon("tfa_bs_sks")
        ply:GiveAmmo(60, "AR2", true)
    elseif math.random(1,4) == 1 then
        ply:GiveWeapon("tfa_bs_mp7")
        ply:GiveAmmo(120, "Pistol", true)
    else
        ply:GiveWeapon("tfa_bs_annabelle")
        ply:GiveAmmo(32, "357", true)
    end
    if math.random(1,3) == 1 then
        ply:GiveWeapon("tfa_bs_cobra")
        ply:GiveAmmo(24, "357", true)
    else
        ply:GiveWeapon("tfa_bs_usp")
        ply:GiveAmmo(36, "Pistol", true)
    end
    ply:GiveWeapon(table.Random(MuR.WeaponsTable["Melee"]).class)
    ply:GiveWeapon(math.random(1, 2) == 1 and "mur_f1" or "mur_m67")
    ply:GiveWeapon(math.random(1, 2) == 1 and "mur_beartrap" or "mur_loot_ducttape")
    ply:GiveWeapon("mur_loot_bandage")

	if isMedic then
		giveMedicItems(ply)
	end

    ply:SetWalkSpeed(100)
    ply:SetRunSpeed(280)
    ply:SetNW2Float("ArrestState", 1)
end

MuR:RegisterRole(ROLE)
