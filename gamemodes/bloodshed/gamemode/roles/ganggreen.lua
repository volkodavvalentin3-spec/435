local ROLE = {}

ROLE.name = "GangGreen"
ROLE.team = 2
ROLE.flashlight = true
ROLE.models = {"models/murdered/pm/gangs/gang_groove_chem.mdl", "models/murdered/pm/gangs/gang_1.mdl", "models/murdered/pm/gangs/gang_2.mdl"}
ROLE.male = true
ROLE.group = "ganggreen"

ROLE.langName = "ganggreen"
ROLE.color = Color(50, 200, 50)
ROLE.desc = "gang_desc"

ROLE.onSpawn = function(ply)
    local sec = table.Random(MuR.WeaponsTable["Secondary"])
    ply:GiveWeapon(sec.class)
    ply:GiveAmmo(sec.count * 5, sec.ammo, true)
    ply:GiveWeapon(table.Random(MuR.WeaponsTable["Melee"]).class)
    ply:SetNW2Float("ArrestState", 1)
end

MuR:RegisterRole(ROLE)
