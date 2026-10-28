local ROLE = {}

ROLE.name = "Killer"
ROLE.team = 1
ROLE.health = 300
ROLE.flashlight = true
ROLE.killer = true
ROLE.trapTier = "basic"

ROLE.langName = "murderer"
ROLE.color = Color(150, 10, 10)
ROLE.desc = "murderer_desc"

ROLE.onSpawn = function(ply)
    if MuR.ApplyKillerClass(ply) then return end

    local weapons = {"mur_poisoncanister", "mur_cyanide", "mur_disguise", "mur_scanner", "mur_trap_kit", "mur_break_tool", "tfa_bs_combk", "mur_chemistry_illegal"}
    for _, wep in pairs(weapons) do ply:GiveWeapon(wep, true) end
    ply:GiveWeapon(math.random(1, 2) == 1 and "mur_loot_heroin" or "mur_loot_adrenaline")
end

MuR:RegisterRole(ROLE)
