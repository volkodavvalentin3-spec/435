local ROLE = {}

ROLE.name = "ArmoredOfficer"
ROLE.team = 3
ROLE.flashlight = true
ROLE.models = {"models/murdered/pm/css_swat.mdl"}
ROLE.male = true
ROLE.group = "police"

ROLE.langName = "swat"
ROLE.color = Color(25, 25, 255)
ROLE.desc = "swat_desc"

ROLE.onSpawn = function(ply)
    if math.random(1,6) == 1 then
        ply:GiveWeapon("tfa_bs_m1014")
        ply:GiveAmmo(35, "Buckshot", true)
    elseif math.random(1,4) == 1 then
        ply:GiveWeapon("tfa_bs_acr")
        ply:GiveAmmo(120, "SMG1", true)
    else
        ply:GiveWeapon("tfa_bs_m4a1")
        ply:GiveAmmo(120, "SMG1", true)
    end

    ply:GiveWeapon("tfa_bs_glock")
    ply:GiveWeapon("mur_radio")

    local weapons = {"mur_taser", "mur_handcuffs", "mur_baterringram", "mur_doorlooker",
                    "tfa_bs_baton", "mur_loot_bandage", "mur_flashbang"}
    for _, wep in pairs(weapons) do ply:GiveWeapon(wep, _ == 2 or _ == 3) end

    ply:GiveAmmo(51, "Pistol", true)
    ply:GiveAmmo(2, "GaussEnergy", true)
    ply.RandomSkinDisabled = true

    local mode = MuR.Mode(MuR.Gamemode)
    if mode and mode.armored_officer_heist_logic then
        ply:SetTeam(2)
        timer.Simple(0.01, function()
            if IsValid(ply) and MuR.PoliceState != 6 then ply:KillSilent() end
            ply.SpectateMode = 0
        end)
    elseif mode and mode.armored_officer_raid_logic then
        ply:SetTeam(2)
        ply:SetNoTarget(true)
        ply:GiveWeapon("mur_loot_medkit")
        ply:GiveWeapon("mur_loot_adrenaline")
        ply:SetWalkSpeed(65)
        ply:SetRunSpeed(130)
        timer.Simple(20, function()
            if !IsValid(ply) or !ply:Alive() then return end
            ply:SetNoTarget(false)
        end)
    end

    timer.Simple(1, function()
        if !IsValid(ply) then return end
        ply:EquipArmor("classIII_police")
        ply:EquipArmor("helmet_ulach")
    end)
end

MuR:RegisterRole(ROLE)
