MuR.RegisterMode(10, {
	name = "Terrorist",
	chance = 30,
	need_players = 5,
	is_swat = true,
	disable_loot = true,
	dispatch = "terrorist",
	police_call_mult = 0.5,
	multi_traitor = true,
	call_police_on_think = true,
	multi_traitor_scale = true,
	killer_spawn_far = true,
	delayed_killer_spawn = 40,
	kteam = "Terrorist",
	dteam = "Officer",
	roles = MuR.DefaultRoles
})
