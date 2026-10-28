local ROLE = {}

ROLE.name = "Soldier"
ROLE.team = 1
ROLE.flashlight = true
ROLE.models = {"models/murdered/pm/css_seb.mdl"}

ROLE.langName = "soldier"
ROLE.color = Color(250, 150, 0)
ROLE.desc = "soldier_desc"

ROLE.onSpawn = function(ply)
    ply.RandomSkinDisabled = true
    if MuR.Gamemode == 15 and MuR.ExperimentWeapon then
        ply:GiveWeapon(MuR.ExperimentWeapon.class)
        ply:GiveAmmo(MuR.ExperimentWeapon.count * 3, MuR.ExperimentWeapon.ammo, true)
        ply:SetWalkSpeed(240)
        ply:SetRunSpeed(400)
        ply:SetJumpPower(360)
        ply:GiveWeapon("mur_loot_adrenaline")
        ply:GiveWeapon("tfa_bs_combk")
        ply:GiveWeapon("mur_loot_bandage")
        ply:GiveWeapon("mur_radio")
    elseif MuR.Gamemode == 18 then
        if !IsValid(ply) then return end
        ply:SetNWInt("MuR_ZombiesPoints", 500)
        ply:GiveWeapon("tfa_bs_colt_nz")
        ply:GiveAmmo(21, "pistol", true)
        ply:GiveWeapon("mur_loot_bandage")
        ply:GiveWeapon("mur_radio")
        ply:GiveWeapon("tfa_bs_compactk")
        ply:SetTeam(1)
    elseif MuR.Gamemode == 19 then
        if !IsValid(ply) then return end
        ply:GiveWeapon("mur_loot_bandage")
        ply:SetTeam(1)
        ply:AllowFlashlight(false)
    else
        local pri, sec = table.Random(MuR.WeaponsTable["Primary"]), table.Random(MuR.WeaponsTable["Secondary"])
        ply:GiveWeapon(pri.class)
        ply:GiveAmmo(pri.count * 6, pri.ammo, true)
        ply:GiveWeapon(sec.class)
        ply:GiveAmmo(sec.count * 4, sec.ammo, true)
        ply:GiveWeapon(math.random(1, 2) == 1 and "mur_f1" or "mur_m67")
        ply:GiveWeapon("mur_loot_medkit")
        ply:GiveWeapon("tfa_bs_combk")
        ply:GiveWeapon("mur_loot_bandage")
        ply:GiveWeapon("mur_radio")
        timer.Simple(1, function()
            if !IsValid(ply) then return end
            ply:EquipArmor("classII_armor")
            ply:EquipArmor("helmet_ulach")
        end)
    end
end

MuR:RegisterRole(ROLE)
