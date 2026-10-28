AddCSLuaFile()

ENT.Base = "npc_bs_pmc"
ENT.Type = "nextbot"
ENT.PrintName = "PMC Gas Unit"
ENT.Author = "Hari"
ENT.Category = "Bloodshed"
ENT.Spawnable = true

if CLIENT then return end

ENT.Model = {"models/murdered/npc/amb/che_pm.mdl"}

ENT.StartHealth = 125

function ENT:GetSpawnWeapons()
	return {"tfa_bs_l1a1"}
end

ENT.Weapon_RetreatDistance = 300

ENT.GrenadeChance = 40
ENT.GrenadeEntity = "mur_gas_cloud"
ENT.GrenadeMinDistance = 250
ENT.GrenadeMaxDistance = 1300
ENT.GrenadeSharedKey = "gas"
ENT.GrenadeSharedCooldown = 9

-- Чем травит. Профиль разыгрывается на каждый бросок, поэтому один и тот же
-- газовик может и выкурить с позиции, и убить стоящих в облаке.
ENT.GasProfiles = {
	{substance = "chlorine", radius = 300, lifetime = 10, color = "200 255 100"},
	{substance = "carbon_monoxide", radius = 400, lifetime = 25, color = "200 255 100"},
	{substance = "nerve_agent", radius = 350, lifetime = 10, color = "180 180 180"},
}

function ENT:OnGrenadeAttackExecute(nade)
	if not IsValid(nade) then return end

	local profile = self.GasProfiles[math.random(#self.GasProfiles)]

	nade.Substance = profile.substance
	nade.Radius = profile.radius
	nade.Lifetime = profile.lifetime
	nade.SmokeColor = profile.color
	nade.Visible = true
end
