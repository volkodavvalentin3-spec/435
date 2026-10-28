local pl = FindMetaTable("Player")

function MuR.IsBoneScaleHidden(scale)
	if not isvector(scale) then return false end
	if scale.x ~= scale.x or scale.y ~= scale.y or scale.z ~= scale.z then return true end

	return scale.x < 0.01 and scale.y < 0.01 and scale.z < 0.01
end

if SERVER then
	function pl:SetSVAnimation(anim, autostop)
		self:SetNW2String('SVAnim', anim)
		self:SetNW2Float('SVAnimDelay', select(2, self:LookupSequence(anim)))
		self:SetNW2Float('SVAnimStartTime', CurTime())
		self:SetCycle(0)

		if autostop and anim ~= "" then
			local delay = select(2, self:LookupSequence(anim))

			timer.Simple(delay, function()
				if not IsValid(self) then return end
				local anim2 = self:GetNW2String('SVAnim')

				if anim == anim2 then
					self:SetSVAnimation("")
				end
			end)
		end

		return select(2, self:LookupSequence(anim))
	end

	hook.Add("PlayerDeath", "SVanimFix", function(ply)
		ply:SetSVAnimation("")
	end)
end

function pl:GetRD()
	return self:GetNW2Entity("RD_Ent")
end

function pl:CanGetUp()
	local rag = self:GetRD()
	local _, opos = MuR:CheckHeight(rag, MuR:BoneData(rag, "ValveBiped.Bip01_Pelvis"))
	local tr = util.TraceHull({

		start = opos,
		endpos = opos + Vector(0,0,4),
		filter = function(ent)
			if ent:GetClass() == "prop_ragdoll" or ent == self or ent:GetClass() == "murwep_ragdoll_weapon" or ent:GetClass() == "murwep_ragdoll_melee" then
				return false
			else
				return true
			end
		end,
		mins = self:OBBMins(),
		maxs = self:OBBMaxs(),
		mask = MASK_SHOT_HULL,
	})

	return not tr.Hit
end

function pl:GetSVAnimation()
	return self:GetNW2String('SVAnim')
end

function pl:TimeGetUpChange(time, isset)
	local rag = self:GetRD()

	if IsValid(rag) then
		if isset then
			local times = math.Clamp(CurTime() + time, CurTime(), CurTime()+45)
			if time > 500 then
				times = time
			end
			self:SetNW2Float('RD_GetUpTime', times)
		else
			local times = math.Clamp(self:GetNW2Float('RD_GetUpTime') + time, CurTime(), CurTime()+45)
			if time > 500 then
				times = time
			end
			self:SetNW2Float('RD_GetUpTime', times)
		end
	end
end

function pl:TimeGetUp(check)
	if check then
		return self:GetNW2Float('RD_GetUpTime') < CurTime()
	else
		return self:GetNW2Float('RD_GetUpTime')
	end
end

function MuR:BoneData(ent, bone)
	if not IsValid(ent) or not isstring(bone) then return vector_origin, angle_zero end

	local fallbackPos = ent.WorldSpaceCenter and ent:WorldSpaceCenter() or ent:GetPos()
	local fallbackAng = ent.GetAngles and ent:GetAngles() or angle_zero
	local boneid = ent:LookupBone(bone)
	if not isnumber(boneid) or boneid < 0 then
		return fallbackPos, fallbackAng
	end

	local function isFiniteVec(v)
		return isvector(v) and v.x == v.x and v.y == v.y and v.z == v.z
	end

	local pos, ang = ent:GetBonePosition(boneid)
	if isFiniteVec(pos) and pos ~= vector_origin and isangle(ang) then
		return pos, ang
	end

	local boneMatrix = ent:GetBoneMatrix(boneid)
	if boneMatrix then
		local matrixPos = boneMatrix:GetTranslation()
		local matrixAng = boneMatrix:GetAngles()
		if isFiniteVec(matrixPos) and matrixPos ~= vector_origin then
			return matrixPos, isangle(matrixAng) and matrixAng or fallbackAng
		end
	end

	return fallbackPos, fallbackAng
end

function MuR:CheckHeight(ent, pos)
	local tr = util.TraceLine({
		start = pos,
		endpos = pos - Vector(0, 0, 999999),
		filter = function(tar)
			if IsValid(ent.Weapon) and tar == ent.Weapon or ent == tar then
				return false
			else
				return true
			end
		end,
		mask = MASK_PLAYERSOLID,
	})

	return (pos - tr.HitPos):Length(), tr.HitPos
end

hook.Add("CalcMainActivity", "!TDMAnims", function(ply, vel)
	local str = ply:GetNW2String('SVAnim')
	local num = ply:GetNW2Float('SVAnimDelay')
	local st = ply:GetNW2Float('SVAnimStartTime')

	if str ~= "" then
		ply:SetCycle((CurTime() - st) / num)

		return -1, ply:LookupSequence(str)
	end
end)

hook.Add("EntityFireBullets", "MuR_RagdollSkipTPIK", function(ent, data)
	if SERVER and ent:IsPlayer() then
        net.Start("TPIK_MuzzleFlash")
        net.WriteEntity(ent)
        net.Broadcast()
    end
	if ent:IsPlayer() and IsValid(ent:GetRD()) then
		local rag = ent:GetRD()
		local pos = MuR:BoneData(rag, "ValveBiped.Bip01_Head1")
		data.Src = pos + ent:EyeAngles():Forward() * 8
		data.IgnoreEntity = rag
	end
end)
