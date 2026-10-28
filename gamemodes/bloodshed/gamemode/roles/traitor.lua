local ROLE = {}

ROLE.name = "Traitor"
ROLE.team = 1
ROLE.flashlight = true
ROLE.killer = true
ROLE.trapTier = "advanced"

ROLE.langName = "traitor"
ROLE.color = Color(150, 10, 10)
ROLE.desc = "traitor_desc"

ROLE.onSpawn = function(ply)
    if MuR.Gamemode == 25 then
        MuR.ApplyKillerClass(ply)
        if MuR.Mode25GiveOfficerCover then
            MuR.Mode25GiveOfficerCover(ply)
        end
        return
    end

    if MuR.ApplyKillerClass(ply) then return end

    if MuR.Gamemode ~= 7 then
        ply:GiveWeapon("tfa_bs_vp9")
        ply:GiveAmmo(30, "Pistol", true)
    else
        ply:GiveWeapon("tfa_bs_cobra")
        ply:GiveAmmo(18, "357", true)
    end

    ply:GiveWeapon(math.random(1, 2) == 1 and "mur_loot_heroin" or "mur_loot_adrenaline")
    ply:GiveWeapon(math.random(1, 2) == 1 and "mur_f1" or "mur_m67")

    local weapons = {"mur_poisoncanister", "mur_cyanide", "mur_disguise", "mur_scanner", "mur_ied", "mur_trap_kit", "mur_break_tool", "tfa_bs_combk", "mur_chemistry_illegal"}
    for _, wep in pairs(weapons) do ply:GiveWeapon(wep, true) end
end

MuR:RegisterRole(ROLE)
