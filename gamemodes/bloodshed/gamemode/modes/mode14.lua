if SERVER then
	CreateConVar("blsd_ror_npccountscale", 1, {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "NPC count scale multiplier for Ready or Not mode", 0.1, 5)
end

MuR.Mode14 = MuR.Mode14 or {}

MuR.Mode14ObjectiveDefs = {
	{id = "secure_suspects",  primary = true,  counter = true,
	 lang = "mode14_obj_secure_suspects",  fallback = "Neutralize or arrest all suspects"},
	{id = "rescue_civilians", primary = true,  counter = true,
	 lang = "mode14_obj_rescue_civilians", fallback = "Evacuate all civilians"},
	{id = "report_bodies",    primary = false, counter = true,
	 lang = "mode14_obj_report_bodies",    fallback = "Report all bodies"},
	{id = "no_civilian_loss", primary = false, counter = false, failable = true,
	 lang = "mode14_obj_no_civilian_loss", fallback = "No civilian casualties"},
}

MuR.Mode14ObjectiveIndex = {}
for i, def in ipairs(MuR.Mode14ObjectiveDefs) do
	MuR.Mode14ObjectiveIndex[def.id] = i
end

MuR.MODE14_OBJ_PENDING  = 0
MuR.MODE14_OBJ_COMPLETE = 1
MuR.MODE14_OBJ_FAILED   = 2

MuR.Mode14ScoreDefs = {
	suspect_arrested             = {money =  250, points =  100, lang = "mode14_suspect_arrested"},
	civilian_secured             = {money =  100, points =   60, lang = "mode14_civilian_secured"},
	suspect_killed               = {money =   50, points =   25, lang = "mode14_deceased_suspect"},
	suspect_killed_surrendering  = {money = -150, points =  -75, lang = "mode14_deceased_surrendering_suspect"},
	civilian_killed              = {money = -300, points = -200, lang = "mode14_deceased_civilian"},
	officer_down                 = {money =    0, points = -100, lang = "mode14_downed_officer"},
	body_reported                = {money =   25, points =   10, lang = "mode14_report_body"},
	trap_disarmed                = {money =   50, points =   20, lang = "mode14_trap_disarmed"},
}

function MuR:Mode14Report(ply, ent)
    if not IsValid(ply) or not IsValid(ent) then return end
    if MuR.Gamemode != 14 and not ent:GetNW2Bool("RoN_ForcedReport") then return end
    if ent:GetNW2Bool("RoN_Reported") then return end
    if ent:GetNW2Bool("MuR.IsLivingRagdoll") then return end

    local type = ent:GetNW2String("RoN_Type", "suspect")
    if IsValid(ent.OwnerDead) and ent.OwnerDead:IsPlayer() then
        type = "swat"
    end

    local isSecured = ent:GetClass() == "bloodshed_anim_model" or ent:GetClass() == "prop_dynamic"
    ent:SetNW2Bool("RoN_Reported", true)

    local plyVoice = ""
    if isSecured then
        if type == "suspect" then
            plyVoice = "ror_police_reportarrestedsuspect"
        else
            plyVoice = "ror_police_reportcivilianarrested"
        end
    else
        if type == "suspect" then
            plyVoice = "ror_police_deadsus"
        elseif type == "civilian" then
            plyVoice = "ror_police_deadciv"
        elseif type == "swat" then
            plyVoice = "ror_police_deadswat"
        end
    end

    if plyVoice != "" then
        ply:PlayVoiceLine(plyVoice)
    end

    timer.Simple(3.5, function()
        if not IsValid(ply) then return end
        local sounds = {
            "npc/overwatch/radiovoice/apply.wav",
            "npc/overwatch/radiovoice/riot404.wav",
            "npc/overwatch/radiovoice/subject.wav",
            "npc/overwatch/radiovoice/respond.wav",
            "npc/overwatch/radiovoice/reporton.wav",
            "npc/overwatch/radiovoice/reportplease.wav"
        }
        ply:EmitSound(table.Random(sounds), 70, 100)
    end)

    if MuR.Mode14 then
        MuR.Mode14.BodiesReported = (MuR.Mode14.BodiesReported or 0) + 1
        MuR:Mode14Score(ply, "body_reported", ent)
        MuR:Mode14RecountObjectives()
    end

    if type == "swat" and not isSecured then
        if ply.NextDeadSwatSound and CurTime() < ply.NextDeadSwatSound then return end
        ply:PlayVoiceLine("ror_police_deadswat")
        ply.NextDeadSwatSound = CurTime() + 5
    end
end

local function GetNPCCountScale()
	local cvar = GetConVar("blsd_ror_npccountscale")
	return cvar and cvar:GetFloat() or 1
end

local function CalculateNPCCount(playerCount)
	local scale = GetNPCCountScale()
	local base = math.Clamp(playerCount * math.Rand(2.5, 4), 6, 32)
	return math.floor(base * scale)
end

local function CalculateMaxActiveNPCs(playerCount)
	local scale = GetNPCCountScale()
	local base = math.Clamp(playerCount * 2, 4, 16)
	return math.floor(base * scale)
end

local function GetMaxPlayersOnMap()
	return 5
end

local function SpawnSuspectNPC(pos)
	if not isvector(pos) then return nil end

	local tab = MuR.PoliceClasses["suspect"]
	if not istable(tab) then return nil end

	local class = tab.npcs[math.random(1, #tab.npcs)]
	local wclass = tab.weps[math.random(1, #tab.weps)]

	local ent = ents.Create(class)
	if not IsValid(ent) then return nil end

	ent:SetPos(pos)
	ent:Spawn()

	if ent.IsSuspect then
		ent:Give(wclass)
	end

	return ent
end

MuR.RegisterMode(14, {
	name = "Ready or Not",
	chance = 20,
	need_players = 1,
	disables = true,
	no_default_roles = true,
	win_condition = "raid",
	custom_spawning = true,
	npc_team_count = true,
	custom_spawning_func = "Mode14SpawnPlayers",
	no_npc_police_spawn = true,
	armored_officer_raid_logic = true,
	no_guilt = true,
	no_friendly_fire = true,
	timer = 900,
	kteam = "ArmoredOfficer",
	dteam = "ArmoredOfficer",
	iteam = "ArmoredOfficer",
	OnModeStarted = function(mode)
		if SERVER then
			util.AddNetworkString("MuR.Mode14Reset")
			util.AddNetworkString("MuR.Mode14Data")
			util.AddNetworkString("MuR.Mode14Objectives")
			util.AddNetworkString("MuR.Mode14Notification")
			util.AddNetworkString("MuR.Mode14Results")
			net.Start("MuR.Mode14Reset")
			net.Broadcast()

			local playerCount = math.min(player.GetCount(), 5)

			local npcTotal = CalculateNPCCount(playerCount)

			MuR.Mode14 = {
				NPCToSpawn = npcTotal,
				NPCSpawned = 0,
				MaxActiveNPCs = CalculateMaxActiveNPCs(playerCount),
				SpawnDelay = 0,
				SpawnInterval = math.Clamp(3 - playerCount * 0.2, 0.8, 3),
				ActivePlayers = {},
				ReinforcementQueue = {},
				MaxPlayersOnMap = GetMaxPlayersOnMap(),
				KilledNPCs = 0,
				TotalNPCs = npcTotal,
				TrapBudget = 2 + math.floor(playerCount * 1.5),
				TrapsPlaced = 0,
				Score = 0,
				Ledger = {},
				ScoredEvents = {},
				SuspectsSeen = 0,
				SuspectsResolved = 0,
				CiviliansSeen = 0,
				CiviliansResolved = 0,
				BodiesTotal = 0,
				BodiesReported = 0,
				ObjectivesDirty = true,
			}

			timer.Simple(2, function()
				if MuR.Gamemode != 14 or not MuR.Mode14 then return end

				local civCount, susCount = 0, 0
				for npc in pairs(MuR.ActiveSuspects or {}) do
					if IsValid(npc) and npc:Health() > 0 then
						if npc.IsSuspect then
							susCount = susCount + 1
						else
							civCount = civCount + 1
						end
					end
				end

				MuR.Mode14.CiviliansSeen = math.max(MuR.Mode14.CiviliansSeen, civCount)
				MuR.Mode14.SuspectsSeen = math.max(MuR.Mode14.SuspectsSeen, susCount)
				MuR:Mode14RecountObjectives()
				MuR:SendMode14Objectives(true)
			end)

			hook.Add("OnNPCKilled", "MuR.Mode14.NPCKilled", function(npc, attacker, inflictor)
				if MuR.Gamemode != 14 then return end
				if not MuR.Mode14 then return end
				if not npc.IsRoNSuspect then return end

				MuR.Mode14.KilledNPCs = MuR.Mode14.KilledNPCs + 1
				MuR.Mode14.BodiesTotal = MuR.Mode14.BodiesTotal + 1

				if npc.IsSuspect then
					MuR.Mode14.SuspectsResolved = MuR.Mode14.SuspectsResolved + 1
				elseif not npc.IsRescued then
					MuR.Mode14.CiviliansResolved = MuR.Mode14.CiviliansResolved + 1
					MuR:Mode14FailObjective("no_civilian_loss")
				end

				local ply = IsValid(attacker) and attacker:IsPlayer() and attacker or nil

				if npc.IsCivilian then
					MuR:Mode14Score(ply, "civilian_killed", npc)
				else
					local surrendering = npc:GetNW2Float("ArrestState") == 1
						or string.find(npc:GetSVAnim() or "", "sequence_ron_comply_start")
					MuR:Mode14Score(ply, surrendering and "suspect_killed_surrendering" or "suspect_killed", npc)
				end

				MuR:Mode14RecountObjectives()
			end)

			hook.Add("BloodshedTrapDisarmed", "MuR.Mode14.TrapDisarmed", function(ply, trap)
				if MuR.Gamemode != 14 or not MuR.Mode14 then return end
				MuR:Mode14Score(ply, "trap_disarmed", trap)
			end)

			hook.Add("KeyPress", "MuR.Mode14.KeyPress", function(ply, key)
				if MuR.Gamemode != 14 then return end
				if key == IN_USE then
					local tr = util.TraceLine({
						start = ply:GetShootPos(),
						endpos = ply:GetShootPos() + ply:GetAimVector() * 96,
						filter = ply
					})
					local ent = tr.Entity
                    local isValidTarget = IsValid(ent) and (ent:GetClass() == "prop_ragdoll" and ent:LookupBone("ValveBiped.Bip01_Head1"))
					if isValidTarget and tr.HitPos:DistToSqr(ply:GetShootPos()) < 14400 then
                        MuR:Mode14Report(ply, ent)
					end
				end
			end)

            hook.Add("CreateEntityRagdoll", "MuR.Mode14.TagRagdoll", function(ent, rag)
                if MuR.Gamemode != 14 then return end
                local type = "suspect"
                if ent:IsPlayer() then
                    type = "swat"
                elseif ent.IsCivilian then
                    type = "civilian"
                end

                rag:SetNW2String("RoN_Type", type)
				rag:SetCollisionGroup(COLLISION_GROUP_DEBRIS_TRIGGER)
                if string.find(ent:GetSequenceName(ent:GetSequence()), "sequence_ron_comply_start") then
                    rag.SurrenderedDeath = true
                end
            end)

			hook.Add("PlayerDeath", "MuR.Mode14.PlayerDeath", function(victim, inflictor, attacker)
				if MuR.Gamemode != 14 then return end
				if not MuR.Mode14 then return end

				MuR:Mode14Score(nil, "officer_down", victim)

				MuR.Mode14.ActivePlayers[victim:SteamID64()] = nil

				if #MuR.Mode14.ReinforcementQueue > 0 then
					local nextPly = table.remove(MuR.Mode14.ReinforcementQueue, 1)
					if IsValid(nextPly) then nextPly:SetNW2Int("MuR_RoNQueuePos", 0) end
					MuR:SyncMode14Queue()
					if IsValid(nextPly) and not nextPly:Alive() then
						timer.Simple(3, function()
							if not IsValid(nextPly) or MuR.Gamemode != 14 then return end
							if not MuR.Mode14 then return end

							nextPly.ForceSpawn = true
							nextPly:SetNW2String("Class", "ArmoredOfficer")
							nextPly:Spawn()
							nextPly:ScreenFade(SCREENFADE.IN, color_black, 1, 0)

							local pos = MuR:GetRandomPos(false)
							if isvector(pos) then
								timer.Simple(0.1, function()
									if IsValid(nextPly) and nextPly:Alive() then
										nextPly:SetPos(pos)
									end
								end)
							end

							MuR.Mode14.ActivePlayers[nextPly:SteamID64()] = true
							MuR:GiveAnnounce("reinforcement_arrived", nextPly)
						end)
					end
				end
			end)
		end
	end,
	OnModeThink = function(mode)
		if not SERVER then return end
		if not MuR.Mode14 then return end
		if MuR.Ending then return end

		if (MuR.Mode14.NextThink or 0) > CurTime() then return end
		MuR.Mode14.NextThink = CurTime() + 0.25

		if MuR.Mode14.NPCSpawned < MuR.Mode14.NPCToSpawn and MuR.Mode14.SpawnDelay < CurTime() then
			local activeNPCs = #ents.FindByClass("npc_bs_suspect")

			if activeNPCs < MuR.Mode14.MaxActiveNPCs then
				local pos = MuR:GetRandomPos(true)
				if not isvector(pos) then
					pos = MuR:GetRandomPos(false)
				end

				if isvector(pos) then
					local npc = SpawnSuspectNPC(pos)
					if IsValid(npc) then
						MuR.Mode14.NPCSpawned = MuR.Mode14.NPCSpawned + 1
						MuR.Mode14.SpawnDelay = CurTime() + MuR.Mode14.SpawnInterval

						if npc.IsSuspect then
							MuR.Mode14.SuspectsSeen = MuR.Mode14.SuspectsSeen + 1
						else
							MuR.Mode14.CiviliansSeen = MuR.Mode14.CiviliansSeen + 1
						end

						MuR:Mode14RecountObjectives()
					end
				end
			end
		end

		MuR:SendMode14Data()
		MuR:SendMode14Objectives()

		if (MuR.Mode14.NextObjectiveResend or 0) < CurTime() then
			MuR.Mode14.NextObjectiveResend = CurTime() + 5
			MuR:SendMode14Objectives(true)
		end
	end,
	OnModeEnded = function(mode)
		if SERVER then
			hook.Remove("OnNPCKilled", "MuR.Mode14.NPCKilled")
			hook.Remove("KeyPress", "MuR.Mode14.KeyPress")
			hook.Remove("BloodshedTrapDisarmed", "MuR.Mode14.TrapDisarmed")
			hook.Remove("PlayerDeath", "MuR.Mode14.PlayerDeath")
			hook.Remove("CreateEntityRagdoll", "MuR.Mode14.TagRagdoll")
			MuR.Mode14 = nil
		end
	end
})

if SERVER then
	function MuR:SendMode14Data(force)
		if not MuR.Mode14 or not MuR.Mode14.ReinforcementQueue then return end

		local killed = MuR.Mode14.KilledNPCs
		local total = MuR.Mode14.TotalNPCs
		local queue = #MuR.Mode14.ReinforcementQueue

		if not force
			and MuR.Mode14.SentKilled == killed
			and MuR.Mode14.SentTotal == total
			and MuR.Mode14.SentQueue == queue
		then
			return
		end

		MuR.Mode14.SentKilled = killed
		MuR.Mode14.SentTotal = total
		MuR.Mode14.SentQueue = queue

		net.Start("MuR.Mode14Data")
		net.WriteInt(killed, 16)
		net.WriteInt(total, 16)
		net.WriteInt(queue, 8)
		net.Broadcast()
	end

	function MuR:SyncMode14Queue()
		if not MuR.Mode14 then return end
		for i, queued in ipairs(MuR.Mode14.ReinforcementQueue) do
			if IsValid(queued) then
				queued:SetNW2Int("MuR_RoNQueuePos", i)
			end
		end
	end

	function MuR:Mode14Score(ply, eventKey, subject)
		if not MuR.Mode14 or not MuR.Mode14.NPCToSpawn then return end

		local def = MuR.Mode14ScoreDefs[eventKey]
		if not def then return end

		if IsValid(subject) then
			local sid = subject.GetCreationID and subject:GetCreationID() or subject:EntIndex()
			local dedup = sid .. "|" .. eventKey

			MuR.Mode14.ScoredEvents = MuR.Mode14.ScoredEvents or {}
			if MuR.Mode14.ScoredEvents[dedup] then return end
			MuR.Mode14.ScoredEvents[dedup] = true
		end

		MuR.Mode14.Score = (MuR.Mode14.Score or 0) + def.points
		MuR.Mode14.Ledger = MuR.Mode14.Ledger or {}
		MuR.Mode14.Ledger[eventKey] = (MuR.Mode14.Ledger[eventKey] or 0) + 1

		if IsValid(ply) and ply:IsPlayer() then
			if def.money ~= 0 and ply.AddMoney then
				ply:AddMoney(def.money)
			end

			net.Start("MuR.Mode14Notification")
			net.WriteString(def.lang)
			net.WriteInt(def.money, 16)
			net.Send(ply)
		end
	end

	local function EnsureObjectives()
		if not MuR.Mode14 then return nil end
		if not MuR.Mode14.Objectives then
			MuR.Mode14.Objectives = {}
			for _, def in ipairs(MuR.Mode14ObjectiveDefs) do
				MuR.Mode14.Objectives[def.id] = {state = MuR.MODE14_OBJ_PENDING, cur = 0, max = 0}
			end
		end
		return MuR.Mode14.Objectives
	end

	function MuR:Mode14FailObjective(id)
		if not MuR.Mode14 or not MuR.Mode14.NPCToSpawn then return end
		local objs = EnsureObjectives()
		if not objs or not objs[id] then return end
		if objs[id].state == MuR.MODE14_OBJ_FAILED then return end
		objs[id].state = MuR.MODE14_OBJ_FAILED
		MuR.Mode14.ObjectivesDirty = true
	end

	function MuR:Mode14RecountObjectives()
		if not MuR.Mode14 or not MuR.Mode14.NPCToSpawn then return end

		local objs = EnsureObjectives()
		if not objs then return end

		local suspectsAlive, civiliansAlive = 0, 0
		for npc in pairs(MuR.ActiveSuspects or {}) do
			if IsValid(npc) and npc:Health() > 0 then
				if npc.IsSuspect then
					suspectsAlive = suspectsAlive + 1
				elseif npc.IsCivilian then
					if not npc.IsRescued then
						civiliansAlive = civiliansAlive + 1
					end
				end
			end
		end

		local allSpawned = MuR.Mode14.NPCSpawned >= MuR.Mode14.NPCToSpawn

		local o = objs["secure_suspects"]
		o.max = math.max(MuR.Mode14.SuspectsSeen or 0, MuR.Mode14.SuspectsResolved or 0)
		o.cur = MuR.Mode14.SuspectsResolved or 0
		if allSpawned and suspectsAlive == 0 then
			o.state = MuR.MODE14_OBJ_COMPLETE
		end

		o = objs["rescue_civilians"]
		o.max = math.max(MuR.Mode14.CiviliansSeen or 0, MuR.Mode14.CiviliansResolved or 0)
		o.cur = MuR.Mode14.CiviliansResolved or 0
		if allSpawned and civiliansAlive == 0 then
			o.state = MuR.MODE14_OBJ_COMPLETE
		end

		o = objs["report_bodies"]
		o.max = MuR.Mode14.BodiesTotal or 0
		o.cur = MuR.Mode14.BodiesReported or 0
		if o.max > 0 and o.cur >= o.max and allSpawned then
			o.state = MuR.MODE14_OBJ_COMPLETE
		end

		o = objs["no_civilian_loss"]
		if o.state ~= MuR.MODE14_OBJ_FAILED then
			o.state = (allSpawned and civiliansAlive == 0)
				and MuR.MODE14_OBJ_COMPLETE or MuR.MODE14_OBJ_PENDING
		end

		MuR.Mode14.ObjectivesDirty = true
	end

	function MuR:Mode14PrimaryComplete()
		local objs = MuR.Mode14 and MuR.Mode14.Objectives
		if not objs then return false end

		for _, def in ipairs(MuR.Mode14ObjectiveDefs) do
			if def.primary then
				local o = objs[def.id]
				if not o or o.state ~= MuR.MODE14_OBJ_COMPLETE then return false end
			end
		end
		return true
	end

	function MuR:SendMode14Objectives(force)
		if not MuR.Mode14 or not MuR.Mode14.NPCToSpawn then return end
		local objs = EnsureObjectives()
		if not objs then return end

		if not force and not MuR.Mode14.ObjectivesDirty then return end
		MuR.Mode14.ObjectivesDirty = false

		net.Start("MuR.Mode14Objectives")
		net.WriteUInt(#MuR.Mode14ObjectiveDefs, 8)
		for idx, def in ipairs(MuR.Mode14ObjectiveDefs) do
			local o = objs[def.id]
			net.WriteUInt(idx, 8)
			net.WriteUInt(o.state, 2)
			net.WriteUInt(math.Clamp(o.cur, 0, 1023), 10)
			net.WriteUInt(math.Clamp(o.max, 0, 1023), 10)
		end
		net.Broadcast()
	end

	function MuR:SendMode14Results(success)
		if not MuR.Mode14 or not MuR.Mode14.NPCToSpawn then return end

		local ledger = MuR.Mode14.Ledger or {}
		local rows = {}
		for key, count in pairs(ledger) do
			if count > 0 then
				rows[#rows + 1] = {key = key, count = count}
			end
		end
		table.sort(rows, function(a, b) return a.key < b.key end)

		local score = MuR.Mode14.Score or 0

		local grade = "D"
		if success then
			if score >= 600 then grade = "S"
			elseif score >= 400 then grade = "A"
			elseif score >= 200 then grade = "B"
			else grade = "C" end
		end

		net.Start("MuR.Mode14Results")
		net.WriteBool(success and true or false)
		net.WriteString(grade)
		net.WriteInt(score, 32)

		net.WriteUInt(#rows, 8)
		for _, row in ipairs(rows) do
			net.WriteString(row.key)
			net.WriteUInt(math.Clamp(row.count, 0, 255), 8)
		end

		local objs = MuR.Mode14.Objectives or {}
		net.WriteUInt(#MuR.Mode14ObjectiveDefs, 8)
		for idx, def in ipairs(MuR.Mode14ObjectiveDefs) do
			local o = objs[def.id]
			net.WriteUInt(idx, 8)
			net.WriteUInt(o and o.state or 0, 2)
		end

		net.Broadcast()
	end

	function MuR:Mode14SpawnPlayers()
		if MuR.Gamemode != 14 then return end
		if not MuR.Mode14 then return end

		local allPlayers = player.GetAll()
		table.Shuffle(allPlayers)

		local spawnPos = MuR:GetRandomPos(false)
		local spawned = 0

		for _, ply in ipairs(allPlayers) do
			if spawned < MuR.Mode14.MaxPlayersOnMap then
				ply:SetNW2String("Class", "ArmoredOfficer")
				ply:Spawn()
				ply:Freeze(true)
				ply:GodEnable()

				if isvector(spawnPos) then
					timer.Simple(1, function()
						if IsValid(ply) and ply:Alive() then
							ply:SetPos(spawnPos)
						end
					end)
				end

				timer.Simple(12, function()
					if IsValid(ply) then
						ply:Freeze(false)
						ply:GodDisable()
					end
				end)

				MuR.Mode14.ActivePlayers[ply:SteamID64()] = true
				spawned = spawned + 1
			else
				table.insert(MuR.Mode14.ReinforcementQueue, ply)
				ply:SetNW2String("Class", "ArmoredOfficer")
				ply:SetTeam(2)
				ply:Freeze(false)
				MuR:SyncMode14Queue()
				MuR:GiveAnnounce("waiting_reinforcement", ply)
			end
		end
	end
end

if CLIENT then
	local function We(x) return x / 1920 * ScrW() end
	local function He(y) return y / 1080 * ScrH() end

	local THEME = {
		bg = Color(0, 0, 0, 180),
		bgDark = Color(0, 0, 0, 220),
		accent = Color(30, 144, 255),
		accentDim = Color(30, 144, 255, 100),
		text = Color(255, 255, 255),
		textDim = Color(180, 180, 180),
		health = Color(50, 205, 50),
		healthLow = Color(255, 80, 80),
		armor = Color(100, 149, 237),
		warning = Color(255, 200, 50),
		danger = Color(255, 50, 50),
		grid = Color(30, 144, 255, 30)
	}

	local compassDirs = {"N", "NE", "E", "SE", "S", "SW", "W", "NW"}
	local compassMat = Material("vgui/gradient-l")

	local function CreateRoNFonts()
		surface.CreateFont("RoN_Font_Small", {font = "VK Sans Display DemiBold", extended = true, size = He(14), weight = 500, antialias = true})
		surface.CreateFont("RoN_Font_Medium", {font = "VK Sans Display DemiBold", extended = true, size = He(18), weight = 500, antialias = true})
		surface.CreateFont("RoN_Font_Large", {font = "VK Sans Display DemiBold", extended = true, size = He(24), weight = 700, antialias = true})
		surface.CreateFont("RoN_Font_Compass", {font = "VK Sans Display DemiBold", extended = true, size = He(16), weight = 600, antialias = true})
		surface.CreateFont("RoN_Font_Big", {font = "VK Sans Display DemiBold", extended = true, size = He(32), weight = 700, antialias = true})
	end

	CreateRoNFonts()
	hook.Add("OnScreenSizeChanged", "MuR.Mode14Fonts", CreateRoNFonts)

	local function DrawCompass(x, y, width)
		local ply = LocalPlayer()
		if not IsValid(ply) then return end

		local ang = ply:EyeAngles().y
		local height = He(28)

		local centerX = x
		local pixelsPerDegree = width / 90

		render.SetScissorRect(x - width/2 + 2, y, x + width/2 - 2, y + height, true)

		for deg = -180, 180, 15 do
			local offset = (deg + ang) % 360
			if offset > 180 then offset = offset - 360 end

			local drawX = centerX - offset * pixelsPerDegree

			if drawX > x - width/2 and drawX < x + width/2 then
				local dirIndex = math.floor(((deg + 180) % 360) / 45) + 1
				local isCardinal = deg % 90 == 0
				local isMajor = deg % 45 == 0

				if isMajor then
					local dir = compassDirs[dirIndex] or ""
					draw.SimpleText(dir, "RoN_Font_Compass", drawX, y + height/2,
						isCardinal and THEME.accent or THEME.textDim,
						TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				else
					surface.SetDrawColor(THEME.grid)
					surface.DrawRect(drawX, y + He(10), 1, He(8))
				end
			end
		end

		render.SetScissorRect(0, 0, 0, 0, false)

		surface.SetDrawColor(THEME.accent)
		local triSize = He(6)
		draw.NoTexture()
		surface.DrawPoly({
			{x = centerX, y = y + 2},
			{x = centerX - triSize, y = y - triSize},
			{x = centerX + triSize, y = y - triSize}
		})
	end

	local function DrawHealthArmor(x, y)
		local ply = LocalPlayer()
		if not IsValid(ply) then return end

		local health = ply:Health()
		local maxHealth = ply:GetMaxHealth()

		local barWidth = We(180)
		local barHeight = He(30)

		local healthColor = health > 30 and THEME.health or THEME.healthLow

		surface.SetDrawColor(healthColor)
		local points = {}
		local step = 2
		local speed = health < 30 and 2.0 or 0.8
		local time = CurTime() * speed

		for i = 0, barWidth, step do
			local normalizedX = i / barWidth
			local phase = (normalizedX * 2 + time) % 1.0
			local y_val = 0

			if phase > 0.4 and phase < 0.6 then
				local p = (phase - 0.4) / 0.2
				if p < 0.2 then
					y_val = math.sin(p / 0.2 * math.pi) * He(3)
				elseif p < 0.3 then
					y_val = 0
				elseif p < 0.4 then
					y_val = -He(3) * math.sin((p-0.3)/0.1 * math.pi)
				elseif p < 0.6 then
					y_val = He(15) * math.sin((p-0.4)/0.2 * math.pi)
					if p > 0.5 then y_val = -y_val * 0.5 end
				elseif p < 0.7 then
					y_val = -He(5) * (1 - (p-0.6)/0.1)
				elseif p < 1.0 then
					y_val = math.sin((p-0.7)/0.3 * math.pi) * He(4)
				end
			end

			if health < 30 then
				y_val = y_val + math.sin(i * 0.5 + CurTime() * 20) * He(1)
			end

			table.insert(points, {x = x + We(4) + i, y = y + He(4) + barHeight/2 - y_val})
		end

		for i=1, #points-1 do
			surface.DrawLine(points[i].x, points[i].y, points[i+1].x, points[i+1].y)
		end

		local healthPercent = math.Clamp(health / maxHealth, 0, 1)
		local baseBPM = 60 + (1 - healthPercent) * 80
		local variance = 5 + (1 - healthPercent) * 10
		local bpm = baseBPM + math.sin(CurTime() * (2 - healthPercent)) * variance

		local bpmColor
		if healthPercent > 0.7 then
			bpmColor = Color(
				Lerp((healthPercent - 0.7) / 0.3, 150, 50),
				Lerp((healthPercent - 0.7) / 0.3, 200, 205),
				50
			)
		elseif healthPercent > 0.3 then
			bpmColor = Color(
				Lerp((healthPercent - 0.3) / 0.4, 255, 150),
				Lerp((healthPercent - 0.3) / 0.4, 150, 200),
				50
			)
		else
			bpmColor = Color(
				255,
				Lerp(healthPercent / 0.3, 80, 150),
				Lerp(healthPercent / 0.3, 80, 50)
			)
		end

		draw.SimpleText("BPM " .. math.Round(bpm), "RoN_Font_Small", x + barWidth + He(8), y + He(4) + barHeight/2, bpmColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	local function DrawTeammates(x, y)
		local ply = LocalPlayer()
		if not IsValid(ply) then return end

		local teammates = {}
		for _, p in player.Iterator() do
			if p ~= ply and p:Alive() and p:Team() == ply:Team() then
				table.insert(teammates, p)
			end
		end

		if #teammates == 0 then return end

		local entryHeight = He(24)
		local width = We(180)

		draw.SimpleText(MuR.Language["mode14_squad"] or "SQUAD", "RoN_Font_Small", x + We(8), y + He(10), THEME.accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		surface.SetDrawColor(THEME.accent)
		surface.DrawRect(x + We(4), y + He(18), width - We(8), 1)

		for i, mate in ipairs(teammates) do
			local yPos = y + He(24) + (i-1) * entryHeight
			local hp = mate:Health()
			local maxHp = mate:GetMaxHealth()
			local hpPercent = math.Clamp(hp / maxHp, 0, 1)

			local hpColor = hp > 30 and THEME.health or THEME.healthLow

			surface.SetDrawColor(Color(hpColor.r, hpColor.g, hpColor.b, 30))
			surface.DrawRect(x + We(4), yPos + He(2), (width - We(8)) * hpPercent, entryHeight - He(4))

			local mateHealthPercent = math.Clamp(hp / maxHp, 0, 1)
			local mateBaseBPM = 60 + (1 - mateHealthPercent) * 80
			local mateVariance = 5 + (1 - mateHealthPercent) * 10
			local mateBPM = mateBaseBPM + math.sin(CurTime() * (2 - mateHealthPercent)) * mateVariance

			local name = string.sub(mate:Nick(), 1, 12)
			draw.SimpleText(name, "RoN_Font_Small", x + We(8), yPos + entryHeight/2, THEME.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			draw.SimpleText(math.Round(mateBPM) .. " BPM", "RoN_Font_Small", x + width - We(8), yPos + entryHeight/2, hpColor, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		end
	end

	local function DrawMissionTimer(x, y)
		if not MuR.Data["TimerActive"] then return end

		local timeLeft = MuR.Data["TimerLeft"] or 0
		local mins = math.floor(timeLeft / 60)
		local secs = math.floor(timeLeft % 60)
		local timeStr = string.format("%02d:%02d", mins, secs)

		local boxHeight = He(36)

		local timeColor = THEME.text
		if timeLeft < 60 then
			local flash = math.abs(math.sin(CurTime() * 4))
			timeColor = Color(255, 255 * flash, 255 * flash)
		end

		draw.SimpleText(timeStr, "RoN_Font_Large", x, y + boxHeight/2, timeColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	local function DrawWeaponInfo(x, y)
		local ply = LocalPlayer()
		if not IsValid(ply) then return end

		local wep = ply:GetActiveWeapon()
		if not IsValid(wep) then return end

		local name = wep:GetPrintName()
		if not name or name == "" then return end

		name = string.upper(name)

		draw.SimpleText(name, "RoN_Font_Small", x, y, THEME.textDim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
	end

	local scanlineMat, scanlineW, scanlineH
	local function BuildScanlines()
		scanlineW, scanlineH = ScrW(), ScrH()

		local rt = GetRenderTargetEx("MuR_RoN_Scanlines_" .. scanlineW .. "x" .. scanlineH,
			scanlineW, scanlineH, RT_SIZE_NO_CHANGE, MATERIAL_RT_DEPTH_NONE,
			16, 0, IMAGE_FORMAT_BGRA8888)

		render.PushRenderTarget(rt)
			render.Clear(0, 0, 0, 0)
			cam.Start2D()
				surface.SetDrawColor(0, 0, 0, 255)
				for i = 0, scanlineH, 4 do
					surface.DrawRect(0, i, scanlineW, 1)
				end
			cam.End2D()
		render.PopRenderTarget()

		scanlineMat = CreateMaterial("MuR_RoN_ScanlineMat_" .. scanlineW .. "x" .. scanlineH, "UnlitGeneric", {
			["$basetexture"] = rt:GetName(),
			["$translucent"] = "1",
			["$vertexalpha"] = "1",
			["$vertexcolor"] = "1",
		})
	end

	local function DrawScanlines()
		if not scanlineMat or scanlineW != ScrW() or scanlineH != ScrH() then
			BuildScanlines()
		end

		surface.SetMaterial(scanlineMat)
		surface.SetDrawColor(255, 255, 255, 15)
		surface.DrawTexturedRect(0, 0, ScrW(), ScrH())
	end

	local function NewMode14ClientState()
		return {
			KilledNPCs = 0,
			TotalNPCs = 0,
			ReinforcementQueue = 0,
			Objectives = {},
			Notifications = {},
		}
	end

	local function EnsureMode14ClientState()
		local st = MuR.Mode14Client
		if not istable(st) then
			st = NewMode14ClientState()
			MuR.Mode14Client = st
		end

		if not istable(st.Objectives) then st.Objectives = {} end
		if not istable(st.Notifications) then st.Notifications = {} end
		st.KilledNPCs = st.KilledNPCs or 0
		st.TotalNPCs = st.TotalNPCs or 0
		st.ReinforcementQueue = st.ReinforcementQueue or 0

		return st
	end

	EnsureMode14ClientState()

	net.Receive("MuR.Mode14Reset", function()
		MuR.Mode14Client = NewMode14ClientState()
	end)

	net.Receive("MuR.Mode14Data", function()
		local st = EnsureMode14ClientState()
		st.KilledNPCs = net.ReadInt(16)
		st.TotalNPCs = net.ReadInt(16)
		st.ReinforcementQueue = net.ReadInt(8)
	end)

	net.Receive("MuR.Mode14Objectives", function()
		local count = net.ReadUInt(8)
		local objs = EnsureMode14ClientState().Objectives

		for _ = 1, count do
			local idx = net.ReadUInt(8)
			local state = net.ReadUInt(2)
			local cur = net.ReadUInt(10)
			local max = net.ReadUInt(10)

			local prev = objs[idx]
			if not prev then
				prev = {state = state, cur = cur, max = max, changedAt = 0}
				objs[idx] = prev
			end

			if prev.state ~= state then
				prev.changedAt = CurTime()
			end

			prev.state = state
			prev.cur = cur
			prev.max = max
		end
	end)

    net.Receive("MuR.Mode14Notification", function()
        local msg = net.ReadString()
        local money = net.ReadInt(16)
        table.insert(EnsureMode14ClientState().Notifications, {
            msg = MuR.Language[msg] or msg,
            money = money,
            time = CurTime() + 4,
            fade = 0,
            yOff = He(20)
        })
    end)

    local radioIcon = Material("murdered/ror_report.png", "smooth")
    local promptAlpha = 0
    local parsed_prompt
    hook.Add("HUDPaint", "MuR.Mode14ReportPrompt", function()
        if MuR.GamemodeCount != 14 or not LocalPlayer():Alive() then
            promptAlpha = 0
            return
        end
        if not MuR.DrawHUD or MuR:GetClient("blsd_nohud") then
            promptAlpha = 0
            return
        end

        local tr = LocalPlayer():GetEyeTrace()
        local ent = tr.Entity
        local canReport = IsValid(ent) and (ent:GetClass() == "prop_ragdoll" and ent:LookupBone("ValveBiped.Bip01_Head1")) and tr.HitPos:DistToSqr(LocalPlayer():GetShootPos()) < 10000

        if canReport and not ent:GetNW2Bool("RoN_Reported") and not ent:GetNW2Bool("MuR.IsLivingRagdoll") then
            promptAlpha = Lerp(FrameTime() * 10, promptAlpha, 1)
        else
            promptAlpha = Lerp(FrameTime() * 10, promptAlpha, 0)
        end

        if promptAlpha > 0.01 then
            local x, y = ScrW() / 2, ScrH() / 2 + He(150)
            local alpha = promptAlpha * 255

            surface.SetMaterial(radioIcon)
            surface.SetDrawColor(255, 255, 255, alpha * 0.8)
            surface.DrawTexturedRect(x - We(24), y - He(65), We(48), He(48))

            parsed_prompt = parsed_prompt or markup.Parse(string.format(
                "<font=RoN_Font_Medium><colour=255,0,0>%s [</colour><colour=255,255,255>E</colour><colour=255,0,0>]</colour></font>",
                MuR.Language["mode14_report_body"] or "REPORT BODY"))
            parsed_prompt:Draw(x, y, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, alpha)
        end

        local centerX = ScrW() / 2
        local startY = ScrH() / 2 + He(160)

        local notifications = EnsureMode14ClientState().Notifications

        for i = #notifications, 1, -1 do
            local v = notifications[i]
            local isExpired = v.time < CurTime()
            v.fade = Lerp(FrameTime() * 8, v.fade, isExpired and 0 or 1)
            v.yOff = Lerp(FrameTime() * 8, v.yOff, (i - 1) * He(25))

            if isExpired and v.fade < 0.01 then
                table.remove(notifications, i)
                continue
            end

            if not v.parsed then
                local moneyText = ""
                if v.money > 0 then
                    moneyText = "+" .. v.money .. "$ "
                elseif v.money < 0 then
                    moneyText = v.money .. "$ "
                end

                v.parsed = markup.Parse(string.format(
                    "<font=RoN_Font_Medium><colour=255,255,255>%s</colour><colour=255,0,0>%s</colour></font>",
                    moneyText, v.msg))
            end

            v.parsed:Draw(centerX, startY + v.yOff, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, v.fade * 255)
        end
    end)

	local OBJ_COL_DONE = Color(140, 140, 140)
	local OBJ_COL_FAIL = Color(210, 70, 70)

	local function DrawObjectives(x, y)
		local defs = MuR.Mode14ObjectiveDefs
		if not defs then return end

		local objs = EnsureMode14ClientState().Objectives
		local lineHeight = He(26)

		draw.SimpleText(MuR.Language["mode14_objectives_title"] or "OBJECTIVES:",
			"RoN_Font_Medium", x, y, THEME.accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

		local yOffset = y + He(24)

		for idx, def in ipairs(defs) do
			local o = objs[idx]
			local state = o and o.state or 0
			local isDone = state == 1
			local isFailed = state == 2

			local show = def.primary or isDone or isFailed or (o and o.cur and o.cur > 0)
			if show then
				local label = MuR.Language[def.lang] or def.fallback or def.id
				local text = "• " .. label

				if def.counter and o and o.max and o.max > 0 then
					text = text .. "  " .. o.cur .. "/" .. o.max
				end

				local col = THEME.text
				if isFailed then
					col = OBJ_COL_FAIL
				elseif isDone then
					col = OBJ_COL_DONE
				elseif not def.primary then
					col = THEME.textDim
				end

				draw.SimpleText(text, "RoN_Font_Small", x, yOffset, col,
					TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

				if isDone or isFailed then
					surface.SetFont("RoN_Font_Small")
					local textW, textH = surface.GetTextSize(text)
					local progress = math.Clamp((CurTime() - (o.changedAt or 0)) / 0.5, 0, 1)

					surface.SetDrawColor(isFailed and OBJ_COL_FAIL or THEME.danger)
					surface.DrawRect(x, yOffset + textH / 2, textW * progress, 2)
				end

				yOffset = yOffset + lineHeight
			end
		end
	end

	local function DrawReinforcementStatus(x, y)
		local ply = LocalPlayer()
		if not IsValid(ply) then return end

		if ply:Alive() then return end

		local queuePos = ply:GetNW2Int("MuR_RoNQueuePos", 0)

		if queuePos > 0 then
			local boxWidth = We(300)
			local boxHeight = He(60)
			local drawX, drawY = ScrW()/2 - boxWidth/2, He(150)

			draw.RoundedBox(4, drawX, drawY, boxWidth, boxHeight, THEME.bg)
			draw.SimpleText(MuR.Language["mode14_waiting_deployment"] or "WAITING FOR DEPLOYMENT", "RoN_Font_Medium", drawX + boxWidth/2, drawY + He(15), THEME.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
			draw.SimpleText((MuR.Language["mode14_queue_position"] or "In queue: ") .. queuePos, "RoN_Font_Small", drawX + boxWidth/2, drawY + He(35), THEME.accent, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		end
	end

	local results = nil

	net.Receive("MuR.Mode14Results", function()
		local r = {
			success = net.ReadBool(),
			grade = net.ReadString(),
			score = net.ReadInt(32),
			rows = {},
			objectives = {},
			shownAt = CurTime(),
		}

		local rowCount = net.ReadUInt(8)
		for _ = 1, rowCount do
			local key = net.ReadString()
			local count = net.ReadUInt(8)
			r.rows[#r.rows + 1] = {key = key, count = count}
		end

		local objCount = net.ReadUInt(8)
		for _ = 1, objCount do
			local idx = net.ReadUInt(8)
			local state = net.ReadUInt(2)
			r.objectives[idx] = state
		end

		results = r
	end)

	local GRADE_COLORS = {
		S = Color(255, 215, 0),
		A = Color(120, 220, 120),
		B = Color(120, 190, 240),
		C = Color(230, 190, 110),
		D = Color(220, 90, 90),
	}

	local function DrawMissionResults()
		if not results then return end

		local age = CurTime() - results.shownAt
		if age > 15 then results = nil return end

		local fade = math.Clamp(age / 0.6, 0, 1) * math.Clamp((15 - age) / 1.5, 0, 1)
		if fade <= 0.01 then return end

		local w, h = We(560), He(440)
		local x, y = ScrW() / 2 - w / 2, ScrH() / 2 - h / 2
		local a = fade * 255

		draw.RoundedBox(6, x, y, w, h, Color(0, 0, 0, 230 * fade))
		surface.SetDrawColor(THEME.accent.r, THEME.accent.g, THEME.accent.b, a)
		surface.DrawOutlinedRect(x, y, w, h, 2)

		local title = results.success
			and (MuR.Language["mode14_mission_success"] or "MISSION COMPLETE")
			or (MuR.Language["mode14_mission_failed"] or "MISSION FAILED")

		draw.SimpleText(title, "RoN_Font_Large", x + w / 2, y + He(24),
			Color(results.success and 255 or 255, results.success and 255 or 90,
				results.success and 255 or 90, a),
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		local gc = GRADE_COLORS[results.grade] or THEME.text
		draw.SimpleText(results.grade, "RoN_Font_Big", x + w / 2, y + He(84),
			Color(gc.r, gc.g, gc.b, a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		draw.SimpleText((MuR.Language["mode14_score"] or "SCORE") .. ": " .. results.score,
			"RoN_Font_Medium", x + w / 2, y + He(124),
			Color(THEME.text.r, THEME.text.g, THEME.text.b, a),
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		local ly = y + He(160)

		for idx, def in ipairs(MuR.Mode14ObjectiveDefs) do
			local state = results.objectives[idx] or 0
			local mark = state == 1 and "[+]" or (state == 2 and "[x]" or "[ ]")
			local col = state == 1 and THEME.health or (state == 2 and THEME.danger or THEME.textDim)
			local label = MuR.Language[def.lang] or def.fallback or def.id

			draw.SimpleText(mark .. " " .. label, "RoN_Font_Small", x + We(28), ly,
				Color(col.r, col.g, col.b, a), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			ly = ly + He(20)
		end

		ly = ly + He(12)
		surface.SetDrawColor(THEME.accent.r, THEME.accent.g, THEME.accent.b, a * 0.5)
		surface.DrawRect(x + We(28), ly, w - We(56), 1)
		ly = ly + He(12)

		for _, row in ipairs(results.rows) do
			local def = MuR.Mode14ScoreDefs[row.key]
			if def then
				local label = MuR.Language[def.lang] or row.key
				local subtotal = def.points * row.count
				local col = subtotal >= 0 and THEME.text or THEME.danger

				draw.SimpleText(label .. "  x" .. row.count, "RoN_Font_Small",
					x + We(28), ly, Color(col.r, col.g, col.b, a),
					TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

				draw.SimpleText((subtotal >= 0 and "+" or "") .. subtotal, "RoN_Font_Small",
					x + w - We(28), ly, Color(col.r, col.g, col.b, a),
					TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

				ly = ly + He(18)
			end
		end
	end

	local briefingOpen = false

	concommand.Add("mur_ron_briefing", function()
		if MuR.GamemodeCount != 14 then return end
		briefingOpen = not briefingOpen
	end)

	local function DrawBriefing()
		if not briefingOpen then return end

		local w, h = We(620), He(500)
		local x, y = ScrW() / 2 - w / 2, ScrH() / 2 - h / 2

		draw.RoundedBox(6, x, y, w, h, Color(0, 0, 0, 235))
		surface.SetDrawColor(THEME.accent)
		surface.DrawOutlinedRect(x, y, w, h, 2)

		draw.SimpleText(MuR.Language["mode14_briefing_title"] or "MISSION BRIEFING",
			"RoN_Font_Large", x + w / 2, y + He(24), THEME.accent,
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		draw.SimpleText(game.GetMap(), "RoN_Font_Small", x + w / 2, y + He(50),
			THEME.textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		local ly = y + He(80)
		draw.SimpleText(MuR.Language["mode14_objectives_title"] or "OBJECTIVES:",
			"RoN_Font_Medium", x + We(28), ly, THEME.accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		ly = ly + He(26)

		local objs = EnsureMode14ClientState().Objectives
		for idx, def in ipairs(MuR.Mode14ObjectiveDefs) do
			local o = objs[idx]
			local state = o and o.state or 0
			local label = MuR.Language[def.lang] or def.fallback or def.id

			if def.counter and o and o.max and o.max > 0 then
				label = label .. "  " .. o.cur .. "/" .. o.max
			end
			if not def.primary then
				label = label .. "  (" .. (MuR.Language["mode14_optional"] or "optional") .. ")"
			end

			local col = state == 1 and THEME.health or (state == 2 and THEME.danger or THEME.text)
			draw.SimpleText("• " .. label, "RoN_Font_Small", x + We(36), ly, col,
				TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			ly = ly + He(20)
		end

		ly = ly + He(16)
		draw.SimpleText(MuR.Language["mode14_scoring_title"] or "SCORING:",
			"RoN_Font_Medium", x + We(28), ly, THEME.accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		ly = ly + He(26)

		local order = {
			"suspect_arrested", "civilian_secured",
			"suspect_killed", "body_reported", "trap_disarmed",
			"suspect_killed_surrendering", "civilian_killed", "officer_down",
		}

		for _, key in ipairs(order) do
			local def = MuR.Mode14ScoreDefs[key]
			if def then
				local label = MuR.Language[def.lang] or key
				local col = def.points >= 0 and THEME.textDim or THEME.danger

				draw.SimpleText(label, "RoN_Font_Small", x + We(36), ly, col,
					TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
				draw.SimpleText((def.points >= 0 and "+" or "") .. def.points,
					"RoN_Font_Small", x + w - We(36), ly, col,
					TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
				ly = ly + He(18)
			end
		end
	end

	hook.Add("HUDPaint", "MuR.Mode14HUD", function()
		if MuR.GamemodeCount != 14 then return end

		local ply = LocalPlayer()
		if not IsValid(ply) then return end

		DrawMissionResults()
		DrawBriefing()

		if not MuR.DrawHUD or MuR:GetClient("blsd_nohud") then return end

		DrawScanlines()

		if ply:Alive() then
			DrawCompass(ScrW()/2, He(10), We(400))
			DrawHealthArmor(We(20), ScrH() - He(60))
			DrawTeammates(We(20), He(150))
			DrawMissionTimer(ScrW()/2, He(50))
			DrawObjectives(We(20), He(10))
		else
			DrawReinforcementStatus()
		end
	end)
end
