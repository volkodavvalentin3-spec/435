local ROLE = {}

ROLE.name = "FBI"
ROLE.team = 3
ROLE.flashlight = true
ROLE.models = {"models/murdered/pm/citizen/male_01.mdl", "models/murdered/pm/citizen/male_02.mdl", "models/murdered/pm/citizen/male_03.mdl", "models/murdered/pm/citizen/male_04.mdl", "models/murdered/pm/citizen/male_05.mdl", "models/murdered/pm/citizen/male_06.mdl", "models/murdered/pm/citizen/male_07.mdl", "models/murdered/pm/citizen/male_08.mdl", "models/murdered/pm/citizen/male_09.mdl", "models/murdered/pm/citizen/male_10.mdl", "models/murdered/pm/citizen/male_11.mdl"}
ROLE.male = true
ROLE.group = "police"

ROLE.langName = "fbiagent"
ROLE.color = Color(25, 25, 255)
ROLE.desc = "fbiagent_desc"

ROLE.onSpawn = function(ply)
    ply:GiveWeapon("tfa_bs_p320")
    ply:GiveWeapon("mur_radio")
    ply:GiveWeapon("mur_handcuffs", true)
    ply:GiveWeapon("mur_loot_bandage")
    ply:GiveWeapon("mur_disguise", true)
    ply:GiveAmmo(45, "Pistol", true)
    ply:SetArmor(10)
end

MuR:RegisterRole(ROLE)
