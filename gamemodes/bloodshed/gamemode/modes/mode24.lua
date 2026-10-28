MuR.RegisterMode(24, {
	name = "Last Stand - Ambush",
	chance = 10,
	need_players = 1,
	disables = true,
	disables_police = true,
	disable_loot = true,
	no_default_roles = true,
	no_guilt = true,
	custom_spawning = true,
	custom_spawning_func = "Mode24SpawnPlayers",

	OnModeStarted = function(mode)
		if SERVER then MuR:Mode24Start() end
	end,

	OnModeThink = function(mode)
		if SERVER then MuR:Mode24Think() end
	end,

	OnModeEnded = function(mode)
		if SERVER then MuR:Mode24End() end
	end
})

if SERVER then
	local WAVE_PREP_FIRST = 60
	local WAVE_PREP_BETWEEN = 45
	local SPAWN_MIN_DIST, SPAWN_MAX_DIST = 1200, 3200
	local MODE24_MED_POOL = {"mur_loot_bandage", "mur_loot_tourniquet", "mur_loot_medkit", "mur_morphine", "mur_loot_adrenaline"}
	local COMMANDER_START_POINTS = 1000

	-- Награда отряду за закрытую волну: 500 за первую, дальше плюс 250 за каждую.
	local WAVE_REWARD_BASE, WAVE_REWARD_STEP = 500, 250
	-- Сколько стоит поднять одного павшего по рации.
	local REINFORCE_PRICE = 500

	util.AddNetworkString("MuR.Mode24Radio")
	util.AddNetworkString("MuR.Mode24Reinforce")

	-- Наёмники переехали на собственную nextbot-базу; стволы теперь настоящие
	-- TFA-классы, а не один SWEP-хамелеон weapon_vj_bloodshed_sus_primary.
	local PMC_RIFLES = {"tfa_bs_acr", "tfa_bs_hk416", "tfa_bs_m4a1", "tfa_bs_mp5a5"}
	local PMC_HEAVY = {"tfa_bs_sr25", "tfa_bs_m24", "tfa_bs_m1014"}

	local PMC_ENEMY_CLASSES = {
		{class = "npc_bs_pmc", unlock = 1, weight = 55, weapons = PMC_RIFLES},
		{class = "npc_bs_pmc_armored", unlock = 2, weight = 20, weapons = PMC_RIFLES},
		{class = "npc_bs_pmc_explosive", unlock = 3, weight = 10, weapons = PMC_RIFLES},
		{class = "npc_bs_pmc_juggernaut", unlock = 4, weight = 6, weapons = PMC_HEAVY},
		{class = "npc_bs_pmc_flame", unlock = 5, weight = 10, weapons = PMC_RIFLES},
		{class = "npc_bs_pmc_gas", unlock = 6, weight = 10, weapons = PMC_RIFLES},
	}

	local function PickPMCClass(wave)
		local pool, total = {}, 0
		for _, v in ipairs(PMC_ENEMY_CLASSES) do
			if wave >= v.unlock then
				pool[#pool + 1] = v
				total = total + v.weight
			end
		end
		if #pool == 0 then return PMC_ENEMY_CLASSES[1] end

		local roll = math.random() * total
		local acc = 0
		for _, v in ipairs(pool) do
			acc = acc + v.weight
			if roll <= acc then return v end
		end

		return pool[#pool]
	end

	--
	-- Множитель РАЗБРОСА по онлайну: больше — хуже стрелок.
	--
	-- Прежняя кривая начиналась с 4 на соло и это оказалось мало: одиночный
	-- игрок жаловался, что наёмники играют как живые. Разброс у TFA задан в
	-- долях радиана и сам по себе крошечный, так что четырёхкратный остаётся
	-- почти снайперским на средней дистанции.
	--
	-- Теперь соло начинается с 9 и падает до 1.5 к восьми игрокам: в толпе
	-- каждый ствол должен быть опасным, в одиночку — нет.
	--
	local ACC_SOLO, ACC_FULL, ACC_FULL_AT = 9, 1.5, 8

	local function PMCAccuracyForPlayerCount()
		local online = math.Clamp(player.GetCount(), 1, ACC_FULL_AT)
		local t = (online - 1) / (ACC_FULL_AT - 1)

		return Lerp(t, ACC_SOLO, ACC_FULL)
	end

	function MuR:Mode24Start()
		MuR.Mode24 = {
			Commander = nil,
			Wave = 0,
			Phase = "prep",
			PhaseEnd = CurTime() + WAVE_PREP_FIRST,
			AliveNPCs = 0,
			TotalToSpawn = 0,
			SpawnedThisWave = 0,
			Ending = false
		}
	end

	function MuR:Mode24SpawnPlayers()
		if MuR.Gamemode ~= 24 then return end
		if not MuR.Mode24 then MuR.Mode24 = {} end

		local tab = {}
		for _, ply in player.Iterator() do
			tab[#tab + 1] = ply
		end
		if #tab == 0 then return end

		table.Shuffle(tab)
		local commander = tab[1]
		MuR.Mode24.Commander = commander

		local spawnPos = MuR:GetRandomPos(false) or MuR:GetRandomPos(true) or MuR:GetRandomPos()

		local function launch(ply, class)
			if not IsValid(ply) then return end

			ply:SetNW2String("Class", class)
			ply:SetTeam(1)
			ply.ForceSpawn = true
			ply:Spawn()
			ply:Freeze(true)
			ply:GodEnable()

			if isvector(spawnPos) then
				local offset = VectorRand() * 80
				offset.z = 0
				ply:SetPos(spawnPos + offset + Vector(0, 0, 10))
			end

			timer.Simple(12, function()
				if not IsValid(ply) then return end
				ply:Freeze(false)
				ply:GodDisable()
			end)
		end

		launch(commander, "PMCCommander")
		commander:SetNWInt("MuR_Mode24Points", COMMANDER_START_POINTS)

		for i = 2, #tab do
			launch(tab[i], "PMCSoldier")
		end
	end

	--
	-- Командование переходит живому, если прежний командир не пережил волну.
	--
	-- Без этого отряд оставался без магазина до конца игры: очки начисляются
	-- командиру, покупать может только он, а мёртвый не может ни того, ни другого.
	--
	-- Возвращает нового командира либо nil, если менять некого или незачем.
	--
	function MuR:Mode24PromoteCommander()
		local M = MuR.Mode24
		if not M then return nil end

		local old = M.Commander
		if IsValid(old) and old:Alive() then return nil end

		local pool = {}
		for _, ply in player.Iterator() do
			if ply ~= old and ply:Alive() and ply:Team() == 1 then
				pool[#pool + 1] = ply
			end
		end

		if #pool == 0 then return nil end

		local heir = pool[math.random(#pool)]

		--
		-- Очки — ресурс ОТРЯДА, а не личный, поэтому переходят вместе с
		-- должностью. Иначе смерть командира стоила бы отряду всей казны.
		--
		local points = IsValid(old) and old:GetNWInt("MuR_Mode24Points", 0) or 0
		if IsValid(old) then old:SetNWInt("MuR_Mode24Points", 0) end

		M.Commander = heir
		heir:SetNW2String("Class", "PMCCommander")
		heir:SetNWInt("MuR_Mode24Points", heir:GetNWInt("MuR_Mode24Points", 0) + points)

		MuR:GiveAnnounce("mode24_new_commander", heir)

		return heir
	end

	function MuR:Mode24GetSquadCenter()
		local sum, count = Vector(0, 0, 0), 0
		for _, ply in player.Iterator() do
			if ply:Alive() then
				sum = sum + ply:GetPos()
				count = count + 1
			end
		end

		if count == 0 then
			return IsValid(MuR.Mode24.Commander) and MuR.Mode24.Commander:GetPos() or Vector(0, 0, 0)
		end

		return sum / count
	end

	function MuR:Mode24PickSpawnPos(center)
		local wantIndoor = math.random(1, 100) <= 10
		local pos = MuR:GetRandomPos(wantIndoor, center, SPAWN_MIN_DIST, SPAWN_MAX_DIST)

		if not isvector(pos) then
			pos = MuR:GetRandomPos(nil, center, SPAWN_MIN_DIST, SPAWN_MAX_DIST)
		end
		if not isvector(pos) then
			pos = MuR:GetRandomPos(false)
		end

		return pos
	end

	function MuR:Mode24SpawnOneNPC(pos)
		local pick = PickPMCClass(MuR.Mode24.Wave)

		local npc = ents.Create(pick.class)
		if not IsValid(npc) then return end

		npc:SetPos(pos)
		npc:SetAngles(Angle(0, math.random(0, 360), 0))
		npc:Spawn()
		npc:Activate()

		-- Give только ПОСЛЕ Spawn: у своей базы оружие создаётся отдельной
		-- сущностью и вешается на attachment, которого до спавна ещё нет.
		npc:Give(pick.weapons[math.random(#pick.weapons)])

		npc.IsMode24Wave = true
		npc.Mode24WaveNumber = MuR.Mode24.Wave
		npc.Weapon_Accuracy = PMCAccuracyForPlayerCount() * (npc.PMCAccuracyMul or 1)

		timer.Simple(2, function()
			if not IsValid(npc) then return end
			local wanderPos = MuR:GetRandomPos(tobool(math.random(0, 7)))
			if isvector(wanderPos) then
				-- Свой nextbot: SetLastPosition/SetSchedule у него нет.
				npc:OrderMove(wanderPos, {run = true})
			end
		end)

		MuR.Mode24.AliveNPCs = MuR.Mode24.AliveNPCs + 1
	end

	--
	-- Выпуск волны.
	--
	-- Таймер бесконечный, а не «ровно TotalToSpawn срабатываний»: при упёртом
	-- потолке живых такт пропускается, и с конечным числом повторов остаток
	-- волны просто потерялся бы — волна закрылась бы, не выпустив всех.
	--
	-- Центр отряда пересчитывается каждый раз: волна теперь может тянуться
	-- минутами, а отряд за это время уходит с места.
	--
	function MuR:Mode24SpawnWaveBatch()
		timer.Remove("Mode24WaveSpawn")

		timer.Create("Mode24WaveSpawn", 0.35, 0, function()
			local M = MuR.Mode24

			if not M or MuR.Gamemode ~= 24 then
				timer.Remove("Mode24WaveSpawn")
				return
			end

			if M.SpawnedThisWave >= M.TotalToSpawn then
				timer.Remove("Mode24WaveSpawn")
				return
			end

			if M.AliveNPCs >= MuR:GetMaxNPCs(M.Wave) then return end

			local pos = MuR:Mode24PickSpawnPos(MuR:Mode24GetSquadCenter())
			if not isvector(pos) then return end

			MuR:Mode24SpawnOneNPC(pos)
			M.SpawnedThisWave = M.SpawnedThisWave + 1
		end)
	end

	function MuR:Mode24StartWave()
		local M = MuR.Mode24
		M.Wave = M.Wave + 1
		M.Phase = "combat"
		M.PhaseEnd = 0

		local playerCount = math.max(1, player.GetCount())
		M.TotalToSpawn = math.floor(4 + playerCount * 2 + (M.Wave - 1) * 1.5)
		M.SpawnedThisWave = 0
		M.AliveNPCs = 0

		MuR:Mode24SpawnWaveBatch()
	end

	function MuR:Mode24EndWave()
		local M = MuR.Mode24
		M.Phase = "prep"
		M.PhaseEnd = CurTime() + WAVE_PREP_BETWEEN

		-- Сначала командир, потом награда: если прежний не дожил, начислять
		-- надо уже новому, иначе деньги уйдут в мертвеца.
		MuR:Mode24PromoteCommander()

		local commander = M.Commander
		if not IsValid(commander) then return end

		local reward = WAVE_REWARD_BASE + math.max(0, M.Wave - 1) * WAVE_REWARD_STEP
		commander:SetNWInt("MuR_Mode24Points", commander:GetNWInt("MuR_Mode24Points", 0) + reward)

		MuR:GiveAnnounce("mode24_wave_reward", commander)
	end

	function MuR:Mode24Think()
		local M = MuR.Mode24
		if not M or M.Ending then return end

		local anyActive = false
		for _, ply in player.Iterator() do
			if ply:IsCombatEffective() then
				anyActive = true
				break
			end
		end

		if anyActive then
			MuR.Delay_Before_Lose = CurTime() + 12
			M.LossPending = nil
		else
			M.LossPending = M.LossPending or (CurTime() + 5)
			if CurTime() < M.LossPending then return end

			M.Ending = true
			MuR.Ending = true
			MuR.TimeBeforeStart = CurTime() + 17
			MuR.PoliceState = 0
			MuR:ShowFinalScreen("pmc_wiped", false)
			return
		end

		if M.Phase == "prep" then
			if CurTime() >= M.PhaseEnd then
				MuR:Mode24StartWave()
			end
			return
		end

		if M.Phase == "combat" and M.AliveNPCs <= 0 and M.SpawnedThisWave >= M.TotalToSpawn then
			MuR:Mode24EndWave()
		end
	end

	function MuR:Mode24End()
		timer.Remove("Mode24WaveSpawn")

		for npc in pairs(MuR.PMCEnemies or {}) do
			if IsValid(npc) and npc.IsMode24Wave then
				npc:Remove()
			end
		end

		MuR.Mode24 = nil
	end

	-- Кого вообще можно поднять: свои, не в игре, не сам покупатель.
	local function reinforceCandidates(buyer)
		local out = {}

		for _, ply in player.Iterator() do
			if ply ~= buyer and not ply:Alive() then
				out[#out + 1] = ply
			end
		end

		return out
	end

	--
	-- Рация открывает МЕНЮ, а не поднимает первого попавшегося.
	--
	-- Раньше выбор был за кодом: он брал первого мёртвого из player.Iterator, то
	-- есть по сути случайного, и командир не мог решить, кто ему нужнее — медик
	-- или пулемётчик.
	--
	function MuR:Mode24OpenRadio(buyer)
		if not IsValid(buyer) then return end

		local list = reinforceCandidates(buyer)

		if #list == 0 then
			MuR:GiveAnnounce("mode24_no_reinforcement", buyer)
			return
		end

		net.Start("MuR.Mode24Radio")
		net.WriteUInt(REINFORCE_PRICE, 32)
		net.WriteUInt(#list, 8)
		for _, ply in ipairs(list) do
			net.WriteEntity(ply)
		end
		net.Send(buyer)
	end

	function MuR:Mode24Revive(target, buyer)
		if not IsValid(target) then return false end

		target:SetNW2String("Class", "PMCSoldier")
		target:SetTeam(1)
		target.ForceSpawn = true
		target:Spawn()

		if IsValid(buyer) then
			local offset = VectorRand() * 60
			offset.z = 0
			target:SetPos(buyer:GetPos() + offset + Vector(0, 0, 10))
		end

		return true
	end

	net.Receive("MuR.Mode24Reinforce", function(len, ply)
		if MuR.Gamemode ~= 24 or not MuR.Mode24 then return end
		if not IsValid(ply) or not ply:Alive() then return end

		-- Платит и решает только командир: очки лежат на нём.
		if MuR.Mode24.Commander ~= ply then return end

		if CurTime() < (ply.Mode24ReinforceDelay or 0) then return end
		ply.Mode24ReinforceDelay = CurTime() + 1

		local target = net.ReadEntity()
		if not IsValid(target) or not target:IsPlayer() then return end
		if target == ply or target:Alive() then return end

		local points = ply:GetNWInt("MuR_Mode24Points", 0)
		if points < REINFORCE_PRICE then return end

		if not MuR:Mode24Revive(target, ply) then return end

		ply:SetNWInt("MuR_Mode24Points", points - REINFORCE_PRICE)
	end)

	function MuR:Mode24DropAmmo(buyer)
		if not IsValid(buyer) then return end
		local pos = buyer:GetPos()

		for i = 1, 8 do
			local offset = VectorRand() * 60
			offset.z = 0
			local ent = ents.Create("mur_loot_ammo")
			if IsValid(ent) then
				ent:SetPos(pos + offset + Vector(0, 0, 10))
				ent:Spawn()
			end
		end
	end

	function MuR:Mode24DropMedkits(buyer)
		if not IsValid(buyer) then return end
		local pos = buyer:GetPos()

		for i = 1, 10 do
			local offset = VectorRand() * 70
			offset.z = 0
			local class = MODE24_MED_POOL[math.random(#MODE24_MED_POOL)]
			local ent = ents.Create(class)
			if IsValid(ent) then
				ent:SetPos(pos + offset + Vector(0, 0, 10))
				ent:Spawn()
			end
		end
	end

	hook.Add("OnNPCKilled", "MuR_Mode24_Points", function(npc, attacker, inflictor)
		if MuR.Gamemode ~= 24 or not MuR.Mode24 or not npc.IsMode24Wave then return end

		npc.Mode24Counted = true
		MuR.Mode24.AliveNPCs = math.max(0, MuR.Mode24.AliveNPCs - 1)

		if not (IsValid(attacker) and attacker:IsPlayer()) then return end

		local commander = MuR.Mode24.Commander
		if not IsValid(commander) then return end

		local wave = npc.Mode24WaveNumber or MuR.Mode24.Wave
		local reward = 75 + wave * 25
		commander:SetNWInt("MuR_Mode24Points", commander:GetNWInt("MuR_Mode24Points", 0) + reward)
	end)

	hook.Add("EntityRemoved", "MuR_Mode24_Removed", function(npc)
		if MuR.Gamemode ~= 24 or not MuR.Mode24 or not npc.IsMode24Wave then return end
		if npc.Mode24Counted then return end

		MuR.Mode24.AliveNPCs = math.max(0, MuR.Mode24.AliveNPCs - 1)
	end)
end
