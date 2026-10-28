AddCSLuaFile()

ENT.Base = "bs_npc_creature"
ENT.Type = "nextbot"
ENT.PrintName = "Vermin"
ENT.Author = "Hari"
ENT.Category = "Bloodshed: Dark Aether"
ENT.Spawnable = true

if CLIENT then return end

ENT.Model = {"models/murdered/nz/bo6_vermin.mdl"}
ENT.StartHealth = 50

ENT.CollisionMins = Vector(-12, -12, 0)
ENT.CollisionMaxs = Vector(12, 12, 48)
ENT.EyeHeight = 40

ENT.CustomBlood_Particle = {"blood_impact_red_01"}

ENT.SoundTbl_FootStep = MuR.SoundDir("bo6/npc/vermin/step")
ENT.SoundTbl_CombatIdle = MuR.SoundDir("bo6/npc/vermin/amb")
ENT.SoundTbl_Death = MuR.SoundDir("bo6/npc/vermin/death")
ENT.SoundTbl_LeapAttackJump = MuR.SoundDir("bo6/npc/vermin/behind")
ENT.SoundTbl_MeleeAttack = MuR.SoundDir("bo6/npc/mangler/damage")
ENT.SoundTbl_BeforeMeleeAttack = MuR.SoundDir("bo6/npc/vermin/attack")

ENT.HasMeleeAttack = true
ENT.MeleeAttackDamage = 10
ENT.MeleeAttackDamageType = DMG_SLASH
ENT.AnimTbl_MeleeAttack = {
	"nz_base_vermin_attack_01",
	"nz_base_vermin_attack_02",
}
ENT.MeleeAttackDistance = 56
ENT.MeleeAttackDamageDistance = 64
-- Урон навешен на событие анимации "melee", а не на таймер.
ENT.TimeUntilMeleeAttackDamage = false

ENT.HasDeathAnimation = true
ENT.AnimTbl_Death = {"nz_base_vermin_dth_01", "nz_base_vermin_dth_02", "nz_base_vermin_dth_03"}

ENT.JumpParams = {
	Enabled = true,
	MaxRise = 200,
	MaxDrop = 600,
	MaxDistance = 400,
}

ENT.CanFlinch = true
ENT.HasFootstepSounds = false
ENT.FlinchChance = 2
ENT.FlinchCooldown = 8
ENT.AnimTbl_Flinch = {"nz_base_vermin_knockback"}

ENT.HasLeapAttack = true
ENT.AnimTbl_LeapAttack = {"nz_base_vermin_lunge_start"}
ENT.LeapAttackDistance = {150, 500}
ENT.TimeUntilLeapAttackVelocity = 0.3
ENT.NextLeapAttackTime = MuR.Range(6, 8)
ENT.TimeUntilLeapAttackDamage = 0.8
ENT.LeapAttackDamage = 15

function ENT:OnAnimEvent(ev, evTime, evCycle, evType, evOptions)
	if evOptions == "melee" or evOptions == "melee_heavy" then
		self:ExecuteMeleeAttack()
	elseif evOptions == "vermin_step" then
		MuR.EmitSound(self, self.SoundTbl_FootStep, 70, math.random(90, 110))
	end
end

-- CapabilitiesAdd(CAP_MOVE_CLIMB) и трансляции ACT_CLIMB_* из версии на VJ
-- выброшены: у nextbot нет тасков движка, лазание по лестницам навмеша ведёт
-- сам PathFollower.

function ENT:OnLeapAttack(status, enemy)
	return math.abs(enemy:GetPos().z - self:GetPos().z) < 72
end
