AddCSLuaFile()

ENT.Base = "bs_npc_creature"
ENT.Type = "nextbot"
ENT.PrintName = "Shock Mimic"
ENT.Author = "Hari"
ENT.Category = "Bloodshed: Dark Aether"
ENT.Spawnable = true

if CLIENT then
	function ENT:Draw()
		self:DrawModel()

		local dlight = DynamicLight(LocalPlayer():EntIndex())
		if not dlight then return end

		local att = self:GetAttachment(9)
		if not att then return end

		dlight.pos = att.Pos
		dlight.r = math.random(10, 25)
		dlight.g = math.random(10, 25)
		dlight.b = math.random(200, 255)
		dlight.brightness = 2
		dlight.decay = 1000
		dlight.size = 256
		dlight.dietime = CurTime() + 1
	end

	return
end

ENT.Model = {"models/murdered/nz/bo6_mimic.mdl"}
ENT.StartHealth = 500

ENT.CollisionMins = Vector(-16, -16, 0)
ENT.CollisionMaxs = Vector(16, 16, 72)

ENT.CustomBlood_Particle = {"blood_impact_red_01"}

ENT.SoundTbl_FootStep = MuR.SoundDir("bo6/npc/mimic/step")
ENT.SoundTbl_CombatIdle = MuR.SoundDir("bo6/npc/mimic/amb")
ENT.SoundTbl_Pain = MuR.SoundDir("bo6/npc/mimic/pain")
ENT.SoundTbl_Death = MuR.SoundDir("bo6/npc/mimic/death")
ENT.SoundTbl_Swing = MuR.SoundDir("bo6/npc/mangler/swing")
ENT.SoundTbl_MeleeAttack = MuR.SoundDir("bo6/npc/mangler/damage")
ENT.SoundTbl_BeforeMeleeAttack = MuR.SoundDir("bo6/npc/mimic/attack")
ENT.SoundTbl_Grab = MuR.SoundDir("bo6/npc/mimic/grab")

ENT.HasMeleeAttack = true
ENT.MeleeAttackDamage = 20
ENT.MeleeAttackDamageType = DMG_SHOCK
ENT.AnimTbl_MeleeAttack = {
	"nz_ai_mimic_run_attack_01",
	"nz_ai_mimic_run_attack_02",
	"nz_ai_mimic_run_attack_03",
	"nz_ai_mimic_run_attack_04",
	"nz_ai_mimic_walk_attack_01",
	"nz_ai_mimic_stand_attack_01",
	"nz_ai_mimic_stand_attack_02",
	"nz_ai_mimic_stand_attack_03",
	"nz_ai_mimic_stand_attack_04",
	"nz_ai_mimic_stand_attack_05",
}
ENT.MeleeAttackDistance = 72
ENT.MeleeAttackDamageDistance = 80
ENT.TimeUntilMeleeAttackDamage = false

ENT.HasDeathAnimation = true
ENT.HasDeathCorpse = false
ENT.AnimTbl_Death = {"nz_ai_mimic_death_01"}
-- Мимик разлетается гибами через 1.5 с после начала анимации смерти, поэтому
-- база не должна убирать тело раньше.
ENT.DeathRemoveDelay = 2
ENT.HasGibOnDeathEffects = true

ENT.JumpParams = {
	Enabled = true,
	MaxRise = 200,
	MaxDrop = 600,
	MaxDistance = 400,
}

ENT.HasLeapAttack = false
ENT.CanFlinch = true
ENT.HasFootstepSounds = false
ENT.FlinchChance = 10
ENT.FlinchCooldown = 4
ENT.AnimTbl_Flinch = {"nz_ai_mimic_stun_in", "nz_ai_mimic_flail_out"}

ENT.GrabDistance = {120, 260}
ENT.AnimTbl_GrabLong = {"nz_ai_mimic_command_grab_in_01", "nz_ai_mimic_command_grab_success_01"}
ENT.GrabCooldown = 10
ENT.GrabDamage = 30
ENT.GrabAttachment = 8
ENT.GrabChance = 15
ENT.NextSparkTime = 0

function ENT:CustomOnInitialize()
	self.NextGrabTime = 0
	self.GrabbedPlayer = nil
	self.GrabPhase = nil
end

function ENT:CanGrab(ply)
	if not IsValid(ply) or not ply:Alive() then return false end
	if CurTime() < self.NextGrabTime then return false end
	if self.GrabbedPlayer then return false end

	local dist = self:GetPos():Distance(ply:GetPos())
	if dist > self.GrabDistance[2] then return false end
	if dist < self.GrabDistance[1] then return false end

	local tr = util.TraceLine({
		start = self:GetEyeOrigin(),
		endpos = ply:EyePos(),
		filter = {self, ply},
	})
	if tr.Hit then return false end

	return true
end

function ENT:StartGrab(ply)
	if not self:CanGrab(ply) then return end

	self.GrabbedLastPos = ply:GetPos()
	self.GrabbedPlayer = ply
	self.GrabPhase = "in"

	local animTbl = self.AnimTbl_GrabLong

	MuR.EmitSound(self, self.SoundTbl_Grab, 75, math.random(95, 105))

	self:SetState(BS_STATE_ANIM_HOLD)

	local dur = self:PlayAnim(animTbl[1], true)

	timer.Simple(dur, function()
		if not IsValid(self) then return end
		if not IsValid(self.GrabbedPlayer) then
			self:ReleaseGrab(false)
			return
		end
		self:GrabPhaseOut(animTbl)
	end)
end

function ENT:GrabPhaseOut(animTbl)
	self.GrabPhase = "out"
	local ply = self.GrabbedPlayer

	if not IsValid(ply) or not ply:Alive() then
		self:ReleaseGrab(false)
		return
	end

	ply:SetNWBool("AmalgamGrabbed", true)
	ply:SetNWEntity("AmalgamGrabbedBy", self)

	local dur = self:PlayAnim(animTbl[2], true)

	timer.Simple(dur * 0.6, function()
		if not IsValid(self) or not IsValid(ply) or not ply:Alive() then return end

		local dm = self.GrabDamage

		if ply:Health() <= ply:GetMaxHealth() * 0.5 then
			dm = 500
			ply.DeathBlowSpine = true
		end

		local dmg = DamageInfo()
		dmg:SetDamage(dm)
		dmg:SetAttacker(self)
		dmg:SetInflictor(self)
		dmg:SetDamageType(DMG_SHOCK)
		ply:TakeDamageInfo(dmg)

		self:ApplyShockEffect(ply)
	end)

	timer.Simple(dur, function()
		if not IsValid(self) then
			if IsValid(ply) then ply:SetNWBool("AmalgamGrabbed", false) end
			return
		end
		self:ReleaseGrab(true)
	end)
end

function ENT:ApplyShockEffect(ply)
	if not IsValid(ply) then return end

	local effectData = EffectData()
	effectData:SetOrigin(ply:WorldSpaceCenter())
	effectData:SetEntity(ply)
	effectData:SetMagnitude(2)
	effectData:SetScale(1)
	util.Effect("TeslaHitboxes", effectData)

	ply:ScreenFade(SCREENFADE.IN, Color(100, 125, 255, 80), 0.3, 0.1)
	ply:ViewPunch(Angle(math.Rand(-5, 5), math.Rand(-5, 5), math.Rand(-3, 3)))

	local shockDur = math.Rand(1, 2)
	local shockTicks = math.random(4, 8)

	for i = 1, shockTicks do
		timer.Simple(i * (shockDur / shockTicks), function()
			if IsValid(ply) and ply:Alive() then
				ply:ViewPunch(Angle(math.Rand(-3, 3), math.Rand(-3, 3), math.Rand(-2, 2)))
			end
		end)
	end
end

function ENT:SpawnRandomSparks()
	if CurTime() < self.NextSparkTime then return end
	self.NextSparkTime = CurTime() + math.Rand(0.1, 0.4)

	local arcData = EffectData()
	arcData:SetEntity(self)
	arcData:SetMagnitude(4)
	util.Effect("TeslaHitboxes", arcData)

	for _, ply in player.Iterator() do
		if not ply:Alive() then continue end
		if self:GetPos():Distance(ply:GetPos()) > 200 then continue end

		local dmg = DamageInfo()
		dmg:SetDamage(2)
		dmg:SetAttacker(self)
		dmg:SetInflictor(self)
		dmg:SetDamageType(DMG_SHOCK)
		ply:TakeDamageInfo(dmg)

		self:ApplyShockEffect(ply)
	end
end

function ENT:ReleaseGrab(applyKnockback)
	local ply = self.GrabbedPlayer

	if IsValid(ply) then
		ply:SetNWBool("AmalgamGrabbed", false)
		ply:SetNWEntity("AmalgamGrabbedBy", NULL)

		if applyKnockback then
			local dir = (ply:GetPos() - self:GetPos()):GetNormalized()
			dir.z = 0.3
			ply:SetPos(self:WorldSpaceCenter() + self:GetForward() * 64)
			ply:SetVelocity(dir * 400)
		end
	end

	self.GrabbedPlayer = nil
	self.GrabPhase = nil
	self.NextGrabTime = CurTime() + self.GrabCooldown

	if not self.BSDying then self:SetState(BS_STATE_NONE) end
end

function ENT:CustomOnDamageByTarget(dmginfo, hitEnt, isPropDamage)
	if IsValid(hitEnt) and hitEnt:IsPlayer() then
		self:ApplyShockEffect(hitEnt)
	end
end

function ENT:UpdateGrabbedPlayer()
	local ply = self.GrabbedPlayer
	if not IsValid(ply) then return end
	if self.GrabPhase ~= "out" and self.GrabPhase ~= "in" then return end

	if self.GrabPhase == "in" then
		ply:SetPos(self.GrabbedLastPos)
		ply:SetVelocity(-ply:GetVelocity())
	else
		local att = self:GetAttachment(self.GrabAttachment)
		if not att then return end

		ply:SetPos(att.Pos - Vector(0, 0, 48) + self:GetForward() * 4)
		ply:SetVelocity(-ply:GetVelocity())
	end

	ply:SetEyeAngles((self:GetEyeOrigin() - ply:EyePos()):Angle())
end

function ENT:OnAnimEvent(ev, evTime, evCycle, evType, evOptions)
	if evOptions == "melee" or evOptions == "melee_heavy" then
		self:ExecuteMeleeAttack()
	elseif evOptions == "step_left_large" or evOptions == "step_right_large" then
		MuR.EmitSound(self, self.SoundTbl_FootStep, 70, math.random(90, 110))
		util.ScreenShake(self:GetPos(), 4, 4, 0.4, 400)
	elseif evOptions == "melee_whoosh" then
		MuR.EmitSound(self, self.SoundTbl_Swing, 65, math.random(90, 110))
	end
end

function ENT:CustomOnThink()
	self:UpdateGrabbedPlayer()
	self:SpawnRandomSparks()

	if self.GrabbedPlayer then return end

	local enemy = self:GetEnemy()
	if IsValid(enemy) and enemy:IsPlayer() and self:CanGrab(enemy) then
		if math.random(1, 100) <= self.GrabChance then
			self:StartGrab(enemy)
		end
	end
end

function ENT:CustomOnRemove()
	if IsValid(self.GrabbedPlayer) then
		self:ReleaseGrab(false)
	end
end

function ENT:OnDeath(dmginfo, hitgroup, status)
	if IsValid(self.GrabbedPlayer) then
		self:ReleaseGrab(false)
	end

	if status ~= "DeathAnim" then return end

	timer.Simple(1.5, function()
		if not IsValid(self) then return end

		if self.HasGibOnDeathEffects then
			local effectData = EffectData()
			effectData:SetOrigin(self:GetPos() + self:OBBCenter())
			effectData:SetColor(MuR.Color2Byte(Color(130, 19, 10)))
			effectData:SetScale(8)
			effectData:SetFlags(3)
			util.Effect("bloodspray", effectData)
			util.Effect("bloodspray", effectData)
		end

		-- Модели гибов теперь берёт zippygore: пути models/vj_base/gibs/* были
		-- контентом VJ Base и без него не существуют.
		for i = 1, 14 do
			self:CreateGibEntity(nil, nil, {Pos = self:LocalToWorld(Vector(math.random(0, 2), math.random(0, 2), math.random(40, 50)))})
		end

		self:PlaySoundSystem("Gib", "physics/flesh/flesh_squishy_impact_hard1.wav")
	end)
end
