local ROLE = {}

ROLE.name = "PMCSoldier"
ROLE.team = 1
ROLE.flashlight = true
ROLE.models = {
	"models/murdered/pm/pmc/male_01.mdl", "models/murdered/pm/pmc/male_02.mdl",
	"models/murdered/pm/pmc/male_03.mdl", "models/murdered/pm/pmc/male_04.mdl",
	"models/murdered/pm/pmc/male_05.mdl", "models/murdered/pm/pmc/male_06.mdl",
	"models/murdered/pm/pmc/male_07.mdl", "models/murdered/pm/pmc/male_08.mdl",
	"models/murdered/pm/pmc/male_09.mdl"
}
ROLE.male = true

ROLE.langName = "pmc_soldier"
ROLE.color = Color(150, 150, 150)
ROLE.desc = "pmc_soldier_desc"

ROLE.onSpawn = function(ply)
	ply.RandomSkinDisabled = true

	ply:GiveWeapon("mur_radio")
	ply:GiveWeapon("mur_loot_bandage")
	ply:GiveWeapon("mur_loot_tourniquet")
	ply:GiveWeapon("mur_morphine")
	ply:GiveWeapon("tfa_bs_combk")
	ply:GiveWeapon("tfa_bs_walther")
	ply:GiveAmmo(30, "pistol", true)

	timer.Simple(1, function()
		if not IsValid(ply) then return end
		ply:EquipArmor("classII_armor")
		ply:SetBodygroup(2, 3)
	end)
end

MuR:RegisterRole(ROLE)
