MuR.RegisterMode(13, {
	name = "Police Raid",
	chance = 25,
	need_players = 4,
	disables = true,
	no_default_roles = true,
	win_condition = "heist",
	custom_spawning = true,
	police_reinforcements = true,
	no_npc_police_spawn = true,
	armored_officer_heist_logic = true,
	no_guilt = true,
	timer = 600,
	kteam = "Criminal",
	dteam = "ArmoredOfficer"
})
