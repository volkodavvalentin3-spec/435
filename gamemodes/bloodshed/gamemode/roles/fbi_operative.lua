local ROLE = {}

ROLE.name = "FBIOperative"
ROLE.team = 2
ROLE.flashlight = true
ROLE.models = {"models/murdered/pm/fbi_uiu_operative.mdl"}
ROLE.male = true
ROLE.group = "police"

ROLE.langName = "fbi_operative"
ROLE.color = Color(0, 50, 200)
ROLE.desc = "fbi_operative_desc"

ROLE.onSpawn = function(ply)
    ply:GiveWeapon("tfa_bs_glock_t")
    ply:GiveWeapon("tfa_bs_aug")
    ply:GiveWeapon("mur_radio")
    ply:GiveWeapon("tfa_bs_baton")
    ply:GiveWeapon("mur_drone")
    ply:GiveWeapon("mur_ied")
    ply:GiveWeapon("mur_m67")
    ply:GiveWeapon("mur_baterringram")
    ply:GiveWeapon("mur_loot_hammer")
    ply:GiveWeapon("mur_loot_bandage")
    ply:GiveWeapon("mur_loot_medkit")
    ply:GiveAmmo(420, "SMG1", true)
    ply:GiveAmmo(170, "Pistol", true)
    timer.Simple(1, function()
        if !IsValid(ply) then return end
        ply:StripWeapon("mur_hands")
    end)
end

MuR:RegisterRole(ROLE)
