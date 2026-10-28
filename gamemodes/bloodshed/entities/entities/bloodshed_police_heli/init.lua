AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

local canBeDestroyed = true

function ENT:Initialize()
	self:SetModel(self.Model)
	self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
	self:SetCollisionGroup(COLLISION_GROUP_WEAPON)

	self.phys = self:GetPhysicsObject()
	self.phys:EnableGravity(false)
	self.phys:SetMass(5000)
	self.phys:Wake()

	self.LastUpdate = CurTime()
	self.ReplicTime = CurTime()
	self.Downed = false
	self:SetHealth(1500)
	self:SetCustomCollisionCheck(true)
	self.LastShoot = 0
	self.LastPositionChange = 0
	self.PositionChangeInterval = math.random(3, 6)
	self.CurrentAttackPosition = nil

	self.RotateVelocity = 0
	self.IsPolice = true

	self.Owner = self.Owner or game.GetWorld()

	self.MinHeightOutsideWorld = 300
end

function ENT:Think()
	if IsValid(self:GetTarget()) and self:GetTarget():Health() > 0 and !(self:GetTarget() == self.Owner and self.Friendly or self:GetTarget():IsPlayer() and GetConVar("ai_ignoreplayers"):GetBool()) then
		if CurTime() - self.ReplicTime > 8 then
			self.ReplicTime = CurTime()

			self:EmitSound(self.GetQuote(), 80, math.random(95, 105))
		end

		local canSeeTarget = self:IsSeeTarget()
		local shouldReposition = (CurTime() - self.LastPositionChange) > self.PositionChangeInterval

		if canSeeTarget and self:GetTarget():GetNW2Float("ArrestState") == 2 and self.LastShoot < CurTime() then
			if self.phys:GetVelocity():Length2D() < 100 then
				self:EmitSound(self.ShootSound, 90, math.random(95, 105))
				local spr = math.atan(72/self:GetTarget():GetPos():Distance(self:GetPos()))/(math.pi/2)/2
				local dir = (self:GetTarget():GetBonePosition(0) - self:GetPos()):GetNormalized()
				if IsValid(self:GetTarget():GetRD()) then
					dir = (self:GetTarget():GetRD():GetBonePosition(0) - self:GetPos()):GetNormalized()
				end

				self.LastShoot = CurTime() + math.Rand(0.4, 0.8)
				self:FireBullets({
					Damage = 20,
					Dir = dir,
					Spread = Vector(spr, spr, 0),
					Src = self:GetPos(),
					AmmoType = "AR2",
					Attacker = game.GetWorld()
				})
			elseif self.phys:GetVelocity():Length2D() < 150 then
				self.phys:SetVelocity(self.phys:GetVelocity() * 0.8)
			end
		elseif !canSeeTarget or shouldReposition then
			self:FindAttackPosition()
		end
	end

	local tply, dist = nil, math.huge
	for _, ply in player.Iterator() do
		local ndist = ply:GetPos():DistToSqr(self:GetPos())
		if ply:Alive() and ply:GetNW2Float("ArrestState") > 0 and ndist < dist then
			tply = ply
			dist = ndist
		end
	end
	self:SetTarget(tply)

	if self.Downed then
		if CurTime() - self.DownTime > 5 then
			self:Explode()
		end
	end

	local p = self:GetPos()
	local isOutsideBounds = self:IsOutsideWorldBounds()

	if isOutsideBounds then
		local newPos = p

		if IsValid(self:GetTarget()) then
			local targetZ = self:GetTarget():GetPos().z
			newPos.z = math.max(newPos.z, targetZ + self.MinHeightOutsideWorld)
		end

		self:SetPos(newPos)
	end

	self:NextThink(CurTime() + 0.25)
	return true
end

function ENT:FindAttackPosition()
	if !IsValid(self:GetTarget()) then return end
	if CurTime() - self.LastPositionChange < self.PositionChangeInterval then return end

	self.LastPositionChange = CurTime()
	self.PositionChangeInterval = math.random(3, 6)

	local targetPos = self:GetTarget():GetPos()
	local attempts = 0
	local bestPos, bestScore = nil, -1

	while attempts < 8 do
		attempts = attempts + 1

		local angle = math.random(0, 360)
		local distance = math.random(400, 800)
		local height = math.random(200, 400)

		local testPos = targetPos + Vector(
			math.cos(math.rad(angle)) * distance,
			math.sin(math.rad(angle)) * distance,
			height
		)

		local trace = util.TraceLine({
			start = testPos,
			endpos = targetPos,
			filter = self,
			mask = MASK_VISIBLE
		})

		local score = 0
		if trace.Fraction == 1 then
			score = score + 3
		elseif trace.Fraction > 0.5 then
			score = score + 1
		end

		local heightTrace = util.TraceLine({
			start = testPos,
			endpos = testPos - Vector(0, 0, 1000),
			filter = self,
			mask = MASK_VISIBLE
		})

		if heightTrace.Hit and heightTrace.Fraction > 0.2 then
			score = score + 1
		end

		if score > bestScore then
			bestPos = testPos
			bestScore = score
		end
	end

	if bestPos then
		self.CurrentAttackPosition = bestPos
	else
		local angle = math.random(0, 360)
		local distance = math.random(500, 800)
		local height = math.random(200, 400)

		self.CurrentAttackPosition = targetPos + Vector(
			math.cos(math.rad(angle)) * distance,
			math.sin(math.rad(angle)) * distance,
			height
		)
	end
end

function ENT:GetTargetPos()
	if self.CurrentAttackPosition and IsValid(self:GetTarget()) then
		local targetPos = self:GetTarget():GetPos()
		local distToTarget = targetPos:Distance(self:GetPos())

		if distToTarget < 300 or !self:IsSeeTarget() then
			return self.CurrentAttackPosition
		end

		return self:GetTarget():GetPos()
	end

	return IsValid(self:GetTarget()) and self:GetTarget():GetPos() or self:GetPos()
end

function ENT:PhysicsUpdate()
	if !self.Downed then
		if GetConVar("ai_disabled"):GetBool() then
			self:ApplyAngles()
			self:ApplyHeight("stop")
			self:SlowDown()
			self:StopRotating()

			self.LastUpdate = CurTime()
			return
		end

		local closetotar = self.CloseToTarget
		self.CloseToTarget = false

		self:ApplyAngles()
		self:ApplyHeight()

		if !IsValid(self:GetTarget()) then
			self:SlowDown()
			self:StopRotating()

			self.LastUpdate = CurTime()
			return
		end

		self:RotateToTarget()

		local effectiveTargetPos = self:GetTargetPos()
		local distToTarget = self:DistIgnoreZ(effectiveTargetPos)

		if distToTarget > (closetotar and 1250 or 750) then
			self:FlyTo(effectiveTargetPos)
		elseif self:IsSeeTarget() then
			if self.LastShoot > CurTime() then
				self:SlowDown(effectiveTargetPos)
			else
				self:ApproachAndHover(effectiveTargetPos)
			end
			self.CloseToTarget = true
		else
			self:RotateAround(effectiveTargetPos)
			self.CloseToTarget = true
		end
	else
		local time = CurTime() - self.LastUpdate

		local vel = self.phys:GetVelocity() + self.DownedVector * 5
		self.DownedRotate = self.DownedRotate + (!self.DownState and 90 * time or (CurTime() - self.DownTime) * 90 / 2) * 2
		self.phys:SetAngles(select(2, LocalToWorld(Vector(), Angle(0, self.DownedRotate, 0), Vector(), self.DownedAng)))
		self.phys:AddAngleVelocity(-self.phys:GetAngleVelocity())
		self.phys:SetVelocity(vel)

		if math.random(1, 20) == 1 then
			local effect = EffectData()
			effect:SetOrigin(self:GetPos())
			effect:SetScale(0.5)
			util.Effect("Explosion", effect)
		end
	end

	self.LastUpdate = CurTime()
end

function ENT:ApproachAndHover(pos)
	local time = CurTime() - self.LastUpdate
	local dist = self:DistIgnoreZ(pos)
	local vel = WorldToLocal(self.phys:GetVelocity(), Angle(), Vector(), (Vector(pos.x, pos.y, self:GetPos().z) - self:GetPos()):Angle())

	local targetSpeed = 50 + math.sin(CurTime() * 1.5) * 30

	if dist > 400 then
		vel.x = math.min(500, vel.x + (dist - 400) / 5 * time)
	elseif dist < 250 then
		vel.x = math.max(-200, vel.x - (250 - dist) / 3 * time)
	else
		vel.x = vel.x * 0.95 + targetSpeed * 0.05
	end

	vel.y = vel.y * 0.9 + math.sin(CurTime() * 0.7) * 20 * 0.1

	vel = LocalToWorld(vel, Angle(), Vector(), (Vector(pos.x, pos.y, self:GetPos().z) - self:GetPos()):Angle())
	self.phys:SetVelocity(vel)
end

function ENT:ApplyAngles()
	local time = CurTime() - self.LastUpdate
	local ang = self:GetAngles()
	local absvel = self.phys:GetVelocity()
	local vel = WorldToLocal(absvel, Angle(), Vector(), Angle(0, ang.y, 0))
	local speed = vel:Length2D()

	ang.p = math.Clamp(vel.x / 2000 * 60, -60, 60) * (speed == 0 and 1 or math.abs(vel.x) / speed)
	ang.y = ang.y + self.RotateVelocity * time
	ang.r = math.Clamp(-vel.y / 2000 * 60, -60, 60) * (speed == 0 and 1 or math.abs(vel.y) / speed)

	self.phys:SetAngles(ang)
	self.phys:AddAngleVelocity(-self.phys:GetAngleVelocity())
	self.phys:SetVelocity(absvel)
end

function ENT:ApplyHeight(height)
	height = height or self:CheckWorldHeight()

	if IsValid(self:GetTarget()) and self:IsOutsideWorldBounds() then
		local targetZ = self:GetTarget():GetPos().z
		if self:GetPos().z < targetZ + self.MinHeightOutsideWorld then
			height = "up"
		end
	end

	if (!height or height == "stop") and (self:GetTarMode() or IsValid(self:GetTarget())) then
		local targetPos = IsValid(self:GetTarget()) and self:GetTarget():GetPos() or self:GetPos()
		local d = self:GetPos().z - (self.Friendly and self.Owner:GetPos() or targetPos).z

		height = d < (self.StayInAir and 550 or 500) and "up" or d > (self.StayInAir and 650 or 600) and height != "stop" and "down" or false
	end

	local vel = self.phys:GetVelocity()
	local time = CurTime() - self.LastUpdate
	local max = 400

	if height and height != "stop" then
		self.StayInAir = false

		if height == "up" then
			if vel.z < max then
				vel.z = math.min(vel.z + 200 * time, max)
			end
		else
			if vel.z > -max then
				vel.z = math.max(vel.z - 200 * time, -max)
			end
		end
	elseif math.Round(vel.z) != 0 and !self.StayInAir then
		if vel.z > 0 then
			vel.z = math.max(vel.z - 200 * vel.z / 30 * time, 0)
		else
			vel.z = math.min(vel.z + 200 * -vel.z / 30 * time, 0)
		end
	elseif math.Round(vel.x) == 0 and math.Round(vel.y) == 0 and (math.Round(vel.z) == 0 or self.StayInAir) then
		self.StayInAir = true

		local dir = math.floor(CurTime() / 2) == math.Round(CurTime() / 2) and 1 or -1
		vel.z = 25 * dir
	else
		self.StayInAir = false
	end

	self.phys:SetVelocity(vel)
end

function ENT:IsOutsideWorldBounds()
	local p = self:GetPos()
	return !util.IsInWorld(p)
end

function ENT:StopRotating()
	local time = CurTime() - self.LastUpdate
	local vel = self.RotateVelocity
	self.RotateVelocity = math.Clamp(vel > 0 and math.max(vel - 45 * time, 0) or math.min(vel + 45 * time, 0), -60, 60)
end

function ENT:RotateToTarget()
	local time = CurTime() - self.LastUpdate
	local vel = self.RotateVelocity
	local targetPos = self:GetTargetPos()
	local _, ang = WorldToLocal(Vector(), (targetPos - Vector(self:GetPos().x, self:GetPos().y, targetPos.z)):Angle(), Vector(), Angle(0, self:GetAngles().y, 0))
	local side = ang.y > 0 and 1 or -1

	local mv = WorldToLocal(self.phys:GetVelocity(), Angle(), Vector(), (targetPos - Vector(self:GetPos().x, self:GetPos().y, targetPos.z)):Angle())
	local spd = mv:Length2D()

	if math.abs(ang.y) > (spd > 1000 and (spd == 0 and 1 or math.abs(mv.x / mv.y) > 3) and 60 or 30) then
		if math.abs(vel) < 60 then
			self.RotateVelocity = math.Clamp(self.RotateVelocity + 45 * side * time, -60, 60)
		end
	elseif math.abs(vel) > 0 then
		self:StopRotating()
	end
end

function ENT:RotateAround(pos)
	local time = CurTime() - self.LastUpdate
	local ang = (Vector(pos.x, pos.y, self:GetPos().z) - self:GetPos()):Angle()
	local vel1 = WorldToLocal(self.phys:GetVelocity(), Angle(), Vector(), ang)
	self:SlowDown(pos)
	local vel2 = WorldToLocal(self.phys:GetVelocity(), Angle(), Vector(), ang)

	local dist = self:DistIgnoreZ(pos)
	local spd = math.min(100 / 750 * dist, 300)

	if vel1.y > spd then return end

	local vel = Vector(math.max(math.abs(vel2.x), dist > 50 and 40 or 0) * (vel2.x != 0 and vel2.x / math.abs(vel2.x) or 1), vel1.y > spd and vel1.y or spd, vel2.z)
	vel = LocalToWorld(vel, Angle(), Vector(), ang)
	self.phys:SetVelocity(vel)
end

function ENT:FlyTo(pos)
	local time = CurTime() - self.LastUpdate
	local dist = self:DistIgnoreZ(pos)
	local vel = WorldToLocal(self.phys:GetVelocity(), Angle(), Vector(), (Vector(pos.x, pos.y, self:GetPos().z) - self:GetPos()):Angle())

	vel.x = math.min(2000, vel.x + (dist - 500) / 5 * time)
	vel.y = math.min(2000, vel.y - vel.y / 5 * time)

	vel = LocalToWorld(vel, Angle(), Vector(), (Vector(pos.x, pos.y, self:GetPos().z) - self:GetPos()):Angle())
	self.phys:SetVelocity(vel)
end

function ENT:SlowDown(pos)
	pos = pos or self:GetPos() + self.phys:GetVelocity():GetNormalized()

	local time = CurTime() - self.LastUpdate
	local vel = WorldToLocal(self.phys:GetVelocity(), Angle(), Vector(), (Vector(pos.x, pos.y, self:GetPos().z) - self:GetPos()):Angle())

	vel.x = vel.x > 0 and math.max(vel.x - 300 * time, 0) or math.min(vel.x + 300 * time, 0)
	vel.y = vel.y > 0 and math.max(vel.y - 300 * time, 0) or math.min(vel.y + 300 * time, 0)

	vel = LocalToWorld(vel, Angle(), Vector(), (Vector(pos.x, pos.y, self:GetPos().z) - self:GetPos()):Angle())
	self.phys:SetVelocity(vel)
end

function ENT:DistIgnoreZ(pos)
	return self:GetPos():Distance(Vector(pos.x, pos.y, self:GetPos().z))
end

function ENT:CheckWorldHeight()
	local floor = util.TraceLine({start = self:GetPos(), endpos = self:GetPos() - Vector(0, 0, self.StayInAir and 650 or 600), filter = self, mask = MASK_ALL})
	if floor.Hit then
		if self:GetPos().z - floor.HitPos.z > (self.StayInAir and 550 or 500) then
			return "stop"
		else
			return "up"
		end
	end

	if util.TraceLine({start = self:GetPos(), endpos = self:GetPos(), mask = MASK_NPCWORLDSTATIC}).StartSolid then
		if util.TraceLine({start = self:GetPos(), endpos = self:GetPos() + Vector(0, 0, 48000), mask = MASK_NPCWORLDSTATIC}).Hit then
			return "up"
		elseif util.TraceLine({start = self:GetPos(), endpos = self:GetPos() - Vector(0, 0, 48000), mask = MASK_NPCWORLDSTATIC}).Hit then
			return "down"
		end
	else
		local tr = util.TraceLine({start = self:GetPos(), endpos = self:GetPos() + Vector(0, 0, 48000), mask = MASK_NPCWORLDSTATIC})
		if tr.Hit then
			local tr = util.TraceLine({start = tr.HitPos, endpos = self:GetPos(), mask = MASK_NPCWORLDSTATIC})
			if tr.HitTexture == "**displacement**" then
				return "up"
			end
		end
	end

	return false
end

function ENT:IsSeeTarget()
	if !IsValid(self:GetTarget()) then return false end

	local targetBonePos = self:GetTarget():GetBonePosition(0) or self:GetTarget():GetPos()
	local tr = util.TraceLine({
		start = self:GetPos(),
		endpos = targetBonePos + Vector(0, 0, 1),
		mask = MASK_VISIBLE,
		filter = {self, self:GetTarget()}
	})

	return tr.Fraction == 1
end

function ENT:OnTakeDamage(dmg)
	if canBeDestroyed and !self.Downed then
		local att = dmg:GetAttacker()
		if att:IsPlayer() and att:CanBecomeWanted() then
			att:SetNW2Float("ArrestState", 2)
		end
		if dmg:IsExplosionDamage() then
			dmg:ScaleDamage(10)
		end
		if self:Health() <= 0 then
			self:StartCrush()
		else
			self:SetHealth(self:Health() - dmg:GetDamage())
		end
	end
end

function ENT:StartCrush()
	self.Downed = true
	self.DownedVector = Vector(math.random(-1, 1), math.random(-1, 1), 0)
	self:EmitSound(")murdered/pheli/mayday.wav", 90)

	local r = self:GetAngles().r

	self.DownedAng = Angle(self:GetAngles().p, self:GetAngles().y, r)
	self.DownedRotate = 0

	self.phys:SetAngles(self.DownedAng)
	self.phys:SetVelocity(LocalToWorld(Vector(0, -r * 100, -25), Angle(), Vector(), Angle(0, self:GetAngles().y, 0)))

	self.DownTime = CurTime()
	self.DownState = false

	local effect = EffectData()
	effect:SetOrigin(self:GetPos())
	effect:SetScale(0.5)
	util.Effect("Explosion", effect)
end

function ENT:Explode()
	local effect = EffectData()
	effect:SetOrigin(self:GetPos())
	effect:SetScale(2)
	util.Effect("Explosion", effect)
	util.BlastDamage(self, self, self:GetPos(), 200, 150)
	MuR:ApplyConcussion(self:GetPos(), "vehicle", self)
	MakeExplosionReverb(self:GetPos())
	self:Remove()
end

function ENT:PhysicsCollide(data, phys)
	if self.Downed then self:Explode() end
end

local function check(ent1, ent2)
	if (ent1:GetClass() == "bloodshed_police_heli" or ent1.Base == "bloodshed_police_heli") and !ent1.Downed and (ent2 == game.GetWorld() or IsValid(ent2:GetPhysicsObject()) and !ent2:GetPhysicsObject():IsMotionEnabled()) then
		return false
	end
end

hook.Add("ShouldCollide", "bloodshed_police_heli", function(ent1, ent2)
	local ret = check(ent1, ent2) == false or check(ent2, ent1) == false
	if ret then return false end
end)
