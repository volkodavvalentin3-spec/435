local ROLE = {}

ROLE.name = "Shooter"
ROLE.team = 1
ROLE.flashlight = true
ROLE.models = {"models/murdered/pm/hatred_mh.mdl"}
ROLE.male = true
ROLE.killer = "active"

ROLE.langName = "shooter"
ROLE.color = Color(150, 10, 10)
ROLE.desc = "shooter_desc"

ROLE.onSpawn = function(ply)
    ply:SetArmor(100)

    local pri, sec = table.Random(MuR.WeaponsTable["Primary"]), table.Random(MuR.WeaponsTable["Secondary"])
    ply:GiveWeapon(pri.class)
    ply:GiveAmmo(pri.count * 4, pri.ammo, true)
    ply:GiveWeapon(sec.class)
    ply:GiveAmmo(sec.count * 2, sec.ammo, true)
    ply:GiveWeapon("tfa_bs_combk")
    ply:GiveWeapon(math.random(0,1) == 1 and "mur_m67" or "mur_f1")
    ply:GiveWeapon("mur_scanner", true)

    ply:SetWalkSpeed(80)
    ply:SetRunSpeed(240)
    ply:SetNW2Float("ArrestState", 1)

    timer.Simple(2, function()
        if IsValid(ply) and ply:Alive() then ply:PlayVoiceLine("shooter_intro", true) end
    end)
end

MuR:RegisterRole(ROLE)
