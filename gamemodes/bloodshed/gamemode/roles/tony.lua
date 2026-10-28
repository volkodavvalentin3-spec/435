local ROLE = {}

ROLE.name = "Tony"
ROLE.team = 1
ROLE.flashlight = true
ROLE.models = {"models/murdered/pm/tony.mdl"}
ROLE.male = true
ROLE.health = 500

ROLE.langName = "tony"
ROLE.color = Color(255, 0, 0)
ROLE.desc = "tony_desc"

ROLE.onSpawn = function(ply)
    ply:SetPlayerColor(Color(255,0,0):ToVector())

    local wep = table.Random(MuR.WeaponsTable["Primary"])
    if wep then ply:GiveWeapon(wep.class); ply:GiveAmmo(wep.count * 2, wep.ammo, true) end
    ply:GiveWeapon("tfa_bs_fireaxe_maniac", true)
    ply:SetWalkSpeed(110)
    ply:SetRunSpeed(300)
    ply:SetMaxHealth(500)
end

MuR:RegisterRole(ROLE)
