if SERVER then return end

LiteWounds = LiteWounds or {}

local ENABLED = true
local DAMAGE_MULT = 1
local WOUNDS_ENABLED = true
local WOUNDS_LIVE = true
local WOUNDS_LIMIT = 256
local KEEP_SERVER_RAGDOLLS = false

LiteWounds.Ragdolls = LiteWounds.Ragdolls or {}
LiteWounds.RagdollGibs = LiteWounds.RagdollGibs or {}
LiteWounds.Wounds = LiteWounds.Wounds or {}
LiteWounds.MaxWounds = WOUNDS_LIMIT

function LiteWounds.GibCallback(myself, boneCount)
	if myself.gibbedBones then
		for k, v in pairs(myself.gibbedBones) do
			if k > boneCount or v > boneCount then return end
			if myself:GetBoneName(k) ~= "__INVALIDBONE__" then
				local mat = myself:GetBoneMatrix(v)
				if not mat then return end
				mat:Scale(vector_origin)
				myself:SetBoneMatrix(k, mat)
			end
		end
	end
end

local entMeta = FindMetaTable("Entity")
local fleshMat = Material("models/gore/inside")

local function RenderWounds(ent)
	if not IsValid(ent.goreModel) then
		ent:DrawModel()
		return
	end

	if not ent.LiteGibWounds then
		ent:DrawModel()
		return
	end

	if halo.RenderedEntity() == ent then
		ent:DrawModel()
		return
	end

	if #ent.LiteGibWounds == 0 then
		ent:DrawModel()
		return
	end

	render.SetStencilWriteMask(0xFF)
	render.SetStencilTestMask(0xFF)
	render.SetStencilReferenceValue(0)
	render.SetStencilCompareFunction(STENCIL_ALWAYS)
	render.SetStencilPassOperation(STENCIL_KEEP)
	render.SetStencilFailOperation(STENCIL_KEEP)
	render.SetStencilZFailOperation(STENCIL_KEEP)
	render.ClearStencil()

	render.SetStencilEnable(true)
	render.SetStencilReferenceValue(1)
	render.SetStencilCompareFunction(STENCIL_ALWAYS)
	render.SetStencilPassOperation(STENCILOPERATION_REPLACE)
	render.SetStencilFailOperation(STENCILOPERATION_REPLACE)
	render.SetStencilZFailOperation(STENCIL_KEEP)
	render.CullMode(MATERIAL_CULLMODE_CCW)
	render.OverrideColorWriteEnable(true, false)
	ent:DrawModel()
	render.OverrideColorWriteEnable(false, false)

	render.SetStencilCompareFunction(STENCIL_EQUAL)
	render.SetStencilPassOperation(STENCIL_INCR)
	render.SetStencilFailOperation(STENCIL_KEEP)
	render.SetStencilZFailOperation(STENCIL_KEEP)
	render.SetBlend(0)
	render.OverrideDepthEnable(true, false)

	for _, v in ipairs(ent.LiteGibWounds) do
		if IsValid(v.model) and v.bone and v.pos and v.ang then
			local mat = ent:GetBoneMatrix(v.bone)
			if mat then
				local bpos, bang
				bpos = mat:GetTranslation()
				bang = mat:GetAngles()
				local pos, ang = LocalToWorld(v.pos, v.ang, bpos, bang)
				v.model:SetupBones()
				v.model:SetRenderOrigin(pos)
				v.model:SetRenderAngles(ang)
				v.model:DrawModel()
			end
		end
	end

	render.OverrideDepthEnable(false, false)
	render.SetBlend(1)

	render.SetStencilPassOperation(STENCIL_KEEP)
	render.SetStencilFailOperation(STENCIL_KEEP)
	render.SetStencilZFailOperation(STENCIL_KEEP)
	render.SetStencilReferenceValue(0)
	render.SetStencilCompareFunction(STENCIL_NOTEQUAL)
	render.OverrideColorWriteEnable(true, false)
	render.ClearBuffersObeyStencil(0, 0, 0, 0, true)
	render.OverrideColorWriteEnable(false, false)

	render.SetStencilReferenceValue(2)
	render.SetStencilCompareFunction(STENCIL_EQUAL)
	render.ModelMaterialOverride(fleshMat)
	render.CullMode(MATERIAL_CULLMODE_CW)
	ent:DrawModel()
	render.OverrideDepthEnable(true, false)
	render.CullMode(MATERIAL_CULLMODE_CCW)
	ent.goreModel:SetupBones()
	ent.goreModel:DrawModel()

	if ent.LiteGibInterior then
		for _, entry in pairs(ent.LiteGibInterior) do
			if IsValid(entry.prop) then
				local mat = ent:GetBoneMatrix(entry.anchor)
				if mat then
					local pos, ang = LocalToWorld(entry.def.pos, entry.def.ang,
						mat:GetTranslation(), mat:GetAngles())
					entry.prop:SetupBones()
					entry.prop:SetRenderOrigin(pos)
					entry.prop:SetRenderAngles(ang)
					entry.prop:DrawModel()
				end
			end
		end
	end

	render.OverrideDepthEnable(false, false)
	render.ModelMaterialOverride()
	render.SetStencilReferenceValue(2)
	render.SetStencilCompareFunction(STENCIL_NOTEQUAL)
	ent:DrawModel()
	render.ClearStencil()
	render.SetStencilEnable(false)
end

if entMeta then
	function entMeta:ClearWounds()
		if IsValid(self.goreModel) then
			SafeRemoveEntityDelayed(self.goreModel, 0.1)
		end
		if self.ClearInterior then self:ClearInterior() end
		if not self.LiteGibWounds then return end
		local toremove
		for k, v in ipairs(self.LiteGibWounds) do
			toremove = toremove or {}
			toremove[#toremove + 1] = k
			if IsValid(v.model) then
				SafeRemoveEntityDelayed(v.model, 0.1)
			end
		end

		if not toremove then return end
		for i = #toremove, 1, -1 do
			table.remove(self.LiteGibWounds, toremove[i])
		end
	end

	function entMeta:AddInteriorModel(bone)
		if not bone or bone < 0 then return end

		local def = LiteWounds.InteriorModels[string.lower(self:GetBoneName(bone) or "")]
		if not def then return end

		self.LiteGibInterior = self.LiteGibInterior or {}
		if self.LiteGibInterior[def.model] then return end

		local anchor = self:LookupBone(def.bone)
		if not anchor then return end

		local prop = ClientsideModel(def.model)
		if not IsValid(prop) then return end

		prop:SetOwner(self)
		prop:SetNoDraw(true)
		prop:DrawShadow(false)
		if def.scale and def.scale ~= 1 then prop:SetModelScale(def.scale, 0) end
		prop:SetRenderBounds(Vector(-48, -48, -48), Vector(48, 48, 48))

		self.LiteGibInterior[def.model] = {prop = prop, anchor = anchor, def = def}
	end

	function entMeta:ClearInterior()
		if not self.LiteGibInterior then return end

		for _, entry in pairs(self.LiteGibInterior) do
			if IsValid(entry.prop) then SafeRemoveEntityDelayed(entry.prop, 0.1) end
		end

		self.LiteGibInterior = nil
	end

	function entMeta:AddWoundModel(model, scale, localPos, localAng, bone)
		if not WOUNDS_ENABLED then return end

		if ((self.Alive and self:Alive()) or MuR.IsAI(self)) and not WOUNDS_LIVE then return end
		if self.gibbedBones and self.gibbedBones[bone] then return end
		if not IsValid(self) then return end

		self.LiteGibWounds = self.LiteGibWounds or {}
		local woundModel = ClientsideModel(model)
		woundModel:SetOwner(self)
		woundModel:SetNoDraw(true)
		woundModel:DrawShadow(false)
		woundModel:SetModelScale(scale, 0)
		woundModel:SetRenderBounds(Vector(-32, -32, -32), Vector(32, 32, 32))

		local t = {self, woundModel}
		LiteWounds.MaxWounds = WOUNDS_LIMIT

		if #LiteWounds.Wounds >= LiteWounds.MaxWounds then
			local tMax = LiteWounds.Wounds[LiteWounds.MaxWounds]
			if tMax and IsValid(tMax[2]) then
				SafeRemoveEntityDelayed(tMax[2], 0.1)
			end
			table.insert(LiteWounds.Wounds, 1, t)
		else
			LiteWounds.Wounds[#LiteWounds.Wounds + 1] = t
		end

		self.LiteGibWounds[#self.LiteGibWounds + 1] = {
			["pos"] = localPos,
			["ang"] = localAng,
			["model"] = woundModel,
			["modelpath"] = model,
			["scale"] = scale,
			["bone"] = bone
		}
	end

	function entMeta:CopyWounds(ent)
		if not ent.LiteGibWounds then return end
		for k, v in ipairs(ent.LiteGibWounds) do
			if not (self.gibbedBones and self.gibbedBones[v.bone]) then
				self:AddWoundModel(v.modelpath, v.scale, v.pos, v.ang, v.bone)
				self:AddInteriorModel(v.bone)
			end
		end
		self:Wound()
	end

	function entMeta:Wound(ogPos, ogAng, bone, woundModel, woundModelScale, goreModel)
		if self.WoundProxy then
			return self.WoundProxy:Wound(ogPos, ogAng, bone, woundModel, woundModelScale, goreModel)
		end
		if not WOUNDS_ENABLED then return end

		self:SetupBones()
		if not IsValid(self.goreModel) then
			self.goreModel = ClientsideModel(goreModel or LiteWounds.DefaultGoreUndermodel)
			self.goreModel:SetParent(self)
			self.goreModel:AddEffects(EF_BONEMERGE)
			self.goreModel:SetNoDraw(true)
			self.goreModel:DrawShadow(false)

			local findTable
			for i = #LiteWounds.RagdollGibs, 1, -1 do
				if LiteWounds.RagdollGibs[i][1] == self then
					findTable = LiteWounds.RagdollGibs[i]
					break
				end
			end

			if not findTable then
				findTable = {self, {}}
				table.insert(LiteWounds.RagdollGibs, findTable)
			end

			table.insert(findTable[2], self.goreModel)
		end

		self.LiteWoundsRender = RenderWounds

		if not self.RenderOverride then
			self.RenderOverride = RenderWounds
		end

		local p, a = self:GetBonePosition(bone or -1)
		if not ogPos then return end
		if not p then return end
		if not a then return end

		local woundTable = LiteWounds.WoundRadius[self:GetModel()]
		local radius = woundTable[string.lower(self:GetBoneName(bone))] or woundTable["default"]
		local boneCenter = self:GetBoneCenter(bone)
		local newPos = ogPos
		local nrm = (boneCenter - p):GetNormalized()
		local dist = ogPos:Distance(boneCenter)
		newPos = util.IntersectRayWithPlane(p, nrm, ogPos, nrm)

		woundModel = woundModel or "models/Combine_Helicopter/helicopter_bomb01.mdl"
		local woundrad = LiteWounds.WoundModelRadius[string.lower(woundModel)] or 8
		woundrad = woundrad * woundModelScale

		if newPos then
			if dist > radius then
				newPos = newPos + (ogPos - newPos):GetNormalized() * math.max(0, radius - woundrad)
			else
				newPos = newPos + (ogPos - newPos):GetNormalized() * math.max(0, dist - woundrad)
			end
		else
			if dist > radius then
				newPos = boneCenter + (ogPos - boneCenter):GetNormalized() * math.max(0, radius - woundrad)
			else
				newPos = boneCenter + (ogPos - boneCenter):GetNormalized() * math.max(0, dist - woundrad)
			end
		end

		local localPos, localAng = WorldToLocal(newPos, ogAng, p, a)
		self:AddWoundModel(woundModel, woundModelScale or 1, localPos, localAng, bone)
		self:AddInteriorModel(bone)
	end
end

local function WoundEnt(ent, dmg, hg, vec)
	local bloodColor = ent:GetBloodColorLG()
	if bloodColor == DONT_BLEED then return end
	if dmg < 15 then return end

	local finalBone = ent:GetClosestBoneInList(vec, LiteWounds.Bones.HitGroupSearch[hg])
	local bn = ent:GetBoneName(finalBone)
	bn = string.Replace(string.lower(bn), "valvebiped.", "")
	bn = string.Replace(string.lower(bn), "bip01_", "")

	local goreModelTable = LiteWounds.GoreModels[ent:GetModel()]
	local woundModelTable = LiteWounds.WoundModels[ent:GetModel()]
	local wound_def = woundModelTable["default"] or LiteWounds.WoundModels["default"].default
	local wound = woundModelTable[bn] or woundModelTable["default"]

	local dmgClamped = math.max(0, math.min(dmg, 200))
	local rad = 0.04 + (dmgClamped / 200) * (0.32 - 0.04)

	ent:Wound(vec, angle_zero, finalBone, wound["model"] or wound_def["model"], rad, goreModelTable[bn] or goreModelTable["default"])

	local fx = EffectData()
	fx:SetOrigin(vec)
	fx:SetColor(bloodColor)
	fx:SetFlags(0)
	fx:SetMagnitude(finalBone)
	util.Effect("bd_blood_spray", fx)
end

local function AddToDamageTable(ent, hitgroup, damage, damageType, vec)
	ent.LGDamageTable = ent.LGDamageTable or {}
	local function IsDamageType(dmg, typev)
		return bit.band(dmg, typev) == typev
	end

	local ValidHitGroups = {HITGROUP_HEAD, HITGROUP_CHEST, HITGROUP_STOMACH, HITGROUP_LEFTARM, HITGROUP_RIGHTARM, HITGROUP_LEFTLEG, HITGROUP_RIGHTLEG}

	if IsDamageType(damageType, DMG_BLAST) then
		for _, hgruppe in pairs(ValidHitGroups) do
			ent.LGDamageTable[hgruppe] = ent.LGDamageTable[hgruppe] or {}
			ent.LGDamageTable[hgruppe].damage = ent.LGDamageTable[hgruppe].damage or 0
			ent.LGDamageTable[hgruppe].damage = ent.LGDamageTable[hgruppe].damage + damage * math.Rand(0.5, 1.5)
			ent.LGDamageTable[hgruppe].damageType = bit.bor(damageType, ent.LGDamageTable[hgruppe].damageType or 0)
		end

		ent.LGDamageTable[hitgroup] = ent.LGDamageTable[hitgroup] or {}
		ent.LGDamageTable[hitgroup].damage = ent.LGDamageTable[hitgroup].damage or 0
		ent.LGDamageTable[hitgroup].damage = ent.LGDamageTable[hitgroup].damage + damage / 2
		ent.LGDamageTable[hitgroup].damageType = bit.bor(damageType, ent.LGDamageTable[hitgroup].damageType or 0)
	elseif IsDamageType(damageType, DMG_SLASH) then
		ent.LGDamageTable[hitgroup] = ent.LGDamageTable[hitgroup] or {}
		ent.LGDamageTable[hitgroup].damage = ent.LGDamageTable[hitgroup].damage or 0
		ent.LGDamageTable[hitgroup].damage = ent.LGDamageTable[hitgroup].damage + damage
		ent.LGDamageTable[hitgroup].damageType = bit.bor(damageType, ent.LGDamageTable[hitgroup].damageType or 0)
	end

	if IsDamageType(damageType, DMG_ALWAYSGIB) then
		ent.LGDamageTable[hitgroup] = ent.LGDamageTable[hitgroup] or {}
		ent.LGDamageTable[hitgroup].damage = 1000
		if damage < 160 then
			ent.LGDamageTable[hitgroup].damageType = DMG_SLASH
		else
			ent.LGDamageTable[hitgroup].damageType = damageType
		end
	elseif not IsDamageType(damageType, DMG_NEVERGIB) then
		ent.LGDamageTable[hitgroup] = ent.LGDamageTable[hitgroup] or {}
		ent.LGDamageTable[hitgroup].damage = damage
		ent.LGDamageTable[hitgroup].damageType = damageType
	end
end

local keepcorpses = { GetBool = function() return KEEP_SERVER_RAGDOLLS end }
local dmgs = {
	[2] = true, [128] = true, [4] = true, [536870912] = true, [1073741824] = true,
	[2147483648] = true, [1024] = true, [1048576] = true, [4098] = true, [8194] = true
}

net.Receive("LITEGIBDMG", function()
	if not ENABLED then return end

	local ent = net.ReadEntity()
	local hitgroup = net.ReadUInt(4)
	local damage = net.ReadInt(12)
	local damageType = net.ReadUInt(31)
	local vec = net.ReadVector()
	local inf = net.ReadEntity()

	if not IsValid(ent) then return end
	if not hitgroup then return end
	if not damage then return end
	if not damageType then return end

	damage = damage * DAMAGE_MULT

	--
	-- GetActiveWeapon проверяется на существование: у своих nextbot-NPC он живёт
	-- в sv_weapon.lua и на клиенте его НЕТ вовсе, в отличие от движковых NPC, у
	-- которых метод нативный и есть в обоих реалмах. Без проверки каждое
	-- попадание от наёмника или полицейского валило этот хук.
	--
	if IsValid(inf) and MuR.IsAI(inf) and isfunction(inf.GetActiveWeapon) then
		local wep = inf:GetActiveWeapon()
		if IsValid(wep) and not wep:IsScripted() then
			damage = damage * 8
		end
	end

	if not keepcorpses:GetBool() then
		AddToDamageTable(ent, hitgroup, damage, damageType, vec)
	end

	if damage > 1 and dmgs[damageType] then
		WoundEnt(ent, damage, hitgroup, vec)
		ent.LGLastDamage = damage
		ent.LGLastHG = hitgroup
		ent.LGLastVec = vec
		ent.LGLastInf = inf
	end
end)

net.Receive("LITEGIBPS", function()
	local ent = net.ReadEntity()
	if IsValid(ent) then
		ent.LGDamageTable = nil
		ent:ClearWounds()
		ent.LGDamageTable = nil
		ent.gibbedBones = nil
	end
end)

net.Receive("CLBloodType", function()
	local ent = net.ReadEntity()
	if IsValid(ent) then
		local bt = net.ReadInt(8)
		ent.BloodColor = bt
	end
end)

net.Receive("LGCopyWounds", function()
	local ent = net.ReadEntity()
	local rag = net.ReadEntity()
	if IsValid(ent) and IsValid(rag) then
		rag:CopyWounds(ent)
		if not rag.gibbedBones then
			rag.gibbedBones = ent.gibbedBones
		else
			if rag.gibbedBones ~= nil and ent.gibbedBones ~= nil then
				table.Merge(rag.gibbedBones, ent.gibbedBones)
			end
		end
	end
end)

hook.Add("CreateClientsideRagdoll", "LiteWoundsCCR", function(ent, rag)
	if not ENABLED then return end
	if keepcorpses:GetBool() then return end
	if not IsValid(ent) then return end
	if not ent.LGDamageTable then return end

	ent.Dead = true
	if IsValid(rag) then
		ent.LGDeathRagdoll = rag
		for i = 0, rag:GetPhysicsObjectCount() - 1 do
			local phys = rag:GetPhysicsObjectNum(i)
			if IsValid(phys) then
				phys:SetVelocity(phys:GetVelocity():GetNormalized() * math.pow(phys:GetVelocity():Length() / 100, 0.3) * 100)
			end
		end

		rag.BloodColor = ent:GetBloodColorLG()
		rag.mat = ent:GetMaterial()
		rag.owner = ent
		local index = #LiteWounds.Ragdolls + 1
		LiteWounds.Ragdolls[index] = rag
		rag.id = index
		rag:CopyWounds(ent)

		if not WOUNDS_LIVE then
			WoundEnt(rag, ent.LGLastDamage or 0.1, ent.LGLastHG or HITGROUP_GENERIC, ent.LGLastVec or vector_origin)
		end
	end
end)

hook.Add("CreateClientsideRagdoll", "LiteWoundsAddRagdollParent", function(ent, ragdoll)
	ragdoll.LGParentEntity = ent
	if IsValid(ragdoll) then
		for i = #LiteWounds.RagdollGibs, 1, -1 do
			if LiteWounds.RagdollGibs[i][1] == ent then
				LiteWounds.RagdollGibs[i][1] = ragdoll
				break
			end
		end
	end
end)

hook.Add("EntityRemoved", "LiteWoundsGarbageColectWounds", function(ent)
	ent:ClearWounds()
end)

hook.Add("PreCleanupMap", "LiteWoundsCleanup", function()
	for i, data in ipairs(LiteWounds.Wounds) do
		local wound = data[2]
		if IsValid(wound) then
			SafeRemoveEntityDelayed(wound, 0.1)
		end
	end
	LiteWounds.Wounds = {}
end)

timer.Create("LiteWoundsGarbageCollectWounds", 1, 0, function()
	local toremove
	for i, data in ipairs(LiteWounds.Wounds) do
		local par = data[1]
		local wound = data[2]
		if not IsValid(par) or not IsValid(wound) then
			toremove = toremove or {}
			toremove[#toremove + 1] = i
			if IsValid(wound) then
				SafeRemoveEntityDelayed(wound, 0.1)
			end
		end
	end

	if not toremove then return end
	for i = #toremove, 1, -1 do
		table.remove(LiteWounds.Wounds, toremove[i])
	end
end)

timer.Create("LiteWoundsGarbageCollectRagdollGibs", 1, 0, function()
	local toremove
	for i, data in ipairs(LiteWounds.RagdollGibs) do
		if not IsValid(data[1]) then
			toremove = toremove or {}
			table.insert(toremove, i)
			for i2, gib in ipairs(data[2]) do
				if IsValid(gib) then
					gib:Remove()
				end
			end
		end
	end

	if not toremove then return end
	for i = #toremove, 1, -1 do
		table.remove(LiteWounds.RagdollGibs, toremove[i])
	end
end)
