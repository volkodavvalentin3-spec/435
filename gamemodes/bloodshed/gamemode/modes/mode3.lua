MuR.RegisterMode(3, {
	name = "Maniac",
	chance = 40,
	need_players = 2,
	disable_loot = true,
	dispatch = "maniac",
	police_call_mult = 0.5,
	call_police_on_think = true,
	killer_spawn_far = true,
	delayed_killer_spawn = 20,
	kteam = "Maniac",
	dteam = "Innocent",
	iteam = "Innocent",
	roles = MuR.DefaultRoles
})
