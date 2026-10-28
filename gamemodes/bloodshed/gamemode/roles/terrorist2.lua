local ROLE = {}

ROLE.name = "Terrorist2"
ROLE.team = 1
ROLE.flashlight = true
ROLE.models = {"models/murdered/pm/t_phoenix.mdl", "models/murdered/pm/t_leet.mdl", "models/murdered/pm/t_guerilla.mdl", "models/murdered/pm/t_arctic.mdl"}
ROLE.male = true
ROLE.group = "terrorists"

ROLE.langName = "terrorist"
ROLE.color = Color(160, 20, 20)
ROLE.desc = "terrorist_desc2"

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
