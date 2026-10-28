local ROLE = {}

ROLE.name = "GangRed"
ROLE.team = 1
ROLE.flashlight = true
ROLE.models = {"models/murdered/pm/gangs/gang_ballas_chem.mdl", "models/murdered/pm/gangs/gang_ballas_1.mdl", "models/murdered/pm/gangs/gang_ballas_2.mdl"}
ROLE.male = true
ROLE.group = "gangred"

ROLE.langName = "gangred"
ROLE.color = Color(200, 50, 50)
ROLE.desc = "gang_desc"

ROLE.onSpawn = function(ply)
    local sec = table.Random(MuR.WeaponsTable["Secondary"])
    ply:GiveWeapon(sec.class)
    ply:GiveAmmo(sec.count * 5, sec.ammo, true)
    ply:GiveWeapon(table.Random(MuR.WeaponsTable["Melee"]).class)
    ply:SetNW2Float("ArrestState", 1)
end

MuR:RegisterRole(ROLE)
