util.AddNetworkString("MuR.TrapOpen")
util.AddNetworkString("MuR.TrapBuild")
util.AddNetworkString("MuR.TrapCancel")
util.AddNetworkString("MuR.TrapNotify")
util.AddNetworkString("MuR.TrapSpec")
util.AddNetworkString("MuR.TrapProximity")
util.AddNetworkString("MuR.TrapReadyBP")

local T = MuR.Traps

local PLANT_TIME = 1.6

function T:Notify(ply, key)
	if not IsValid(ply) or not ply:IsPlayer() then return end

	net.Start("MuR.TrapNotify")
	net.WriteString(key)
	net.Send(ply)
end

-- Клиенту нужен состав готового устройства, иначе призрак нечем рисовать.
function T:SendReady(ply, bp)
	net.Start("MuR.TrapReadyBP")
	net.WriteString(bp and bp.sensor or "")
	net.WriteString(bp and bp.vector or "")
	net.WriteString(bp and bp.payload or "")
	net.Send(ply)
end

function T:CountActive(ply)
	ply.MuR_ActiveTraps = ply.MuR_ActiveTraps or {}

	local count = 0

	for ent in pairs(ply.MuR_ActiveTraps) do
		if IsValid(ent) then
			count = count + 1
		else
			ply.MuR_ActiveTraps[ent] = nil
		end
	end

	return count
end

local function holdingKit(ply)
	local wep = ply:GetActiveWeapon()
	return IsValid(wep) and wep:GetClass() == "mur_trap_kit"
end

--[[ ------------------------------------------------------------------
	Открытие конструктора
------------------------------------------------------------------ ]]--

concommand.Add("mur_open_traps", function(ply)
	if not IsValid(ply) or not ply:Alive() then return end
	if not MuR:NetRateLimit(ply, "trap_open", 0.5) then return end
	if not holdingKit(ply) then return end

	T:BuildChemPayloads()

	-- Какие химические начинки игрок реально несёт с собой.
	local carried = {}

	for _, id in ipairs(T.PayloadList) do
		local payload = T.Payloads[id]
		if payload.weapon and ply:HasWeapon(payload.weapon) then
			carried[id] = true
		end
	end

	net.Start("MuR.TrapOpen")
	net.WriteString(T:GetTier(ply))
	net.WriteUInt(T:CountActive(ply), 4)
	net.WriteTable(carried)
	net.Send(ply)
end)

--[[ ------------------------------------------------------------------
	Шаг второй: изготовление. Занимает время, прерывается сменой оружия,
	падением в реалдолл и смертью.
------------------------------------------------------------------ ]]--

local function assemblyTimer(ply)
	return "MuR_TrapAssemble_" .. ply:EntIndex()
end

function T:StopAssembly(ply, refund)
	if not IsValid(ply) then return end

	timer.Remove(assemblyTimer(ply))

	local pending = ply.MuR_TrapAssembly
	ply.MuR_TrapAssembly = nil

	ply:SetNW2Float("MuR_TrapAssembleStart", 0)
	ply:SetNW2Float("MuR_TrapAssembleEnd", 0)

	if refund and pending and pending.consumed then
		ply:GiveWeapon(pending.consumed, true)
	end
end

net.Receive("MuR.TrapCancel", function(_, ply)
	if not IsValid(ply) then return end
	if not MuR:NetRateLimit(ply, "trap_cancel", 0.3) then return end
	if not ply.MuR_TrapAssembly then return end

	T:StopAssembly(ply, true)
	T:Notify(ply, "trap_msg_cancelled")
end)

net.Receive("MuR.TrapBuild", function(_, ply)
	if not IsValid(ply) or not ply:Alive() then return end
	if not MuR:NetRateLimit(ply, "trap_build", 1) then return end
	if not holdingKit(ply) then return end

	local bp = {
		sensor = net.ReadString(),
		vector = net.ReadString(),
		payload = net.ReadString(),
		mods = {},
	}

	local modCount = net.ReadUInt(4)
	for i = 1, math.min(modCount, #T.ModList) do
		bp.mods[i] = net.ReadString()
	end

	if ply.MuR_TrapAssembly then
		T:Notify(ply, "trap_err_busy")
		return
	end

	if ply.MuR_TrapBlueprint then
		T:Notify(ply, "trap_err_already")
		return
	end

	if IsValid(ply:GetRD()) then
		T:Notify(ply, "trap_err_ragdoll")
		return
	end

	local ok, err = T:Validate(ply, bp)
	if not ok then
		T:Notify(ply, err or "trap_err_broken")
		return
	end

	-- Химия расходует реальный предмет: вещество физически закладывается внутрь.
	local payload = T.Payloads[bp.payload]
	local consumed

	if payload.weapon then
		if not ply:HasWeapon(payload.weapon) then
			T:Notify(ply, "trap_err_noitem")
			return
		end

		ply:StripWeapon(payload.weapon)
		consumed = payload.weapon
	end

	local duration = T:AssembleTime(bp)

	ply.MuR_TrapAssembly = {bp = bp, consumed = consumed}
	ply:SetNW2Float("MuR_TrapAssembleStart", CurTime())
	ply:SetNW2Float("MuR_TrapAssembleEnd", CurTime() + duration)
	ply:EmitSound("murdered/items/ducttape_use.wav", 55, 100)

	timer.Create(assemblyTimer(ply), duration, 1, function()
		if not IsValid(ply) or not ply.MuR_TrapAssembly then return end

		local pending = ply.MuR_TrapAssembly

		T:StopAssembly(ply, false)

		ply.MuR_TrapBlueprint = pending.bp
		ply:SetNW2Bool("MuR_TrapReady", true)
		T:SendReady(ply, pending.bp)
		ply:EmitSound("buttons/button9.wav", 55, 105)
		T:Notify(ply, "trap_msg_built")
	end)
end)

-- Сборка срывается, если игрок перестал быть в состоянии её вести.
timer.Create("MuR.TrapAssemblyWatch", 0.25, 0, function()
	for _, ply in player.Iterator() do
		if not ply.MuR_TrapAssembly then continue end

		if not ply:Alive() or not holdingKit(ply) or IsValid(ply:GetRD()) then
			T:StopAssembly(ply, true)
			T:Notify(ply, "trap_msg_interrupted")
		end
	end
end)

--[[ ------------------------------------------------------------------
	Шаг третий: установка удержанием. Пока вы ставите, вы беззащитны.
------------------------------------------------------------------ ]]--

function T:StopPlant(ply)
	if not IsValid(ply) then return end

	ply.MuR_TrapPlanting = nil
	ply:SetNW2Float("MuR_TrapPlantStart", 0)
	ply:SetNW2Float("MuR_TrapPlantEnd", 0)
end


--[[ ------------------------------------------------------------------
	Второй конец растяжки игрок закрепляет сам: куда протянуть нить —
	его решение, а не автоматическая трассировка вбок.
------------------------------------------------------------------ ]]--

function T:AnchorThink(ply, holding)
	local trap = ply.MuR_TrapAnchoring

	if not IsValid(trap) then
		ply.MuR_TrapAnchoring = nil
		return false
	end

	if not holding then return true end
	if CurTime() < (ply.MuR_TrapAnchorCooldown or 0) then return true end

	ply.MuR_TrapAnchorCooldown = CurTime() + 0.6

	local hit, reason = self:AnchorTrace(ply, trap:TripOrigin())

	if reason then
		self:Notify(ply, reason)
		return true
	end

	trap:AnchorTo(hit)
	ply.MuR_TrapAnchoring = nil
	ply:SetNW2Bool("MuR_TrapAnchoring", false)
	self:Notify(ply, "trap_msg_anchored")

	return true
end

function T:PlantThink(ply, holding)
	if not IsValid(ply) or not ply:Alive() then return end

	-- Пока висит незакреплённая растяжка, ЛКМ занята ею.
	if ply.MuR_TrapAnchoring and self:AnchorThink(ply, holding) then return end

	local state = ply.MuR_TrapPlanting

	if not holding then
		if state then self:StopPlant(ply) end
		return
	end

	if not state then
		if not ply.MuR_TrapBlueprint then return end
		if CurTime() < (ply.MuR_TrapPlantCooldown or 0) then return end

		local _, _, err = self:PlantTrace(ply, ply.MuR_TrapBlueprint)
		if err then
			self:StopPlant(ply)
			return
		end

		ply.MuR_TrapPlanting = true
		ply:SetNW2Float("MuR_TrapPlantStart", CurTime())
		ply:SetNW2Float("MuR_TrapPlantEnd", CurTime() + PLANT_TIME)
		return
	end

	if CurTime() < ply:GetNW2Float("MuR_TrapPlantEnd", 0) then
		-- Отвели прицел от поверхности — установка срывается.
		local _, _, err = self:PlantTrace(ply, ply.MuR_TrapBlueprint)
		if err then self:StopPlant(ply) end
		return
	end

	self:StopPlant(ply)

	-- Не вышло — короткая пауза, иначе зажатая кнопка зациклит уведомления.
	if not self:Place(ply) then
		ply.MuR_TrapPlantCooldown = CurTime() + 2
	end
end

function T:Place(ply)
	if not IsValid(ply) or not ply:Alive() then return false end

	local bp = ply.MuR_TrapBlueprint
	if not bp then
		self:Notify(ply, "trap_err_nodevice")
		return false
	end

	local profile = self:GetProfile(ply)
	if self:CountActive(ply) >= profile.maxActive then
		self:Notify(ply, "trap_err_limit")
		return false
	end

	local tr, host, err = self:PlantTrace(ply, ply.MuR_TrapBlueprint)
	if err then
		self:Notify(ply, err)
		return false
	end

	local trap = ents.Create("mur_trap")
	if not IsValid(trap) then return false end

	local pos, ang = self:PlantTransform(tr)
	trap:SetPos(pos)
	trap:SetAngles(ang)
	trap:Spawn()
	trap:Configure(bp, ply, host)

	ply.MuR_ActiveTraps = ply.MuR_ActiveTraps or {}
	ply.MuR_ActiveTraps[trap] = true
	ply.MuR_TrapBlueprint = nil
	ply:SetNW2Bool("MuR_TrapReady", false)
	self:SendReady(ply, nil)

	-- Индекс, а не Entity: клиент может ещё не знать о только что созданной энтити.
	net.Start("MuR.TrapSpec")
	net.WriteUInt(trap:EntIndex(), 13)
	net.WriteString(bp.sensor)
	net.WriteString(bp.vector)
	net.WriteString(bp.payload)
	net.Send(ply)

	if trap.NeedsAnchor then
		ply.MuR_TrapAnchoring = trap
		ply.MuR_TrapAnchorCooldown = CurTime() + 0.6
		ply:SetNW2Bool("MuR_TrapAnchoring", true)
		self:Notify(ply, "trap_msg_needanchor")
	else
		self:Notify(ply, "trap_msg_placed")
	end

	return true
end

--[[ ------------------------------------------------------------------
	Радиодетонация
------------------------------------------------------------------ ]]--

function T:DetonateRemote(ply)
	if not IsValid(ply) then return false end

	local fired = false

	for trap in pairs(ply.MuR_ActiveTraps or {}) do
		if IsValid(trap) and trap:GetArmed() then
			local sensor = trap:GetSensorDef()
			if sensor and sensor.remote then
				trap.PendingVictim = MuR.Traps:FindVictim(trap, 320, false)
				trap:Trigger(trap.PendingVictim)
				fired = true
			end
		end
	end

	if not fired then
		self:Notify(ply, "trap_err_noremote")
	end

	return fired
end

--[[ ------------------------------------------------------------------
	Уборка
------------------------------------------------------------------ ]]--

local function resetPlayer(ply)
	if not IsValid(ply) then return end

	T:StopAssembly(ply, false)
	T:StopPlant(ply)

	ply.MuR_TrapBlueprint = nil
	ply.MuR_TrapAnchoring = nil
	ply:SetNW2Bool("MuR_TrapReady", false)
	ply:SetNW2Bool("MuR_TrapAnchoring", false)
	T:SendReady(ply, nil)
end

hook.Add("PlayerDeath", "MuR.TrapCleanupBlueprint", resetPlayer)
hook.Add("PlayerDisconnected", "MuR.TrapCleanupLeave", resetPlayer)

hook.Add("PlayerSpawn", "MuR.TrapResetState", function(ply)
	resetPlayer(ply)
	ply.MuR_ActiveTraps = {}
end)
