MuR.GameStarted = true
MuR.Delay_Before_Lose = 0
MuR.Gamemode = 1

function MuR:AssignSupportRoles(tab, roles)
	local total = player.GetCount()

	for _, r in ipairs(roles) do
		local rname = r.class or r.name
		if not rname then continue end

		local minp = math.max(0, tonumber(r.min_players) or 0)
		if total < minp then continue end

		local odds = math.max(1, tonumber(r.odds) or 1)
		local count = math.max(1, tonumber(r.count) or 1)

		local perPlayers = tonumber(r.per_players)
		if perPlayers and perPlayers > 0 then
			count = count + math.floor(math.max(0, total - minp) / perPlayers)
		end

		local maxCount = tonumber(r.max)
		if maxCount then count = math.min(count, maxCount) end

		for i = 1, count do
			if #tab <= 1 then break end
			if math.random(1, odds) != 1 then continue end

			local ply = table.remove(tab, math.random(1, #tab))
			ply:SetNW2String("Class", rname)
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
	end
end
MuR.PoliceState = 0
MuR.SniperArrived = false
MuR.SniperSettings = {30,40, 15,75}
MuR.HeliArrived = false
MuR.HeliSettings = {15,25, 35,40}
MuR.PoliceArriveTime = 0
MuR.PoliceDelaySpawn = 0
MuR.EarlyOfficers = nil
MuR.TimeCount = 0
MuR.SecuritySpawned = false
MuR.TeamAssign = false
MuR.TeamAssignDelay = 30
MuR.NextGamemode = 0
MuR.NextTraitors = MuR.NextTraitors or {}

local function takeDesignatedTraitor(pool)
	local queue = MuR.NextTraitors
	if not istable(queue) then return nil end

	while #queue > 0 do
		local ply = table.remove(queue, 1)
		if IsValid(ply) then
			local id = table.KeyFromValue(pool, ply)
			if id then return ply, id end
		end
	end

	return nil
end

MuR.TakeDesignatedTraitor = takeDesignatedTraitor

local cvTraitorsPer = CreateConVar("blsd_players_per_traitor", "8",
	{FCVAR_ARCHIVE, FCVAR_NOTIFY},
	"One killer is assigned per this many players in modes that scale by headcount.")

local cvEarlyOfficersChance = CreateConVar("blsd_early_officers_chance", "0.5",
	{FCVAR_ARCHIVE, FCVAR_NOTIFY},
	"Chance that killed players return as officers before the police arrival timer ends.")

local cvEarlyOfficersOnline = CreateConVar("blsd_early_officers_online", "9",
	{FCVAR_ARCHIVE, FCVAR_NOTIFY},
	"Online count from which two early officers respond instead of one.")

local EARLY_OFFICER_MIN_FRAC, EARLY_OFFICER_MAX_FRAC = 0.4, 0.7
local EARLY_OFFICER_MIN_TIME = 45
local EARLY_OFFICER_DEATH_GRACE = 5

local TRAITOR_SHARE_CAP = 1 / 3

--
-- Сколько предателей на такой онлайн.
--
-- Округление ВВЕРХ, а не вниз, и это принципиально. С округлением вниз конвар
-- со значением 8 давал второго предателя только на шестнадцатом игроке: на
-- десяти выходило floor(10/8) = 1, то есть один предатель на десятерых —
-- ровно то, на что и жаловались, «конвар будто не работает».
--
-- Вверх это читается так, как написано в описании конвара: каждые N игроков
-- (или их начатая часть) добавляют предателя. 8 -> 1, 9 -> 2, 17 -> 3.
--
-- Потолок в треть состава остаётся: он и защищает от того, чтобы маленькая
-- игра превратилась в предателей против одного мирного.
--
function MuR:GetTraitorCount(modeDef, playerCount)
	if not modeDef or not modeDef.traitor_ratio then return 1 end

	local per = math.max(cvTraitorsPer:GetInt(), 1)
	local count = math.ceil(playerCount / per)

	return math.Clamp(count, 1, math.max(math.floor(playerCount * TRAITOR_SHARE_CAP), 1))
end
MuR.Ending = false
MuR.TimeBeforeStart = 0
MuR.NPC_To_Spawn = 0
MuR.VoteLog = 0
MuR.VoteAllowed = false
MuR.VoteLogDeadPolice = 0
MuR.GunShots = 0
MuR.TimerEndTime = 0
MuR.TimerActive = false
MuR.ExperimentWeapon = nil
MuR.DefaultSkyname = MuR.DefaultSkyname or ""
MuR.WeaponsTable = MuR.WeaponsTable or MuR:GenerateWeaponsTable()
MuR.LootMinDistance = MuR.LootMinDistance or 160
MuR.MaxLootRetries = MuR.MaxLootRetries or 8
MuR.LootSpawnPositions = MuR.LootSpawnPositions or {}
MuR.LootSpawnInterval = MuR.LootSpawnInterval or 0.25
MuR.LootSpawnBatch = MuR.LootSpawnBatch or 1
MuR.LootSpawnInitialDelay = MuR.LootSpawnInitialDelay or 4
MuR.LogTable = {
	dead = {},
	dead_cops = {},
	injured = {},
	heavy_injured = {},
}

hook.Add("InitPostEntity", "MuR.InitPostEntity", function()
	MuR.DefaultSkyname = GetConVar("sv_skyname"):GetString()
	MuR.WeaponsTable = MuR:GenerateWeaponsTable()

	-- TFA регистрирует оружие позже InitPostEntity: перепроверяем таблицу чуть позже.
	timer.Simple(5, function() MuR:EnsureWeaponsTable() end)
end)

function MuR:RemoveMapLogic()
	for _, ent in ents.Iterator() do
		if MuR.IsAI(ent) or ent:IsWeapon() then
			ent:Remove()
		end
	end
end

function MuR:ReplaceMapProps()
	for _, ent in ipairs(ents.FindByClass("prop_*")) do
		local model = ent:GetModel()
		local replaceWith = MuR.EntityReplaceMapModel[model]
		if not replaceWith then continue end

		local phys = ent:GetPhysicsObject()
		if IsValid(phys) and phys:IsMotionEnabled() then
			local pos = ent:GetPos()
			local ang = ent:GetAngles()
			ent:Remove()

			if string.StartWith(replaceWith, "mur_armor_") then
				local armorId = string.sub(replaceWith, 11)
				MuR:SpawnArmorPickup(pos, armorId)
			else
				local newEnt = ents.Create(replaceWith)
				if IsValid(newEnt) then
					newEnt:SetPos(pos)
					newEnt:SetAngles(ang)
					newEnt:Spawn()
				end
			end
		end
	end
end

function MuR:SpawnZone()
	if MuR.Gamemode != -1 then return end
	timer.Simple(2, function()
		local ply = GetRandomPlayer()
		if IsValid(ply) then
			local ent = ents.Create("bloodshed_zone")
			ent:SetPos(ply:GetPos())
			ent:Spawn()
		end
	end)
end

function MuR:GiveRandomTableWithChance(tab, extra)
    local filtered = {}
    for idx, subtable in pairs(tab) do
        if not isfunction(extra) or extra(subtable) == true then
            table.insert(filtered, {orig_idx = idx, data = subtable})
        end
    end

    if #filtered == 0 then return end

    local totalChance = 0
    for _, v in ipairs(filtered) do
        totalChance = totalChance + (v.data.chance or 0)
    end

    if totalChance == 0 then return end

    local randomValue = math.random(totalChance)
    local currentChance = 0
    for _, v in ipairs(filtered) do
        currentChance = currentChance + (v.data.chance or 0)
        if randomValue <= currentChance then
            return v.data, v.orig_idx
        end
    end
end

local probabilities = {
	{chance = 1/50, value = function() return 6 end},
	{chance = 1/40, value = function() return 5 end},
	{chance = 1/30, value = function() return 4 end},
    {chance = 1/25, value = function() return 3 end},
    {chance = 1/16, value = function() return 2 end},
    {chance = 1/8, value = function() return 1 end},
}

function MuR:GetLootSpawnCount()
	local maxLoot = MuR.MaxLootNumber or 100
	local pcount = math.max(1, player.GetCount())
	local scaled = math.floor(20 + (pcount * 4))
	return math.Clamp(scaled, 20, maxLoot)
end

function MuR:MakeLootableProps()
	for _, ent in ipairs(ents.FindByClass("prop_*")) do
		if istable(ent.Inventory) then continue end

		ent.Inventory = {}
		local add = 0
		for _, p in ipairs(probabilities) do
			if math.Rand(0,1) < p.chance then
				add = p.value()
				break
			end
		end
		for i=1,add do
			local loot = MuR:GiveRandomTableWithChance(MuR.Loot)
			if not (MuR:DisableWeaponLoot() and (string.find(loot.class, "tfa_bs_") or loot.class == "mur_pepperspray")) then
				table.insert(ent.Inventory, loot.class)
			end
		end
	end
end

function MuR:ChangeStateOfGame(state)
	game.CleanUpMap()

	if state then
		MuR.LootSpawnPositions = {}
		MuR.LootPointQueue = nil
		MuR.LootToSpawn = 0
		MuR.LootSpawnStartTime = 0
		local prev = MuR.Mode and MuR.Mode(MuR.Gamemode) or {}

		--
		-- Раунд начался: расставленные точки снова свободны, и командам заново
		-- бросается монетка, какой набор чей. Без сброса занятости второй раунд
		-- подряд считал бы все спавны занятыми и уходил на навмеш.
		--
		MuR:ResetSpawnTaken()
		MuR:RollTeamSpawnSwap()

		MuR:EnsureWeaponsTable()

		hook.Call("MuR.GameState", nil, true)
		MuR.GameStarted = true
		MuR.TimeCount = CurTime()

		local gm_tbl, gm_rnd = MuR:GiveRandomTableWithChance(MuR.GamemodeChances, function(v) return player.GetCount() >= v.need_players end)
		if not gm_rnd then
			gm_tbl, gm_rnd = MuR:GiveRandomTableWithChance(MuR.GamemodeChances)
		end
		MuR.Gamemode = gm_rnd or 1

		if MuR.EnableDebug then
			MuR.Gamemode = 5
		elseif MuR.NextGamemode > 0 then
			MuR.Gamemode = MuR.NextGamemode
			MuR.NextGamemode = 0
		end

		MuR:RemoveMapLogic()
		MuR:ExecuteString("decals")

		local mode = MuR.Mode and MuR.Mode(MuR.Gamemode) or {}
		if isfunction(mode.OnModeStarted) then
			mode.OnModeStarted(MuR.Gamemode)
		end

		if not MuR:DisablesGamemode() then
			MuR.LootToSpawn = MuR:GetLootSpawnCount()
			MuR.LootSpawnStartTime = CurTime() + (MuR.LootSpawnInitialDelay or 4)

			--
			-- Точки вещей на этот раунд. Шанс каждой разыгран ОДИН раз здесь, а
			-- не при каждом обращении: иначе предмет то появлялся бы, то нет,
			-- между соседними тиками таймера.
			--
			-- Класс предмета по-прежнему выбирает MuR:SpawnLoot из MuR.Loot —
			-- точка отвечает только за место.
			--
			MuR.LootPointQueue = MuR:RollItemSpawns()
			timer.Create("MuRSpawnLoot", MuR.LootSpawnInterval or 0.25, 0, function()
				if not MuR.GameStarted then
					timer.Remove("MuRSpawnLoot")
					return
				end
				if CurTime() < (MuR.LootSpawnStartTime or 0) then return end
				if (MuR.LootToSpawn or 0) <= 0 then
					timer.Remove("MuRSpawnLoot")
					return
				end

				local batch = MuR.LootSpawnBatch or 1
				for i = 1, batch do
					if (MuR.LootToSpawn or 0) <= 0 then break end

					-- Сначала разбираем расставленные точки, дальше как раньше —
					-- случайными из навмеша.
					local queue = MuR.LootPointQueue
					local point = queue and table.remove(queue, 1) or nil

					MuR:SpawnLoot(point and point.pos or nil)
					MuR.LootToSpawn = MuR.LootToSpawn - 1
				end
			end)
		end

		timer.Simple(0.01, function()
			for _, ply in player.Iterator() do
				net.Start("MuR.StartScreen")
				net.WriteFloat(MuR.Gamemode)
				net.WriteString(ply:GetNW2String("Class"))
				net.Send(ply)
			end
			MuR:ReplaceMapProps()
		end)

		MuR:RandomizePlayers()

		local mode = MuR.Mode and MuR.Mode(MuR.Gamemode) or {}
		if mode.timer and mode.timer > 0 then
			MuR.TimerEndTime = CurTime() + mode.timer
			MuR.TimerActive = true
		else
			MuR.TimerActive = false
		end

		MuR:MakeDoorsBreakable()
		MuR:MakeLootableProps()
		MuR:SpawnZone()

		for _, ent in ents.Iterator() do
			if ent:IsWeapon() then
				ent:Remove()
			end

			if ent:IsPlayer() then
				ent:ChangeGuilt(-0.5)
			end
		end

		local mode = MuR.Mode and MuR.Mode(MuR.Gamemode) or {}
		if mode.countdown_on_start then
			timer.Simple(12, function() MuR:GiveCountdown(10) end)
		end
	else
		local mode = MuR.Mode and MuR.Mode(MuR.Gamemode) or {}
		timer.Remove("MuR_SpecialForcesHeli")
		timer.Remove("MuR_SpecialForcesSniper")
		timer.Remove("MuRSpawnLoot")
		MuR.PoliceState = 0
		MuR.EarlyOfficers = nil
		MuR.SniperArrived = false
		MuR.HeliArrived = false
		MuR:SetPoliceTime(0)
		MuR.NPC_To_Spawn = 0
		MuR.SecuritySpawned = false
		MuR.TeamAssign = false
		MuR.TeamAssignDelay = math.random(60, 300)
		MuR.Ending = false
		MuR.VoteLog = 0
		MuR.VoteAllowed = false
		MuR.VoteLogDeadPolice = 0
		MuR.GameStarted = false
		MuR.GunShots = 0
		MuR.TimerActive = false
		MuR.TimerEndTime = 0
		INFECTED_PLAYERS = {}
		MuR.LogTable = {
			dead = {},
			dead_cops = {},
			injured = {},
			heavy_injured = {},
		}
		hook.Call("MuR.GameState", nil, false)

		if isfunction(mode.OnModeEnded) then
			mode.OnModeEnded(MuR.Gamemode)
		end

		for _, ply in player.Iterator() do
			if ply:Alive() then
				ply:KillSilent()
			end
		end
	end
end

function MuR:SpawnPlayerPolice(assault)
	local mode = MuR.Mode and MuR.Mode(MuR.Gamemode) or {}
	if MuR.Gamemode == 17 or MuR.PoliceClasses.no_player_police or mode.no_player_police then return end
	local donthave = false
	for _, ply in player.Iterator() do
		if ply:Alive() or ply:Team() == 1 then continue end
		if math.random(1,2) == 1 and donthave and not assault then continue end

		donthave = true
		ply.ForceSpawn = true

		ply:SetNW2String("Class", MuR:PickPoliceClass(mode, assault))

		ply:Spawn()
		ply:ScreenFade(SCREENFADE.IN, color_black, 1, 1)

		-- Расставленные точки в приоритете, навмеш добирает остаток.
		local pos, ang = MuR:GetPlayerSpawnPos()
		MuR:PlaceAtSpawn(ply, pos, ang)

		MuR:GiveAnnounce("officer_spawn", ply)
	end
	if not donthave then
		local ply = table.Random(team.GetPlayers(2))
		if IsValid(ply) then
			ply.ForceSpawn = true

			ply:SetNW2String("Class", MuR:PickPoliceClass(mode, assault))

			ply:Spawn()
			ply:ScreenFade(SCREENFADE.IN, color_black, 1, 1)

			local pos, ang = MuR:GetPlayerSpawnPos()
			MuR:PlaceAtSpawn(ply, pos, ang)

			MuR:GiveAnnounce("officer_spawn", ply)
		end
	end
	for _, ply in player.Iterator() do
		if ply:IsKiller() and ply:CanBecomeWanted() and ply:GetNW2Float("ArrestState") < 1 then
			ply:SetNW2Float("ArrestState", 1)
		end
	end
end

function MuR:PickPoliceClass(mode, assault)
	if mode and mode.police_swat_only then return "SWAT" end
	if MuR.PoliceState == 4 or assault then return "ArmoredOfficer" end
	return "Officer"
end

function MuR:RollEarlyOfficers()
	MuR.EarlyOfficers = nil

	if MuR.EnableDebug then return end

	local mode = MuR.Mode(MuR.Gamemode)
	if not mode or MuR.Gamemode == 17 or MuR.PoliceClasses.no_player_police or mode.no_player_police then return end
	if math.random() > cvEarlyOfficersChance:GetFloat() then return end

	local remaining = MuR.PoliceArriveTime - CurTime()
	if remaining < EARLY_OFFICER_MIN_TIME then return end

	MuR.EarlyOfficers = {
		ArriveAt = CurTime() + remaining * math.Rand(EARLY_OFFICER_MIN_FRAC, EARLY_OFFICER_MAX_FRAC),
		NextTry = 0,
	}
end

function MuR:GetEarlyOfficerCandidates()
	local list = {}

	for _, ply in player.Iterator() do
		if not IsValid(ply) or ply:Alive() then continue end
		if ply:Team() == 1 then continue end
		if ply.DeathTime and CurTime() - ply.DeathTime < EARLY_OFFICER_DEATH_GRACE then continue end

		list[#list + 1] = ply
	end

	return list
end

function MuR:GetEarlyOfficerCount()
	if player.GetCount() >= cvEarlyOfficersOnline:GetInt() then return 2 end

	return 1
end

function MuR:SpawnEarlyOfficers()
	local mode = MuR.Mode(MuR.Gamemode)
	if not mode or MuR.Gamemode == 17 or MuR.PoliceClasses.no_player_police or mode.no_player_police then return false end

	local candidates = MuR:GetEarlyOfficerCandidates()
	if #candidates == 0 then return false end

	local class = MuR:PickPoliceClass(mode, MuR.PoliceState == 3)
	local count = MuR:GetEarlyOfficerCount()
	local spawned = 0

	while spawned < count and #candidates > 0 do
		local ply = table.remove(candidates, math.random(#candidates))
		if not IsValid(ply) or ply:Alive() then continue end

		ply.ForceSpawn = true
		ply:SetNW2String("Class", class)
		ply:Spawn()
		ply:ScreenFade(SCREENFADE.IN, color_black, 1, 1)

		local pos, ang = MuR:GetPlayerSpawnPos()
		MuR:PlaceAtSpawn(ply, pos, ang)

		MuR:GiveAnnounce("officer_spawn", ply)
		spawned = spawned + 1
	end

	if spawned <= 0 then return false end

	for _, ply in player.Iterator() do
		if ply:IsKiller() and ply:CanBecomeWanted() and ply:GetNW2Float("ArrestState") < 1 then
			ply:SetNW2Float("ArrestState", 1)
		end
	end

	return true
end

function MuR:SpawnLoot(pos)
	local pos2
	local attempts = MuR.MaxLootRetries or 8
	local basePos = pos

	local function IsLootPosBlocked(testPos)
		local minDist = MuR.LootMinDistance or 160
		local minDistSq = minDist * minDist
		local list = MuR.LootSpawnPositions
		if not istable(list) then return false end
		for i = 1, #list do
			local prev = list[i]
			if prev and prev:DistToSqr(testPos) < minDistSq then
				return true
			end
		end
		return false
	end

	while attempts > 0 do
		if not basePos then
			basePos = MuR:GetRandomPos(true)
			if not isvector(basePos) then return end
			pos2 = MuR:FindPositionInRadius(basePos, 256)
		else
			pos2 = basePos
		end

		if isvector(pos2) and not IsLootPosBlocked(pos2) then
			break
		end

		basePos = nil
		pos2 = nil
		attempts = attempts - 1
	end

	if isvector(pos2) then
		local loot = MuR:GiveRandomTableWithChance(MuR.Loot)
		if not loot then return end
		local class = loot.class
		local ent

		if string.StartWith(class, "mur_armor_") then
			local armorId = string.sub(class, 11)
			ent = MuR:SpawnArmorPickup(pos2, armorId)
			if IsValid(ent) then
				ent.MuR_IsLootSpawned = true
				if istable(MuR.LootSpawnPositions) then
					table.insert(MuR.LootSpawnPositions, pos2)
				end
			end
		else
			ent = ents.Create(class)

			if IsValid(ent) then
				ent:SetPos(pos2)
				ent:Spawn()

				if ent:IsWeapon() then
					if ent.ClipSize then
						ent.Primary.DefaultClip = 0

						if ent.ClipSize then
							ent:SetClip1(math.random(0, ent.ClipSize))
							ent:SetClip2(0)
						end
					end
					if MuR:DisableWeaponLoot() then
						ent:Remove()
						return
					end
				end

				if IsValid(ent) then
					ent.MuR_IsLootSpawned = true
					if istable(MuR.LootSpawnPositions) then
						table.insert(MuR.LootSpawnPositions, pos2)
					end
				end
			end
		end
	end
end

function MuR:MakeDoorsBreakable()
	for _, ent in ipairs(ents.FindByClass("*_door_*")) do
		local health = math.Clamp(math.floor(ent:OBBMaxs():Length() * 10), 10, 2500)
		ent:SetNW2Bool("BreakableThing", true)
		ent:SetMaxHealth(health)
		ent:SetHealth(health)
		ent.FixMaxHP = health
	end
end

local function CheckOtherReasons()
	local reason = false
	for _, ply in player.Iterator() do
		if ply:Health() <= 80 then
			reason = "assault"
		end
	end
	for _, rag in ipairs(ents.FindByClass("prop_ragdoll")) do
		if rag.IsDead and rag.IsDead == true and reason != "officer" then
			reason = "homicide"
		end
		if rag.IsPoliceCorpse then
			reason = "officer"
		end
	end
	return reason
end

function MuR:SetPoliceTime(val, wm)
	if wm then
		MuR.PoliceArriveTime = CurTime()+val
	else
		MuR.PoliceArriveTime = CurTime()+(val*1.5)
	end
end

function MuR:CallPolice(mult, reason)
	if not mult then
		mult = 1
	end

	local mode = MuR.Mode(MuR.Gamemode)
	local isswat = mode.is_swat
	if MuR.EnableDebug or MuR.PoliceState > 0 or not MuR.GameStarted or MuR:DisablesGamemode() or MuR.Ending or mode.disables_police then return false end

	if mode.police_call_mult then
		mult = mode.police_call_mult
	end
	if mode.police_time_mult then
		mult = mode.police_time_mult
	end

	if isswat then
		MuR:SetPoliceTime((120 + math.Rand(10,12) * player.GetCount()) * mult)
		MuR.PoliceState = 3
	else
		MuR:SetPoliceTime((120 + math.Rand(12,14) * player.GetCount()) * mult)
		MuR.PoliceState = 1
	end

	local disp = mode.dispatch
	if disp then
		MuR:PlayDispatch(disp)
	elseif reason then
		MuR:PlayDispatch(reason)
	elseif CheckOtherReasons() then
		MuR:PlayDispatch(CheckOtherReasons())
	else
		MuR:PlayDispatch("unknown")
	end

	MuR:CheckOtherForces()
	MuR:RollEarlyOfficers()

	return true
end

function MuR:ExfilPlayers(pos, dist)
	if not pos then
		pos = Vector(0,0,0)
	end
	if not dist then
		dist = 32000
	end
	for _, ply in player.Iterator() do
		local allow = ply:GetPos():Distance(pos) <= dist
		if !ply:IsKiller() and ply:GetNW2String("Class") != "Zombie" and ply:Alive() then
			if allow then
				ply:KillSilent()
				ply:SetNW2Float("DeathStatus", 4)
			else
				MuR.ForceKill(ply)
			end
		end
	end
end

function MuR:MakeTeamsInGame()
	local alive = {}
	for _, ply in player.Iterator() do
		if ply:Alive() then alive[#alive + 1] = ply end
	end

	if #alive < 2 then return end

	local function equipTraitor(ply)
		ply:SetNW2String("Class", "Traitor")
		ply:SetTeam(1)

		local sidearmPool = MuR.WeaponData and MuR.WeaponData["DefenderWeapons"]
		local sidearm = istable(sidearmPool) and table.Random(sidearmPool) or nil
		local gaveFallbackPistol = false

		if sidearm and sidearm.class then
			ply:GiveWeapon(sidearm.class)
			if sidearm.ammo and sidearm.ammo ~= "" and sidearm.count then
				ply:GiveAmmo(sidearm.count * 2, sidearm.ammo, true)
			end
		else
			ply:GiveWeapon("tfa_bs_m9")
			ply:GiveAmmo(30, "Pistol", true)
			gaveFallbackPistol = true
		end

		ply:AllowFlashlight(true)
		if not gaveFallbackPistol then
			ply:GiveAmmo(30, "Pistol", true)
		end

		ply:GiveWeapon("mur_combat_knife", true)
		ply:GiveWeapon("mur_disguise", true)
		ply:GiveWeapon("mur_scanner", true)

		MuR:GiveAnnounce("you_killer", ply)
	end

	local wanted = math.min(MuR:GetTraitorCount(MuR.Mode(MuR.Gamemode), #alive), #alive - 1)

	for _ = 1, math.max(wanted, 1) do
		if #alive <= 1 then break end

		local pickedPly, pickedId = takeDesignatedTraitor(alive)
		local id = pickedId or math.random(1, #alive)

		equipTraitor(table.remove(alive, id))
	end

	MuR.NextTraitors = {}

	if #alive > 0 then
		local ply = table.remove(alive, math.random(1, #alive))
		ply:SetNW2String("Class", "Defender")
		ply:GiveWeapon("tfa_bs_m9")
		MuR:GiveAnnounce("you_defender", ply)
	end
end

function MuR:ScheduleDelayedKillerSpawn(ply, delay)
	delay = math.max(tonumber(delay) or 30, 1)

	MuR.KillersAwaitingSpawn = (MuR.KillersAwaitingSpawn or 0) + 1

	local serial = MuR.RoundSerial or 0
	ply:SetNW2Bool("MuR.AwaitingKillerSpawn", true)
	ply:SetNW2Float("MuR.KillerSpawnAt", CurTime() + delay)

	timer.Simple(delay, function()
		if not IsValid(ply) or (MuR.RoundSerial or 0) != serial then
			if IsValid(ply) then
				ply:SetNW2Bool("MuR.AwaitingKillerSpawn", false)
			end
			MuR.KillersAwaitingSpawn = math.max((MuR.KillersAwaitingSpawn or 1) - 1, 0)
			return
		end

		local pos, spawnAng = MuR:GetPlayerSpawnPos()

		ply:SetNW2Bool("MuR.AwaitingKillerSpawn", false)
		MuR.KillersAwaitingSpawn = math.max((MuR.KillersAwaitingSpawn or 1) - 1, 0)

		if ply:Alive() or not MuR.GameStarted then return end

		ply.ForceSpawn = true
		ply:Spawn()

		if isvector(pos) then
			ply:SetPos(pos)
		end
	end)
end

function MuR:RandomizePlayers()
	MuR.RoundSerial = (MuR.RoundSerial or 0) + 1
	MuR.KillersAwaitingSpawn = 0

	local kteam, dteam, iteam = "Killer", "Defender", "Innocent"

	local modeDef = MuR.Mode(MuR.Gamemode)
	if isstring(modeDef.kteam) then kteam = modeDef.kteam end
	if isstring(modeDef.dteam) then dteam = modeDef.dteam end
	if isstring(modeDef.iteam) then iteam = modeDef.iteam end

	if modeDef.experiment_weapon then
		MuR.ExperimentWeapon = table.Random(MuR.ExperimentWeapons)
	end

	local tab = {}
	for _, ply in player.Iterator() do
		ply.MuR_PatientZero = nil
		table.insert(tab, ply)
	end

	if modeDef.soldier_spawning then
		for _, ply in ipairs(tab) do
			ply:SetNW2String("Class", "Soldier")
			ply:Spawn()
			ply:SetTeam(1)
			ply:Freeze(true)
			ply:GodEnable()
			timer.Simple(12, function()
				if IsValid(ply) then
					ply:Freeze(false)
					ply:GodDisable()
				end
			end)
		end
		return
	end

	if not modeDef.custom_spawning and modeDef.spawn_type != "tdm" then
		if #tab >= 2 then
			local id = math.random(1, #tab)
			local ply = tab[id]

			local pickedPly, pickedId = takeDesignatedTraitor(tab)
			if pickedPly then ply, id = pickedPly, pickedId end

			ply:SetNW2String("Class", kteam)
			if kteam == "Zombie" then ply.MuR_PatientZero = true end

			if modeDef.delayed_killer_spawn then
				MuR:ScheduleDelayedKillerSpawn(ply, modeDef.delayed_killer_spawn)
			else
				ply:Spawn()
				ply:Freeze(true)
				ply:GodEnable()

				if modeDef.killer_spawn_far then
					timer.Simple(1, function()
						if not IsValid(ply) or not ply:Alive() then return end
						local farPos = MuR:FindFarthestSpawnFromPlayers()
						if isvector(farPos) then
							ply:SetPos(farPos)
						end
					end)
				end

				timer.Simple(12, function()
					if not IsValid(ply) then return end
					ply:Freeze(false)
					ply:GodDisable()
				end)
			end

			table.remove(tab, id)

			if #tab > 0 then
				local id = math.random(1, #tab)
				local ply = tab[id]
				ply:SetNW2String("Class", dteam)
				ply:Spawn()
				ply:Freeze(true)
				ply:GodEnable()

				timer.Simple(12, function()
					if not IsValid(ply) then return end
					ply:Freeze(false)
					ply:GodDisable()
				end)

				table.remove(tab, id)
			end
		end

		local extraTraitors = 0

		if modeDef.traitor_ratio then
			extraTraitors = MuR:GetTraitorCount(modeDef, player.GetCount()) - 1
		elseif modeDef.multi_traitor then
			extraTraitors = 1
			if modeDef.multi_traitor_scale then
				local pCount = player.GetCount()
				if pCount <= 8 then
					extraTraitors = 1
				elseif pCount <= 12 then
					extraTraitors = 2
				else
					extraTraitors = 3
				end
			end
		end

		if #tab >= 1 and extraTraitors > 0 then
			local count = extraTraitors
			for i = 1, count do
				if #tab >= 1 then
					local id = math.random(1, #tab)
					local ply = tab[id]

					local pickedPly, pickedId = takeDesignatedTraitor(tab)
					if pickedPly then ply, id = pickedPly, pickedId end

					ply:SetNW2String("Class", kteam)

					if modeDef.delayed_killer_spawn then
						MuR:ScheduleDelayedKillerSpawn(ply, modeDef.delayed_killer_spawn)
					else
						ply:Spawn()
						ply:Freeze(true)
						ply:GodEnable()

						if modeDef.killer_spawn_far then
							timer.Simple(1, function()
								if not IsValid(ply) or not ply:Alive() then return end
								local farPos = MuR:FindFarthestSpawnFromPlayers()
								if isvector(farPos) then
									ply:SetPos(farPos)
								end
							end)
						end

						timer.Simple(12, function()
							if not IsValid(ply) then return end
							ply:Freeze(false)
							ply:GodDisable()
						end)
					end

					table.remove(tab, id)
				end
			end
		end

		MuR.NextTraitors = {}

		local roles = istable(modeDef.roles) and modeDef.roles or nil

		if not roles and #tab >= 5 and not modeDef.no_default_roles then
			roles = MuR.DefaultRoles
		end

		if roles then
			MuR:AssignSupportRoles(tab, roles)
		end

		for i = 1, #tab do
			local ply = tab[i]
			ply:SetNW2String("Class", iteam)
			ply:SetTeam(2)
			ply:Spawn()
			ply:Freeze(true)
			ply:GodEnable()

			timer.Simple(12, function()
				if not IsValid(ply) then return end
				ply:Freeze(false)
				ply:GodDisable()
			end)
		end
	elseif modeDef.custom_spawning_func then
		if isfunction(MuR[modeDef.custom_spawning_func]) then
			MuR[modeDef.custom_spawning_func](MuR)
		end
	else
		table.Shuffle(tab)

		--
		-- Базы команд. Расставленные наборы вытесняют поиск двух далёких точек
		-- целиком: автор карты уже решил, откуда начинают стороны, и угадывать
		-- поверх этого незачем. Какой набор чьим будет, решено монеткой на
		-- старте раунда (MuR:RollTeamSpawnSwap).
		--
		local pos1, pos2 = MuR:FindTwoDistantSpawnLocations()
		local useTeamSpawns = MuR:HasSpawns("team1") and MuR:HasSpawns("team2")

		local team1_count = math.ceil(#tab / 2)
		if modeDef.kteam_count then
			team1_count = modeDef.kteam_count
		elseif modeDef.kteam_ratio then
			team1_count = math.ceil(#tab * modeDef.kteam_ratio)
		end

		for i = #MuR.NextTraitors, 1, -1 do
			local ply = MuR.NextTraitors[i]
			if IsValid(ply) then
				local id = table.KeyFromValue(tab, ply)
				if id then
					table.remove(tab, id)
					table.insert(tab, 1, ply)
				end
			end
		end

		MuR.NextTraitors = {}

		local team2_count = #tab - team1_count

		for i = 1, #tab do
			local ply = tab[i]

			if i <= team1_count then
				ply:SetNW2String("Class", kteam)
				ply:SetTeam(1)
				ply:Spawn()
				ply:Freeze(true)
				ply:GodEnable()
				if useTeamSpawns then
					timer.Simple(1, function()
						if !IsValid(ply) or !ply:Alive() then return end
						local tpos, tang = MuR:GetTeamSpawnPos(1)
						MuR:PlaceAtSpawn(ply, tpos, tang)
					end)
				elseif isvector(pos1) then
					timer.Simple(1, function()
						if !IsValid(ply) or !ply:Alive() then return end
						local nearbyPos = MuR:FindNearbySpawnPosition(pos1, 500)
						ply:SetPos(nearbyPos or pos1)
					end)
				end

				timer.Simple(12, function()
					if not IsValid(ply) then return end
					ply:Freeze(false)
					ply:GodDisable()
				end)
			else
				ply:SetNW2String("Class", dteam)
				ply:SetTeam(2)
				ply:Spawn()
				ply:Freeze(true)
				ply:GodEnable()
				if useTeamSpawns then
					timer.Simple(1, function()
						if !IsValid(ply) or !ply:Alive() then return end
						local tpos, tang = MuR:GetTeamSpawnPos(2)
						MuR:PlaceAtSpawn(ply, tpos, tang)
					end)
				elseif isvector(pos2) then
					timer.Simple(1, function()
						if !IsValid(ply) or !ply:Alive() then return end
						local nearbyPos = MuR:FindNearbySpawnPosition(pos2, 500)
						ply:SetPos(nearbyPos or pos2)
					end)
				end

				timer.Simple(12, function()
					if not IsValid(ply) then return end
					ply:Freeze(false)
					ply:GodDisable()
				end)
			end
		end
	end
end

local senddatadelay = 0

hook.Add("Think", "SuR_GameLogic", function()
	if MuR.GameStarted then
		local mode = MuR.Mode(MuR.Gamemode)
		if isfunction(mode.OnModeThink) then
			mode.OnModeThink(MuR.Gamemode)
		end

		local team1, team2 = 0, 0

		for _, ent in player.Iterator() do
			if ent:IsRoundParticipant() then
				if ent:Team() == 1 then
					team1 = team1 + 1
				elseif ent:Team() == 2 or ent:Team() == 3 then
					team2 = team2 + 1
				end
			end
		end

		local npc_count = 0
		if mode.npc_team_count then
			local activeNPCs = #ents.FindByClass("npc_bs_suspect")
			local remainingToSpawn = MuR.Mode14 and (MuR.Mode14.NPCToSpawn - MuR.Mode14.NPCSpawned) or 0
			npc_count = activeNPCs + remainingToSpawn
		end

		if MuR.EnableDebug then
			MuR.TimerActive = false
			MuR.TimeCount = 0
			MuR.Delay_Before_Lose = CurTime() + 8
		end

		if mode.win_condition == "zombie" then
			if team1 > 0 then
				MuR.Delay_Before_Lose = CurTime() + 8
			end
		elseif mode.soldier_spawning then
			if team1 > 0 then
				MuR.Delay_Before_Lose = CurTime() + 8
			end
		elseif mode.win_condition == "survivor" then
			if team1 > 1 or team2 > 1 or MuR.TimeCount > CurTime() - 12 then
				MuR.Delay_Before_Lose = CurTime() + 8
			end
		elseif mode.win_condition == "heist" then
			if team1 > 0 then
				MuR.Delay_Before_Lose = CurTime() + 8
			end
		elseif mode.win_condition == "raid" then
			local objectivesDone = isfunction(MuR.Mode14PrimaryComplete)
				and MuR:Mode14PrimaryComplete() or false

			if team2 > 0 and not objectivesDone and npc_count > 0 then
				MuR.Delay_Before_Lose = CurTime() + 8
			end
		elseif mode.win_condition == "tdm" or mode.win_condition == "riot" or mode.win_condition == "specops" then
			if team1 > 0 and team2 > 0 then
				MuR.Delay_Before_Lose = CurTime() + 8
			end
		elseif mode.win_condition == "vip" then
			local vipAlive = isfunction(MuR.Mode8VIPAlive) and MuR:Mode8VIPAlive()
			local killers = isfunction(MuR.Mode8TraitorsAlive) and MuR:Mode8TraitorsAlive() or team1

			if (vipAlive and killers > 0) or MuR.TimeCount > CurTime() - 12 then
				MuR.Delay_Before_Lose = CurTime() + 8
			end
		elseif mode.win_condition == "prison_break" then
			if MuR.Mode23 and not MuR.Mode23.GuardsSpawned then
				MuR.Delay_Before_Lose = CurTime() + 8
			elseif team1 > 0 and team2 > 0 then
				MuR.Delay_Before_Lose = CurTime() + 8
			end
		else
			local killers_pending = (MuR.KillersAwaitingSpawn or 0) > 0
			local standard_logic = not MuR:DisablesGamemode() and (team1 > 0 or killers_pending) and team2 > 0
			local team_assign_wait = mode.team_assign_delay and MuR.TimeCount > CurTime() - MuR.TeamAssignDelay
			local start_grace = MuR.TimeCount > CurTime() - 12

			if standard_logic or team_assign_wait or start_grace then
				MuR.Delay_Before_Lose = CurTime() + 8
			elseif mode.tdm_end_logic and team1 > 0 and team2 > 0 then
				MuR.Delay_Before_Lose = CurTime() + 8
			end
		end

		if mode.team_assign_delay and MuR.TimeCount < CurTime() - MuR.TeamAssignDelay and not MuR.TeamAssign then
			MuR.TeamAssign = true
			MuR:MakeTeamsInGame()
		end

		if not MuR.EnableDebug and (MuR.PoliceState == 1 or MuR.PoliceState == 3 or MuR.PoliceState == 5) and MuR.PoliceArriveTime < CurTime() then
			MuR.PoliceState = MuR.PoliceState + 1
			MuR:PlaySoundOnClient("murdered/other/policearrive.wav")
			MuR:SpawnPlayerPolice(MuR.PoliceState == 6 or MuR.PoliceState == 4)
			MuR.NPC_To_Spawn = math.floor(math.Clamp(player.GetCount()*math.Rand(0.5,2), 4, 16))
			if MuR.PoliceState == 6 then
				MuR.NPC_To_Spawn = 64
			end
		end

		if MuR.EarlyOfficers then
			if MuR.PoliceState ~= 1 and MuR.PoliceState ~= 3 then
				MuR.EarlyOfficers = nil
			elseif MuR.EarlyOfficers.ArriveAt < CurTime() and MuR.EarlyOfficers.NextTry < CurTime() then
				MuR.EarlyOfficers.NextTry = CurTime() + 1

				if MuR:SpawnEarlyOfficers() then
					MuR.EarlyOfficers = nil
				end
			end
		end

		if MuR.PoliceState == 7 and MuR.PoliceArriveTime < CurTime() then
			MuR:SetPoliceTime(math.random(45,60))
			MuR.PoliceState = MuR.PoliceState + 1
		elseif MuR.PoliceState == 8 and MuR.PoliceArriveTime < CurTime() then
			MuR.PoliceState = 0
		end

		if not MuR.EnableDebug and not mode.no_npc_police_spawn and MuR:CountNPCPolice(true) < MuR:GetMaxNPCs() and MuR.PoliceDelaySpawn < CurTime() and not MuR.PoliceClasses.no_npc_police and MuR.NPC_To_Spawn > 0 then
			--
			-- Есть расставленные точки НПС — берём только их: ровно то правило,
			-- ради которого спавнеры и заводились. Нет ни одной — навмеш, как
			-- было. nil означает «сейчас ни одна точка не годится», и тогда
			-- попытка просто переносится на следующий тик.
			--
			local pos = MuR:HasSpawns("npc") and MuR:GetNPCSpawnPos()
				or MuR:GetRandomPos(false) or MuR:GetRandomPos(true)

			if isvector(pos) then
				MuR.PoliceDelaySpawn = CurTime() + MuR.PoliceClasses.delay_spawn
				MuR.NPC_To_Spawn = MuR.NPC_To_Spawn - 1

				if mode.police_swat_only or MuR.PoliceState == 4 or MuR.PoliceState == 6 then
					MuR:SpawnNPC("swat", pos)
				else
					MuR:SpawnNPC("patrol", pos)
				end
			end
		end

		if not MuR.EnableDebug and mode.zombie_spawning and #ents.FindByClass("npc_*") < MuR:GetMaxNPCs() and MuR.TimeCount < CurTime() - 12 and MuR.PoliceDelaySpawn < CurTime() then
			local pos = MuR:HasSpawns("npc") and MuR:GetNPCSpawnPos()
				or MuR:GetRandomPos(tobool(math.random(0, 1)))

			if isvector(pos) then
				MuR.PoliceDelaySpawn = CurTime() + MuR.PoliceClasses.delay_spawn
				MuR:SpawnNPC("zombie", pos)
			end
		end

		if not MuR.EnableDebug and MuR.TimeCount < CurTime() - 12 then
			if MuR.Ending then
				MuR.PoliceState = 0
			elseif mode.call_police_on_think and (MuR.KillersAwaitingSpawn or 0) == 0 then
				MuR:CallPolice()
			elseif mode.police_reinforcements then
				MuR:CheckPoliceReinforcment()
			end

			if mode.zombie_spawning and MuR.PoliceState == 0 and MuR.TimeCount > CurTime() - 13 then
				MuR:SetPoliceTime(math.random(90,120))
				MuR.PoliceState = 7
			end

			if mode.escape_flare and MuR.PoliceState == 8 and !IsValid(MuR.EscapeFlareEntity) then
				local underroof = false
				local pos = MuR:GetRandomPos(underroof)
				if not isvector(pos) then
					pos = MuR:GetRandomPos(not underroof)
				end
				if isvector(pos) then
					local ent = ents.Create("escape_flare")
					ent:SetPos(pos)
					ent:Spawn()
					MuR.EscapeFlareEntity = ent
				end
			elseif mode.escape_flare and MuR.PoliceState != 8 and IsValid(MuR.EscapeFlareEntity) then
				MuR.EscapeFlareEntity:Remove()
			end

			if not MuR:DisablesGamemode() and not MuR.SecuritySpawned then
				MuR.SecuritySpawned = true

				for i = 1, MuR.PoliceClasses.security_spawn do
					local pos = MuR:GetRandomPos(MuR.PoliceClasses["security"].underroof)

					if not isvector(pos) then
						pos = MuR:GetRandomPos(not MuR.PoliceClasses["security"].underroof)
					end

					if isvector(pos) then
						MuR:SpawnNPC("security", pos)
					end
				end
			end
		end

		if MuR.Delay_Before_Lose < CurTime() and not MuR.Ending then
			MuR.TimeBeforeStart = CurTime() + 17
			MuR.Ending = true
			MuR.PoliceState = 0

			local show_vote = MuR:GetLogTable() and player.GetCount() > 4

			if mode.win_condition == "survivor" then
				local humans = 0
				for _, v in player.Iterator() do
					if v:Alive() and v:GetNW2String("Class") != "Zombie" then humans = humans + 1 end
				end
				if humans > 0 then
					MuR:ShowFinalScreen("humans_win", false)
				else
					MuR:ShowFinalScreen("zombies_win", false)
				end
			elseif mode.win_condition == "riot" then
				local police = 0
				for _, v in player.Iterator() do
					if v:Alive() and v:GetNW2String("Class") == "Riot" then police = police + 1 end
				end
				if police > 0 then
					MuR:ShowFinalScreen("police_win", false)
				else
					MuR:ShowFinalScreen("rioters_win", false)
				end
			elseif mode.win_condition == "specops" then
				local police = 0
				for _, v in player.Iterator() do
					if v:Alive() and v:GetNW2String("Class") == "SWAT" then police = police + 1 end
				end
				if police > 0 then
					MuR:ShowFinalScreen("specops_win", false)
				else
					MuR:ShowFinalScreen("terrorists_win", false)
				end
			elseif mode.win_condition == "heist" then
				local criminals = 0
				for _, v in player.Iterator() do
					if v:Alive() and v:GetNW2String("Class") == "Criminal" then criminals = criminals + 1 end
				end
				if criminals > 0 then
					MuR:ShowFinalScreen("criminals_win", false)
				else
					MuR:ShowFinalScreen("police_win", false)
				end
			elseif mode.win_condition == "raid" then
				local police = 0
				for _, v in player.Iterator() do
					if v:Alive() and v:GetNW2String("Class") == "ArmoredOfficer" then police = police + 1 end
				end

				if isfunction(MuR.SendMode14Results) then
					MuR:SendMode14Results(police > 0)
				end

				if police > 0 then
					MuR:ShowFinalScreen("police_win", false)
				else
					MuR:ShowFinalScreen("criminals_win", false)
				end
			elseif mode.win_condition == "prison_break" then
				if team1 > 0 then
					MuR:ShowFinalScreen("prisoners_win", false)
				else
					MuR:ShowFinalScreen("guards_win", false)
				end
			elseif mode.tdm_end_logic then
				local team1_alive = 0
				local team2_alive = 0
				for _, v in player.Iterator() do
					if v:IsRoundParticipant() then
						if v:Team() == 1 then team1_alive = team1_alive + 1 end
						if v:Team() == 2 or v:Team() == 3 then team2_alive = team2_alive + 1 end
					end
				end
				if team1_alive > 0 and team2_alive == 0 then
					MuR:ShowFinalScreen(mode.win_screen_team1 or "team1_win", false)
				elseif team2_alive > 0 and team1_alive == 0 then
					MuR:ShowFinalScreen(mode.win_screen_team2 or "team2_win", false)
				else
					MuR:ShowFinalScreen("draw", false)
				end
			elseif mode.win_condition == "vip" then
				local vipAlive = isfunction(MuR.Mode8VIPAlive) and MuR:Mode8VIPAlive()

				MuR:ShowFinalScreen(vipAlive
					and (mode.win_screen_team2 or "innocent")
					or (mode.win_screen_team1 or "traitor"), show_vote)

				if show_vote then
					MuR.VoteAllowed = true
					MuR.VoteLog = 0
				end
			elseif mode.no_win_screen then
				MuR:ShowFinalScreen("", false)
			elseif team1 > 0 then
				if mode.win_screen_team1 then
					MuR:ShowFinalScreen(mode.win_screen_team1, show_vote)
				else
					MuR:ShowFinalScreen("traitor", show_vote)
				end
				if show_vote then
					MuR.VoteAllowed = true
					MuR.VoteLog = 0
				end
			elseif team2 > 0 then
				if mode.win_screen_team2 then
					MuR:ShowFinalScreen(mode.win_screen_team2, show_vote)
				else
					MuR:ShowFinalScreen("innocent", show_vote)
				end
				if show_vote then
					MuR.VoteAllowed = true
					MuR.VoteLog = 0
				end
			else
				MuR:ShowFinalScreen("", false)
			end

			local tab = player.GetAll()

			for i = 1, #tab do
				local ent = tab[i]
				ent:Freeze(true)
			end
		end

		if MuR.Ending and MuR.TimeBeforeStart < CurTime() then
			if MuR.VoteAllowed and MuR.VoteLog >= player.GetCount()/2 then
				MuR.VoteLog = 0
				MuR.VoteAllowed = false
				MuR:ShowLogScreen()
			else
				MuR:ChangeStateOfGame(false)
			end
		end
	else
		if player.GetCount() > 1 or MuR.EnableDebug or (isnumber(MuR.NextGamemode) and istable(MuR.Mode(MuR.NextGamemode)) and MuR.Mode(MuR.NextGamemode).need_players == 1) then
			MuR:ChangeStateOfGame(true)
		end
	end

	if senddatadelay < CurTime() then
		senddatadelay = CurTime() + 0.1
		MuR:SendDataToClient("HeliArrived", MuR.HeliArrived)
		MuR:SendDataToClient("SniperArrived", MuR.SniperArrived)
		MuR:SendDataToClient("VoteLog", MuR.VoteLog)
		MuR:SendDataToClient("PoliceState", MuR.PoliceState)
		MuR:SendDataToClient("PoliceArriveTime", MuR.PoliceArriveTime)
		MuR:SendDataToClient("EnableDebug", MuR.EnableDebug)

		if MuR.Gamemode == 24 and MuR.Mode24 then
			MuR:SendDataToClient("Mode24Wave", MuR.Mode24.Wave)
			MuR:SendDataToClient("Mode24Phase", MuR.Mode24.Phase)
			MuR:SendDataToClient("Mode24PhaseEnd", MuR.Mode24.PhaseEnd)
		end

		local timerShouldPause = false
		local timerShouldStop = false

		if MuR.Ending then
			timerShouldStop = true
		end

		if MuR.Delay_Before_Lose-7 < CurTime() then
			timerShouldPause = true
		end

		if MuR.TimerActive and not timerShouldStop then
			if timerShouldPause then
				local timeLeft = math.max(0, MuR.TimerEndTime - CurTime())
				MuR:SendDataToClient("TimerActive", true)
				MuR:SendDataToClient("TimerLeft", timeLeft)
				MuR:SendDataToClient("TimerPaused", true)
			else
				local timeLeft = math.max(0, MuR.TimerEndTime - CurTime())
				MuR:SendDataToClient("TimerActive", true)
				MuR:SendDataToClient("TimerLeft", timeLeft)
				MuR:SendDataToClient("TimerPaused", false)
			end
		else
			MuR:SendDataToClient("TimerActive", false)
			MuR:SendDataToClient("TimerPaused", false)
		end

		local flare = ents.FindByClass("escape_flare")[1]
		if MuR.PoliceState == 8 and IsValid(flare) then
			MuR:SendDataToClient("ExfilPos", flare:GetPos()+Vector(0,0,32))
		end
	end

	if MuR.TimerActive and MuR.TimerEndTime <= CurTime() and not MuR.Ending and MuR.Delay_Before_Lose-7 > CurTime() then
		local team1, team2 = 0, 0
		local tab = player.GetAll()

		for i = 1, #tab do
			local ent = tab[i]
			if ent:Alive() then
				if ent:Team() == 1 then
					team1 = team1 + 1
				elseif ent:Team() == 2 or ent:Team() == 3 then
					team2 = team2 + 1
				end
			end
		end

		if MuR.Gamemode == 5 or MuR.Gamemode == 14 or MuR.Gamemode == 15 then
			for i = 1, #tab do
				local ent = tab[i]
				if ent:Alive() then
					MuR.ForceKill(ent)
				end
			end
			MuR.Delay_Before_Lose = CurTime() - 1
		else
			local killTeam = 0
			if team1 < team2 then
				killTeam = 1
			elseif team2 < team1 then
				killTeam = 2
			elseif team1 == team2 and team1 > 0 then
				killTeam = math.random(1, 2)
			end

			if killTeam > 0 then
				for i = 1, #tab do
					local ent = tab[i]
					if ent:Alive() and (ent:Team() == killTeam or (killTeam == 2 and ent:Team() == 3)) then
						MuR.ForceKill(ent)
					end
				end
			end

			MuR.Delay_Before_Lose = CurTime() - 1
		end

		MuR.TimerActive = false
	end
end)

local maxBullets = math.random(8, 16)
hook.Add("EntityFireBullets", "TrackBulletsFired", function(entity, tab)
	local inf = tab.Inflictor
    if entity:IsPlayer() and IsValid(inf) and !inf.Melee then
        MuR.GunShots = MuR.GunShots + 1

        if MuR.GunShots >= maxBullets then
            MuR:CallPolice(1, "gunfire")
            maxBullets = math.random(24, 32)
			MuR.GunShots = 0
        end
    end
end)
