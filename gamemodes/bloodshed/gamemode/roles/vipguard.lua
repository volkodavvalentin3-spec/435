local ROLE = {}

ROLE.name = "VIPGuard"
ROLE.team = 2
ROLE.flashlight = false
ROLE.models = {"models/murdered/pm/sf/guard_01.mdl", "models/murdered/pm/sf/guard_02.mdl", "models/murdered/pm/sf/guard_03.mdl", "models/murdered/pm/sf/guard_04.mdl", "models/murdered/pm/sf/guard_05.mdl", "models/murdered/pm/sf/guard_06.mdl", "models/murdered/pm/sf/guard_07.mdl", "models/murdered/pm/sf/guard_08.mdl", "models/murdered/pm/sf/guard_09.mdl"}
ROLE.male = true

ROLE.langName = "vipguard"
ROLE.color = Color(25, 25, 255)
ROLE.desc = "vipguard_desc"

ROLE.onSpawn = function(ply)
    ply:GiveWeapon("mur_taser")
    ply:GiveWeapon("tfa_bs_baton")
    ply:GiveWeapon("mur_radio")
    ply:GiveAmmo(3, "GaussEnergy", true)

    timer.Simple(1, function()
        if not IsValid(ply) then return end
        ply:EquipArmor("classI_armor")

        ply:SetArmorHidden("body", true)
    end)
end

MuR:RegisterRole(ROLE)
