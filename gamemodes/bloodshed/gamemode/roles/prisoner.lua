local ROLE = {}

ROLE.name = "Prisoner"
ROLE.team = 1
ROLE.flashlight = true

ROLE.langName = "prisoner"
ROLE.color = Color(255, 140, 0)
ROLE.desc = "prisoner_desc"
ROLE.male = true

ROLE.models = {
    "models/player/group01/male_01.mdl",
    "models/player/group01/male_02.mdl",
    "models/player/group01/male_03.mdl",
    "models/player/group01/male_04.mdl",
    "models/player/group01/male_05.mdl",
    "models/player/group01/male_06.mdl",
    "models/player/group01/male_07.mdl",
    "models/player/group01/male_08.mdl",
    "models/player/group01/male_09.mdl",
}

ROLE.onSpawn = function(ply)
    ply:SetNW2Float("ArrestState", 1)
    ply:SetPlayerColor(Vector(1, 0.6, 0))
end

MuR:RegisterRole(ROLE)
