local showBodyZones = CreateClientConVar("mur_debug_organs", "0", false, false, "Draw organ and bone zones for players and ragdolls")
if showBodyZones:GetBool() then
	RunConsoleCommand("mur_debug_organs", "0")
end
local debugShotMarkers = {}
local debugMarkerLifetime = 8

local organDamageKeys = {
	["Brain"] = "brain",
	["Carotid Artery"] = "carotid",
	["Neck"] = "neck",
	["Heart"] = "heart",
	["Right Lung"] = "lung_right",
	["Left Lung"] = "lung_left",
	["Liver"] = "liver",
	["Right Brachial Artery"] = "brachial_right",
	["Left Brachial Artery"] = "brachial_left",
	["Right Femoral Artery"] = "femoral_right",
	["Left Femoral Artery"] = "femoral_left"
}

local function canUseOrganDebug()
	local ply = LocalPlayer()
	return IsValid(ply) and ply:IsAdmin()
end

local function getZoneTransform(ent, zone, box)
	local boneId = ent:LookupBone(box.bone or zone.bone)
	if not boneId then return end

	local bonePos, boneAng = ent:GetBonePosition(boneId)
	if not bonePos then return end

	return LocalToWorld(box.offset or vector_origin, box.angle or angle_zero, bonePos, boneAng)
end

local function drawZone(ent, zone, color)
	for _, box in ipairs(zone.hitboxes or {}) do
		local boxPos, boxAng = getZoneTransform(ent, zone, box)
		if not boxPos then continue end

		cam.Start3D()
			render.DrawWireframeBox(boxPos, boxAng, box.mins, box.maxs, color, false)
		cam.End3D()
	end
end

local function hasBoneFracture(ent, fractureType)
	if fractureType == "jaw" then return ent:GetNW2Bool("JawFracture") end
	if fractureType == "clavicle" then return ent:GetNW2Bool("ClavicleFracture") end
	if fractureType == "arm" then return ent:GetNW2Bool("ArmFracture") end
	if fractureType == "forearm" then return ent:GetNW2Bool("ForearmFracture") end
	if fractureType == "ribs" then return ent:GetNW2Bool("RibFracture") end
	if fractureType == "pelvis" then return ent:GetNW2Bool("PelvisFracture") end
	if fractureType == "leg" then return ent:GetNW2Bool("LegBroken") end
	if fractureType == "foot" then return ent:GetNW2Bool("FootFracture") end

	return false
end

local function isOrganDamaged(ent, organName)
	if organName == "Spine" then
		return ent:GetNW2Bool("SpineBroken")
	end

	local organKey = organDamageKeys[organName]
	if organKey and ent:GetNW2Int("OrganDamage_" .. organKey, 0) > 0 then
		return true
	end

	if organName == "Right Lung" or organName == "Left Lung" then
		if organName == "Right Lung" then
			return ent:GetNW2Bool("PneumothoraxRight")
		end

		return ent:GetNW2Bool("PneumothoraxLeft")
	end

	if organName == "Liver" then
		return ent:GetNW2Float("ToxinLevel") > 0
	end

	return false
end

local function addDebugShotMarker(shooter, startPos, endPos, hitLiving)
	local shotDir = endPos - startPos
	if shotDir:IsZero() then
		shotDir = Vector(1, 0, 0)
	end

	local shotLength = shotDir:Length()
	local centerPos = startPos + shotDir * 0.5

	debugShotMarkers[#debugShotMarkers + 1] = {
		shooter = shooter,
		pos = centerPos,
		angle = shotDir:Angle(),
		length = shotLength,
		hitLiving = hitLiving,
		expiresAt = CurTime() + debugMarkerLifetime
	}
end

net.Receive("MuR.DebugOrganRay", function()
	if not canUseOrganDebug() then return end

	local shooter = net.ReadEntity()
	local startPos = net.ReadVector()
	local endPos = net.ReadVector()
	local hitLiving = net.ReadBool()

	addDebugShotMarker(shooter, startPos, endPos, hitLiving)
end)

hook.Add("PostDrawOpaqueRenderables", "MuR_DrawOrgans", function()
	if not showBodyZones:GetBool() then return end
	if not canUseOrganDebug() then return end

	for _, ent in ents.Iterator() do
		if not ent:IsPlayer() and not ent:IsRagdoll() then continue end
		if ent:IsPlayer() and not ent:Alive() then continue end
		if ent == LocalPlayer() and not LocalPlayer():ShouldDrawLocalPlayer() then continue end

		for _, organ in ipairs(MuR.Organs) do
			local color = organ.color
			if isOrganDamaged(ent, organ.name) then
				color = Color(0, 0, 0)
			end

			drawZone(ent, organ, color)
		end

		for _, boneZone in ipairs(MuR.BoneZones or {}) do
			local color = boneZone.color
			if hasBoneFracture(ent, boneZone.fractureType) then
				color = Color(25, 25, 25)
			end

			drawZone(ent, boneZone, color)
		end
	end

	for i = #debugShotMarkers, 1, -1 do
		local marker = debugShotMarkers[i]
		local lifeLeft = marker.expiresAt - CurTime()
		if lifeLeft <= 0 then
			table.remove(debugShotMarkers, i)
			continue
		end

		local alpha = math.Clamp((lifeLeft / debugMarkerLifetime) * 255, 20, 255)
		local markerColor = marker.hitLiving and Color(255, 90, 90, alpha) or Color(255, 210, 90, alpha)
		local halfLength = math.max((marker.length or 0) * 0.5, 1)
		render.DrawWireframeBox(marker.pos, marker.angle, Vector(-halfLength, -0.45, -0.45), Vector(halfLength, 0.45, 0.45), markerColor, false)
	end
end)
