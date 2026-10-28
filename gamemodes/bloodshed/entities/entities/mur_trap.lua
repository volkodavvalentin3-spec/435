AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Improvised Trap"
ENT.Author = "Hari"
ENT.Spawnable = false
ENT.AdminSpawnable = false

local ARM_DELAY = 2
local REARM_DELAY = 5
local DISARM_RANGE = 120

function ENT:SetupDataTables()
	self:NetworkVar("String", 0, "VectorID")
	self:NetworkVar("String", 1, "SensorID")
	self:NetworkVar("String", 2, "PayloadID")
	self:NetworkVar("Bool", 0, "Armed")
	self:NetworkVar("Bool", 1, "Spent")
	self:NetworkVar("Vector", 0, "AnchorPos")
end

if CLIENT then
	local WIRE_MATERIAL = Material("cable/cable2")
	local GLOW_MATERIAL = Material("sprites/light_glow02_add")

	-- Внутренняя проводка провисает, растяжка натянута — это разные вещи и
	-- выглядеть должны по-разному.
	local WIRE_COLOR = Color(40, 34, 28)
	local TRIP_COLOR = Color(150, 145, 130)

	local TRIP_HEIGHT = 7
	local WIRE_SEGMENTS = 6

	local function drawWire(from, to, width, sag, color)
		local prev = from

		for i = 1, WIRE_SEGMENTS do
			local frac = i / WIRE_SEGMENTS
			local point = LerpVector(frac, from, to)

			if sag > 0 then
				point.z = point.z - math.sin(frac * math.pi) * sag
			end

			render.DrawBeam(prev, point, width, 0, 1, color)
			prev = point
		end
	end

	function ENT:BuildParts()
		self:ClearParts()

		self.PartCacheKey = self:GetSensorID() .. "|" .. self:GetVectorID() .. "|" .. self:GetPayloadID()
		self.Parts = {}

		local defs = MuR.Traps:CollectParts(self:GetSensorID(), self:GetVectorID(), self:GetPayloadID())

		for _, def in ipairs(defs) do
			if not util.IsValidModel(def.model) then continue end

			local model = ClientsideModel(def.model, RENDERGROUP_OPAQUE)
			if not IsValid(model) then continue end

			model:SetNoDraw(true)
			model:SetModelScale(def.scale or 1)

			self.Parts[#self.Parts + 1] = {ent = model, pos = def.pos, ang = def.ang or angle_zero}
		end
	end

	function ENT:ClearParts()
		for _, part in ipairs(self.Parts or {}) do
			if IsValid(part.ent) then part.ent:Remove() end
		end

		self.Parts = nil
	end

	function ENT:TripOrigin()
		local sensor = MuR.Traps.Sensors[self:GetSensorID()]
		return self:LocalToWorld(sensor and sensor.tripOrigin or Vector(0, 11, TRIP_HEIGHT))
	end

	-- Пока второй конец не закреплён, владельцу показывается, куда он ляжет.
	function ENT:DrawAnchorPreview()
		if not MuR.TrapKnown[self:EntIndex()] then return end

		local ply = LocalPlayer()
		if not IsValid(ply) then return end

		local wep = ply:GetActiveWeapon()
		if not IsValid(wep) or wep:GetClass() ~= "mur_trap_kit" then return end

		local origin = self:TripOrigin()
		local hit, reason = MuR.Traps:AnchorTrace(ply, origin)
		local col = reason and Color(220, 70, 60) or Color(90, 255, 140)

		render.SetMaterial(WIRE_MATERIAL)
		drawWire(origin, hit, 0.5, 0, col)
	end

	function ENT:Draw()
		self:DrawModel()

		local key = self:GetSensorID() .. "|" .. self:GetVectorID() .. "|" .. self:GetPayloadID()
		if not self.Parts or self.PartCacheKey ~= key then self:BuildParts() end

		local origin, angles = self:GetPos(), self:GetAngles()
		local hub = self:LocalToWorld(MuR.Traps.WireHub)

		for _, part in ipairs(self.Parts or {}) do
			if not IsValid(part.ent) then continue end

			local pos, ang = LocalToWorld(part.pos, part.ang, origin, angles)

			part.ent:SetPos(pos)
			part.ent:SetAngles(ang)
			part.ent:SetupBones()
			part.ent:DrawModel()

			part.world = pos
		end

		render.SetMaterial(WIRE_MATERIAL)

		for _, part in ipairs(self.Parts or {}) do
			if part.world then drawWire(hub, part.world, 0.7, 1.4, WIRE_COLOR) end
		end

		local anchor = self:GetAnchorPos()

		if anchor ~= vector_origin then
			drawWire(self:TripOrigin(), anchor, 0.35, 0.25, TRIP_COLOR)
		elseif MuR.Traps.Sensors[self:GetSensorID()] and MuR.Traps.Sensors[self:GetSensorID()].needsAnchor then
			self:DrawAnchorPreview()
		end

		self:DrawIndicator(hub)
	end

	-- Огонёк взвода: единственная подсказка, что устройство ещё живое.
	function ENT:DrawIndicator(hub)
		if not self:GetArmed() then return end

		local pulse = 0.5 + math.sin(CurTime() * 4) * 0.5
		if pulse < 0.35 then return end

		render.SetMaterial(GLOW_MATERIAL)
		render.DrawSprite(hub + self:GetAngles():Up() * 2, 5 * pulse, 5 * pulse, Color(255, 40, 30, 200 * pulse))
	end

	function ENT:OnRemove()
		self:ClearParts()
	end

	return
end

-- Габарит собранного устройства: детали рисуются клиентом и не имеют физики,
-- поэтому объём для наведения и E задаётся вручную по всей сборке.
local BOUNDS_MIN = Vector(-12, -20, 0)
local BOUNDS_MAX = Vector(12, 20, 18)

function ENT:Initialize()
	self:SetModel(MuR.Traps.ChassisModel)
	self:SetModelScale(MuR.Traps.ChassisScale)
	self:PhysicsInitBox(BOUNDS_MIN, BOUNDS_MAX)
	self:SetCollisionBounds(BOUNDS_MIN, BOUNDS_MAX)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetUseType(SIMPLE_USE)
	self:SetCollisionGroup(COLLISION_GROUP_WEAPON)

	local phys = self:GetPhysicsObject()
	if IsValid(phys) then
		phys:EnableMotion(false)
		phys:Sleep()
	end

	self.Uses = 0
	self.MaxUses = self.MaxUses or 1
	self.Delay = self.Delay or 0
	self.Firing = false
	self.TrapArmTime = CurTime() + ARM_DELAY

	self:SetArmed(true)
	self:SetSpent(false)
	self:NextThink(CurTime() + ARM_DELAY)
end

--[[ ------------------------------------------------------------------
	Сборка из чертежа
------------------------------------------------------------------ ]]--

function ENT:Configure(bp, ply, host)
	local T = MuR.Traps

	self.Blueprint = bp
	self.TrapOwner = ply
	self.TrapHost = host

	local sensor = T.Sensors[bp.sensor]

	self.ModFlags = {}
	self.Delay = 0
	self.MaxUses = 1

	for _, modID in ipairs(bp.mods or {}) do
		local mod = T.Mods[modID]
		if mod then
			self.ModFlags[modID] = mod
			if mod.delay then self.Delay = mod.delay end
			if mod.uses then self.MaxUses = mod.uses end
		end
	end

	-- Все три id уходят на клиент: по ним он собирает видимые детали.
	self:SetSensorID(bp.sensor)
	self:SetVectorID(bp.vector)
	self:SetPayloadID(bp.payload)

	if IsValid(host) then
		self:SetParent(host)
	end

	if sensor and sensor.Setup then
		sensor.Setup(self)
	end

	-- Растяжке нужен второй конец: до него устройство лежит невзведённым.
	if sensor and sensor.needsAnchor then
		self.NeedsAnchor = true
		self:SetArmed(false)
	end

	if not self:HasMod("silent") then
		self:EmitSound("buttons/button9.wav", 55, 110)
	end
end

-- Проволока натянута: устройство встаёт на боевой взвод.
function ENT:AnchorTo(pos)
	self:SetAnchorPos(pos)
	self.NeedsAnchor = false
	self.TrapArmTime = CurTime() + 1
	self:SetArmed(true)
	self:EmitSound("physics/metal/metal_solid_impact_bullet" .. math.random(1, 4) .. ".wav", 55, 130)
end

function ENT:TripOrigin()
	local sensor = self:GetSensorDef()
	return self:LocalToWorld(sensor and sensor.tripOrigin or Vector(0, 11, 7))
end

function ENT:HasMod(id)
	return self.ModFlags ~= nil and self.ModFlags[id] ~= nil
end

function ENT:GetSensorDef()
	return self.Blueprint and MuR.Traps.Sensors[self.Blueprint.sensor]
end

function ENT:GetVectorDef()
	return self.Blueprint and MuR.Traps.Vectors[self.Blueprint.vector]
end

function ENT:GetPayloadDef()
	return self.Blueprint and MuR.Traps:GetPayload(self.Blueprint.payload)
end

--[[ ------------------------------------------------------------------
	Опрос датчика
------------------------------------------------------------------ ]]--

function ENT:Think()
	self:NextThink(CurTime() + 0.2)

	if not self:GetArmed() then return true end
	if self.Firing then return true end
	if CurTime() < (self.TrapArmTime or 0) then return true end

	local sensor = self:GetSensorDef()
	if not sensor or not sensor.Poll then return true end

	local victim = sensor.Poll(self)
	if IsValid(victim) and self:CanTrigger(victim) then
		self:Trigger(victim)
		return true
	end

	self:PingOwner()

	return true
end

-- Владелец должен знать, что к устройству кто-то подошёл: на этом строится
-- вся игра с алиби — успеть оказаться на глазах у свидетелей.
function ENT:PingOwner()
	if CurTime() < (self.NextPing or 0) then return end
	self.NextPing = CurTime() + 4

	local ply = self.TrapOwner
	if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then return end

	local near = MuR.Traps:FindVictim(self, 400, true)
	if not IsValid(near) then return end

	net.Start("MuR.TrapProximity")
	net.WriteUInt(self:EntIndex(), 13)
	net.Send(ply)
end

function ENT:CanTrigger(victim)
	if not IsValid(victim) then return false end

	-- Сработку от предмета фильтры по цели не касаются: нить физически
	-- дёрнули, и устройству всё равно, кто там рядом стоял.
	if not victim:IsPlayer() then return true end

	if not MuR.Traps:IsValidVictim(self, victim) then return false end

	for _, mod in pairs(self.ModFlags or {}) do
		if mod.Allows and not mod.Allows(self, victim) then return false end
	end

	return true
end

--[[ ------------------------------------------------------------------
	Срабатывание
------------------------------------------------------------------ ]]--

-- chain — множество уже сработавших в этой цепи устройств, чтобы связка
-- не могла закольцеваться сама на себя.
function ENT:Trigger(victim, chain)
	if self.Firing then return end
	self.Firing = true

	chain = chain or {}
	chain[self] = true

	local delay = self.Delay or 0

	if delay <= 0 then
		self:FirePayload(victim, chain)
		return
	end

	if not self:HasMod("silent") then
		self:EmitSound("buttons/blip1.wav", 60, 120)
	end

	timer.Simple(delay, function()
		if not IsValid(self) then return end
		self:FirePayload(victim, chain)
	end)
end

function ENT:GetAttacker()
	return IsValid(self.TrapOwner) and self.TrapOwner or self
end

-- Имя FirePayload, а не Fire: нативный Entity:Fire(input) перекрывает
-- одноимённый метод скриптованной энтити и падает на nil-строке.
function ENT:FirePayload(victim, chain)
	self.PendingVictim = nil

	local vector = self:GetVectorDef()
	local payload = self:GetPayloadDef()

	if not vector or not payload then
		self:Disarm()
		return
	end

	vector.Fire(self, victim, payload)

	self.Uses = (self.Uses or 0) + 1
	self:NotifyOwner("trap_msg_fired")

	if self:HasMod("link") then
		self:FireChain(victim, chain or {})
	end

	if self:HasMod("selfdestruct") then
		SafeRemoveEntityDelayed(self, 0.5)
		return
	end

	if self.Uses >= (self.MaxUses or 1) then
		self:Disarm()
		return
	end

	timer.Simple(REARM_DELAY, function()
		if not IsValid(self) then return end
		self.Firing = false
	end)
end

-- Ищет ближайшее своё взведённое устройство и поджигает его следом.
function ENT:FireChain(victim, chain)
	local owner = self.TrapOwner
	if not IsValid(owner) then return end

	local best, bestDist

	for _, ent in ipairs(ents.FindByClass("mur_trap")) do
		if ent ~= self and not chain[ent] and IsValid(ent) and ent:GetArmed()
			and ent.TrapOwner == owner and not ent.Firing then

			local dist = self:GetPos():DistToSqr(ent:GetPos())
			if dist <= MuR.Traps.ChainRadius * MuR.Traps.ChainRadius and (not bestDist or dist < bestDist) then
				best, bestDist = ent, dist
			end
		end
	end

	if not IsValid(best) then return end

	timer.Simple(0.5, function()
		if not IsValid(best) then return end
		best:Trigger(IsValid(victim) and victim or MuR.Traps:FindVictim(best, 320, false), chain)
	end)
end

-- Единая точка применения начинки: здесь учитывается совпадение маршрута
-- введения с вектором доставки.
function ENT:ApplyPayload(payload, victim, potency)
	if not payload or not payload.Apply then return end

	potency = (potency or 1) * MuR.Traps:RouteEfficiency(self:GetVectorDef(), payload)

	if payload.areaOnly then
		payload.Apply(self, victim, potency)
		return
	end

	if not MuR.Traps:IsValidVictim(self, victim) then return end

	payload.Apply(self, victim, potency)
end

function ENT:Disarm()
	self.Firing = false
	self:SetArmed(false)
	self:SetSpent(true)
end

function ENT:NotifyOwner(key)
	local ply = self.TrapOwner
	if not IsValid(ply) or not ply:IsPlayer() then return end

	net.Start("MuR.TrapNotify")
	net.WriteString(key)
	net.Send(ply)
end

--[[ ------------------------------------------------------------------
	Обезвреживание — переиспользуем существующую мини-игру растяжки
------------------------------------------------------------------ ]]--

function ENT:Use(activator, caller)
	if not IsValid(caller) or not caller:IsPlayer() then return end
	if caller:GetPos():DistToSqr(self:GetPos()) > (DISARM_RANGE * DISARM_RANGE) then return end

	-- Хозяин снимает своё устройство без мини-игры, но компоненты сгорают.
	if caller == self.TrapOwner then
		self:EmitSound("physics/metal/metal_box_impact_soft" .. math.random(1, 3) .. ".wav", 60)
		self:Disarm()
		self:Remove()
		return
	end

	local sensor = self:GetSensorDef()

	-- Датчик-приманка ждёт, что предмет заберут — это и есть срабатывание.
	if sensor and sensor.usable and self:GetArmed() then
		self.PendingVictim = caller
		return
	end

	if not self:GetArmed() then
		self:EmitSound("physics/metal/metal_box_impact_soft" .. math.random(1, 3) .. ".wav", 60)
		self:Remove()
		return
	end

	if self.DisarmInProgress then return end

	self.DisarmInProgress = true
	self.DisarmPlayer = caller

	net.Start("MuR.TripwireMinigame")
	net.WriteEntity(self)
	net.Send(caller)

	timer.Create("MuR_TrapDisarm_" .. self:EntIndex(), 6, 1, function()
		if IsValid(self) then
			self.DisarmInProgress = false
			self.DisarmPlayer = nil
		end
	end)
end

function ENT:HandleDisarmResult(ply, success)
	if not self.DisarmInProgress or self.DisarmPlayer ~= ply then return end

	self.DisarmInProgress = false
	self.DisarmPlayer = nil
	timer.Remove("MuR_TrapDisarm_" .. self:EntIndex())

	if not success then
		self:Trigger(ply)
		return
	end

	self:NotifyOwner("trap_msg_disarmed")
	self:Disarm()
	self:EmitSound("physics/metal/metal_box_impact_soft" .. math.random(1, 3) .. ".wav", 60)
	hook.Run("BloodshedTrapDisarmed", ply, self)
end

function ENT:OnTakeDamage(dmg)
	if not self:GetArmed() then return end
	if dmg:GetDamage() < 5 then return end

	local att = dmg:GetAttacker()
	if IsValid(att) and att:IsPlayer() then
		self:Trigger(att)
	else
		self:Disarm()
	end
end

function ENT:OnRemove()
	timer.Remove("MuR_TrapDisarm_" .. self:EntIndex())

	local ply = self.TrapOwner
	if IsValid(ply) and ply.MuR_ActiveTraps then
		ply.MuR_ActiveTraps[self] = nil
	end
end
