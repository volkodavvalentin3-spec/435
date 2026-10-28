local ROLE = {}

ROLE.name = "Zombie"
ROLE.team = 2
ROLE.flashlight = false
ROLE.models = {"models/murdered/pm/zombie/zombie_male_01.mdl", "models/murdered/pm/zombie/zombie_male_02.mdl", "models/murdered/pm/zombie/zombie_male_03.mdl", "models/murdered/pm/zombie/zombie_male_04.mdl", "models/murdered/pm/zombie/zombie_male_05.mdl", "models/murdered/pm/zombie/zombie_male_06.mdl", "models/murdered/pm/zombie/zombie_male_07.mdl", "models/murdered/pm/zombie/zombie_male_08.mdl", "models/murdered/pm/zombie/zombie_male_09.mdl"}

ROLE.langName = "zombie"
ROLE.color = Color(80, 0, 0)
ROLE.desc = "zombie_desc"

ROLE.onSpawn = function(ply)
    timer.Simple(0.01, function()
        if IsValid(ply) then ply:StripWeapon("mur_hands") end
    end)

    ply:GiveWeapon("mur_zombie", true)

    ply:SetNW2Bool("MuR.PatientZero", ply.MuR_PatientZero == true)

    if ply.MuR_PatientZero then
        ply:SetMaxHealth(250)
        ply:SetHealth(250)
        ply:SetRunSpeed(330)
        ply:SetWalkSpeed(200)
        ply:SetJumpPower(420)

        timer.Simple(1.1, function()
            if not IsValid(ply) or not ply:Alive() then return end
            if not ply.MuR_PatientZero then return end
            ply:SetColor(Color(190, 120, 120, 255))
        end)
    else
        ply:SetRunSpeed(260)
        ply:SetWalkSpeed(160)
        ply:SetJumpPower(320)
    end
end

MuR:RegisterRole(ROLE)
