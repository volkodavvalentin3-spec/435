if not SERVER then return end

MuR = MuR or {}

local HEAD_BONES = {
	["ValveBiped.Bip01_Head1"] = true,
	["ValveBiped.Bip01_Neck1"] = true
}

function MuR.IsBodyHeadless(rag)
	if not IsValid(rag) then return false end

	if istable(rag.ZippyGoreMod3_GibbedPhysBones) then
		for physBone, gibbed in pairs(rag.ZippyGoreMod3_GibbedPhysBones) do
			if gibbed then
				local boneId = rag:TranslatePhysBoneToBone(physBone)
				if boneId and HEAD_BONES[rag:GetBoneName(boneId) or ""] then
					return true
				end
			end
		end
	end

	for name in pairs(HEAD_BONES) do
		local boneId = rag:LookupBone(name)
		if boneId then
			local scale = rag:GetManipulateBoneScale(boneId)
			if MuR.IsBoneScaleHidden(scale) then return true end
		end
	end

	return false
end

function MuR.IsBodyIdentified(rag)
	if not IsValid(rag) then return false end

	local name = rag:GetNWString("Name", "")
	return name ~= "" and name ~= MuR.UNIDENTIFIED_NAME
end

function MuR.RefreshBodyIdentity(rag)
	if not IsValid(rag) then return end
	if not MuR.IsBodyIdentified(rag) then return end
	if not MuR.IsBodyHeadless(rag) then return end

	rag:SetNWString("Name", MuR.UNIDENTIFIED_NAME)
end

local ENT = FindMetaTable("Entity")
local breakPhysBone = ENT.ZippyGoreMod3_BreakPhysBone

if breakPhysBone and not MuR.BodyIdentityWrapped then
	MuR.BodyIdentityWrapped = true

	function ENT:ZippyGoreMod3_BreakPhysBone(physBone, data)
		breakPhysBone(self, physBone, data)
		MuR.RefreshBodyIdentity(self)
	end
elseif not breakPhysBone then
	ErrorNoHalt("[Bloodshed] ZippyGoreMod3_BreakPhysBone missing: bodies will keep their " ..
		"name after decapitation\n")
end
