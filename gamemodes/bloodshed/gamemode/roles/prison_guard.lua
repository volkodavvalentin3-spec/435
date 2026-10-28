local ROLE = {}

ROLE.name = "PrisonGuard"
ROLE.team = 2
ROLE.flashlight = true
ROLE.models = {"models/murdered/pm/css_swat.mdl"}
ROLE.male = true
ROLE.group = "police"

ROLE.langName = "prison_guard"
ROLE.color = Color(25, 25, 255)
ROLE.desc = "prison_guard_desc"

ROLE.onSpawn = function(ply)
    ply:GiveWeapon("tfa_bs_mp5")
    ply:GiveAmmo(90, "SMG1", true)

    ply:GiveWeapon("tfa_bs_glock")
    ply:GiveAmmo(51, "Pistol", true)

    ply:GiveWeapon("tfa_bs_baton")
    ply:GiveWeapon("mur_taser")
    ply:GiveWeapon("mur_handcuffs")
    ply:GiveWeapon("mur_loot_bandage")
    ply:GiveWeapon("mur_flashbang")
    ply:GiveAmmo(2, "GaussEnergy", true)

    ply.RandomSkinDisabled = true

    timer.Simple(1, function()
        if not IsValid(ply) then return end
        ply:EquipArmor("classII_police")
        ply:EquipArmor("helmet_riot")
    end)
end

MuR:RegisterRole(ROLE)
