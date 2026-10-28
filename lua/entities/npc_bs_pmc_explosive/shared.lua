AddCSLuaFile()

ENT.Base = "npc_bs_pmc"
ENT.Type = "nextbot"
ENT.PrintName = "PMC Explosive Unit"
ENT.Author = "Hari"
ENT.Category = "Bloodshed"
ENT.Spawnable = true

if CLIENT then return end

ENT.Model = {"models/murdered/npc/amb/tactical teology.mdl"}

ENT.StartHealth = 125

function ENT:GetSpawnWeapons()
	return {"tfa_bs_mp7"}
end

-- В ближнем бою почти бесполезен: его оружие — то, что он расставил заранее.
ENT.MeleeAttackDamage = 6
ENT.Weapon_RetreatDistance = 350

-- Гранат не носит: весь боезапас уходит в мины.
ENT.GrenadeChance = 0

ENT.TrapPlaceCooldown = 16
ENT.MaxActiveTraps = 2
-- Ближе этого к врагу не минирует: ставить капкан под огнём бессмысленно.
ENT.TrapSafeEnemyRange = 320
ENT.IEDDetonateRange = 190
ENT.IEDArmTime = 2

local function TraceFloor(pos)
	return util.TraceLine({
		start = pos + Vector(0, 0, 8),
		endpos = pos - Vector(0, 0, 64),
		mask = MASK_SOLID_BRUSHONLY,
	})
end

function ENT:PlaceBeartrap()
	local tr = TraceFloor(self:GetPos())
	if not tr.Hit then return end

	local trap = ents.Create("trap_entity")
	if not IsValid(trap) then return end

	trap:SetPos(tr.HitPos)
	trap:SetAngles(tr.HitNormal:Angle() + Angle(90, 0, 0))
	trap:SetOwner(self)

	-- Хозяин ловушки нужен, чтобы она не сработала на своих и на нём самом.
	if isfunction(MuR.SetTrapOwner) then MuR:SetTrapOwner(trap, self) end

	trap:Spawn()

	if IsValid(tr.Entity) then
		constraint.Weld(trap, tr.Entity, 0, tr.PhysicsBone or 0, 0, true, false)
	end

	trap:EmitSound("physics/metal/metal_box_impact_soft" .. math.random(1, 3) .. ".wav", 60)

	self.ActiveTraps[#self.ActiveTraps + 1] = trap
end

function ENT:PlaceIED()
	local pos = self:GetPos() + self:GetForward() * math.Rand(60, 140)
	local tr = TraceFloor(pos)
	if not tr.Hit then return end

	local ied = ents.Create("murwep_ied")
	if not IsValid(ied) then return end

	ied:SetPos(tr.HitPos + Vector(0, 0, 4))
	ied:SetAngles(Angle(0, math.random(0, 360), 0))

	if isfunction(MuR.SetTrapOwner) then MuR:SetTrapOwner(ied, self) end

	ied:Spawn()
	ied:Activate()

	ied.PlantedAt = CurTime()

	self.ActiveTraps[#self.ActiveTraps + 1] = ied
end

--
-- Фугас подрывается вручную, а не по наступанию: сапёр ждёт, пока цель войдёт
-- в радиус, и жмёт кнопку. Задержка IEDArmTime не даёт подорвать его в тот же
-- миг, когда он лёг на землю.
--
function ENT:DetonateReadyIEDs()
	for _, trap in ipairs(self.ActiveTraps) do
		if trap:GetClass() ~= "murwep_ied" then continue end
		if not trap.PlantedAt or CurTime() - trap.PlantedAt <= self.IEDArmTime then continue end
		if not isfunction(trap.Explode) then continue end

		local rangeSqr = self.IEDDetonateRange * self.IEDDetonateRange

		for _, ply in player.Iterator() do
			if not isfunction(ply.IsCombatEffective) or not ply:IsCombatEffective() then continue end
			if ply:GetPos():DistToSqr(trap:GetPos()) > rangeSqr then continue end

			trap:Explode()
			break
		end
	end
end

function ENT:UpdateTraps()
	for i = #self.ActiveTraps, 1, -1 do
		if not IsValid(self.ActiveTraps[i]) then table.remove(self.ActiveTraps, i) end
	end

	self:DetonateReadyIEDs()

	if self:GetPMCCooldown("trap_place") > 0 then return end
	if #self.ActiveTraps >= self.MaxActiveTraps then return end

	local enemy = self:GetEnemy()
	if IsValid(enemy) and self:GetPos():DistToSqr(enemy:GetPos()) < self.TrapSafeEnemyRange ^ 2 then
		return
	end

	self:SetPMCCooldown("trap_place", self.TrapPlaceCooldown)

	if math.random(1, 2) == 1 then
		self:PlaceBeartrap()
	else
		self:PlaceIED()
	end
end

function ENT:PMCOnThink()
	self.ActiveTraps = self.ActiveTraps or {}
	self:UpdateTraps()
end

-- Мины умирают вместе с сапёром: иначе карта копит их всю волну.
function ENT:PMCOnRemove()
	for _, trap in ipairs(self.ActiveTraps or {}) do
		if IsValid(trap) then trap:Remove() end
	end
end
