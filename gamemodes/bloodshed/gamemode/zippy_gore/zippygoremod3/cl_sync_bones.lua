if SERVER then return end

local zeroScale = Vector(0, 0, 0)

net.Receive("ZGM3_SyncBoneScale", function()
	local ent = net.ReadEntity()
	local bone = net.ReadUInt(16)
	local scale = net.ReadVector()

	if not IsValid(ent) then return end

	ent:ManipulateBoneScale(bone, scale)
end)

local function ApplyHiddenBones(ent)
	if not IsValid(ent) then return end

	local list = ent:GetNW2String("ZGM3_HiddenBones", "")
	if list == "" then return end

	for idx in string.gmatch(list, "[^,]+") do
		local bone = tonumber(idx)
		if bone and bone >= 0 then
			ent:ManipulateBoneScale(bone, zeroScale)
		end
	end
end

hook.Add("OnEntityCreated", "ZGM3_HiddenBones", function(ent)
	if ent:GetClass() ~= "prop_ragdoll" then return end

	timer.Simple(0, function()
		ApplyHiddenBones(ent)
	end)
end)
