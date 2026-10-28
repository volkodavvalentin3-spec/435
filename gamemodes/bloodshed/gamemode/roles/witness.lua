local ROLE = {}

ROLE.name = "Witness"
ROLE.team = 2
ROLE.flashlight = false

ROLE.langName = "witness"
ROLE.color = Color(50, 120, 50)
ROLE.desc = "witness_desc"

ROLE.onSpawn = function(ply)
    ply:GiveWeapon("mur_roledetector")
end

MuR:RegisterRole(ROLE)
