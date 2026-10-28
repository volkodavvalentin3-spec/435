if not SERVER then return end

MuR = MuR or {}

local meta = FindMetaTable("Player")
if not meta then return end

local TICK = 0.1

function meta:GetAnalgesia()
	return math.Clamp(self:GetNW2Float("ChemAnalgesia", 0), 0, 1)
end

function meta:GetTremor()
	local tremor = 0

	local coordEnd = self:GetNW2Float("CoordinationEnd", 0)
	if coordEnd > CurTime() then
		local frac = math.Clamp((coordEnd - CurTime()) / 8, 0, 1)
		tremor = tremor + math.Clamp(self:GetNW2Float("CoordinationSeverity", 0) / 2, 0, 1) * frac
	end

	local concEnd = self:GetNW2Float("ConcussionEnd", 0)
	if concEnd > CurTime() then
		local frac = math.Clamp((concEnd - CurTime()) / 6, 0, 1)
		tremor = tremor + math.Clamp(self:GetNW2Float("ConcussionIntensity", 0) / 2, 0, 1) * frac * 0.8
	end

	if self:GetNW2Bool("ArmFracture", false) or self:GetNW2Bool("ForearmFracture", false)
		or self:GetNW2Bool("ClavicleFracture", false) then
		tremor = tremor + 0.35
	end
	if self:GetNW2Bool("Artery_ArmLeft", false) or self:GetNW2Bool("Artery_ArmRight", false) then
		tremor = tremor + 0.25
	end

	tremor = tremor + self:GetNW2Int("ShockLevel", 0) * 0.15

	if self.GetHypovolemiaStage then
		tremor = tremor + self:GetHypovolemiaStage() * 0.12
	end

	tremor = tremor * (1 - self:GetAnalgesia() * 0.6)

	return math.Clamp(tremor, 0, 1)
end

function meta:HasSteadyHands()
	return not (self:GetNW2Bool("ArmFracture", false)
		or self:GetNW2Bool("ForearmFracture", false)
		or self:GetNW2Bool("ClavicleFracture", false))
end

hook.Add("EntityFireBullets", "MuR.InjurySpread", function(shooter, data)
	if not IsValid(shooter) or not shooter:IsPlayer() then return end
	if not shooter.GetTremor then return end

	local tremor = shooter:GetNW2Float("Tremor", 0)
	if tremor <= 0.05 then return end

	data.Spread = (data.Spread or Vector(0, 0, 0)) + Vector(1, 1, 0) * tremor * 0.06
	return true
end)

hook.Add("PlayerPostThink", "MuR.InjuryEffects", function(ply)
	if not ply:Alive() then return end
	if ply:IsRoleWithoutOrgans() then return end

	local now = CurTime()
	if (ply.MuR_NextInjuryTick or 0) > now then return end
	ply.MuR_NextInjuryTick = now + TICK

	ply:SetNW2Float("Tremor", ply:GetTremor())

	if not ply:HasSteadyHands() and math.random() < 0.004 then
		local wep = ply:GetActiveWeapon()
		if IsValid(wep) and not wep.NeverDrop and not wep.CantDrop and wep:GetClass() ~= "mur_hands" then
			ply:DropWeapon(wep)
			MuR:GiveMessage2("arm_drop_weapon", ply)
		end
	end

	if not IsValid(ply:GetRD()) and ply:GetVelocity():Length2D() > 180 then
		local stumbleChance = 0
		if ply:GetNW2Bool("LegBroken", false) then stumbleChance = stumbleChance + 0.006 end
		if ply:GetNW2Bool("FootFracture", false) then stumbleChance = stumbleChance + 0.004 end
		if ply:GetNW2Bool("PelvisFracture", false) then stumbleChance = stumbleChance + 0.01 end
		if ply.GetHypovolemiaStage and ply:GetHypovolemiaStage() >= 2 then
			stumbleChance = stumbleChance + 0.004
		end

		if stumbleChance > 0 and math.random() < stumbleChance then
			ply:StartRagdolling(0, 4)
			MuR:GiveMessage2("leg_stumble", ply)
		end
	end
end)

hook.Add("PlayerCanHearPlayersVoice", "MuR.InjuryVoice", function(listener, talker)
	if not IsValid(talker) or not talker:Alive() then return end
	if talker:GetOrganDamageStage("neck") >= 2 then
		return false
	end
end)

hook.Add("PlayerSpawn", "MuR.InjuryEffectsReset", function(ply)
	ply:SetNW2Float("Tremor", 0)
	ply.MuR_NextInjuryTick = nil
end)
