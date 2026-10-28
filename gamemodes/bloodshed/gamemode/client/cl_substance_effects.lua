if not CLIENT then return end

MuR = MuR or {}
MuR.SubstanceEffects = MuR.SubstanceEffects or {}
MuR.SubstanceEffects.Active = {}

local Active = MuR.SubstanceEffects.Active

net.Receive("MuR.SubstanceVisual", function()
	local id = net.ReadString()
	local duration = net.ReadFloat()
	local amount = net.ReadFloat()

	Active[id] = {
		start = CurTime(),
		endTime = CurTime() + duration,
		amount = amount
	}
end)

net.Receive("MuR.SubstanceVisualClear", function()
	local id = net.ReadString()

	if id == "" then
		table.Empty(Active)
	else
		Active[id] = nil
	end
end)

hook.Add("PlayerSpawn", "MuR.SubstanceEffectsReset", function(ply)
	if ply == LocalPlayer() then table.Empty(Active) end
end)

local function strength(entry)
	local total = entry.endTime - entry.start
	if total <= 0 then return 0 end

	local frac = (CurTime() - entry.start) / total
	if frac < 0 then return 0 end
	if frac > 1 then return 0 end

	local shape
	if frac < 0.2 then
		shape = frac / 0.2
	elseif frac > 0.7 then
		shape = 1 - (frac - 0.7) / 0.3
	else
		shape = 1
	end

	return math.Clamp(shape * entry.amount, 0, 1)
end

local function prune()
	local now = CurTime()
	for id, entry in pairs(Active) do
		if now > entry.endTime then Active[id] = nil end
	end
end

local colour = {
	["$pp_colour_addr"] = 0, ["$pp_colour_addg"] = 0, ["$pp_colour_addb"] = 0,
	["$pp_colour_brightness"] = 0, ["$pp_colour_contrast"] = 1,
	["$pp_colour_colour"] = 1, ["$pp_colour_mulr"] = 0,
	["$pp_colour_mulg"] = 0, ["$pp_colour_mulb"] = 0
}

hook.Add("RenderScreenspaceEffects", "MuR.SubstanceEffects", function()
	local ply = LocalPlayer()
	if not IsValid(ply) or not ply:Alive() then return end

	prune()
	if not next(Active) then return end

	local blur, desat, warm, sick, sharpen = 0, 0, 0, 0, 0

	for id, entry in pairs(Active) do
		local s = strength(entry)
		if s > 0 then
			if id == "heroin" or id == "morphine" then
				blur = blur + s * 1.6
				warm = warm + s * 0.5
				desat = desat + s * 0.35
			elseif id == "midazolam" or id == "chloroform" then
				blur = blur + s * 2.2
				desat = desat + s * 0.6
			elseif id == "ketamine" then
				blur = blur + s * 2.6
				desat = desat + s * 0.45
			elseif id == "pcp" then
				sharpen = sharpen + s * 2
				warm = warm + s * 0.3
			elseif id == "cyanide" then
				warm = warm + s * 0.7
				sharpen = sharpen + s
			elseif id == "chlorine" or id == "nerve_agent" then
				blur = blur + s * 1.4
				sick = sick + s * 0.6
			elseif id == "tetrodotoxin" then
				desat = desat + s * 0.7
				blur = blur + s * 0.8
			elseif id == "insulin" then
				desat = desat + s * 0.8
				blur = blur + s * 1.2
			elseif id == "strychnine" then
				local wave = 0.6 + 0.4 * math.sin(CurTime() * 1.7)
				sharpen = sharpen + s * 3 * wave
				warm = warm + s * 0.6 * wave
			end
		end
	end

	if blur > 0 then
		DrawMotionBlur(0.4, math.min(blur * 0.25, 0.75), 0.01)
	end

	if sharpen > 0 then
		DrawSharpen(math.min(sharpen, 3), 1)
	end

	if desat > 0 or warm > 0 or sick > 0 then
		colour["$pp_colour_colour"] = math.max(1 - math.min(desat, 1) * 0.8, 0.15)
		colour["$pp_colour_addr"] = math.min(warm, 1) * 0.12
		colour["$pp_colour_addg"] = math.min(sick, 1) * 0.10
		colour["$pp_colour_addb"] = -math.min(warm, 1) * 0.05
		colour["$pp_colour_contrast"] = 1 + math.min(warm + sick, 1) * 0.15
		colour["$pp_colour_brightness"] = -math.min(desat, 1) * 0.05
		DrawColorModify(colour)
	end
end)

function MuR.SubstanceEffects:GetActive()
	prune()

	local out = {}
	for id, entry in pairs(Active) do
		out[#out + 1] = {id = id, strength = strength(entry), remaining = entry.endTime - CurTime()}
	end

	return out
end
