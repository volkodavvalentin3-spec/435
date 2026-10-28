AddCSLuaFile()

ENT.Base = "bs_npc_creature"
ENT.Type = "nextbot"
ENT.PrintName = "Mangler"
ENT.Author = "Hari"
ENT.Category = "Bloodshed: Dark Aether"
ENT.Spawnable = true

if CLIENT then return end

ENT.Model = {"models/murdered/nz/bo6_mangler.mdl"}
ENT.StartHealth = 500

ENT.CollisionMins = Vector(-16, -16, 0)
ENT.CollisionMaxs = Vector(16, 16, 72)

ENT.CustomBlood_Particle = {"blood_impact_red_01"}

ENT.SoundTbl_FootStep = MuR.SoundDir("bo6/npc/mangler/step")
ENT.SoundTbl_Breath = MuR.SoundDir("bo6/npc/mangler/breathe")
ENT.SoundTbl_CombatIdle = MuR.SoundDir("bo6/npc/mangler/lines")
ENT.SoundTbl_Enrage = MuR.SoundDir("bo6/npc/mangler/rage")
ENT.SoundTbl_Pain = MuR.SoundDir("bo6/npc/mangler/pain")
ENT.SoundTbl_Death = MuR.SoundDir("bo6/npc/mangler/death")
ENT.SoundTbl_Swing = MuR.SoundDir("bo6/npc/mangler/swing")
ENT.SoundTbl_MeleeAttack = MuR.SoundDir("bo6/npc/mangler/damage")
ENT.SoundTbl_BeforeMeleeAttack = MuR.SoundDir("bo6/npc/mangler/attack")

ENT.HasMeleeAttack = true
ENT.MeleeAttackDamage = 50
ENT.MeleeAttackDamageType = DMG_BLAST
ENT.AnimTbl_MeleeAttack = {
	"nz_base_zmb_raz_attack_sickle_double_swing_1",
	"nz_base_zmb_raz_attack_sickle_double_swing_2",
	"nz_base_zmb_raz_attack_sickle_double_swing_3",
	"nz_base_zmb_raz_attack_sickle_swing_down",
	"nz_base_zmb_raz_attack_sickle_swing_l_to_r",
	"nz_base_zmb_raz_attack_sickle_swing_r_to_l",
	"nz_base_zmb_raz_attack_sickle_swing_uppercut",
	"nz_base_zmb_raz_attack_swing_l_to_r",
	"nz_base_zmb_raz_attack_swing_r_to_l",
}
ENT.MeleeAttackDistance = 72
ENT.MeleeAttackDamageDistance = 80
ENT.TimeUntilMeleeAttackDamage = false

-- Плазменный выстрел. На VJ снаряд был obj_vj_grenade; своего аналога у нас
-- нет, поэтому берём гранату аддона — она уже используется PMC.
ENT.HasRangeAttack = true
ENT.RangeAttackEntityToSpawn = "murwep_grenade"
ENT.AnimTbl_RangeAttack = {"nz_base_zmb_raz_attack_shoot_01"}
ENT.RangeDistance = 600
ENT.RangeToMeleeDistance = 300
ENT.RangeAttackOffset = Vector(24, 0, 48)
ENT.TimeUntilRangeAttackProjectileRelease = false
ENT.NextRangeAttackTime = MuR.Range(12, 16)

ENT.HasDeathAnimation = true
ENT.AnimTbl_Death = {
	"nz_base_zmb_raz_death_collapse_fallback_1",
	"nz_base_zmb_raz_death_collapse_fallback_2",
	"nz_base_zmb_raz_death_collapse_fallforward_1",
}

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
ENT.AnimTbl_Flinch = {
	"nz_base_zmb_raz_attack_shoot_01_pain",
	"nz_base_zmb_raz_pain_chest_armor",
	"nz_base_zmb_raz_pain_facemask",
}

-- Пока броня целая манглер идёт тяжёлым шагом; после первого пробития входит
-- в ярость и переходит на бег.
--
-- Шаг именно 120, а не 80: восемьдесят — это медленнее обычного зомби, и босс
-- на пятисот хитах доползал до игрока за половину волны.
ENT.WalkSpeed = 120
ENT.RunSpeed = 260

ENT.InRageState = false
ENT.InArmorBody = true
ENT.InArmorHead = true
ENT.InArmorArm = true

function ENT:OnAnimEvent(ev, evTime, evCycle, evType, evOptions)
	if evOptions == "melee" or evOptions == "melee_heavy" then
		self:ExecuteMeleeAttack()
	elseif evOptions == "step_left_large" or evOptions == "step_right_large" then
		MuR.EmitSound(self, self.SoundTbl_FootStep, 70, math.random(90, 110))
		util.ScreenShake(self:GetPos(), 4, 4, 0.4, 400)
	elseif evOptions == "raz_melee_whoosh" then
		MuR.EmitSound(self, self.SoundTbl_Swing, 65, math.random(90, 110))
	elseif evOptions == "raz_charge" then
		for i = 1, 5 do
			ParticleEffectAttach("vj_rifle_smoke_dark", PATTACH_POINT_FOLLOW, self, 13)
		end
		MuR.EmitSound(self, "bo6/npc/mangler/charge.mp3", 80, math.random(90, 110))
	elseif evOptions == "raz_shoot" then
		self:ExecuteRangeAttack()
		MuR.EmitSound(self, "physics/body/body_medium_impact_hard6.wav", 80, math.random(90, 110))
		ParticleEffectAttach("vj_rifle_full", PATTACH_POINT_FOLLOW, self, 13)
	end
end

function ENT:OnDamaged(dmginfo, hitgroup, status)
	local dm = dmginfo:GetDamage()

	if dmginfo:IsExplosionDamage() then
		self:BreakArmor(table.Random({1, 2, 5}))
	end

	if hitgroup == HITGROUP_HEAD and self.InArmorHead then
		if dm > 100 or self:Health() < self:GetMaxHealth() * 0.7 and math.random(1, 5) == 1 then
			self:BreakArmor(1)
		end
	elseif hitgroup == HITGROUP_CHEST and self.InArmorBody then
		if dm > 100 or self:Health() < self:GetMaxHealth() * 0.6 and math.random(1, 5) == 1 then
			self:BreakArmor(2)
		end
	elseif hitgroup == HITGROUP_RIGHTARM and self.InArmorArm then
		if dm > 100 or self:Health() < self:GetMaxHealth() * 0.8 and math.random(1, 5) == 1 then
			self:BreakArmor(5)
		end
	end

	local exposed = (hitgroup == HITGROUP_HEAD and not self.InArmorHead)
		or (hitgroup == HITGROUP_CHEST and not self.InArmorBody)

	local armored = (hitgroup == HITGROUP_HEAD and self.InArmorHead)
		or (hitgroup == HITGROUP_CHEST and self.InArmorBody)
		or (hitgroup == HITGROUP_RIGHTARM and self.InArmorArm)

	dmginfo:SetDamage(dm * (exposed and 2 or (armored and 0.5 or 0.25)))
end

function ENT:BreakArmor(part)
	if part == 1 and self.InArmorHead then
		self.InArmorHead = false
		self:PlayAnim("nz_base_zmb_raz_pain_facemask", true, 2)
		self:SetBodygroup(2, 1)
	elseif part == 2 and self.InArmorBody then
		self.InArmorBody = false
		self:PlayAnim("nz_base_zmb_raz_pain_chest_armor", true, 2)
		self:SetBodygroup(3, 1)
	elseif part == 5 and self.InArmorArm then
		self.InArmorArm = false
		self.HasRangeAttack = false
		self:PlayAnim("nz_base_zmb_raz_attack_shoot_01_pain", true, 2)
		self:SetBodygroup(1, 1)
	else
		return
	end

	timer.Simple(2, function()
		if not IsValid(self) then return end
		self:SetRageState(true)
	end)
end

function ENT:SetRageState(state)
	if state and self.InRageState ~= state and self:Health() > 0 then
		MuR.EmitSound(self, self.SoundTbl_Enrage, 90, math.random(90, 110))
		self:PlayAnim("nz_base_zmb_raz_enrage", true)
	end

	self.InRageState = state
end

-- До ярости манглер идёт шагом. На VJ это делалось трансляцией ACT_RUN в
-- ACT_WALK; у nextbot скорость задаёт loco, поэтому режем саму скорость.
function ENT:GetRunSpeed()
	local base = self.InRageState and self.RunSpeed or self.WalkSpeed

	return base * self:GetSpeedScale()
end
