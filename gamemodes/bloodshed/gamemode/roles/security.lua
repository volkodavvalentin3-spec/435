local ROLE = {}

ROLE.name = "Security"
ROLE.team = 2
ROLE.flashlight = false
ROLE.models = {"models/murdered/pm/guard/guard_01.mdl", "models/murdered/pm/guard/guard_02.mdl", "models/murdered/pm/guard/guard_03.mdl", "models/murdered/pm/guard/guard_04.mdl", "models/murdered/pm/guard/guard_05.mdl", "models/murdered/pm/guard/guard_06.mdl", "models/murdered/pm/guard/guard_07.mdl", "models/murdered/pm/guard/guard_08.mdl", "models/murdered/pm/guard/guard_09.mdl"}
ROLE.male = true

ROLE.langName = "security"
ROLE.color = Color(25, 25, 255)
ROLE.desc = "security_desc"

ROLE.onSpawn = function(ply)
    ply:GiveWeapon("mur_taser")
    ply:GiveWeapon("tfa_bs_baton")
    ply:GiveWeapon("mur_radio")
    ply:GiveWeapon("mur_ziptie")
    ply:GiveAmmo(3, "GaussEnergy", true)
end

MuR:RegisterRole(ROLE)
