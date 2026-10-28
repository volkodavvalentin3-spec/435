AddCSLuaFile()

ENT.Base = "bs_npc_creature"
ENT.Type = "nextbot"
ENT.PrintName = "PTICHKI"
ENT.Author = "Hari"
ENT.Category = "Bloodshed"
ENT.Spawnable = true
ENT.AdminOnly = true

if CLIENT then
	function ENT:Think()
		local dlight = DynamicLight(self:EntIndex())
		if not dlight then return end

		dlight.pos = self:GetPos() + Vector(0, 0, 8)
		dlight.r = 200
		dlight.g = 20
		dlight.b = 20
		dlight.brightness = 4
		dlight.decay = 512
		dlight.size = 256
		dlight.dietime = CurTime() + 1
	end

	return
end

ENT.Model = {"models/Zombie/Fast.mdl"}
ENT.StartHealth = 999999999

ENT.CollisionMins = Vector(-4, -4, 0)
ENT.CollisionMaxs = Vector(4, 4, 16)
ENT.EyeHeight = 12

ENT.RandomSkins = true
ENT.RandomBodygroups = true

ENT.JumpParams = {
	Enabled = true,
	MaxRise = 1600,
	MaxDrop = 1600,
	MaxDistance = 1600,
}

ENT.RunSpeed = 300

ENT.MeleeAttackDistance = 64
ENT.MeleeAttackDamageDistance = 72
ENT.HasMeleeAttackKnockBack = true
ENT.MeleeAttackDamage = math.huge
ENT.MeleeAttackDamageType = DMG_BLAST
ENT.MeleeAttackPlayerSpeed = true
ENT.AnimTbl_MeleeAttack = {""}

ENT.HasLeapAttack = true
ENT.AnimTbl_LeapAttack = ACT_JUMP
ENT.LeapAttackDistance = {150, 1200}

ENT.HasDeathCorpse = false
ENT.EnemyXRayDetection = true

ENT.PtichkiSoundInterval = 12.2
ENT.AuraRadius = 72

function ENT:CustomOnInitialize()
	self:SetNoDraw(true)
	self:DrawShadow(false)
	self.PtichkiSound = 0

	local mod = ents.Create("base_anim")
	mod:SetModel("models/murdered/secret/pukeko.mdl")
	mod:SetPos(self:GetPos())
	mod:SetAngles(self:GetAngles())
	mod:SetParent(self)
	mod:Spawn()
	self:DeleteOnRemove(mod)
end

function ENT:OnLeapAttack(status, enemy)
	return math.abs(enemy:GetPos().z - self:GetPos().z) < 72
end

function ENT:CustomOnThink()
	if self.PtichkiSound < CurTime() then
		self:EmitSound("<murdered/ptichki.mp3", 90, 100)
		self.PtichkiSound = CurTime() + self.PtichkiSoundInterval
	end

	util.ScreenShake(self:GetPos(), 4, 16, 1, 1024)

	-- Аура смерти. Бьёт всё без разбора — так было и на VJ, это админская
	-- сущность-шутка, а не боевой NPC.
	for _, ent in ipairs(ents.FindInSphere(self:GetPos(), self.AuraRadius)) do
		if ent == self then continue end

		local dmg = DamageInfo()
		dmg:SetDamageType(DMG_BLAST)
		dmg:SetDamage(math.huge)
		dmg:SetAttacker(self)
		dmg:SetInflictor(self)
		dmg:SetDamagePosition(ent:WorldSpaceCenter())
		dmg:SetDamageForce((ent:GetPos() - self:GetPos()):GetNormalized() * 100000)
		ent:TakeDamageInfo(dmg)

		if string.match(ent:GetClass(), "door") then
			ent:Fire("Unlock")
			ent:Fire("Open")
		end
	end
end
