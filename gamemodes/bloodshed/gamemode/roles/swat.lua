local ROLE = {}

ROLE.name = "SWAT"
ROLE.team = 2
ROLE.flashlight = true
ROLE.models = {"models/murdered/pm/css_swat.mdl"}
ROLE.male = true
ROLE.group = "swat"

ROLE.langName = "swat"
ROLE.color = Color(25, 25, 255)
ROLE.desc = "swat_desc"

ROLE.onSpawn = function(ply)
    ply:GiveWeapon("tfa_bs_combk")
    ply:GiveWeapon("mur_loot_bandage")
    ply:GiveWeapon("mur_radio")
    timer.Simple(1, function()
        if !IsValid(ply) then return end
        if MuR and MuR.Gamemode == 12 then return end
        ply:EquipArmor("classIII_armor")
        ply:EquipArmor("helmet_ulach")
    end)
end

MuR:RegisterRole(ROLE)
