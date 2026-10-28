MuR.RegisterMode(21, {
	name = "Hotline Miami",
	chance = 10,
	need_players = 2,
	custom_spawning = true,
	kteam = "Tony",
	dteam = "Mafia",
	iteam = "Mafia",
	disables_police = true,
    no_guilt = true,
    disables = true,
    disable_loot = true,
    timer = 360,

	spawn_type = "tdm",
	win_condition = "tdm",
	kteam_count = 1,
	tdm_end_logic = true,
	win_screen_team1 = "tony",
	win_screen_team2 = "mafia",

	OnModeStarted = function(mode)
		if SERVER then
			MuR.Mode21 = {}
		end
	end,

	OnModeThink = function(mode)
		if SERVER then
			for _, ply in player.Iterator() do
				if ply:GetNW2String("Class") == "Tony" then
					ply:SetNW2Float("Stamina", 100)
					ply.BleedTime = 0
				end
			end
		end
	end,

	OnModeEnded = function(mode)
		if SERVER then
			MuR.Mode21 = nil
		end
	end
})
