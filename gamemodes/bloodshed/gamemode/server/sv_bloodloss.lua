if not SERVER then return end

MuR = MuR or {}

local meta = FindMetaTable("Player")
if not meta then return end

local BLOOD_MAX = 100

local RATE_MINOR_WOUND = 0.12
local RATE_DEEP_WOUND = 0.35
local RATE_ARTERIAL_WOUND = 1.10

local ARTERY_RATES = {
	Artery_Neck = 2.20,
	Artery_Heart = 1.80,
	Artery_LegLeft = 1.30,
	Artery_LegRight = 1.30,
	Artery_ArmLeft = 0.90,
	Artery_ArmRight = 0.90,
	Artery_Generic = 0.80
}

local RATE_INTERNAL_BLEED = 0.25
local RATE_PER_BLEEDLEVEL = 0.18
local RATE_HARDBLEED_FLOOR = 1.00

local REGEN_PER_SECOND = 0.05

local TICK_INTERVAL = 0.25

local NEUTRAL_CHEM = {
	BleedMul = 1, PerfusionMul = 1, DemandAdd = 0, CellularBlock = 0,
	RespDepression = 0, Analgesia = 0, Sedation = 0, StaminaMul = 1,
	CoordNoise = 0, HeartStrain = 0, PulseAdd = 0
}

local function chemMods(ply)
	if not ply.GetChemMods then return NEUTRAL_CHEM end
	return ply:GetChemMods() or NEUTRAL_CHEM
end

MuR.GetChemModsOrNeutral = chemMods

function meta:GetBloodVolume()
	return self:GetNW2Float("BloodVolume", BLOOD_MAX)
end

function meta:SetBloodVolume(value)
	self:SetNW2Float("BloodVolume", math.Clamp(value or BLOOD_MAX, 0, BLOOD_MAX))
end

function meta:AddBloodVolume(delta)
	self:SetBloodVolume(self:GetBloodVolume() + (delta or 0))
end

function meta:GetBloodVolumeFraction()
	return self:GetBloodVolume() / BLOOD_MAX
end

function meta:GetBleedRate()
	if not self:Alive() then return 0 end
	if self:IsRoleWithoutOrgans() then return 0 end

	local rate = 0

	rate = rate + self:GetNW2Int("MinorBleedWounds", 0) * RATE_MINOR_WOUND
	rate = rate + self:GetNW2Int("DeepBleedWounds", 0) * RATE_DEEP_WOUND
	rate = rate + self:GetNW2Int("ArterialBleedWounds", 0) * RATE_ARTERIAL_WOUND

	for flag, flagRate in pairs(ARTERY_RATES) do
		if self:GetNW2Bool(flag, false) then
			rate = rate + flagRate
		end
	end

	rate = rate + self:GetNW2Float("BleedLevel", 0) * RATE_PER_BLEEDLEVEL

	if self:GetNW2Float("InternalBleedEnd", 0) > CurTime() then
		rate = rate + RATE_INTERNAL_BLEED
	end

	if self:GetNW2Bool("HardBleed", false) then
		rate = math.max(rate, RATE_HARDBLEED_FLOOR)
	end

	rate = rate * chemMods(self).BleedMul

	return math.max(rate, 0)
end

function meta:GetBleedExertionScale()
	if self:GetNW2Bool("IsUnconscious", false) then return 0.8 end

	local speed = self:GetVelocity():Length2D()
	if speed > 190 then return 1.5 end
	if speed > 60 then return 1.2 end
	if IsValid(self:GetRD()) then return 0.85 end

	return 1
end

local HYPOVOLEMIA_STAGES = {
	{threshold = 70, stage = 1},
	{threshold = 50, stage = 2},
	{threshold = 30, stage = 3},
	{threshold = 15, stage = 4}
}

function meta:GetHypovolemiaStage()
	local volume = self:GetBloodVolume()
	local stage = 0

	for _, entry in ipairs(HYPOVOLEMIA_STAGES) do
		if volume < entry.threshold then
			stage = math.max(stage, entry.stage)
		end
	end

	return stage
end

local OXYGEN_MAX = 100

local OXYGEN_ARREST_SECONDS = 45

local OXYGEN_RECOVERY_RATE = (OXYGEN_MAX / OXYGEN_ARREST_SECONDS) * 0.6

local CARDIAC_RESERVE = 1.7

local OXYGEN_UNCONSCIOUS = 55
local OXYGEN_INJURY = 25

function meta:GetCerebralOxygen()
	return self:GetNW2Float("CerebralOxygen", OXYGEN_MAX)
end

function meta:SetCerebralOxygen(value)
	self:SetNW2Float("CerebralOxygen", math.Clamp(value or OXYGEN_MAX, 0, OXYGEN_MAX))
end

function meta:GetPerfusion()
	local volFrac = self:GetBloodVolumeFraction()
	local perfusion = math.Clamp((volFrac - 0.15) / 0.55, 0, 1)

	local mods = chemMods(self)

	local heartStage = math.max(self:GetOrganDamageStage("heart") + mods.HeartStrain, 0)
	perfusion = perfusion * math.Clamp(1 - heartStage * 0.22, 0.15, 1)

	local lungStage = math.max(self:GetOrganDamageStage("lungs"),
		self:GetOrganDamageStage("lung_left"), self:GetOrganDamageStage("lung_right"))
	perfusion = perfusion * math.Clamp(1 - lungStage * 0.18, 0.25, 1)
	if self:GetNW2Bool("Pneumothorax", false) then
		perfusion = perfusion * 0.85
	end

	if self:GetNW2Bool("Artery_Neck", false) then
		perfusion = perfusion * 0.45
	end
	perfusion = perfusion * math.Clamp(1 - self:GetOrganDamageStage("carotid") * 0.2, 0.3, 1)

	perfusion = perfusion * mods.PerfusionMul

	return math.Clamp(perfusion, 0, 1)
end

function meta:GetOxygenDemand()
	local demand = 1

	local speed = self:GetVelocity():Length2D()
	if speed > 190 then
		demand = demand + 0.35
	elseif speed > 60 then
		demand = demand + 0.15
	end

	if self:GetNW2Float("AdrenalineEnd", 0) > CurTime() then
		demand = demand + 0.2
	end

	if self:GetNW2Bool("IsUnconscious", false) then
		demand = demand - 0.25
	end

	local mods = chemMods(self)
	demand = demand + mods.DemandAdd

	demand = demand - mods.Sedation * 0.25

	return math.max(demand, 0.5)
end

function meta:GetOxygenDelivery()
	return self:GetPerfusion() * CARDIAC_RESERVE * (1 - chemMods(self).RespDepression)
end

function meta:GetOxygenTimeLeft()
	local deficit = self:GetOxygenDemand() - self:GetOxygenDelivery()
	if deficit <= 0 then return nil end

	local drain = (OXYGEN_MAX / OXYGEN_ARREST_SECONDS) * deficit
	if drain <= 0 then return nil end

	return self:GetCerebralOxygen() / drain
end

local function processOxygen(ply, dt)
	local delivery = ply:GetOxygenDelivery()
	local demand = ply:GetOxygenDemand()
	local deficit = demand - delivery
	local oxygen = ply:GetCerebralOxygen()

	deficit = deficit + chemMods(ply).CellularBlock

	if deficit > 0 then
		oxygen = oxygen - (OXYGEN_MAX / OXYGEN_ARREST_SECONDS) * deficit * dt
	elseif oxygen < OXYGEN_MAX then
		local surplus = math.Clamp(-deficit, 0, 1)
		oxygen = oxygen + OXYGEN_RECOVERY_RATE * (0.4 + surplus * 0.6) * dt
	end

	oxygen = math.Clamp(oxygen, 0, OXYGEN_MAX)
	ply:SetCerebralOxygen(oxygen)

	if oxygen < OXYGEN_UNCONSCIOUS and not ply:GetNW2Bool("IsUnconscious", false) then
		ply:ApplyUnconsciousness(math.Rand(6, 14))
		MuR:GiveMessage2("hypoxia_blackout", ply)
	end

	if oxygen < OXYGEN_INJURY then
		ply.MuR_HypoxicDamage = (ply.MuR_HypoxicDamage or 0) + dt
		if ply.MuR_HypoxicDamage > 8 and ply:GetOrganDamageStage("brain") < 2 then
			ply:SetOrganDamageStage("brain", 1)
		end
	end

	return oxygen
end

MuR.ProcessCerebralOxygen = processOxygen

MuR.PULSE_ABSENT = 0
MuR.PULSE_THREADY = 1
MuR.PULSE_WEAK = 2
MuR.PULSE_RACING = 3
MuR.PULSE_STRONG = 4

function meta:GetPulse()
	if not self:Alive() then return 0, MuR.PULSE_ABSENT end

	local volFrac = self:GetBloodVolumeFraction()
	local perfusion = self:GetPerfusion()

	local bpm = 62 + (1 - volFrac) * 95

	if self:GetNW2Int("ShockLevel", 0) > 0 then
		bpm = bpm + self:GetNW2Int("ShockLevel", 0) * 8
	end
	if self:GetNW2Float("AdrenalineEnd", 0) > CurTime() then
		bpm = bpm + 25
	end

	local mods = chemMods(self)
	bpm = bpm + mods.PulseAdd

	local heartStage = math.max(self:GetOrganDamageStage("heart") + mods.HeartStrain, 0)
	if heartStage > 0 then
		bpm = bpm * math.Clamp(1 - heartStage * 0.18, 0.35, 1)
	end

	if self:GetNW2Bool("IsUnconscious", false) then
		bpm = bpm * 0.9
	end

	if volFrac < 0.12 or perfusion <= 0.05 then
		return math.floor(bpm), MuR.PULSE_ABSENT
	end

	local quality
	if perfusion < 0.35 or volFrac < 0.3 then
		quality = MuR.PULSE_THREADY
	elseif perfusion < 0.7 or volFrac < 0.55 then
		quality = MuR.PULSE_WEAK
	elseif bpm > 105 then
		quality = MuR.PULSE_RACING
	else
		quality = MuR.PULSE_STRONG
	end

	return math.floor(bpm), quality
end

function meta:ResetBloodVolume()
	self:SetBloodVolume(BLOOD_MAX)
	self:SetCerebralOxygen(OXYGEN_MAX)
	self:SetNW2Int("HypovolemiaStage", 0)
	self.NextBloodVolumeTick = nil
	self.NextHypovolemiaFaint = nil
	self.MuR_HypoxicDamage = nil
end

local function applyHypovolemiaEffects(ply, stage, previousStage)
	if stage ~= previousStage then
		ply:SetNW2Int("HypovolemiaStage", stage)

		if stage > previousStage and stage >= 2 then
			MuR:GiveMessage2(stage >= 3 and "blood_loss_severe" or "blood_loss_moderate", ply)
		end
	end

	if stage <= 0 then return end

	if stage >= 1 then
		local ceiling = 100 - stage * 18
		if ply:GetNW2Float("Stamina", 100) > ceiling then
			ply:SetNW2Float("Stamina", math.max(ply:GetNW2Float("Stamina", 100) - stage * 1.5, ceiling))
		end
	end

	if stage >= 2 then
		ply:ApplyCoordinationLoss(2 + stage, 0.15 * stage, "hypovolemia")
	end

	if stage >= 3 and not ply:GetNW2Bool("IsUnconscious", false) then
		ply.NextHypovolemiaFaint = ply.NextHypovolemiaFaint or (CurTime() + math.Rand(12, 22))
		if CurTime() >= ply.NextHypovolemiaFaint then
			ply:ApplyUnconsciousness(math.Rand(4, 9) + stage)
			ply.NextHypovolemiaFaint = CurTime() + math.Rand(15, 30)
		end
	else
		ply.NextHypovolemiaFaint = nil
	end
end

hook.Add("PlayerPostThink", "MuR.BloodVolume", function(ply)
	if not ply:Alive() then return end
	if ply:IsRoleWithoutOrgans() then return end

	local now = CurTime()
	if (ply.NextBloodVolumeTick or 0) > now then return end
	ply.NextBloodVolumeTick = now + TICK_INTERVAL

	local previousStage = ply:GetNW2Int("HypovolemiaStage", 0)
	local rate = ply:GetBleedRate()

	if rate > 0 then
		ply:AddBloodVolume(-rate * ply:GetBleedExertionScale() * TICK_INTERVAL)
	elseif ply:GetBloodVolume() < BLOOD_MAX then
		ply:AddBloodVolume(REGEN_PER_SECOND * TICK_INTERVAL)
	end

	applyHypovolemiaEffects(ply, ply:GetHypovolemiaStage(), previousStage)

	local oxygen = processOxygen(ply, TICK_INTERVAL)

	if oxygen <= 0 then
		local attacker = IsValid(ply.LastAttacker) and ply.LastAttacker or ply
		if ply.IsDying and ply:IsDying() then
			ply:FinishDying(attacker)
		else
			ply.MuR_TerminalDamage = true
			ply:TakeDamage(ply:Health() + 10, attacker, attacker)
			ply.MuR_TerminalDamage = nil
		end
	end
end)

hook.Add("PlayerSpawn", "MuR.BloodVolumeReset", function(ply)
	ply:ResetBloodVolume()
end)
