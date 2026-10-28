local ROLE = {}

ROLE.name = "Builder"
ROLE.team = 2
ROLE.flashlight = false
ROLE.models = {"models/murdered/pm/odessa.mdl"}
ROLE.male = true

ROLE.langName = "builder"
ROLE.color = Color(50, 120, 50)
ROLE.desc = "builder_desc"

ROLE.onSpawn = function(ply)
    local weapons = {"mur_loot_hammer", "mur_loot_ducttape", "tfa_bs_crowbar", "mur_welder"}
    for _, wep in pairs(weapons) do ply:GiveWeapon(wep) end
end

MuR:RegisterRole(ROLE)
