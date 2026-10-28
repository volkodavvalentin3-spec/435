local ROLE = {}

ROLE.name = "Riot"
ROLE.team = 3
ROLE.flashlight = true
ROLE.models = {"models/murdered/pm/css_swat.mdl"}
ROLE.male = true
ROLE.group = "police"

ROLE.langName = "riotpolice"
ROLE.color = Color(25, 25, 255)
ROLE.desc = "riotpolice_desc"

ROLE.onSpawn = function(ply)
    local weapons = {"mur_taser", "mur_handcuffs", "mur_pepperspray", "mur_baterringram", "tfa_bs_baton", "mur_flashbang", "mur_radio"}
    for _, wep in pairs(weapons) do ply:GiveWeapon(wep, _ == 2 or _ == 4) end

    ply.RandomSkinDisabled = true
    timer.Simple(1, function()
        if !IsValid(ply) then return end
        ply:EquipArmor("classII_police")
        ply:EquipArmor("helmet_riot")
    end)
end

MuR:RegisterRole(ROLE)
