local ROLE = {}

ROLE.name = "Civilian"
ROLE.team = 2
ROLE.health = 100
ROLE.flashlight = false
ROLE.models = {
    male = {"models/player/group03/male_01.mdl", "models/player/group03/male_02.mdl", "models/player/group03/male_03.mdl", "models/player/group03/male_04.mdl", "models/player/group03/male_05.mdl", "models/player/group03/male_06.mdl", "models/player/group03/male_07.mdl", "models/player/group03/male_08.mdl", "models/player/group03/male_09.mdl"},
    female = {"models/player/group03/female_01.mdl", "models/player/group03/female_02.mdl", "models/player/group03/female_03.mdl", "models/player/group03/female_04.mdl", "models/player/group03/female_05.mdl", "models/player/group03/female_06.mdl"}
}

ROLE.langName = "civilian"
ROLE.color = Color(100, 150, 200)
ROLE.desc = "civilian_desc"

ROLE.onSpawn = function(ply)
    ply:GiveWeapon("mur_hands", true)
end

MuR:RegisterRole(ROLE)
