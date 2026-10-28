MuR.RegisterMode(2, {
	name = "Shooter",
	chance = 40,
	need_players = 2,
	disable_loot = true,
	dispatch = "shooter",
	police_call_mult = 0.5,
	call_police_on_think = true,
	officer_always_badger = true,
	killer_spawn_far = true,
	delayed_killer_spawn = 30,
	kteam = "Shooter",
	dteam = "Innocent",
	iteam = "Innocent",
	roles = MuR.DefaultRoles
})
