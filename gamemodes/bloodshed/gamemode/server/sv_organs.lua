local function pointInBounds(localPos, mins, maxs)
	return localPos.x >= math.min(mins.x, maxs.x) and localPos.x <= math.max(mins.x, maxs.x)
		and localPos.y >= math.min(mins.y, maxs.y) and localPos.y <= math.max(mins.y, maxs.y)
		and localPos.z >= math.min(mins.z, maxs.z) and localPos.z <= math.max(mins.z, maxs.z)
end

local function boxVolume(mins, maxs)
	return math.abs((maxs.x - mins.x) * (maxs.y - mins.y) * (maxs.z - mins.z))
end

local emptyHitboxes = {}

local function getContainedZoneByName(target, zones, hitPos, wantedName)
	if not IsValid(target) or not istable(zones) or not isstring(wantedName) then return nil end

	local bestZone
	for _, zone in ipairs(zones) do
		if zone.name ~= wantedName then continue end

		for _, box in ipairs(zone.hitboxes or emptyHitboxes) do
			local boxPos, boxAng = MuR.ResolveZoneTransform(target, zone, box)
			if not boxPos then continue end

			local localHitPos = WorldToLocal(hitPos, angle_zero, boxPos, boxAng)
			if pointInBounds(localHitPos, box.mins, box.maxs) then
				local volume = boxVolume(box.mins, box.maxs)
				if not bestZone or volume < bestZone.volume then
					bestZone = {
						name = zone.name,
						data = zone,
						hitbox = box,
						volume = volume
					}
				end
			end
		end
	end

	return bestZone
end

local MELEE_ORGAN_TRACE_WEAPONS = {
	["mur_welder"] = {backtrack = 2.5, penetration = 6.0},
	["mur_hands"] = {backtrack = 2.5, penetration = 5.5},
	["mur_zombie"] = {backtrack = 2.5, penetration = 5.5},
	["tfa_bs_wrench"] = {backtrack = 3.0, penetration = 7.0},
	["tfa_bs_spade"] = {backtrack = 3.25, penetration = 8.0},
	["tfa_bs_sledge"] = {backtrack = 3.5, penetration = 7.0},
	["tfa_bs_compactk"] = {backtrack = 3.0, penetration = 10.0},
	["tfa_bs_pickaxe"] = {backtrack = 3.5, penetration = 9.5},
	["tfa_bs_fireaxe_maniac"] = {backtrack = 3.5, penetration = 10.0},
	["tfa_bs_machete"] = {backtrack = 3.0, penetration = 9.0},
	["tfa_bs_pipe"] = {backtrack = 3.0, penetration = 7.0},
	["tfa_bs_knife"] = {backtrack = 3.0, penetration = 10.0},
	["tfa_bs_hatchet"] = {backtrack = 3.25, penetration = 9.0},
	["tfa_bs_fubar"] = {backtrack = 3.25, penetration = 7.5},
	["tfa_bs_fireaxe"] = {backtrack = 3.5, penetration = 10.0},
	["tfa_bs_crowbar"] = {backtrack = 3.25, penetration = 7.0},
	["tfa_bs_combk"] = {backtrack = 3.0, penetration = 10.0},
	["tfa_bs_cleaver"] = {backtrack = 3.25, penetration = 9.0},
	["tfa_bs_chainsaw"] = {backtrack = 3.5, penetration = 11.0},
	["tfa_bs_baton"] = {backtrack = 3.0, penetration = 6.5},
	["tfa_bs_bat"] = {backtrack = 3.0, penetration = 7.0}
}

util.AddNetworkString("MuR.DebugOrganRay")

local function canUseOrganDebug(ply)
	return IsValid(ply) and ply:IsPlayer() and ply:IsAdmin()
end

local boneTransformCache

function MuR.BeginZoneTransformCache()
	boneTransformCache = {}
end

function MuR.EndZoneTransformCache()
	boneTransformCache = nil
end

function MuR.ResolveZoneTransform(ent, zone, box)
	local boneName = box.bone or zone.bone

	local cached
	if boneTransformCache then
		cached = boneTransformCache[boneName]
		if cached == false then return end
		if cached then
			return LocalToWorld(box.offset or vector_origin, box.angle or angle_zero, cached[1], cached[2])
		end
	end

	local boneId = ent:LookupBone(boneName)
	if not boneId then
		if boneTransformCache then boneTransformCache[boneName] = false end
		return
	end

	local bonePos, boneAng = ent:GetBonePosition(boneId)
	if not isvector(bonePos) or bonePos == vector_origin or bonePos == ent:GetPos() then
		local boneMatrix = ent:GetBoneMatrix(boneId)
		if not boneMatrix then
			if boneTransformCache then boneTransformCache[boneName] = false end
			return
		end

		bonePos = boneMatrix:GetTranslation()
		boneAng = boneMatrix:GetAngles()
	end

	if not isvector(bonePos) or bonePos == vector_origin then
		if boneTransformCache then boneTransformCache[boneName] = false end
		return
	end
	if not isangle(boneAng) then
		if boneTransformCache then boneTransformCache[boneName] = false end
		return
	end

	if boneTransformCache then
		boneTransformCache[boneName] = {bonePos, boneAng}
	end

	return LocalToWorld(box.offset or vector_origin, box.angle or angle_zero, bonePos, boneAng)
end

MuR.ResolveHitboxTransform = MuR.ResolveZoneTransform

local function getDamageWeaponClass(dmginfo)
	if not dmginfo then return nil end

	local inflictor = dmginfo:GetInflictor()
	if IsValid(inflictor) and inflictor:IsWeapon() then
		return inflictor:GetClass()
	end

	local attacker = dmginfo:GetAttacker()
	if IsValid(attacker) and attacker:IsPlayer() then
		local weapon = attacker:GetActiveWeapon()
		if IsValid(weapon) then
			return weapon:GetClass()
		end
	end

	if IsValid(inflictor) then
		return inflictor:GetClass()
	end

	return nil
end

local function getBoneRegion(boneName)
	if not isstring(boneName) then return nil end

	if string.find(boneName, "Head", 1, true) or string.find(boneName, "Neck", 1, true) then
		return "head_neck"
	end

	if string.find(boneName, "Bip01_R_UpperArm", 1, true) or string.find(boneName, "Bip01_R_Forearm", 1, true)
		or string.find(boneName, "Bip01_R_Hand", 1, true) then
		return "right_arm"
	end

	if string.find(boneName, "Bip01_L_UpperArm", 1, true) or string.find(boneName, "Bip01_L_Forearm", 1, true)
		or string.find(boneName, "Bip01_L_Hand", 1, true) then
		return "left_arm"
	end

	if string.find(boneName, "Bip01_R_Thigh", 1, true) or string.find(boneName, "Bip01_R_Calf", 1, true)
		or string.find(boneName, "Bip01_R_Foot", 1, true) then
		return "right_leg"
	end

	if string.find(boneName, "Bip01_L_Thigh", 1, true) or string.find(boneName, "Bip01_L_Calf", 1, true)
		or string.find(boneName, "Bip01_L_Foot", 1, true) then
		return "left_leg"
	end

	if string.find(boneName, "Spine", 1, true) or string.find(boneName, "Pelvis", 1, true) then
		return "torso"
	end

	return nil
end

local function getMeleeTraceOptions(target, dmginfo, hitPos)
	local config = MELEE_ORGAN_TRACE_WEAPONS[getDamageWeaponClass(dmginfo) or ""]
	if not config then return nil end

	local impactBone = target.GetNearestBoneFromPos and target:GetNearestBoneFromPos(hitPos, dmginfo:GetDamageForce())
	local impactRegion = getBoneRegion(impactBone)
	if impactRegion == "torso" then
		impactRegion = nil
	end

	return {
		backtrack = config.backtrack,
		penetration = config.penetration,
		preferContained = true,
		restrictRegion = impactRegion
	}
end

function MuR.GetDamageRay(target, owner, dmginfo, hitPos)
	local attacker = dmginfo:GetAttacker()
	local meleeOptions = getMeleeTraceOptions(target, dmginfo, hitPos)

	if meleeOptions then
		local dir
		local startPos

		if IsValid(attacker) and attacker ~= target and attacker ~= owner then
			if attacker.GetShootPos then
				startPos = attacker:GetShootPos()
			end

			if (not startPos or startPos == vector_origin) and attacker.WorldSpaceCenter then
				startPos = attacker:WorldSpaceCenter()
			end

			if startPos and startPos ~= vector_origin then
				local delta = hitPos - startPos
				if not delta:IsZero() then
					dir = delta:GetNormalized()
				end
			end

			if (not dir or dir:IsZero()) and attacker.GetAimVector then
				dir = attacker:GetAimVector()
			end
		end

		if not dir or dir:IsZero() then
			local force = dmginfo:GetDamageForce()
			if not force:IsZero() then
				dir = force:GetNormalized()
			end
		end

		if not dir or dir:IsZero() then return end

		local backtrack = meleeOptions.backtrack or 3
		local penetration = meleeOptions.penetration or 8
		return hitPos - dir * backtrack, dir * (backtrack + penetration), meleeOptions
	end

	if IsValid(attacker) and attacker ~= target and attacker ~= owner then
		local startPos

		if attacker.GetShootPos then
			startPos = attacker:GetShootPos()
		end

		if (not startPos or startPos == vector_origin) and attacker.WorldSpaceCenter then
			startPos = attacker:WorldSpaceCenter()
		end

		if startPos and startPos ~= vector_origin then
			local delta = hitPos - startPos
			if not delta:IsZero() then
				return startPos, delta + delta:GetNormalized() * 6
			end
		end
	end

	local force = dmginfo:GetDamageForce()
	if force:IsZero() then return end

	local dir = force:GetNormalized()
	return hitPos - dir * 36, dir * 48
end

local function traceBodyZonesUncached(target, zones, hitPos, dmginfo, owner)
	if not IsValid(target) or not istable(zones) or hitPos == vector_origin then return end

	local traceStart, rayDelta, traceOptions = MuR.GetDamageRay(target, owner, dmginfo, hitPos)
	local traceLengthSqr = rayDelta and math.max(rayDelta:LengthSqr(), 0.000001) or nil
	local restrictRegion = traceOptions and traceOptions.restrictRegion
	local preferContained = traceOptions and traceOptions.preferContained
	local jawBoneZone = getContainedZoneByName(target, MuR.BoneZones, hitPos, "Jaw Bone")
	local jawImpact = zones == MuR.Organs and jawBoneZone ~= nil

	if zones == MuR.BoneZones and jawBoneZone then
		return jawBoneZone
	end

	if jawImpact then
		restrictRegion = "head_neck"
	end

	local bestContainedZone
	local rayHits = {}

	for _, zone in ipairs(zones) do
		if jawImpact and (zone.name == "Neck" or zone.name == "Carotid Artery") then
			continue
		end

		for _, box in ipairs(zone.hitboxes or emptyHitboxes) do
			if restrictRegion then
				local zoneRegion = getBoneRegion(box.bone or zone.bone)
				if zoneRegion and zoneRegion ~= restrictRegion then
					continue
				end
			end

			local boxPos, boxAng = MuR.ResolveZoneTransform(target, zone, box)
			if not boxPos then continue end

			local volume = boxVolume(box.mins, box.maxs)
			local localHitPos = WorldToLocal(hitPos, angle_zero, boxPos, boxAng)
			if pointInBounds(localHitPos, box.mins, box.maxs) then
				if not bestContainedZone or volume < bestContainedZone.volume then
					bestContainedZone = {
						name = zone.name,
						data = zone,
						hitbox = box,
						volume = volume
					}
				end
			end

			if traceStart and rayDelta then
				local intersectPos, _, frac = util.IntersectRayWithOBB(traceStart, rayDelta, boxPos, boxAng, box.mins, box.maxs)
				if intersectPos then
					rayHits[#rayHits + 1] = {
						name = zone.name,
						data = zone,
						hitbox = box,
						volume = volume,
						frac = frac or (traceStart:DistToSqr(intersectPos) / traceLengthSqr)
					}
				end
			end
		end
	end

	if preferContained and bestContainedZone then
		return bestContainedZone
	end

	if #rayHits > 0 then
		table.sort(rayHits, function(a, b)
			if a.frac == b.frac then
				return a.volume < b.volume
			end

			return a.frac < b.frac
		end)

		return rayHits[1]
	end

	return bestContainedZone
end

function MuR.TraceBodyZones(target, zones, hitPos, dmginfo, owner)
	local outerCache = boneTransformCache
	if not outerCache then MuR.BeginZoneTransformCache() end

	local ok, result = pcall(traceBodyZonesUncached, target, zones, hitPos, dmginfo, owner)

	if not outerCache then MuR.EndZoneTransformCache() end

	if not ok then
		ErrorNoHalt("[Bloodshed] TraceBodyZones failed: " .. tostring(result) .. "\n")
		return nil
	end

	return result
end

MuR.TraceHitboxEntries = MuR.TraceBodyZones

function MuR.GetDamageEventId(dmginfo)
	if not dmginfo then return nil end

	local pos = dmginfo:GetDamagePosition()
	if not isvector(pos) then return nil end

	local attacker = dmginfo:GetAttacker()
	local attackerId = IsValid(attacker) and attacker:EntIndex() or 0

	return string.format("%d:%d:%d:%d:%d:%d",
		engine.TickCount(),
		attackerId,
		dmginfo:GetDamageType(),
		math.Round(pos.x * 8),
		math.Round(pos.y * 8),
		math.Round(pos.z * 8))
end

hook.Add("EntityTakeDamage", "MuR_OrganSystem", function(target, dmginfo)
	if not target:IsPlayer() and not target:IsRagdoll() then return end
	if target:IsPlayer() and target:GetNW2String("Class") == "Entity" then return end

	local owner = target:IsRagdoll() and target.Owner or target
	if not IsValid(owner) then return end
	if owner.MuR_TerminalDamage then return end

	local hitPos = dmginfo:GetDamagePosition()
	if hitPos == vector_origin then return end

	local traceTarget = target
	if target:IsPlayer() then
		local rd = target.GetRD and target:GetRD()
		if IsValid(rd) then traceTarget = rd end
	end

	local eventId = MuR.GetDamageEventId and MuR.GetDamageEventId(dmginfo)
	if eventId then
		owner.MuR_LastOrganEvent = owner.MuR_LastOrganEvent or {}
		if owner.MuR_LastOrganEvent.id == eventId then return end
		owner.MuR_LastOrganEvent.id = eventId
	end

	local hitZone = MuR.TraceBodyZones(traceTarget, MuR.Organs, hitPos, dmginfo, owner)

	local organName = hitZone and hitZone.name
	if not organName then
		local impactBone = traceTarget.GetNearestBoneFromPos
			and traceTarget:GetNearestBoneFromPos(hitPos, dmginfo:GetDamageForce())

		if impactBone == "ValveBiped.Bip01_Head1" then
			organName = "Brain"
		elseif impactBone == "ValveBiped.Bip01_Neck1" then
			organName = "Neck"
		end
	end

	if not organName then return end

	hook.Run("MuR.HandleCustomHitgroup", traceTarget, owner, organName, dmginfo)
end)

hook.Add("EntityFireBullets", "MuR.DebugOrganRays", function(attacker, bulletData)
	if not IsValid(attacker) then return end
	if not bulletData or not isvector(bulletData.Src) then return end

	local originalCallback = bulletData.Callback
	local shotStart = bulletData.Src

	bulletData.Callback = function(shooter, tr, dmginfo)
		if IsValid(shooter) and tr and tr.HitPos then
			local debugViewers = {}
			for _, ply in ipairs(player.GetAll()) do
				if canUseOrganDebug(ply) then
					debugViewers[#debugViewers + 1] = ply
				end
			end

			if #debugViewers > 0 then
				net.Start("MuR.DebugOrganRay")
				net.WriteEntity(shooter)
				net.WriteVector(shotStart)
				net.WriteVector(tr.HitPos)
				net.WriteBool(IsValid(tr.Entity) and (tr.Entity:IsPlayer() or tr.Entity:IsRagdoll()))
				net.Send(debugViewers)
			end
		end

		if originalCallback then
			return originalCallback(shooter, tr, dmginfo)
		end
	end
end)
