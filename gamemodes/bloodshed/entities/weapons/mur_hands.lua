if SERVER then
	AddCSLuaFile()
	SWEP.Weight = 5
	SWEP.AutoSwitchTo = false
	SWEP.AutoSwitchFrom = false
	SWEP.CantDrop = true
	SWEP.NeverDrop = true
else
	SWEP.PrintName = "Hands"
	SWEP.DrawWeaponInfoBox = false
	SWEP.CantDrop = true
	SWEP.NeverDrop = true
	SWEP.Slot = 0
	SWEP.SlotPos = 1
	SWEP.DrawAmmo = false
	SWEP.DrawCrosshair = false
	SWEP.ViewModelFOV = 90
	SWEP.BounceWeaponIcon = false

	SWEP.TPIKForce = true
	SWEP.TPIKPos = Vector(4, 2, 4)

	local HandTex, ClosedTex = surface.GetTextureID("vgui/hud/gmod_hand"), surface.GetTextureID("vgui/hud/gmod_closedhand")

	function SWEP:DrawHUD()
		if not (GetViewEntity() == LocalPlayer()) then return end
		if LocalPlayer():InVehicle() then return end

		if not self:GetFists() then
			local Tr = util.QuickTrace(self:GetOwner():GetShootPos(), self:GetOwner():GetAimVector() * self.ReachDistance, {self:GetOwner()})

			if Tr.Hit then
				if self:CanPickup(Tr.Entity) then
					local Size = math.Clamp(1 - ((Tr.HitPos - self:GetOwner():GetShootPos()):Length() / self.ReachDistance) ^ 2, .2, 1)

					if self:GetOwner():KeyDown(IN_ATTACK2) then
						surface.SetTexture(ClosedTex)
					else
						surface.SetTexture(HandTex)
					end

					surface.SetDrawColor(Color(255, 255, 255, 255 * Size))
					surface.DrawTexturedRect(ScrW() / 2 - (64 * Size), ScrH() / 2 - (64 * Size), 128 * Size, 128 * Size)
				end
			end
		end
	end
end

SWEP.SwayScale = 3
SWEP.BobScale = 3
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.HoldType = "normal"
SWEP.ViewModel = "models/weapons/cod2019/c_melee_fist.mdl"
SWEP.WorldModel = ""
SWEP.UseHands = true
SWEP.AttackSlowDown = .5
SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "none"
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"
SWEP.ReachDistance = 60

function SWEP:SetupDataTables()
	self:NetworkVar("Float", 0, "NextIdle")
	self:NetworkVar("Bool", 2, "Fists")
	self:NetworkVar("Float", 1, "NextDown")
	self:NetworkVar("Bool", 3, "Blocking")
	self:NetworkVar("Bool", 4, "IsCarrying")
end

function SWEP:Initialize()
	self:SetNextIdle(CurTime() + 5)
	self:SetNextDown(CurTime() + 5)
	self:SetHoldType(self.HoldType)
	self:SetFists(false)
	self:SetBlocking(false)
end

function SWEP:GetBFSViewModel()
	local owner = self:GetOwner()

	if not IsValid(owner) then return end

	local vm = owner:GetViewModel()

	if not IsValid(vm) then return end

	return vm
end

function SWEP:Deploy()
	if not IsFirstTimePredicted() then
		local vm = self:DoBFSAnimation("holster")

		if IsValid(vm) then
			vm:SetPlaybackRate(.1)
		end

		return
	end

	self:SetNextPrimaryFire(CurTime() + .1)
	self:SetFists(false)
	self:SetNextDown(CurTime())
	self:DoBFSAnimation("holster")

	return true
end

function SWEP:Holster()
	self:OnRemove()

	return true
end

function SWEP:CanPrimaryAttack()
	return true
end

local pickupWhiteList = {
	["prop_ragdoll"] = true,
	["prop_physics"] = true,
	["prop_physics_multiplayer"] = true
}

function SWEP:CanPickup(ent)
	if MuR.IsAI(ent) then return false end
	if ent:IsPlayer() then return false end
	if ent:IsWorld() then return false end
	local class = ent:GetClass()
	if pickupWhiteList[class] then return true end
	if CLIENT then return true end
	if IsValid(ent:GetPhysicsObject()) then return true end

	return false
end

function SWEP:SecondaryAttack()
	if not IsFirstTimePredicted() then return end
	if self:GetFists() then return end

	if SERVER then
		self:SetCarrying()
		local tr = self:GetOwner():GetEyeTraceNoCursor()

		if IsValid(tr.Entity) and self:CanPickup(tr.Entity) and not tr.Entity:IsPlayer() then
			local Dist = (self:GetOwner():GetShootPos() - tr.HitPos):Length()

			if Dist < self.ReachDistance then
				sound.Play("physics/cardboard/cardboard_box_impact_soft1.wav", self:GetOwner():GetShootPos(), 65, math.random(90, 110))
				self:SetCarrying(tr.Entity, tr.PhysicsBone, tr.HitPos, Dist)
				tr.Entity.Touched = true
				self:ApplyForce()
			end
		elseif IsValid(tr.Entity) and tr.Entity:IsPlayer() then
			local Dist = (self:GetOwner():GetShootPos() - tr.HitPos):Length()

			if Dist < self.ReachDistance then
				sound.Play(")weapons/tfa/melee_hit_body"..math.random(1,6)..".wav", self:GetOwner():GetShootPos(), 65, math.random(90, 110))
				local vel = self:GetOwner():GetAimVector() * 500
				vel.z = vel.z/5
				tr.Entity:SetVelocity(vel)
				tr.Entity:TakeDamage(1)
				self:SetNextSecondaryFire(CurTime() + 1)
				self:GetOwner():ViewPunch(Angle(10,0,0))
				BroadcastLua([[
					local e = Entity(]]..self:GetOwner():EntIndex()..[[)
					if IsValid(e) then
						e:DoAnimationEvent(ACT_GMOD_GESTURE_MELEE_SHOVE_2HAND)
					end
				]])
			end
		end
	end
end

function SWEP:ApplyForce()
	local target = self:GetOwner():GetAimVector() * self.CarryDist + self:GetOwner():GetShootPos()
	local phys = self.CarryEnt:GetPhysicsObjectNum(self.CarryBone)

	if IsValid(phys) then
		local TargetPos = phys:GetPos()

		if self.CarryPos then
			TargetPos = self.CarryEnt:LocalToWorld(self.CarryPos)
		end

		local vec = target - TargetPos
		local len, mul = vec:Length(), self.CarryEnt:GetPhysicsObject():GetMass()

		if len > self.ReachDistance then
			self:SetCarrying()

			return
		end

		local limit = 15000
		if self.CarryEnt:GetClass() == "prop_ragdoll" then
			mul = mul * 4
			limit = 40000
		end

		vec:Normalize()
		local avec, velo = vec * len, phys:GetVelocity() - self:GetOwner():GetVelocity()
		local Force = (avec - velo / 2) * mul
		local ForceMagnitude = Force:Length()

		if ForceMagnitude > limit then
			self:SetCarrying()
			return
		end

		local CounterDir, CounterAmt = velo:GetNormalized(), velo:Length()

		if self.CarryPos then
			phys:ApplyForceOffset(Force, self.CarryEnt:LocalToWorld(self.CarryPos))
		else
			phys:ApplyForceCenter(Force)
		end

		phys:ApplyForceCenter(Vector(0, 0, mul))
		phys:AddAngleVelocity(-phys:GetAngleVelocity() / 10)
	end
end

function SWEP:OnRemove()
	if IsValid(self:GetOwner()) and CLIENT and self:GetOwner():IsPlayer() then
		local vm = self:GetOwner():GetViewModel()

		if IsValid(vm) then
			vm:SetMaterial("")
		end
	end
end

function SWEP:GetCarrying()
	return self.CarryEnt
end

function SWEP:SetCarrying(ent, bone, pos, dist)
	if IsValid(ent) then
		self.CarryEnt = ent
		self.CarryBone = bone
		self.CarryDist = dist

		if not (ent:GetClass() == "prop_ragdoll") then
			self.CarryPos = ent:WorldToLocal(pos)
		else
			self.CarryPos = nil
		end
	else
		self.CarryEnt = nil
		self.CarryBone = nil
		self.CarryPos = nil
		self.CarryDist = nil
	end
end

function SWEP:Think()
	if IsValid(self:GetOwner()) and self:GetOwner():KeyDown(IN_ATTACK2) and not self:GetFists() then
		if IsValid(self.CarryEnt) then
			self:ApplyForce()
		end
	elseif self.CarryEnt then
		self:SetCarrying()
	end

	if self:GetFists() and self:GetOwner():KeyDown(IN_ATTACK2) then
		self:SetNextPrimaryFire(CurTime() + .5)
		self:SetBlocking(true)
	else
		self:SetBlocking(false)
	end

	local HoldType = "fist"

	if self:GetFists() then
		HoldType = "fist"
		local Time = CurTime()

		if self:GetNextIdle() < Time then
			self:UpdateNextIdle()
		end

		if self:GetBlocking() then
			self:SetNextDown(Time + 1)
			HoldType = "camera"
		end

		if (self:GetNextDown() < Time) or self:GetOwner():IsSprinting() then
			self:SetNextDown(Time + 1)
			self:SetFists(false)
			self:SetBlocking(false)
		end
	else
		HoldType = "normal"
		self:DoBFSAnimation("holster")
	end

	if IsValid(self.CarryEnt) or self.CarryEnt then
		HoldType = "magic"
	end

	if self:GetOwner():IsSprinting() then
		HoldType = "normal"
	end

	if SERVER then
		self:SetHoldType(HoldType)
	end
end

function SWEP:PrimaryAttack()
	local side = "melee_0"..math.random(1,8)

	self:SetNextDown(CurTime() + 7)

	if not self:GetFists() then
		self:SetFists(true)
		self:DoBFSAnimation("draw_first")
		self:SetNextPrimaryFire(CurTime() + .6)

		return
	end

	if self:GetBlocking() then return end
	if self:GetOwner():IsSprinting() then return end

	if not IsFirstTimePredicted() then
		local vm = self:DoBFSAnimation(side)

		if IsValid(vm) then
			vm:SetPlaybackRate(1.25)
		end

		return
	end

	self:GetOwner():ViewPunch(AngleRand(-2, 2))
	local vm = self:DoBFSAnimation(side)
	self:GetOwner():SetAnimation(PLAYER_ATTACK1)

	if IsValid(vm) then
		vm:SetPlaybackRate(1.25)
	end

	self:UpdateNextIdle()

	if SERVER then
		sound.Play(")weapons/tfa/melee"..math.random(1,6)..".wav", self:GetPos(), 65, math.random(90, 110))
		self:GetOwner():ViewPunch(AngleRand(-2, 2))

		timer.Simple(.075, function()
			if IsValid(self) then
				self:AttackFront()
			end
		end)
	end

	self:SetNextPrimaryFire(CurTime() + .5)
	self:SetNextSecondaryFire(CurTime() + .5)
end

function SWEP:AttackFront()
	if CLIENT then return end
	self:GetOwner():LagCompensation(true)

	local owner = self:GetOwner()
	local aimVec = owner:GetAimVector()
	local startPos = owner:EyePos()
	local endPos = startPos + aimVec * self.ReachDistance

	local tr = util.TraceLine({
		start = startPos,
		endpos = endPos,
		filter = owner,
		mask = MASK_SHOT,
	})

	if not IsValid(tr.Entity) and not (tr.Entity and tr.Entity.IsWorld and tr.Entity:IsWorld()) then
		local obstructionTrace = util.TraceLine({
			start = startPos,
			endpos = endPos,
			filter = function(ent)
				if ent == owner then return true end
				return ent:IsPlayer() or MuR.IsAI(ent)
			end,
			mask = MASK_SHOT,
		})

		local pointPos = obstructionTrace.Hit and obstructionTrace.HitPos or endPos
		tr = util.TraceHull({
			start = pointPos - aimVec * 2,
			endpos = pointPos + aimVec * 2,
			filter = owner,
			mask = MASK_SHOT,
			mins = Vector(-2, -2, -2),
			maxs = Vector(2, 2, 2)
		})
	end

	local Ent, HitPos = tr.Entity, tr.HitPos
	local AimVec = aimVec

	if IsValid(Ent) or (Ent and Ent.IsWorld and Ent:IsWorld()) then
		local SelfForce, Mul = 125, 1

		if self:IsEntSoft(Ent) then
			SelfForce = 25

			if Ent:IsPlayer() and IsValid(Ent:GetActiveWeapon()) and Ent:GetActiveWeapon().GetBlocking and Ent:GetActiveWeapon():GetBlocking() then
				Mul = 0.35
				SelfForce = 10
				sound.Play(")weapons/tfa/melee_hit_body"..math.random(1,6)..".wav", HitPos, 65, math.random(90, 110))
			else
				sound.Play(")weapons/tfa/melee_hit_body"..math.random(1,6)..".wav", HitPos, 65, math.random(90, 110))
			end
		else
			sound.Play(")weapons/tfa/melee_hit_body"..math.random(1,6)..".wav", HitPos, 65, math.random(90, 110))
		end

		local isHeadHit = tr.HitGroup == HITGROUP_HEAD
		local DamageAmt = isHeadHit and math.random(4, 5) or math.random(3, 4)
		local damageToDeal = DamageAmt * Mul
		local shouldKnockout = false
		local knockoutDuration

		if Ent:IsPlayer() and Ent:Alive() and not Ent:GetNW2Bool("IsUnconscious", false) then
			local knockoutThreshold = isHeadHit and 14 or 8
			if Ent:Health() - damageToDeal <= knockoutThreshold then
				damageToDeal = math.max(math.min(damageToDeal, Ent:Health() - 1), 0)
				shouldKnockout = true
				knockoutDuration = isHeadHit and math.Rand(10, 16) or math.Rand(6, 10)
			elseif isHeadHit and Ent:Health() <= 22 and math.random() < 0.25 then
				shouldKnockout = true
				knockoutDuration = math.Rand(8, 12)
			end
		end

		local Dam = DamageInfo()
		Dam:SetAttacker(self:GetOwner())
		Dam:SetInflictor(self.Weapon)
		Dam:SetDamage(damageToDeal)
		Dam:SetDamageForce(AimVec * Mul ^ 3)
		Dam:SetDamageType(DMG_CLUB)
		Dam:SetDamagePosition(HitPos)
		Ent:TakeDamageInfo(Dam)

		if Ent:IsPlayer() and Ent:Alive() and not Ent:GetNW2Bool("IsUnconscious", false) then
			if isHeadHit and Ent.ApplyConcussion then
				Ent:ApplyConcussion(Dam, 2.5, 0.8, 0.4)
			end

			if shouldKnockout and Ent.ApplyUnconsciousness then
				Ent:ApplyUnconsciousness(knockoutDuration or math.Rand(6, 10))
			end
		end

		local Phys = Ent:GetPhysicsObject()

		if IsValid(Phys) then
			if Ent:IsPlayer() then
				Ent:SetVelocity(AimVec * SelfForce * 1.5)
			end

			Phys:ApplyForceOffset(AimVec * 8000 * Mul, HitPos)
		end

		if Ent:GetClass() == "func_breakable_surf" then
			if math.random(1, 20) == 10 then
				Ent:Fire("break", "", 0)
			end
		end
	end

	self:GetOwner():LagCompensation(false)
end

function SWEP:Reload()
	if not IsFirstTimePredicted() then return end
	self:SetFists(false)
	self:SetBlocking(false)
	self:SetCarrying()
end

function SWEP:DrawWorldModel()
end

function SWEP:DoBFSAnimation(anim)
	local vm = self:GetBFSViewModel()

	if not IsValid(vm) then return end

	local sequence = vm:LookupSequence(anim)

	if sequence < 0 then return vm end

	vm:SendViewModelMatchingSequence(sequence)

	return vm
end

function SWEP:UpdateNextIdle()
	local vm = self:GetBFSViewModel()

	if not IsValid(vm) then
		self:SetNextIdle(CurTime() + 0.1)
		return
	end

	self:SetNextIdle(CurTime() + vm:SequenceDuration())
end

function SWEP:IsEntSoft(ent)
	return MuR.IsAI(ent) or ent:IsPlayer()
end

function SWEP:ShootEffects()
end

if CLIENT then
	local BlockAmt = 0

	function SWEP:GetViewModelPosition(pos, ang)
		if self:GetBlocking() then
			BlockAmt = math.Clamp(BlockAmt + FrameTime() * 1.5, 0, 1)
		elseif !self:GetFists() then
			BlockAmt = math.Clamp(BlockAmt - FrameTime() * 1.5, -1.5, 0)
		else
			BlockAmt = math.Clamp(BlockAmt - FrameTime() * 1.5, 0, 1)
		end

		pos = pos - ang:Up() * 8 * BlockAmt
		ang:RotateAroundAxis(ang:Right(), BlockAmt * 60)
		ang:RotateAroundAxis(ang:Up(), BlockAmt * 10)

		return pos, ang
	end
end
SWEP.Category = "Bloodshed - Other"
