local ROLE = {}

ROLE.name = "Innocent"
ROLE.team = 2
ROLE.health = 100
ROLE.flashlight = false

ROLE.models = function(ply)
    local males = {"models/murdered/pm/citizen/male_01.mdl", "models/murdered/pm/citizen/male_02.mdl", "models/murdered/pm/citizen/male_03.mdl", "models/murdered/pm/citizen/male_04.mdl", "models/murdered/pm/citizen/male_05.mdl", "models/murdered/pm/citizen/male_06.mdl", "models/murdered/pm/citizen/male_07.mdl", "models/murdered/pm/citizen/male_08.mdl", "models/murdered/pm/citizen/male_09.mdl", "models/murdered/pm/citizen/male_10.mdl", "models/murdered/pm/citizen/male_11.mdl"}
    local females = {"models/murdered/pm/citizen/female_01.mdl", "models/murdered/pm/citizen/female_02.mdl", "models/murdered/pm/citizen/female_03.mdl", "models/murdered/pm/citizen/female_04.mdl", "models/murdered/pm/citizen/female_06.mdl", "models/murdered/pm/citizen/female_07.mdl"}
    return table.Random(ply.Male and males or females)
end

ROLE.langName = "civilian"
ROLE.color = Color(100, 150, 200)
ROLE.desc = "civilian_desc"

ROLE.onSpawn = function(ply)
    ply:GiveWeapon("mur_hands", true)
end

MuR:RegisterRole(ROLE)
