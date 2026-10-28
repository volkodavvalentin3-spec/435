if SERVER then return end

local ragdollStates = {}
local ragdollCache = {}
local ownerByRagdoll = {}
local nextScan = 0

local BREATH_BONES = {
	["ValveBiped.Bip01_Spine"] = 0.45,
	["ValveBiped.Bip01_Spine1"] = 0.65,
	["ValveBiped.Bip01_Spine2"] = 0.85,
	["ValveBiped.Bip01_Spine4"] = 1.0,
}

local function floyd_breathe_map()
	ownerByRagdoll = {}
	for _, ply in ipairs(player.GetAll()) do
		local rd = ply:GetNW2Entity("RD_Ent")
		if IsValid(rd) then
			ownerByRagdoll[rd] = ply
		end

		local rdCam = ply:GetNW2Entity("RD_EntCam")
		if IsValid(rdCam) then
			ownerByRagdoll[rdCam] = ply
		end
	end
end

local function CacheBreathBones(rag, state)
	if state.bones then return state.bones end

	local ids = {}
	local weights = {}

	for name, weight in pairs(BREATH_BONES) do
		local id = rag:LookupBone(name)
		if id then
			ids[#ids + 1] = id
			weights[id] = weight
		end
	end

	state.bones = ids
	state.weights = weights
	state.baseScale = {}
	state.basePos = {}
	state.hidden = {}

	for _, boneId in ipairs(ids) do
		local scale = rag:GetManipulateBoneScale(boneId)
		if not isvector(scale) or MuR.IsBoneScaleHidden(scale) then
			state.hidden[boneId] = true
			continue
		end

		local pos = rag:GetManipulateBonePosition(boneId)
		if not isvector(pos) then
			pos = Vector(0, 0, 0)
		end

		state.baseScale[boneId] = scale
		state.basePos[boneId] = pos
	end

	return ids
end

local function CanBreathe(rag)
	if not IsValid(rag) or rag:GetClass() ~= "prop_ragdoll" then return false end

	local owner = ownerByRagdoll[rag] or rag.Owner
	if IsValid(owner) and owner:IsPlayer() then
		if not owner:Alive() then return false end
		return true, owner
	end

	if rag:GetNW2Bool("MuR.IsLivingRagdoll", false) then
		return true, nil
	end

	return false
end

local function floyd_breathe_params(ply, state)
	if not IsValid(ply) then
		return 0.22, 0.018
	end

	local maxHp = math.max(ply:GetMaxHealth(), 1)
	local hp = math.Clamp(ply:Health(), 0, maxHp)
	local hpFrac = hp / maxHp

	local bleed = math.Clamp(ply:GetNW2Float("BleedLevel", 0), 0, 3)
	local hardBleed = ply:GetNW2Bool("HardBleed", false)
	local shockLevel = ply:GetNW2Int("ShockLevel", ply:GetNW2Bool("ShockState", false) and 2 or 0)
	local pneumo = ply:GetNW2Bool("Pneumothorax", false)
	local stamina = math.Clamp(ply:GetNW2Float("Stamina", 100), 0, 100)

	local target = 0
	target = target + (1 - hpFrac) * 0.5
	target = target + (bleed / 3) * 0.25
	if hardBleed then target = target + 0.2 end
	target = target + shockLevel * 0.1
	if stamina < 30 then target = target + ((30 - stamina) / 30) * 0.15 end
	if pneumo then target = target + 0.3 end

	if state and state.spikeUntil and state.spikeUntil > CurTime() then
		local t = math.Clamp((state.spikeUntil - CurTime()) / 3, 0, 1)
		target = target + t * 0.4
	end

	target = math.Clamp(target, 0, 1)

	state.severity = state.severity or target
	local upSpeed = 0.35
	local downSpeed = 0.12
	if state.healUntil and state.healUntil > CurTime() then
		downSpeed = 0.06
	end
	local speed = target > state.severity and upSpeed or downSpeed
	state.severity = Lerp(FrameTime() * speed, state.severity, target)

	local rate = Lerp(state.severity, 0.22, 0.6)
	local amp = Lerp(state.severity, 0.012, 0.04)

	if ply:GetNW2Bool("IsRagStanding", false) then
		amp = amp * 1.2
		rate = math.min(rate * 1.04, 0.75)
	end

	if pneumo then
		amp = amp * 0.35
		rate = math.max(rate, 0.4)
	end

	return rate, amp
end

local function floyd_breathe_apply(rag, state, rate, amp)
	local bones = CacheBreathBones(rag, state)
	if #bones == 0 then return end

	state.smoothedRate = Lerp(FrameTime() * 4, state.smoothedRate or rate, rate)
	state.smoothedAmp = Lerp(FrameTime() * 4, state.smoothedAmp or amp, amp)

	state.phase = (state.phase or 0) + FrameTime() * state.smoothedRate * math.pi * 2
	if state.phase > math.pi * 2 then
		state.phase = state.phase - math.pi * 2
	end

	local phase = math.sin(state.phase)
	local inhale = math.Clamp((phase + 1) * 0.5, 0, 1)
	local shaped = inhale * inhale * (3 - 2 * inhale)
	local normalized = (shaped - 0.5) * 2

	for _, boneId in ipairs(bones) do
		if state.hidden and state.hidden[boneId] then continue end

		local current = rag:GetManipulateBoneScale(boneId)
		if not isvector(current) or MuR.IsBoneScaleHidden(current) then
			state.hidden[boneId] = true
			continue
		end

		local baseScale = state.baseScale[boneId] or Vector(1, 1, 1)
		local basePos = state.basePos[boneId] or Vector(0, 0, 0)
		local weight = (state.weights and state.weights[boneId]) or 1

		if baseScale:LengthSqr() < 0.0001 then continue end

		local localAmp = state.smoothedAmp * weight
		local scaleX = 1 + normalized * localAmp * 1.05
		local scaleY = 1 + normalized * localAmp * 0.7
		local scaleZ = 1 + normalized * localAmp * 0.4
		rag:ManipulateBoneScale(boneId, Vector(baseScale.x * scaleX, baseScale.y * scaleY, baseScale.z * scaleZ))

		local offset = normalized * localAmp * 1.0
		rag:ManipulateBonePosition(boneId, basePos + Vector(offset, 0, offset * 0.25))
	end
end

local function ResetBreath(rag, state)
	if not state then return end
	for _, boneId in ipairs(state.bones or {}) do
		local current = rag:GetManipulateBoneScale(boneId)
		if isvector(current) and not MuR.IsBoneScaleHidden(current) then
			if state.baseScale and state.baseScale[boneId] then
				rag:ManipulateBoneScale(boneId, state.baseScale[boneId])
			end
			if state.basePos and state.basePos[boneId] then
				rag:ManipulateBonePosition(boneId, state.basePos[boneId])
			end
		end
	end
end

hook.Add("EntityRemoved", "MuR.RagdollBreathCleanup", function(ent)
	if ragdollStates[ent] then
		ragdollStates[ent] = nil
	end
end)

hook.Add("Think", "MuR.RagdollBreath", function()
	local now = CurTime()
	if now >= nextScan then
		ragdollCache = ents.FindByClass("prop_ragdoll")
		floyd_breathe_map()
		nextScan = now + 0.35
	end

	for i = 1, #ragdollCache do
		local rag = ragdollCache[i]
		if not IsValid(rag) then continue end

		local ok, owner = CanBreathe(rag)
		if not ok then
			local state = ragdollStates[rag]
			if state then
				ResetBreath(rag, state)
				ragdollStates[rag] = nil
			end
			continue
		end

		local state = ragdollStates[rag]
		if not state then
			state = {}
			ragdollStates[rag] = state
		end

		if IsValid(owner) then
			local hp = owner:Health()
			if state.lastHp and hp < state.lastHp - 1 then
				local drop = math.min(state.lastHp - hp, 30)
				state.spikeUntil = CurTime() + math.Clamp(1.5 + drop / 10, 1.5, 5)
			end
			if state.lastHp and hp > state.lastHp + 2 then
				state.healUntil = CurTime() + 8
			end
			state.lastHp = hp

			local shockLevel = owner:GetNW2Int("ShockLevel", owner:GetNW2Bool("ShockState", false) and 2 or 0)
			if shockLevel > (state.lastShockLevel or 0) then
				state.spikeUntil = CurTime() + 4
			end
			state.lastShockLevel = shockLevel

			local bleed = owner:GetNW2Float("BleedLevel", 0)
			if state.lastBleed and bleed < state.lastBleed then
				state.healUntil = CurTime() + 8
			end
			state.lastBleed = bleed

			local hardBleed = owner:GetNW2Bool("HardBleed", false)
			if state.lastHardBleed and not hardBleed then
				state.healUntil = CurTime() + 10
			end
			state.lastHardBleed = hardBleed
		end

		local rate, amp = floyd_breathe_params(owner, state)
		floyd_breathe_apply(rag, state, rate, amp)
	end
end)
