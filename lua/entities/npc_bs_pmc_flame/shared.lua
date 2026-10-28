AddCSLuaFile()

ENT.Base = "npc_bs_pmc"
ENT.Type = "nextbot"
ENT.PrintName = "PMC Flame Unit"
ENT.Author = "Hari"
ENT.Category = "Bloodshed"
ENT.Spawnable = true

if CLIENT then return end

ENT.Model = {"models/murdered/npc/amb/epsilon-9.mdl"}

ENT.StartHealth = 125

function ENT:GetSpawnWeapons()
	return {"tfa_bs_m500"}
end

ENT.Weapon_RetreatDistance = 260

ENT.GrenadeChance = 40
ENT.GrenadeEntity = "bloodshed_molotov"
ENT.GrenadeMinDistance = 200
ENT.GrenadeMaxDistance = 900
ENT.GrenadeSharedKey = "fire"
ENT.GrenadeSharedCooldown = 8

-- Дожигание трупов: ищет тела вокруг и закидывает их зажигательной.
ENT.CorpseBurnRange = 500
ENT.CorpseBurnCooldown = 12

local function FindNearestCorpse(self)
	local nearest, nearestDist = nil, self.CorpseBurnRange

	for _, ent in ipairs(ents.FindInSphere(self:GetPos(), self.CorpseBurnRange)) do
		if not IsValid(ent) then continue end
		if ent:GetClass() ~= "prop_ragdoll" then continue end
		if not ent.isRDRag or ent.IsBurning then continue end
		if not self:HasLOS(ent) then continue end

		local dist = self:GetPos():Distance(ent:GetPos())
		if dist < nearestDist then
			nearestDist = dist
			nearest = ent
		end
	end

	return nearest
end

--
-- Трупы дожигаются вне боевой ветки: это работа по площади, а не по цели, и
-- прерывать ради неё перестрелку незачем.
--
function ENT:PMCOnThink()
	if self:GetPMCCooldown("corpse_burn") > 0 then return end

	local corpse = FindNearestCorpse(self)
	if not IsValid(corpse) then return end

	self:SetPMCCooldown("corpse_burn", self.CorpseBurnCooldown)
	corpse.IsBurning = true

	local src = self:GetEyeOrigin()
	local dir = (corpse:GetPos() - src):GetNormalized()

	local fire = ents.Create("bloodshed_molotov")
	if not IsValid(fire) then return end

	fire:SetPos(src)
	fire:SetAngles(dir:Angle())
	fire:SetOwner(self)
	fire.Owner = self
	fire.BSOwner = self
	fire:Spawn()
	fire:Activate()

	local phys = fire:GetPhysicsObject()
	if IsValid(phys) then
		phys:SetVelocity(dir * 700 + Vector(0, 0, 150))
	end
end
