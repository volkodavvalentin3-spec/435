MuR.Modes = MuR.Modes or {}

MuR.DefaultRoles = {
	{class = "Medic", odds = 3, min_players = 5, per_players = 9, max = 3},
	{class = "Builder", odds = 3, min_players = 5, per_players = 14, max = 2},
	{class = "HeadHunter", odds = 4, min_players = 6, per_players = 12, max = 2},
	{class = "Criminal", odds = 5, min_players = 6, per_players = 10, max = 2},
	{class = "Security", odds = 3, min_players = 6, per_players = 10, max = 2},
	{class = "Witness", odds = 3, min_players = 6, per_players = 8, max = 3},
	{class = "Officer", odds = 8, min_players = 7, per_players = 8, max = 3},
	{class = "FBI", odds = 8, min_players = 7, per_players = 10, max = 2}
}

function MuR.RegisterMode(id, def)
	MuR.Modes[id] = def or {}
	if MuR.RebuildGamemodeChances then
		MuR:RebuildGamemodeChances()
	end
end

function MuR.Mode(id)
	return MuR.Modes[id] or {}
end

function MuR:RebuildGamemodeChances()
	local t = {}
	for id, def in pairs(MuR.Modes) do
		if def.enabled ~= false then
			t[id] = {chance = def.chance or 0, need_players = def.need_players or 1}
		end
	end
	MuR.GamemodeChances = t
end
