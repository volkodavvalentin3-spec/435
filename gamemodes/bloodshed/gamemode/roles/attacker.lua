local ROLE = {}

ROLE.name = "Attacker"
ROLE.team = 1
ROLE.flashlight = true
ROLE.models = {"models/murdered/pm/t_grunts.mdl"}
ROLE.male = true

ROLE.langName = "rioter"
ROLE.color = Color(180, 80, 80)
ROLE.desc = "rioter_desc"

ROLE.onSpawn = function(ply)
    ply:GiveWeapon(table.Random(MuR.WeaponsTable["Melee"]).class)
    ply:GiveWeapon("mur_loot_ducttape")
    ply:SetNW2Float("ArrestState", 1)
    local armor = math.random(1,3) == 1 and "pot" or math.random(1,3) == 1 and "helmet" or math.random(1,3) == 1 and "gasmask" or ""
    timer.Simple(1, function()
        if !IsValid(ply) or armor == "" then return end
        ply:EquipArmor(armor)
    end)
end

MuR:RegisterRole(ROLE)
