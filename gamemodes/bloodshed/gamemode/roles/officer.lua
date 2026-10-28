local ROLE = {}

ROLE.name = "Officer"
ROLE.team = 3
ROLE.flashlight = true
ROLE.models = {"models/murdered/pm/police/male_01.mdl", "models/murdered/pm/police/male_03.mdl", "models/murdered/pm/police/male_04.mdl", "models/murdered/pm/police/male_05.mdl", "models/murdered/pm/police/male_06.mdl", "models/murdered/pm/police/male_07.mdl", "models/murdered/pm/police/male_08.mdl", "models/murdered/pm/police/male_09.mdl"}
ROLE.male = true
ROLE.group = "police"

ROLE.langName = "officer"
ROLE.color = Color(25, 25, 255)
ROLE.desc = "officer_desc"

ROLE.onSpawn = function(ply)
    ply:GiveWeapon("tfa_bs_glock")
    ply:GiveWeapon("mur_radio")

    local mode = MuR.Mode(MuR.Gamemode)
    if math.random(1,10) == 1 then
        ply:GiveWeapon("tfa_bs_m590")
        ply:GiveAmmo(24, "Buckshot", true)
    elseif math.random(1,5) == 1 or (mode and mode.officer_always_badger) then
        ply:GiveWeapon("tfa_bs_badger")
        ply:GiveAmmo(75, "SMG1", true)
    end

    local weapons = {"mur_taser", "mur_pepperspray", "mur_handcuffs", "tfa_bs_baton", "mur_loot_bandage"}
    for _, wep in pairs(weapons) do ply:GiveWeapon(wep, _ == 3) end

    ply:GiveAmmo(51, "Pistol", true)
    ply:GiveAmmo(3, "GaussEnergy", true)
    timer.Simple(1, function()
        if !IsValid(ply) then return end
        ply:EquipArmor("classII_police")
        ply:SetBodygroup(5, 0)
    end)
end

MuR:RegisterRole(ROLE)
