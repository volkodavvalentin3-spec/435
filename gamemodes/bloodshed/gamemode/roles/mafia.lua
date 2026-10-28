local ROLE = {}

ROLE.name = "Mafia"
ROLE.team = 2
ROLE.flashlight = true
ROLE.models = {"models/murdered/pm/gangs/gang_groove_chem.mdl", "models/murdered/pm/gangs/gang_1.mdl", "models/murdered/pm/gangs/gang_2.mdl"}
ROLE.male = true

ROLE.langName = "mafia"
ROLE.color = Color(100, 100, 100)
ROLE.desc = "mafia_desc"

ROLE.onSpawn = function(ply)
    ply:SetPlayerColor(Color(50,50,50):ToVector())

    local wep = table.Random(MuR.WeaponsTable["Primary"])
    if wep then ply:GiveWeapon(wep.class); ply:GiveAmmo(wep.count * 2, wep.ammo, true) end
    local wep2 = table.Random(MuR.WeaponsTable["Secondary"])
    if wep2 then ply:GiveWeapon(wep2.class); ply:GiveAmmo(wep2.count * 2, wep2.ammo, true) end
    ply:GiveWeapon(table.Random(MuR.WeaponsTable["Melee"]).class)
    ply:SetWalkSpeed(100)
    ply:SetRunSpeed(280)
end

MuR:RegisterRole(ROLE)
