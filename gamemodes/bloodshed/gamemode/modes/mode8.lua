MuR.RegisterMode(8, {
	name = "VIP Protection",
	chance = 40,
	need_players = 4,

	kteam = "Traitor",
	iteam = "Innocent",

	traitor_ratio = true,

	custom_spawning = true,
	custom_spawning_func = "Mode8SpawnPlayers",

	win_condition = "vip",
	win_screen_team1 = "vip_dead",
	win_screen_team2 = "vip_saved",

	guard_ratio = 0.25,

	roles = {
		{class = "Medic", odds = 3, min_players = 6},
		{class = "Builder", odds = 4, min_players = 7},
		{class = "HeadHunter", odds = 5, min_players = 8},
		{class = "Criminal", odds = 5, min_players = 8},
		{class = "Witness", odds = 4, min_players = 7}
	}
})

if not SERVER then return end

local function aliveInVIPMode(ply)
	return ply:Alive()
end

function MuR:Mode8VIPAlive()
	for _, ply in player.Iterator() do
		if ply:GetNW2String("Class") == "VIP" and aliveInVIPMode(ply) then
			return true
		end
	end

	return false
end

function MuR:Mode8TraitorsAlive()
	local count = 0

	for _, ply in player.Iterator() do
		if ply:Team() == 1 and aliveInVIPMode(ply) then
			count = count + 1
		end
	end

	return count
end

local GUARD_SPAWN_RADIUS = 420

local function guardPositionsNear(basePos, count)
	local out = {}
	if not isvector(basePos) or count <= 0 then return out end

	local candidates = {}
	local nodes = MuR.AI_Nodes or {}

	for i = 1, #nodes do
		local pos = nodes[i].pos
		local distSqr = basePos:DistToSqr(pos)

		if distSqr <= GUARD_SPAWN_RADIUS * GUARD_SPAWN_RADIUS then
			local tr = util.TraceHull({
				start = pos + Vector(0, 0, 2),
				endpos = pos + Vector(0, 0, 2),
				mins = Vector(-16, -16, 0),
				maxs = Vector(16, 16, 72),
				mask = MASK_SHOT_HULL
			})

			if not tr.Hit then
				candidates[#candidates + 1] = {pos = pos, dist = distSqr}
			end
		end
	end

	table.SortByMember(candidates, "dist", true)

	for i = 1, count do
		if candidates[i] then out[i] = candidates[i].pos end
	end

	for i = 1, count do
		if not out[i] then
			local angle = (i / count) * math.pi * 2
			local offset = Vector(math.cos(angle), math.sin(angle), 0) * 90

			local drop = util.TraceLine({
				start = basePos + offset + Vector(0, 0, 40),
				endpos = basePos + offset - Vector(0, 0, 200),
				mask = MASK_SOLID_BRUSHONLY
			})

			out[i] = drop.Hit and (drop.HitPos + Vector(0, 0, 4)) or basePos
		end
	end

	return out
end

function MuR:Mode8SpawnPlayers()
	if MuR.Gamemode ~= 8 then return end

	local modeDef = MuR.Mode(8)

	local pool = {}
	for _, ply in player.Iterator() do
		pool[#pool + 1] = ply
	end

	if #pool < 2 then return end

	table.Shuffle(pool)

	local total = #pool
	local assigned = {}

	local function assign(ply, class, teamNum)
		assigned[ply] = true
		ply:SetNW2String("Class", class)
		ply:SetTeam(teamNum)

		ply.ForceSpawn = true
		ply:Spawn()
		ply:Freeze(true)
		ply:GodEnable()

		timer.Simple(12, function()
			if IsValid(ply) then
				ply:Freeze(false)
				ply:GodDisable()
			end
		end)
	end

	local function takeRandom()
		for i = 1, #pool do
			if not assigned[pool[i]] then
				return table.remove(pool, i)
			end
		end
	end

	local traitorCount = MuR:GetTraitorCount(modeDef, total)

	for _ = 1, traitorCount do
		if #pool <= 1 then break end

		local picked = MuR.TakeDesignatedTraitor and select(1, MuR.TakeDesignatedTraitor(pool))
		if picked then
			table.RemoveByValue(pool, picked)
		else
			picked = takeRandom()
		end

		if not picked then break end
		assign(picked, "Traitor", 1)
	end

	MuR.NextTraitors = {}

	local vip = takeRandom()
	if vip then assign(vip, "VIP", 2) end

	local guards = math.floor(total * (modeDef.guard_ratio or 0.25))
	guards = math.Clamp(guards, total >= 4 and 1 or 0, math.max(#pool, 0))

	local detail = {}

	for _ = 1, guards do
		local guard = takeRandom()
		if not guard then break end
		assign(guard, "VIPGuard", 2)
		detail[#detail + 1] = guard
	end

	if IsValid(vip) and #detail > 0 then
		timer.Simple(1, function()
			if not IsValid(vip) or not vip:Alive() then return end

			local spots = guardPositionsNear(vip:GetPos(), #detail)

			for i, guard in ipairs(detail) do
				if IsValid(guard) and guard:Alive() and isvector(spots[i]) then
					guard:SetPos(spots[i])
				end
			end
		end)
	end

	while true do
		local ply = takeRandom()
		if not ply then break end
		assign(ply, "Innocent", 2)
	end
end
