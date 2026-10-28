local ROLE = {}

ROLE.name = "Terrorist"
ROLE.team = 1
ROLE.flashlight = true
ROLE.models = {"models/murdered/pm/t_grunts.mdl"}
ROLE.male = true
ROLE.killer = "active"

ROLE.langName = "terrorist"
ROLE.color = Color(160, 20, 20)
ROLE.desc = "terrorist_desc"

ROLE.onSpawn = function(ply)
    ply:SetArmor(100)

    local sec, mel = table.Random(MuR.WeaponsTable["Primary"]), table.Random(MuR.WeaponsTable["Melee"])
    local weapons = {"tfa_bs_rpg7", "mur_ied", "mur_m67", "mur_f1"}
    for _, wep in pairs(weapons) do ply:GiveWeapon(wep, _ <= 3) end

    ply:GiveAmmo(4, "RPG_Round", true)
    ply:GiveWeapon(sec.class)
    ply:GiveAmmo(sec.count * 6, sec.ammo, true)
    ply:GiveWeapon(mel.class)
    ply:GiveWeapon("mur_scanner", true)

    ply:SetWalkSpeed(80)
    ply:SetRunSpeed(240)
    ply:SetNW2Float("ArrestState", 2)
end

MuR:RegisterRole(ROLE)
