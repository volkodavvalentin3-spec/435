local ROLE = {}

ROLE.name = "SecurityForces"
ROLE.team = 2
ROLE.flashlight = false
ROLE.models = {"models/murdered/pm/sf/guard_01.mdl", "models/murdered/pm/sf/guard_02.mdl", "models/murdered/pm/sf/guard_03.mdl", "models/murdered/pm/sf/guard_04.mdl", "models/murdered/pm/sf/guard_05.mdl", "models/murdered/pm/sf/guard_06.mdl", "models/murdered/pm/sf/guard_07.mdl", "models/murdered/pm/sf/guard_08.mdl", "models/murdered/pm/sf/guard_09.mdl"}
ROLE.male = true

ROLE.langName = "security"
ROLE.color = Color(25, 25, 255)
ROLE.desc = "security_desc"

ROLE.onSpawn = function(ply)
    ply:GiveWeapon("mur_taser")
    ply:GiveWeapon("tfa_bs_baton")
    ply:GiveWeapon("mur_radio")
    ply:GiveWeapon("mur_pepperspray")
    ply:GiveWeapon("tfa_bs_m9")
    ply:GiveAmmo(4, "GaussEnergy", true)
    ply:GiveAmmo(30, "Pistol", true)
end

MuR:RegisterRole(ROLE)
