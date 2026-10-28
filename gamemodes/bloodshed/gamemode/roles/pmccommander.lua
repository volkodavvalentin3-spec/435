local ROLE = {}

ROLE.name = "PMCCommander"
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

ROLE.langName = "pmc_commander"
ROLE.color = Color(200, 150, 50)
ROLE.desc = "pmc_commander_desc"

ROLE.onSpawn = function(ply)
	ply.RandomSkinDisabled = true

	local soldierRole = MuR:GetRole("Soldier")
	if soldierRole and soldierRole.onSpawn then
		soldierRole.onSpawn(ply)
	end

	ply:GiveWeapon("mur_m67")
	ply:GiveWeapon("mur_loot_medkit")

	timer.Simple(1.2, function()
		if not IsValid(ply) then return end
		ply:EquipArmor("classIII_armor")
		ply:EquipArmor("helmet_ulach")
		ply:SetBodygroup(2, 3)
	end)
end

MuR:RegisterRole(ROLE)
