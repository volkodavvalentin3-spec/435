if not SERVER then return end

MuR = MuR or {}
MuR.Chem = MuR.Chem or {}

local Chem = MuR.Chem
local meta = FindMetaTable("Player")
if not meta then return end

util.AddNetworkString("MuR.SubstanceVisual")
util.AddNetworkString("MuR.SubstanceVisualClear")

local TICK_INTERVAL = 0.25

local TOLERANCE_BUILD = 0.18
local TOLERANCE_MAX = 0.7
local TOLERANCE_DECAY = 0.06
local TOLERANCE_INTERVAL = 3600

Chem.Tolerance = Chem.Tolerance or {}

local TOLERANCE_CATEGORIES = {
	opioid = true,
	stimulant = true,
	dissociative = true,
	sedative = true
}

local function defaultMods()
	return {
		BleedMul = 1,
		PerfusionMul = 1,
		DemandAdd = 0,
		CellularBlock = 0,
		RespDepression = 0,
		Analgesia = 0,
		Sedation = 0,
		StaminaMul = 1,
		CoordNoise = 0,
		HeartStrain = 0,
		PulseAdd = 0,
		ToxinClear = 0,
		ToxinResist = 0,
		StaminaFloor = 0,

		RespRelief = 0
	}
end

MuR.ChemDefaultMods = defaultMods

local NEUTRAL_MODS = defaultMods()
MuR.ChemNeutralMods = NEUTRAL_MODS

function Chem:GetTolerance(ply, id)
	local def = MuR.Substances[id]
	if not def or not def.tolerance then return 0 end
	if not IsValid(ply) or not ply:IsPlayer() then return 0 end

	local store = self.Tolerance[ply:SteamID64() or ""]
	if not store then return 0 end

	return store[id] or 0
end

function Chem:AddTolerance(ply, id)
	local def = MuR.Substances[id]
	if not def or not def.tolerance then return end
	if not TOLERANCE_CATEGORIES[def.cat] then return end

	local sid = ply:SteamID64()
	if not sid then return end

	self.Tolerance[sid] = self.Tolerance[sid] or {}
	self.Tolerance[sid][id] = math.min((self.Tolerance[sid][id] or 0) + TOLERANCE_BUILD, TOLERANCE_MAX)
end

local function dosePotency(def, elapsed, amount)
	if elapsed < def.onset then return 0 end

	if elapsed < def.peak then
		local span = math.max(def.peak - def.onset, 0.01)
		return amount * ((elapsed - def.onset) / span)
	end

	if elapsed >= def.duration then return 0 end

	local decayStart = def.duration - def.decay
	if elapsed < decayStart then return amount end

	return amount * (1 - (elapsed - decayStart) / math.max(def.decay, 0.01))
end

function Chem:GetPotency(ply, id)
	local active = ply.MuR_Chem
	if not active then return 0 end

	local entry = active[id]
	if not entry then return 0 end

	local def = MuR.Substances[id]
	if not def then return 0 end

	local now = CurTime()
	local total = 0

	for i = 1, #entry do
		total = total + dosePotency(def, now - entry[i].start, entry[i].amount)
	end

	return total
end

function Chem:Has(ply, id)
	return self:GetPotency(ply, id) > 0
end

function Chem:Carries(ply, id)
	local active = ply.MuR_Chem
	return active ~= nil and active[id] ~= nil and #active[id] > 0
end

function Chem:GetMods(ply)
	if not IsValid(ply) then return NEUTRAL_MODS end

	local active = ply.MuR_Chem
	if not active or not next(active) then return NEUTRAL_MODS end

	local frame = FrameNumber()
	if ply.MuR_ChemModsFrame == frame and ply.MuR_ChemMods then
		return ply.MuR_ChemMods
	end

	local mods = defaultMods()

	for id in pairs(active) do
		local def = MuR.Substances[id]
		if def and def.modify then
			local potency = self:GetPotency(ply, id)
			if potency > 0 then
				local blocked = def.blockedBy and self:GetPotency(ply, def.blockedBy) > 0.25
				if not blocked then
					def.modify(ply, mods, potency)
				end
			end
		end
	end

	mods.RespDepression = mods.RespDepression * (1 - math.Clamp(mods.RespRelief, 0, 1))

	mods.RespDepression = math.Clamp(mods.RespDepression, 0, 0.98)
	mods.Analgesia = math.Clamp(mods.Analgesia, 0, 1)
	mods.Sedation = math.Clamp(mods.Sedation, 0, 1)
	mods.BleedMul = math.max(mods.BleedMul, 0)
	mods.PerfusionMul = math.Clamp(mods.PerfusionMul, 0, 2)
	mods.StaminaMul = math.Clamp(mods.StaminaMul, 0, 2)
	mods.CellularBlock = math.max(mods.CellularBlock, 0)

	ply.MuR_ChemMods = mods
	ply.MuR_ChemModsFrame = frame

	return mods
end

function meta:GetChemMods()
	return MuR.Chem:GetMods(self)
end

function Chem:GetActive(ply)
	local out = {}
	local active = ply.MuR_Chem
	if not active then return out end

	for id in pairs(active) do
		local potency = self:GetPotency(ply, id)
		if potency > 0 then
			out[#out + 1] = {id = id, potency = potency}
		end
	end

	return out
end

function Chem:GetForensics(ply)
	local out = {}
	local active = ply.MuR_Chem
	if not active then return out end

	for id in pairs(active) do
		local def = MuR.Substances[id]
		if def and def.forensic and self:GetPotency(ply, id) > 0 then
			out[#out + 1] = def.forensic
		end
	end

	return out
end

function Chem:HasInjectionMark(ply)
	local active = ply.MuR_Chem
	if not active then return false end

	for id in pairs(active) do
		local def = MuR.Substances[id]
		if def and def.route == "injection" and self:GetPotency(ply, id) > 0 then
			return true
		end
	end

	return false
end

function Chem:Remove(ply, id)
	if not IsValid(ply) then return end
	if not ply.MuR_Chem then return end
	if not ply.MuR_Chem[id] then return end

	ply.MuR_Chem[id] = nil
	ply.MuR_ChemModsFrame = nil

	local def = MuR.Substances[id]
	if def and def.onEnd then def.onEnd(ply) end

	if def and def.vis ~= false then
		net.Start("MuR.SubstanceVisualClear")
			net.WriteString(id)
		net.Send(ply)
	end
end

function Chem:Clear(ply)
	if not IsValid(ply) then return end

	if ply.MuR_Chem then
		for id in pairs(ply.MuR_Chem) do
			local def = MuR.Substances[id]
			if def and def.onEnd then def.onEnd(ply) end
		end
	end

	ply.MuR_Chem = nil
	ply.MuR_ChemMods = nil
	ply.MuR_ChemModsFrame = nil
	ply.MuR_ChemSource = nil
	ply.MuR_ChemNextTick = nil
	ply.MuR_ChemOrganDebt = nil

	if ply:IsPlayer() then
		ply:SetNW2Float("ChemStaminaMul", 1)
		ply:SetNW2Float("ChemAnalgesia", 0)
	end

	if ply:IsPlayer() then
		net.Start("MuR.SubstanceVisualClear")
			net.WriteString("")
		net.Send(ply)
	end
end

function Chem:Apply(ply, id, amount, attacker)
	if not IsValid(ply) or not ply:IsPlayer() then return false end
	if not ply:Alive() then return false end

	local def = MuR.Substances[id]
	if not def then
		ErrorNoHalt("[Bloodshed] unknown substance: " .. tostring(id) .. "\n")
		return false
	end

	if ply:IsRoleWithoutOrgans() then return false end

	amount = amount or 1

	if def.gasBlocked and ply.GetGasProtectionLevel then
		local protection = ply:GetGasProtectionLevel() or 0
		if protection >= 1 then return false end
		amount = amount * (1 - protection)
	end

	local tolerance = self:GetTolerance(ply, id)
	amount = amount * (1 - tolerance)
	if amount < 0.1 then return false end

	self:AddTolerance(ply, id)

	if def.clears then
		for _, clearID in ipairs(def.clears) do
			self:Remove(ply, clearID)
		end
	end

	ply.MuR_Chem = ply.MuR_Chem or {}
	local isNew = ply.MuR_Chem[id] == nil
	ply.MuR_Chem[id] = ply.MuR_Chem[id] or {}

	local list = ply.MuR_Chem[id]
	list[#list + 1] = {start = CurTime(), amount = amount}

	ply.MuR_ChemModsFrame = nil

	if IsValid(attacker) and attacker:IsPlayer() and attacker ~= ply and def.lethal then
		ply.MuR_ChemSource = ply.MuR_ChemSource or {}
		ply.MuR_ChemSource[id] = attacker
		ply.LastAttacker = attacker
	end

	if def.bloodRestore and ply.AddBloodVolume then
		ply:AddBloodVolume(def.bloodRestore * amount)
	end

	if isNew and def.onStart then
		def.onStart(ply, amount, attacker)
	end

	if def.vis ~= false then
		net.Start("MuR.SubstanceVisual")
			net.WriteString(id)
			net.WriteFloat(def.duration)
			net.WriteFloat(amount)
		net.Send(ply)
	end

	return true
end

function Chem:CurePoison(ply)
	if not ply.MuR_Chem then return end

	for id in pairs(table.Copy(ply.MuR_Chem)) do
		local def = MuR.Substances[id]
		if def and (def.cat == "toxin" or def.cat == "gas") then
			self:Remove(ply, id)
		end
	end
end

local function expireDoses(ply)
	local active = ply.MuR_Chem
	if not active then return end

	local now = CurTime()

	for id, list in pairs(active) do
		local def = MuR.Substances[id]
		if not def then
			active[id] = nil
		else
			for i = #list, 1, -1 do
				if now - list[i].start >= def.duration then
					table.remove(list, i)
				end
			end

			if #list == 0 then
				MuR.Chem:Remove(ply, id)
			end
		end
	end
end

local function applyOrganDamage(ply, dt, mods)
	local active = ply.MuR_Chem
	if not active then return end

	local resist = 1 - math.Clamp(mods.ToxinResist, 0, 0.9)

	for id in pairs(active) do
		local def = MuR.Substances[id]
		if def and def.organTick then
			local potency = MuR.Chem:GetPotency(ply, id)

			if def.organAbove then
				potency = math.max(potency - def.organAbove, 0)
			end

			if potency > 0 then
				ply.MuR_ChemOrganDebt = (ply.MuR_ChemOrganDebt or 0) + potency * dt * resist

				if ply.MuR_ChemOrganDebt > 12 then
					ply.MuR_ChemOrganDebt = 0

					if def.cat == "gas" then
						local stage = ply:GetOrganDamageStage("lungs")
						if stage < 3 then ply:SetOrganDamageStage("lungs", stage + 1) end
					else
						ply:SetNW2Float("ToxinLevel",
							math.min(ply:GetNW2Float("ToxinLevel", 0) + 1, 10))
					end
				end
			end
		end
	end
end

hook.Add("PlayerPostThink", "MuR.Chem", function(ply)
	if not ply:Alive() then return end

	local active = ply.MuR_Chem
	if not active or not next(active) then return end

	local now = CurTime()
	if (ply.MuR_ChemNextTick or 0) > now then return end
	ply.MuR_ChemNextTick = now + TICK_INTERVAL

	expireDoses(ply)

	active = ply.MuR_Chem
	if not active or not next(active) then return end

	local mods = MuR.Chem:GetMods(ply)

	if mods.Sedation > 0.6 then
		if not ply:GetNW2Bool("IsUnconscious", false) then
			ply:ApplyUnconsciousness(math.Rand(3, 5))
		else
			ply:SetNW2Float("UnconsciousEnd", math.max(ply:GetNW2Float("UnconsciousEnd", 0), now + 2))
		end
	end

	if mods.CoordNoise > 0.15 then
		ply:ApplyCoordinationLoss(1.5, math.min(mods.CoordNoise * 0.3, 1), "substance")
	end

	if mods.ToxinClear > 0 then
		local toxin = ply:GetNW2Float("ToxinLevel", 0)
		if toxin > 0 then
			ply:SetNW2Float("ToxinLevel", math.max(toxin - mods.ToxinClear * TICK_INTERVAL, 0))
		end
	end

	if mods.StaminaFloor > 0 then
		local stamina = ply:GetNW2Float("Stamina", 100)
		if stamina < mods.StaminaFloor then
			ply:SetNW2Float("Stamina", math.min(stamina + 8 * TICK_INTERVAL, mods.StaminaFloor))
		end
	end

	applyOrganDamage(ply, TICK_INTERVAL, mods)

	ply:SetNW2Float("ChemStaminaMul", mods.StaminaMul)
	ply:SetNW2Float("ChemAnalgesia", mods.Analgesia)
end)

hook.Add("PlayerSpawn", "MuR.ChemReset", function(ply)
	MuR.Chem:Clear(ply)
end)

hook.Add("PlayerDeath", "MuR.ChemDeathReset", function(ply)
	ply.MuR_ChemMods = nil
	ply.MuR_ChemModsFrame = nil
end)

hook.Add("PlayerDisconnected", "MuR.ChemDisconnect", function(ply)
	MuR.Chem:Clear(ply)
end)

timer.Create("MuR.ChemToleranceDecay", TOLERANCE_INTERVAL, 0, function()
	for sid, store in pairs(Chem.Tolerance) do
		local empty = true

		for id, value in pairs(store) do
			local remaining = value - TOLERANCE_DECAY
			if remaining <= 0 then
				store[id] = nil
			else
				store[id] = remaining
				empty = false
			end
		end

		if empty then Chem.Tolerance[sid] = nil end
	end
end)

local adrCfg = {
	len = 30,
	tick = 0.05,
	stack = 30,
	die = 9,
	spasm = 0.18,
	roll = 40,
	waitMin = 7,
	waitMax = 12
}

Chem.Adr = Chem.Adr or {}

local function adrState(ply)
	local data = Chem.Adr[ply]
	if data then return data end

	data = {n = 0, t = 0, od = false, rollAt = 0}
	Chem.Adr[ply] = data
	return data
end

local function adrRag(ply)
	local rag = ply:GetRD()
	if IsValid(rag) then return rag end
	return ply:StartRagdolling(0, 0)
end

function Chem:StopAdr(ply)
	if not IsValid(ply) then return end

	timer.Remove("AdrUse" .. ply:EntIndex())
	ply:SetNW2Float("AdrenalineEnd", 0)
end

function Chem:ClearAdr(ply)
	if not IsValid(ply) then return end

	local data = Chem.Adr[ply]
	if data then
		data.n = 0
		data.t = 0
		data.od = false
		data.rollAt = 0
	end

	self:StopAdr(ply)

	timer.Remove("AdrRoll" .. ply:EntIndex())
	timer.Remove("AdrSpasm" .. ply:EntIndex())
	timer.Remove("AdrDie" .. ply:EntIndex())
	ply:SetNW2Bool("AdrenalineOverdosing", false)
	ply:SetNW2Float("AdrenalineOverdoseEnd", 0)
end

function Chem:AdrOD(ply, att)
	if not IsValid(ply) or not ply:Alive() then return false end

	local data = adrState(ply)
	if data.od then return true end

	data.od = true
	data.n = 0
	data.t = 0
	data.rollAt = 0

	self:StopAdr(ply)
	timer.Remove("AdrRoll" .. ply:EntIndex())

	local id = ply:EntIndex()
	local dieAt = CurTime() + adrCfg.die

	ply:SetNW2Bool("AdrenalineOverdosing", true)
	ply:SetNW2Float("AdrenalineOverdoseEnd", dieAt)
	ply:SetNW2Bool("IsUnconscious", true)
	ply.UnconsciousStart = CurTime()
	ply.IsRagStanding = false

	adrRag(ply)

	timer.Create("AdrSpasm" .. id, adrCfg.spasm, math.ceil(adrCfg.die / adrCfg.spasm), function()
		if not IsValid(ply) or not ply:Alive() or not ply:GetNW2Bool("AdrenalineOverdosing", false) then return end

		ply:SetNW2Bool("IsUnconscious", true)
		ply.IsRagStanding = false

		local rag = adrRag(ply)
		if IsValid(rag) then
			rag:StruggleBone()

			local boneId = rag:LookupBone("ValveBiped.Bip01_Spine2")
			if boneId then
				local phys = rag:GetPhysicsObjectNum(rag:TranslateBoneToPhysBone(boneId))
				if IsValid(phys) then
					phys:ApplyForceCenter(VectorRand(-140, 140) + Vector(0, 0, 160))
				end
			end
		end

		ply:ViewPunch(Angle(math.Rand(-4, 4), math.Rand(-5, 5), math.Rand(-2, 2)))

		if math.random(1, 100) <= 35 then
			ply:EmitSound("vo/npc/male01/moan0" .. math.random(1, 5) .. ".wav", 60, math.random(95, 110))
		end
	end)

	timer.Create("AdrDie" .. id, adrCfg.die, 1, function()
		if not IsValid(ply) or not ply:Alive() or not ply:GetNW2Bool("AdrenalineOverdosing", false) then return end

		local killer = IsValid(att) and att or ply
		local dmg = DamageInfo()
		dmg:SetDamage(math.max(ply:Health() + 25, 80))
		dmg:SetAttacker(killer)
		dmg:SetInflictor(IsValid(att) and att or game.GetWorld())
		dmg:SetDamageType(DMG_POISON)

		ply.MuR_TerminalDamage = true
		ply:TakeDamageInfo(dmg)
		ply.MuR_TerminalDamage = nil

		if IsValid(ply) and ply:Alive() then
			MuR.ForceKill(ply)
		end
	end)

	return true
end

function Chem:UseAdr(ply, att)
	if not IsValid(ply) or not ply:Alive() then return false end

	local data = adrState(ply)
	if data.od then return false end

	local now = CurTime()
	if data.t <= now then
		data.n = 0
	end

	data.n = data.n + 1
	data.t = now + adrCfg.stack

	if data.n >= 3 then
		self:AdrOD(ply, att)
		return false
	end

	if data.n == 2 then
		local id = ply:EntIndex()
		local wait = math.Rand(adrCfg.waitMin, adrCfg.waitMax)
		data.rollAt = now + wait

		timer.Remove("AdrRoll" .. id)
		timer.Create("AdrRoll" .. id, wait, 1, function()
			if not IsValid(ply) or not ply:Alive() then return end
			if ply:GetNW2Bool("AdrenalineOverdosing", false) then return end

			local cur = adrState(ply)
			if cur.n < 2 or cur.t <= CurTime() or cur.rollAt <= 0 then return end

			cur.rollAt = 0

			if math.random(100) <= adrCfg.roll then
				Chem:AdrOD(ply, att)
			end
		end)
	end

	self:StopAdr(ply)
	ply:SetNW2Float("AdrenalineEnd", now + 1)

	timer.Create("AdrUse" .. ply:EntIndex(), adrCfg.tick, math.floor(adrCfg.len / adrCfg.tick), function()
		if not IsValid(ply) or not ply:Alive() or ply:GetNW2Bool("AdrenalineOverdosing", false) then
			timer.Remove("AdrUse" .. ply:EntIndex())
			return
		end

		ply:SetNW2Float("Stamina", ply:GetNW2Float("Stamina") + 1)
		ply:SetNW2Float("AdrenalineEnd", CurTime() + 1)
	end)

	return true
end

hook.Add("PlayerPostThink", "MuR.AdrLock", function(ply)
	if not ply:GetNW2Bool("AdrenalineOverdosing", false) then return end

	if not ply:Alive() then
		MuR.Chem:ClearAdr(ply)
		return
	end

	ply:SetNW2Bool("IsUnconscious", true)
	ply.IsRagStanding = false
end)

hook.Add("PlayerSpawn", "MuR.AdrReset", function(ply)
	MuR.Chem:ClearAdr(ply)
end)

hook.Add("PlayerDeath", "MuR.AdrDeathReset", function(ply)
	MuR.Chem:ClearAdr(ply)
end)

hook.Add("PlayerDisconnected", "MuR.AdrDisconnect", function(ply)
	MuR.Chem:ClearAdr(ply)
	Chem.Adr[ply] = nil
end)
