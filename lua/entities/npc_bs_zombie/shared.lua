AddCSLuaFile()

ENT.Base = "bs_npc_creature"
ENT.Type = "nextbot"
ENT.PrintName = "Zombie"
ENT.Author = "Hari"
ENT.Category = "Bloodshed"
ENT.Spawnable = true

if CLIENT then return end

ENT.Model = {
	"models/murdered/npc/zombie/zombie_male_01.mdl",
	"models/murdered/npc/zombie/zombie_male_02.mdl",
	"models/murdered/npc/zombie/zombie_male_03.mdl",
	"models/murdered/npc/zombie/zombie_male_04.mdl",
	"models/murdered/npc/zombie/zombie_male_05.mdl",
	"models/murdered/npc/zombie/zombie_male_06.mdl",
	"models/murdered/npc/zombie/zombie_male_07.mdl",
	"models/murdered/npc/zombie/zombie_male_08.mdl",
	"models/murdered/npc/zombie/zombie_male_09.mdl",
}
ENT.StartHealth = 75

ENT.RandomSkins = true
ENT.RandomBodygroups = true

ENT.JumpParams = {
	Enabled = true,
	MaxRise = 600,
	MaxDrop = 600,
	MaxDistance = 600,
}

ENT.MeleeAttackDamage = 20
ENT.MeleeAttackDamageType = DMG_SLASH
ENT.MeleeAttackPlayerSpeed = true
ENT.AnimTbl_MeleeAttack = {"attackh_quick", "attackg_quick"}

-- Прыжковой атаки у обычного зомби нет: он должен просто идти. JumpParams
-- ниже при этом оставлены включёнными — по ним PathFollower перепрыгивает
-- разрывы, когда так ведёт сам маршрут.
ENT.HasLeapAttack = false
ENT.AnimTbl_LeapAttack = ACT_JUMP

ENT.SoundTbl_MeleeAttack = "Zombie.AttackHit"
ENT.SoundTbl_MeleeAttackExtra = "Zombie.AttackHit"
ENT.SoundTbl_MeleeAttackMiss = "Zombie.AttackHit"
ENT.SoundTbl_Feeding = {"npc/barnacle/barnacle_crunch2.wav", "npc/barnacle/barnacle_crunch3.wav"}

ENT.AnimTbl_GetUp = {"slumprise_a", "slumprise_a2"}

--------------------------------------------------------------------------------
-- Кормление на сбитых с ног игроках
--------------------------------------------------------------------------------

ENT.CanFeedOnRagdoll = true
ENT.FeedingRagdollSearchRadius = 400
ENT.FeedingDamagePerTick = 4
ENT.FeedingTickInterval = 0.8
ENT.FeedingEffectInterval = 0.6
ENT.ActiveRagdoll = nil
ENT.FeedingTarget = nil
ENT.IsFeedingMode = false
ENT.FeedingTargetBone = nil
ENT.NextFeedingSearchT = 0

function ENT:OnLeapAttack(status, enemy)
	return math.abs(enemy:GetPos().z - self:GetPos().z) < 72
end

function ENT:CustomOnThink()
	if not self.CanFeedOnRagdoll then return end
	if self.IsFeedingMode then return end
	if IsValid(self:GetEnemy()) then return end
	if self:IsBusy() then return end
	if MuR.GameStarted == false then return end

	local feedTarget = self:FindFeedingRagdoll()
	if IsValid(feedTarget) then
		self:StartFeedingMode(feedTarget)
	end
end

function ENT:FindFeedingRagdoll()
	if CurTime() < self.NextFeedingSearchT then return nil end
	self.NextFeedingSearchT = CurTime() + 0.5

	local nearestRag = nil
	local nearestDist = self.FeedingRagdollSearchRadius

	for _, ent in ipairs(ents.FindInSphere(self:GetPos(), self.FeedingRagdollSearchRadius)) do
		if not IsValid(ent) then continue end
		if ent:GetClass() ~= "prop_ragdoll" then continue end
		if not ent.isRDRag or ent.IsDead then continue end
		if not IsValid(ent.Owner) or not ent.Owner:Alive() then continue end

		local ragHP = ent.RagdollHealth
		if not ragHP or ragHP <= 0 then continue end
		if not self:HasLOS(ent) then continue end

		local dist = self:GetPos():Distance(ent:GetPos())
		if dist < nearestDist then
			nearestDist = dist
			nearestRag = ent
		end
	end

	return nearestRag
end

function ENT:GetClosestPhysBone(ragdoll)
	if not IsValid(ragdoll) then return nil, nil end

	local closestBone = 0
	local closestPos = ragdoll:GetPos()
	local closestDist = math.huge
	local myPos = self:GetPos()

	for i = 0, ragdoll:GetPhysicsObjectCount() - 1 do
		local phys = ragdoll:GetPhysicsObjectNum(i)
		if not IsValid(phys) then continue end

		local bonePos = phys:GetPos()
		local dist = myPos:Distance(bonePos)
		if dist < closestDist then
			closestDist = dist
			closestBone = i
			closestPos = bonePos
		end
	end

	return closestBone, closestPos
end

-- Зомби на время кормления сам становится рэгдоллом и ползёт к жертве на
-- физике. MoveType не трогаем, в отличие от версии на VJ: у nextbot им управляет
-- loco, и MOVETYPE_NONE его ломает. Стоять на месте заставляет BS_STATE_ANIM_HOLD.
function ENT:CreateActiveRagdoll()
	if IsValid(self.ActiveRagdoll) then return self.ActiveRagdoll end

	local ragdoll = ents.Create("prop_ragdoll")
	if not IsValid(ragdoll) then return nil end

	ragdoll:SetModel(self:GetModel())
	ragdoll:SetPos(self:GetPos())
	ragdoll:SetAngles(self:GetAngles())
	ragdoll:SetSkin(self:GetSkin())

	for i = 0, self:GetNumBodyGroups() - 1 do
		ragdoll:SetBodygroup(i, self:GetBodygroup(i))
	end

	ragdoll:Spawn()
	ragdoll:Activate()

	ragdoll.IsActiveZombieRagdoll = true
	ragdoll.OwnerNPC = self
	ragdoll.RagdollHealth = self:Health()
	ragdoll.MaxRagdollHealth = self:GetMaxHealth()
	ragdoll.DisableMuRGibs = true

	self.ActiveRagdoll = ragdoll
	self:SetNoDraw(true)
	-- SOLID менять нельзя: у nextbot от него зависит loco. Хватает флага
	-- «не сплошной» — тело на время кормления всё равно изображает рэгдолл.
	self:SetNotSolid(true)

	return ragdoll
end

function ENT:MoveRagdollToTarget()
	if not IsValid(self.ActiveRagdoll) or not IsValid(self.FeedingTarget) then return end

	local targetBone, targetPos = self:GetClosestPhysBone(self.FeedingTarget)
	if not targetPos then return end

	self.FeedingTargetBone = targetBone

	local ragdoll = self.ActiveRagdoll
	local pelvisPhys = ragdoll:GetPhysicsObjectNum(0)
	if not IsValid(pelvisPhys) then return end

	local pelvisPos = pelvisPhys:GetPos()
	local dist = pelvisPos:Distance(targetPos)

	local headBoneIdx = self:GetHeadPhysBone(ragdoll)
	local headPhys = ragdoll:GetPhysicsObjectNum(headBoneIdx)
	local headPos = IsValid(headPhys) and headPhys:GetPos() or pelvisPos

	local dirFromPelvis = (targetPos - pelvisPos):GetNormalized()

	self.CrawlPhase = (self.CrawlPhase or 0) + 0.15
	local crawlCycle = math.sin(self.CrawlPhase)

	if dist > 40 then
		if IsValid(headPhys) then
			local headToTarget = targetPos - headPos
			local headDist = headToTarget:Length()
			local headDir = headToTarget:GetNormalized()

			local headForce = headDir * 300
			headForce.z = headForce.z + 150
			headPhys:ApplyForceCenter(headForce)

			if headDist > 50 then
				local aggressivePull = headDir * 400
				aggressivePull.z = aggressivePull.z + 200
				headPhys:ApplyForceCenter(aggressivePull)
			end
		end

		for _, boneIdx in ipairs({1, 2}) do
			local spinePhys = ragdoll:GetPhysicsObjectNum(boneIdx)
			if IsValid(spinePhys) then
				local spineForce = dirFromPelvis * (boneIdx == 1 and 175 or 150)
				spineForce.z = spineForce.z - (boneIdx == 1 and 15 or 10)
				spinePhys:ApplyForceCenter(spineForce)
			end
		end

		local rightPhase = crawlCycle > 0

		for _, boneIdx in ipairs({3, 4, 5}) do
			local phys = ragdoll:GetPhysicsObjectNum(boneIdx)
			if IsValid(phys) then
				local reachDir = (targetPos - phys:GetPos()):GetNormalized()
				local reachForce = reachDir * (rightPhase and 350 or 150)
				reachForce.z = reachForce.z + (rightPhase and 50 or -25)
				phys:ApplyForceCenter(reachForce)

				if boneIdx == 5 then
					phys:ApplyForceCenter(reachDir * 250)
				end
			end
		end

		for _, boneIdx in ipairs({6, 7, 8}) do
			local phys = ragdoll:GetPhysicsObjectNum(boneIdx)
			if IsValid(phys) then
				local reachDir = (targetPos - phys:GetPos()):GetNormalized()
				local reachForce = reachDir * (rightPhase and 150 or 350)
				reachForce.z = reachForce.z + (rightPhase and -25 or 50)
				phys:ApplyForceCenter(reachForce)

				if boneIdx == 8 then
					phys:ApplyForceCenter(reachDir * 250)
				end
			end
		end

		for _, boneIdx in ipairs({9, 10, 11, 12, 13, 14}) do
			local phys = ragdoll:GetPhysicsObjectNum(boneIdx)
			if IsValid(phys) then
				local dragForce = dirFromPelvis * 75
				dragForce.z = -15
				phys:ApplyForceCenter(dragForce)
			end
		end

		local pelvisForce = dirFromPelvis * 125
		pelvisForce.z = -10
		pelvisPhys:ApplyForceCenter(pelvisForce)
	else
		if IsValid(headPhys) then
			local biteDir = (targetPos - headPos):GetNormalized()
			local biteForce = biteDir * 500
			biteForce.z = biteForce.z + 150
			headPhys:ApplyForceCenter(biteForce)
		end

		for _, boneIdx in ipairs({3, 4, 5, 6, 7, 8}) do
			local phys = ragdoll:GetPhysicsObjectNum(boneIdx)
			if IsValid(phys) then
				local grabDir = (targetPos - phys:GetPos()):GetNormalized()
				phys:ApplyForceCenter(grabDir * 300)
			end
		end
	end

	return dist
end

function ENT:GetHeadPhysBone(ragdoll)
	local physCount = ragdoll:GetPhysicsObjectCount()
	local highestBone = 0
	local highestZ = -math.huge

	for i = 0, math.min(physCount - 1, 3) do
		local phys = ragdoll:GetPhysicsObjectNum(i)
		if IsValid(phys) then
			local pos = phys:GetPos()
			if pos.z > highestZ then
				highestZ = pos.z
				highestBone = i
			end
		end
	end

	return highestBone
end

function ENT:StartFeedingMode(targetRagdoll)
	if self.IsFeedingMode then return end
	if not IsValid(targetRagdoll) then return end

	self.IsFeedingMode = true
	self.FeedingTarget = targetRagdoll

	local activeRag = self:CreateActiveRagdoll()
	if not IsValid(activeRag) then
		self.IsFeedingMode = false
		return
	end

	self:SetState(BS_STATE_ANIM_HOLD)

	self.FeedingThinkTimer = "BS_FeedingThink_" .. self:EntIndex()
	local name = self.FeedingThinkTimer

	timer.Create(name, 0.1, 0, function()
		local rag = self.ActiveRagdoll

		if not IsValid(self) then
			if IsValid(rag) then
				rag.IsActiveZombieRagdoll = false
				rag.OwnerNPC = nil
				SafeRemoveEntityDelayed(rag, 30)
			end
			timer.Remove(name)
			return
		end

		self:FeedingThink()
	end)
end

function ENT:FeedingThink()
	if not self.IsFeedingMode then return end
	if not IsValid(self.ActiveRagdoll) then self:StopFeedingMode() return end
	if not IsValid(self.FeedingTarget) then self:StopFeedingMode() return end

	local targetOwner = self.FeedingTarget.Owner
	if not IsValid(targetOwner) or not targetOwner:Alive() or MuR.GameStarted == false then
		self:StopFeedingMode()
		return
	end

	local dist = self:MoveRagdollToTarget()

	if dist and dist <= 60 then
		self:PerformFeeding()
	end

	if not IsValid(self.ActiveRagdoll) then return end

	local torsoPhys = self.ActiveRagdoll:GetPhysicsObjectNum(0)
	if IsValid(torsoPhys) then
		self:SetPos(torsoPhys:GetPos())
	end
end

function ENT:PerformFeeding()
	if not IsValid(self.FeedingTarget) then return end

	self.NextFeedingDamageT = self.NextFeedingDamageT or 0
	self.NextFeedingEffectT = self.NextFeedingEffectT or 0

	if CurTime() >= self.NextFeedingDamageT then
		local dmginfo = DamageInfo()
		dmginfo:SetDamage(self.FeedingDamagePerTick)
		dmginfo:SetDamageType(DMG_SLASH)
		dmginfo:SetAttacker(self)
		dmginfo:SetInflictor(self)

		if self.FeedingTargetBone then
			local phys = self.FeedingTarget:GetPhysicsObjectNum(self.FeedingTargetBone)
			if IsValid(phys) then
				dmginfo:SetDamagePosition(phys:GetPos())
			end
		end

		self.FeedingTarget:TakeDamageInfo(dmginfo)

		local ply = self.FeedingTarget.Owner
		if IsValid(ply) and ply:IsPlayer() then
			ply.IsRagStanding = false
		end

		if self.FeedingTarget.RagdollHealth then
			self.FeedingTarget.RagdollHealth = self.FeedingTarget.RagdollHealth - self.FeedingDamagePerTick
			if self.FeedingTarget.RagdollHealth <= 0 then
				self:OnFeedingTargetDepleted()
			end
		end

		self.NextFeedingDamageT = CurTime() + self.FeedingTickInterval
	end

	if CurTime() >= self.NextFeedingEffectT then
		self:CreateFeedingEffects()
		self.NextFeedingEffectT = CurTime() + self.FeedingEffectInterval
	end
end

function ENT:CreateFeedingEffects()
	if MuR.GameStarted == false then return end
	if not IsValid(self.ActiveRagdoll) or not IsValid(self.FeedingTarget) then return end

	local effectPos = self.FeedingTarget:GetPos()

	if self.FeedingTargetBone then
		local phys = self.FeedingTarget:GetPhysicsObjectNum(self.FeedingTargetBone)
		if IsValid(phys) then effectPos = phys:GetPos() end
	end

	local effectBlood = EffectData()
	effectBlood:SetOrigin(effectPos)
	effectBlood:SetScale(math.random(5, 15))
	util.Effect("BloodImpact", effectBlood)

	MuR.EmitSound(self.ActiveRagdoll, self.SoundTbl_Feeding, 70, math.random(90, 110))

	if math.random(1, 5) == 1 then
		self:CreateGibEntity(nil, nil, {Pos = effectPos})
	end
end

function ENT:OnFeedingTargetDepleted()
	self:StopFeedingMode()
end

function ENT:StopFeedingMode()
	self.IsFeedingMode = false
	self.FeedingTarget = nil
	self.FeedingTargetBone = nil

	local timerName = self.FeedingThinkTimer
	if timerName then
		timer.Remove(timerName)
		self.FeedingThinkTimer = nil
	end

	if IsValid(self.ActiveRagdoll) then
		local ragPos = self.ActiveRagdoll:GetPos()
		local ragAng = self.ActiveRagdoll:GetAngles()

		self:SetPos(ragPos + Vector(0, 0, 20))
		self:SetAngles(Angle(0, ragAng.y, 0))

		self.ActiveRagdoll:Remove()
	end

	self.ActiveRagdoll = nil
	self:SetNoDraw(false)
	self:SetNotSolid(false)

	if self.BSDying then return end

	self:SetState(BS_STATE_NONE)

	for _, anim in ipairs(self.AnimTbl_GetUp) do
		local dur = MuR.AnimDuration(self, anim)
		if dur > 0 then
			self:PlayAnim(anim, true, dur)
			self:SetState(BS_STATE_ANIM, dur)
			break
		end
	end
end

function ENT:OnActiveRagdollDamaged(dmginfo)
	if not IsValid(self.ActiveRagdoll) then return end

	self.ActiveRagdoll.RagdollHealth = (self.ActiveRagdoll.RagdollHealth or self:Health()) - dmginfo:GetDamage() * 2

	if self.ActiveRagdoll.RagdollHealth <= 0 then
		self:OnActiveRagdollKilled(dmginfo)
	end
end

function ENT:OnActiveRagdollKilled(dmginfo)
	local timerName = self.FeedingThinkTimer
	if timerName then
		timer.Remove(timerName)
		self.FeedingThinkTimer = nil
	end

	if IsValid(self.ActiveRagdoll) then
		local ragPos = self.ActiveRagdoll:GetPos()

		local effectBlood = EffectData()
		effectBlood:SetOrigin(ragPos)
		effectBlood:SetScale(math.random(20, 40))
		util.Effect("BloodImpact", effectBlood)

		for i = 1, math.random(3, 6) do
			self:CreateGibEntity(nil, nil, {Pos = ragPos})
		end

		self.ActiveRagdoll.IsActiveZombieRagdoll = false
		self.ActiveRagdoll.OwnerNPC = nil
		SafeRemoveEntityDelayed(self.ActiveRagdoll, 30)
	end

	self.IsFeedingMode = false
	self.ActiveRagdoll = nil
	self:Remove()
end

function ENT:CustomOnRemove()
	local timerName = self.FeedingThinkTimer
	if timerName then
		timer.Remove(timerName)
		self.FeedingThinkTimer = nil
	end

	if IsValid(self.ActiveRagdoll) then
		self.ActiveRagdoll.IsActiveZombieRagdoll = false
		self.ActiveRagdoll.OwnerNPC = nil
		SafeRemoveEntityDelayed(self.ActiveRagdoll, 30)
		self.ActiveRagdoll = nil
	end
end

-- Пока зомби кормится, его тело — это prop_ragdoll, и урон приходит в него,
-- а не в NPC. Хук переводит попадания обратно на владельца.
hook.Add("EntityTakeDamage", "BS_ActiveRagdollDamage_Zombie", function(ent, dmginfo)
	if not IsValid(ent) then return end
	if ent:GetClass() ~= "prop_ragdoll" then return end
	if not ent.IsActiveZombieRagdoll then return end
	if not IsValid(ent.OwnerNPC) then return end

	local att = dmginfo:GetAttacker()
	if not IsValid(att) or att == game.GetWorld() or MuR.IsAI(att) then return end

	local dmgType = dmginfo:GetDamageType()
	if not dmginfo:IsBulletDamage() and not dmginfo:IsExplosionDamage()
		and dmgType ~= DMG_CLUB and dmgType ~= DMG_SLASH then
		return
	end

	ent.OwnerNPC:OnActiveRagdollDamaged(dmginfo)
end)
