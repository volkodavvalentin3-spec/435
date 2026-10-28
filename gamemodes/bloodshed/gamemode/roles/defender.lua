local ROLE = {}

ROLE.name = "Defender"
ROLE.team = 2
ROLE.flashlight = false

ROLE.langName = "civilian"
ROLE.color = Color(50, 75, 175)
ROLE.desc = "defender_desc"
ROLE.other = "defender_var_light"

ROLE.onSpawn = function(ply)
    ply:GiveWeapon(MuR.Gamemode ~= 7 and "tfa_bs_walther" or "tfa_bs_cobra")
end

MuR:RegisterRole(ROLE)
