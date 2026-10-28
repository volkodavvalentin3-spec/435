MuR.RegisterMode(25, {
	name = "Police Department",
	chance = 15,
	need_players = 5,
	disables = true,
	no_default_roles = true,
	no_guilt = true,

	police_swat_only = true,
	killer_sanity_mul = 0.4,
	no_wanted_until_assault = true,

	win_condition = "tdm",
	tdm_end_logic = true,
	win_screen_team1 = "traitors_win",
	win_screen_team2 = "police_win",

	kteam = "Traitor",
	dteam = "Officer",
	iteam = "Officer",
	multi_traitor = true,
	multi_traitor_scale = true,

	OnModeStarted = function(mode)
		if SERVER then
			local ARRIVE_MIN, ARRIVE_JITTER = 240, 90
			MuR.PoliceState = 3
			MuR:SetPoliceTime(ARRIVE_MIN + math.random(0, ARRIVE_JITTER), true)
			MuR:PlayDispatch("raidstart")
			MuR:RollEarlyOfficers()
		end
	end
})

if SERVER then
	function MuR.Mode25GiveOfficerCover(ply)
		local role = MuR:GetRole("Officer")
		if not role then return end

		if istable(role.models) then
			local mdl = table.Random(role.models)
			if isstring(mdl) and util.IsValidModel(mdl) then
				ply:SetModel(mdl)
			end
		end

		ply.RandomSkinDisabled = true

		ply:GiveWeapon("tfa_bs_glock")
		ply:GiveWeapon("mur_radio")
		ply:GiveWeapon("mur_taser")
		ply:GiveWeapon("mur_pepperspray")
		ply:GiveWeapon("mur_handcuffs")
		ply:GiveWeapon("tfa_bs_baton")
		ply:GiveWeapon("mur_loot_bandage")

		ply:GiveAmmo(51, "Pistol", true)
		ply:GiveAmmo(3, "GaussEnergy", true)

		timer.Simple(1, function()
			if not IsValid(ply) then return end
			ply:EquipArmor("classII_police")
			ply:SetBodygroup(5, 0)
		end)
	end
end
