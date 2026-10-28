local ROLE = {}

ROLE.name = "Medic"
ROLE.team = 2
ROLE.flashlight = false
ROLE.models = {
    male = {"models/murdered/pm/medic_01.mdl", "models/murdered/pm/medic_02.mdl", "models/murdered/pm/medic_03.mdl", "models/murdered/pm/medic_04.mdl", "models/murdered/pm/medic_05.mdl", "models/murdered/pm/medic_06.mdl", "models/murdered/pm/medic_07.mdl"},
    female = {"models/murdered/pm/medic_01_f.mdl", "models/murdered/pm/medic_02_f.mdl", "models/murdered/pm/medic_03_f.mdl", "models/murdered/pm/medic_04_f.mdl", "models/murdered/pm/medic_05_f.mdl", "models/murdered/pm/medic_06_f.mdl"}
}

ROLE.langName = "medic"
ROLE.color = Color(50, 120, 50)
ROLE.desc = "medic_desc"

local KIT = {
    "mur_loot_medkit",
    "mur_loot_adrenaline",
    "mur_loot_bandage",
    "mur_loot_surgicalkit",
    "mur_loot_tourniquet",
    "mur_tranexamic",
    "mur_naloxone",
    "mur_chemistry_basic"
}

local EXTRA_MEDS = {
    "mur_plasma",
    "mur_atropine",
    "mur_morphine",
    "mur_pills_vitamink",
    "mur_pills_prussianblue",
    "mur_pills_analgesic",
    "mur_pills_glucose"
}

ROLE.onSpawn = function(ply)
    for _, wep in ipairs(KIT) do ply:GiveWeapon(wep) end

    local pool = table.Copy(EXTRA_MEDS)

    for _ = 1, math.random(3, 4) do
        if #pool == 0 then break end
        ply:GiveWeapon(table.remove(pool, math.random(#pool)))
    end
end

MuR:RegisterRole(ROLE)
