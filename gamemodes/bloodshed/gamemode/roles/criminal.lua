local ROLE = {}

ROLE.name = "Criminal"
ROLE.team = 2
ROLE.flashlight = false

ROLE.langName = "criminal"
ROLE.color = Color(255, 120, 60)
ROLE.desc = "criminal_desc"

ROLE.onSpawn = function(ply)
    ply:SetNW2Float("ArrestState", 1)
    ply:GiveWeapon("tfa_bs_knife")
    ply:GiveWeapon("mur_ziptie")

    if MuR.Gamemode == 13 then
        ply:SetNW2Float("ArrestState", 2)
        ply:SetTeam(1)
        local pri = table.Random(MuR.WeaponsTable["Secondary"])
        ply:GiveWeapon(pri.class)
        ply:GiveAmmo(pri.count * 6, pri.ammo, true)
    else
        ply:GiveWeapon("tfa_bs_izh43sw")
    end
end

MuR:RegisterRole(ROLE)
