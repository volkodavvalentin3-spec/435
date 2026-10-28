local ROLE = {}

ROLE.name = "Hunter"
ROLE.team = 2
ROLE.flashlight = false

ROLE.langName = "civilian"
ROLE.color = Color(50, 75, 175)
ROLE.desc = "defender_desc"
ROLE.other = "defender_var_heavy"

ROLE.onSpawn = function(ply)
    local pri = table.Random(MuR.WeaponData["DefenderWeapons"])
    ply:GiveWeapon(pri.class)
    ply:GiveAmmo(pri.count * 2, pri.ammo, true)
end

MuR:RegisterRole(ROLE)
