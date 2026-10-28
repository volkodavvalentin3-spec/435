MuR = MuR or {}
MuR.Substances = {}
MuR.SubstanceList = {}

function MuR.SubCombine(a, b)
	return a + b - a * b
end

function MuR.SubOver(potency)
	return math.Clamp(potency - 1, 0, 2)
end

function MuR.SubDose(potency)
	return math.min(potency, 1)
end

local combine, over, dose = MuR.SubCombine, MuR.SubOver, MuR.SubDose

local function reg(id, def)
	def.id = id
	def.route = def.route or "injection"
	def.onset = def.onset or 0
	def.peak = def.peak or (def.onset + 5)
	def.duration = def.duration or (def.peak + 30)
	def.decay = def.decay or math.max((def.duration - def.peak) * 0.5, 1)
	MuR.Substances[id] = def
	MuR.SubstanceList[#MuR.SubstanceList + 1] = id
end

MuR.SubstanceRegister = reg

reg("cyanide", {
	cat = "toxin", route = "injection",
	onset = 4, peak = 18, duration = 150,
	forensic = "cyanide", antidote = "hydroxocobalamin", lethal = true,
	modify = function(ply, mods, potency)
		mods.CellularBlock = mods.CellularBlock + potency * 2.0
		mods.CoordNoise = mods.CoordNoise + potency * 0.5
	end
})

reg("tetrodotoxin", {
	cat = "toxin", route = "oral",
	onset = 35, peak = 125, duration = 400,
	forensic = "tetrodotoxin", lethal = true,
	modify = function(ply, mods, potency)
		mods.RespDepression = combine(mods.RespDepression, potency * 0.8)
		mods.StaminaMul = mods.StaminaMul * (1 - potency * 0.9)
		mods.CoordNoise = mods.CoordNoise + potency * 1.2
	end
})

reg("digoxin", {
	vis = false,
	cat = "toxin", route = "injection",
	onset = 40, peak = 100, duration = 420,
	forensic = "digoxin", antidote = "atropine", lethal = true,
	modify = function(ply, mods, potency)
		mods.HeartStrain = mods.HeartStrain + potency * 2
		mods.PerfusionMul = mods.PerfusionMul * (1 - potency * 0.4)
	end
})

reg("insulin", {
	cat = "toxin", route = "injection",
	onset = 55, peak = 130, duration = 360,
	forensic = nil, antidote = "glucose", lethal = true,
	modify = function(ply, mods, potency)
		mods.StaminaMul = mods.StaminaMul * (1 - potency)
		mods.CoordNoise = mods.CoordNoise + potency * 1.6
		mods.Sedation = combine(mods.Sedation, math.max(potency - 0.45, 0) * 1.4)
		mods.CellularBlock = mods.CellularBlock + math.max(potency - 0.4, 0) * 4.0
	end
})

reg("strychnine", {
	cat = "toxin", route = "injection",
	onset = 14, peak = 45, duration = 200,
	forensic = "strychnine", antidote = "midazolam", lethal = true,
	modify = function(ply, mods, potency)
		local wave = 0.75 + 0.25 * math.sin(CurTime() * 1.7)
		mods.DemandAdd = mods.DemandAdd + potency * 1.8 * wave
		mods.CoordNoise = mods.CoordNoise + potency * 2
	end
})

reg("botulinum", {
	vis = false,
	cat = "toxin", route = "injection",
	onset = 220, peak = 420, duration = 900,
	forensic = "botulinum", antidote = "antitoxin", lethal = true,
	modify = function(ply, mods, potency)
		mods.RespDepression = combine(mods.RespDepression, potency * 0.9)
		mods.StaminaMul = mods.StaminaMul * (1 - potency * 0.95)
		mods.CoordNoise = mods.CoordNoise + potency * 1.1
	end
})

reg("potassium", {
	vis = false,
	cat = "toxin", route = "injection",
	onset = 8, peak = 22, duration = 180,
	forensic = nil, antidote = "atropine", lethal = true,
	modify = function(ply, mods, potency)
		mods.HeartStrain = mods.HeartStrain + potency * 4
		mods.PerfusionMul = mods.PerfusionMul * (1 - potency * 0.5)
		mods.CellularBlock = mods.CellularBlock + potency * 0.8
	end
})

reg("succinylcholine", {
	vis = false,
	cat = "toxin", route = "injection",
	onset = 9, peak = 20, duration = 200,
	forensic = nil, lethal = true,
	modify = function(ply, mods, potency)
		mods.RespDepression = combine(mods.RespDepression, potency * 0.95)
		mods.StaminaMul = mods.StaminaMul * (1 - potency)
		mods.CoordNoise = mods.CoordNoise + potency * 2.2
	end
})

reg("warfarin", {
	vis = false,
	cat = "toxin", route = "oral",
	onset = 25, peak = 120, duration = 480,
	forensic = "warfarin", antidote = "vitamink",
	modify = function(ply, mods, potency)
		mods.BleedMul = mods.BleedMul * (1 + potency * 1.8)
	end
})

reg("thallium", {
	vis = false,
	cat = "toxin", route = "oral",
	onset = 180, peak = 480, duration = 1200,
	forensic = "thallium", antidote = "prussianblue", lethal = true,
	organTick = true,
	modify = function(ply, mods, potency)
		mods.StaminaMul = mods.StaminaMul * (1 - potency * 0.5)
		mods.CoordNoise = mods.CoordNoise + potency * 0.7
	end
})

reg("carbon_monoxide", {
	vis = false,
	cat = "gas", route = "inhaled", gasBlocked = true,
	onset = 3, peak = 45, duration = 500,
	forensic = "carbon_monoxide", lethal = true,
	modify = function(ply, mods, potency)
		mods.PerfusionMul = mods.PerfusionMul * (1 - potency * 0.7)
	end
})

reg("chlorine", {
	cat = "gas", route = "inhaled", gasBlocked = true,
	onset = 2, peak = 15, duration = 120,
	forensic = "chlorine", organTick = true,
	modify = function(ply, mods, potency)
		mods.RespDepression = combine(mods.RespDepression, potency * 0.35)
		mods.StaminaMul = mods.StaminaMul * (1 - potency * 0.7)
	end
})

reg("nerve_agent", {
	cat = "gas", route = "inhaled", gasBlocked = true,
	onset = 2, peak = 12, duration = 130,
	forensic = "nerve_agent", antidote = "atropine", blockedBy = "atropine", lethal = true,
	modify = function(ply, mods, potency)
		mods.RespDepression = combine(mods.RespDepression, potency * 0.9)
		mods.CoordNoise = mods.CoordNoise + potency * 2.4
		mods.DemandAdd = mods.DemandAdd + potency * 0.3
	end
})

reg("midazolam", {
	cat = "sedative", route = "injection", tolerance = true,
	onset = 6, peak = 20, duration = 110,
	forensic = "sedative", antidote = "flumazenil", blockedBy = "flumazenil",
	modify = function(ply, mods, potency)
		mods.Sedation = combine(mods.Sedation, dose(potency) * 0.9)
		mods.CoordNoise = mods.CoordNoise + potency * 0.8

		mods.RespDepression = combine(mods.RespDepression,
			dose(potency) * 0.15 + over(potency) * 0.4)
	end
})

reg("chloroform", {
	cat = "sedative", route = "contact",
	onset = 2, peak = 8, duration = 55,
	forensic = "sedative",
	modify = function(ply, mods, potency)
		mods.Sedation = combine(mods.Sedation, dose(potency) * 0.95)
		mods.RespDepression = combine(mods.RespDepression, over(potency) * 0.6)
	end
})

reg("ketamine", {
	cat = "dissociative", route = "injection", tolerance = true,
	onset = 5, peak = 18, duration = 150,
	forensic = "dissociative",
	modify = function(ply, mods, potency)
		mods.Sedation = combine(mods.Sedation, dose(potency) * 0.9)
		mods.Analgesia = combine(mods.Analgesia, dose(potency) * 0.75)

		mods.RespDepression = combine(mods.RespDepression, over(potency) * 0.45)
	end
})

reg("pcp", {
	cat = "dissociative", route = "injection", tolerance = true,
	onset = 8, peak = 30, duration = 240,
	forensic = "dissociative",
	modify = function(ply, mods, potency)
		mods.Analgesia = combine(mods.Analgesia, dose(potency) * 0.7)
		mods.CoordNoise = mods.CoordNoise + potency * 1.4

		mods.DemandAdd = mods.DemandAdd + potency * 0.4 + over(potency) * 0.8
		mods.HeartStrain = mods.HeartStrain + over(potency) * 1.2
	end
})

reg("heroin", {
	cat = "opioid", route = "injection", tolerance = true,
	onset = 10, peak = 35, duration = 330,
	forensic = "opioid", antidote = "naloxone", blockedBy = "naloxone", lethal = true,
	modify = function(ply, mods, potency)
		mods.RespDepression = combine(mods.RespDepression,
			dose(potency) * 0.45 + over(potency) * 0.4)
		mods.Analgesia = combine(mods.Analgesia, dose(potency) * 0.8)
		mods.Sedation = combine(mods.Sedation, dose(potency) * 0.5 + over(potency) * 0.4)
	end
})

reg("morphine", {
	cat = "opioid", route = "injection", tolerance = true,
	onset = 4, peak = 18, duration = 260,
	forensic = "opioid", antidote = "naloxone", blockedBy = "naloxone",
	modify = function(ply, mods, potency)
		mods.Analgesia = combine(mods.Analgesia, dose(potency) * 0.85)
		mods.RespDepression = combine(mods.RespDepression,
			dose(potency) * 0.35 + over(potency) * 0.3)

		mods.Sedation = combine(mods.Sedation, over(potency) * 0.6)
	end
})

reg("plasma", {
	vis = false,
	cat = "medical", route = "injection",
	onset = 1, peak = 8, duration = 60,
	bloodRestore = 35,
	modify = function(ply, mods, potency)
		mods.PerfusionMul = mods.PerfusionMul * (1 - dose(potency) * 0.12)

		mods.BleedMul = mods.BleedMul * (1 + over(potency) * 0.7)
		mods.RespDepression = combine(mods.RespDepression, over(potency) * 0.2)
	end
})

reg("tranexamic", {
	vis = false,
	cat = "medical", route = "injection",
	onset = 3, peak = 12, duration = 190,
	modify = function(ply, mods, potency)
		mods.BleedMul = mods.BleedMul * (1 - dose(potency) * 0.65)

		mods.PerfusionMul = mods.PerfusionMul * (1 - over(potency) * 0.22)
		mods.DemandAdd = mods.DemandAdd + over(potency) * 0.5
		mods.CoordNoise = mods.CoordNoise + over(potency) * 0.8
	end
})

reg("mannitol", {
	vis = false,
	cat = "medical", route = "injection",
	onset = 2, peak = 10, duration = 120,
	onStart = function(ply, amount)
		local d = dose(amount)
		if d < 0.25 then return end

		local concEnd = ply:GetNW2Float("ConcussionEnd", 0)
		if concEnd > CurTime() then
			local left = concEnd - CurTime()
			ply:SetNW2Float("ConcussionEnd", CurTime() + math.max(2, left * (1 - d * 0.65)))
		end
	end,
	modify = function(ply, mods, potency)
		mods.PerfusionMul = mods.PerfusionMul * (1 + dose(potency) * 0.06)

		mods.PerfusionMul = mods.PerfusionMul * (1 - over(potency) * 0.3)
		mods.HeartStrain = mods.HeartStrain + over(potency) * 1.1
		mods.CoordNoise = mods.CoordNoise + over(potency) * 0.7
		mods.DemandAdd = mods.DemandAdd + over(potency) * 0.4
	end
})

reg("naloxone", {
	vis = false,
	cat = "medical", route = "injection",
	onset = 0, peak = 3, duration = 120,
	clears = {"heroin"},
	modify = function(ply, mods, potency)
		mods.DemandAdd = mods.DemandAdd + over(potency) * 0.6
		mods.PulseAdd = mods.PulseAdd + over(potency) * 25
		mods.CoordNoise = mods.CoordNoise + over(potency) * 1.2
		mods.StaminaMul = mods.StaminaMul * (1 - over(potency) * 0.3)
	end
})

reg("atropine", {
	vis = false,
	cat = "medical", route = "injection",
	onset = 1, peak = 6, duration = 180,
	clears = {"nerve_agent"},
	modify = function(ply, mods, potency)
		mods.HeartStrain = mods.HeartStrain - dose(potency) * 2
		mods.RespRelief = combine(mods.RespRelief, dose(potency) * 0.6)

		mods.PulseAdd = mods.PulseAdd + dose(potency) * 18 + over(potency) * 30
		mods.HeartStrain = mods.HeartStrain + over(potency) * 1.5
		mods.DemandAdd = mods.DemandAdd + over(potency) * 0.7
		mods.CoordNoise = mods.CoordNoise + over(potency) * 1.6
	end
})

reg("vitamink", {
	vis = false,
	cat = "medical", route = "oral",
	onset = 4, peak = 20, duration = 300,
	clears = {"warfarin"},
	modify = function(ply, mods, potency)
		mods.BleedMul = mods.BleedMul * (1 - dose(potency) * 0.45)

		mods.PerfusionMul = mods.PerfusionMul * (1 - over(potency) * 0.18)
		mods.CoordNoise = mods.CoordNoise + over(potency) * 0.3
	end
})

reg("prussianblue", {
	vis = false,
	cat = "medical", route = "oral",
	onset = 5, peak = 25, duration = 420,
	clears = {"thallium"},
	modify = function(ply, mods, potency)
		mods.ToxinClear = mods.ToxinClear + dose(potency) * 0.35
		mods.ToxinResist = math.max(mods.ToxinResist, dose(potency) * 0.6)

		mods.StaminaMul = mods.StaminaMul * (1 - over(potency) * 0.25)
	end
})

reg("analgesic", {
	vis = false,
	cat = "medical", route = "oral",
	onset = 12, peak = 45, duration = 480,
	organTick = true, organAbove = 1,
	modify = function(ply, mods, potency)
		mods.Analgesia = combine(mods.Analgesia, dose(potency) * 0.35)

		mods.BleedMul = mods.BleedMul * (1 + over(potency) * 0.5)
	end
})

reg("glucose", {
	vis = false,
	cat = "medical", route = "oral",
	onset = 3, peak = 15, duration = 240,
	clears = {"insulin"},
	modify = function(ply, mods, potency)
		mods.StaminaMul = mods.StaminaMul * (1 + dose(potency) * 0.6)
		mods.StaminaFloor = math.max(mods.StaminaFloor, dose(potency) * 45)

		mods.PerfusionMul = mods.PerfusionMul * (1 - over(potency) * 0.15)
		mods.CoordNoise = mods.CoordNoise + over(potency) * 0.5
	end
})

reg("hydroxocobalamin", {
	vis = false,
	cat = "medical", route = "injection",
	onset = 2, peak = 10, duration = 180,
	clears = {"cyanide"},
	modify = function(ply, mods, potency)
		mods.PulseAdd = mods.PulseAdd + dose(potency) * 12

		mods.DemandAdd = mods.DemandAdd + over(potency) * 0.4
		mods.CoordNoise = mods.CoordNoise + over(potency) * 0.6
	end
})

reg("flumazenil", {
	vis = false,
	cat = "medical", route = "injection",
	onset = 1, peak = 4, duration = 100,
	clears = {"midazolam"},
	modify = function(ply, mods, potency)
		mods.PulseAdd = mods.PulseAdd + dose(potency) * 15

		local habit = MuR.Chem:GetTolerance(ply, "midazolam")
		if habit > 0 then
			mods.CoordNoise = mods.CoordNoise + dose(potency) * habit * 1.2
			mods.PulseAdd = mods.PulseAdd + dose(potency) * habit * 20
			mods.DemandAdd = mods.DemandAdd + dose(potency) * habit * 0.6
		end

		mods.CoordNoise = mods.CoordNoise + over(potency) * 0.8
	end
})

reg("antitoxin", {
	vis = false,
	cat = "medical", route = "injection",
	onset = 3, peak = 15, duration = 240,
	clears = {"botulinum"},
	modify = function(ply, mods, potency)
		mods.PulseAdd = mods.PulseAdd + dose(potency) * 8
		mods.StaminaMul = mods.StaminaMul * (1 - dose(potency) * 0.12)

		mods.DemandAdd = mods.DemandAdd + over(potency) * 0.7
		mods.StaminaMul = mods.StaminaMul * (1 - over(potency) * 0.2)
		mods.CoordNoise = mods.CoordNoise + over(potency) * 0.5
	end
})

reg("amphetamine", {
	cat = "stimulant", route = "oral", tolerance = true,
	onset = 15, peak = 60, duration = 360,
	forensic = "stimulant", lethal = true,
	modify = function(ply, mods, potency)
		mods.StaminaMul = mods.StaminaMul * (1 + dose(potency) * 0.7)
		mods.Analgesia = combine(mods.Analgesia, dose(potency) * 0.25)
		mods.PulseAdd = mods.PulseAdd + dose(potency) * 20
		mods.CoordNoise = mods.CoordNoise + potency * 0.35

		mods.CoordNoise = mods.CoordNoise + over(potency) * 1.6
		mods.HeartStrain = mods.HeartStrain + over(potency) * 1.4
		mods.DemandAdd = mods.DemandAdd + over(potency) * 0.9
	end
})

reg("cocaine", {
	cat = "stimulant", route = "injection", tolerance = true,
	onset = 4, peak = 12, duration = 90,
	forensic = "stimulant", lethal = true,
	modify = function(ply, mods, potency)
		mods.StaminaMul = mods.StaminaMul * (1 + dose(potency) * 0.45)
		mods.Analgesia = combine(mods.Analgesia, dose(potency) * 0.35)
		mods.PulseAdd = mods.PulseAdd + dose(potency) * 28
		mods.DemandAdd = mods.DemandAdd + dose(potency) * 0.2
		mods.CoordNoise = mods.CoordNoise + potency * 0.5

		mods.HeartStrain = mods.HeartStrain + over(potency) * 2.2
		mods.CoordNoise = mods.CoordNoise + over(potency) * 2
		mods.DemandAdd = mods.DemandAdd + over(potency) * 1.2
	end
})

function MuR:GetSubstance(id)
	return MuR.Substances[id]
end
