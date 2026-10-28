local noiseP, noiseY = 0, 0

timer.Create("MuR.AimDriftNoise", 0.1, 0, function()
	noiseP = math.Rand(-1, 1)
	noiseY = math.Rand(-1, 1)
end)

local function getTremor(ply)
	local tremor = 0

	local coordEnd = ply:GetNW2Float("CoordinationEnd", 0)
	if coordEnd > CurTime() then
		local frac = math.Clamp((coordEnd - CurTime()) / 8, 0, 1)
		tremor = tremor + math.Clamp(ply:GetNW2Float("CoordinationSeverity", 0) / 2, 0, 1) * frac
	end

	local concEnd = ply:GetNW2Float("ConcussionEnd", 0)
	if concEnd > CurTime() then
		local frac = math.Clamp((concEnd - CurTime()) / 6, 0, 1)
		tremor = tremor + math.Clamp(ply:GetNW2Float("ConcussionIntensity", 0) / 2, 0, 1) * frac * 0.8
	end

	if ply:GetNW2Bool("ArmFracture", false) or ply:GetNW2Bool("ForearmFracture", false)
		or ply:GetNW2Bool("ClavicleFracture", false) then
		tremor = tremor + 0.35
	end
	if ply:GetNW2Bool("Artery_ArmLeft", false) or ply:GetNW2Bool("Artery_ArmRight", false) then
		tremor = tremor + 0.25
	end

	tremor = tremor + ply:GetNW2Int("ShockLevel", 0) * 0.15
	tremor = tremor + ply:GetNW2Int("HypovolemiaStage", 0) * 0.12

	tremor = tremor * (1 - math.Clamp(ply:GetNW2Float("ChemAnalgesia", 0), 0, 1) * 0.6)

	return math.Clamp(tremor, 0, 1)
end

hook.Add("CreateMove", "MuR.AimDrift", function(cmd)
	local ply = LocalPlayer()
	if not IsValid(ply) or not ply:Alive() then return end
	if IsValid(ply:GetRD()) then return end

	local tremor = getTremor(ply)
	if tremor < 0.15 then return end

	local amp = tremor * 0.55
	local t = CurTime()

	local ang = cmd:GetViewAngles()
	ang.p = ang.p + math.sin(t * 7.3) * amp + noiseP * amp * 0.4
	ang.y = ang.y + math.cos(t * 5.9) * amp + noiseY * amp * 0.4
	cmd:SetViewAngles(ang)
end)
