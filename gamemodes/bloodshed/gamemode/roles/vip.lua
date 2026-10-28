local ROLE = {}

ROLE.name = "VIP"
ROLE.team = 2
ROLE.flashlight = true
ROLE.models = {"models/murdered/pm/male_09_vip_player.mdl"}
ROLE.male = true

ROLE.langName = "vip"
ROLE.color = Color(226, 170, 76)
ROLE.desc = "vip_desc"

ROLE.onSpawn = function(ply)
    ply:GiveWeapon("mur_radio")
    ply:GiveWeapon("tfa_bs_baton")
    ply:GiveWeapon("mur_loot_bandage")
end

MuR:RegisterRole(ROLE)
