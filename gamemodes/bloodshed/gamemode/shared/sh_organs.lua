MuR = MuR or {}
MuR.Organs = {}
MuR.BoneZones = {}

local function SymmetricBounds(half)
	return -Vector(half.x, half.y, half.z), Vector(half.x, half.y, half.z)
end

local function BodyBox(offset, half, bone, ang)
	return {
		bone = bone,
		offset = offset,
		half = half,
		angle = ang
	}
end

local function NormalizeZoneHitbox(baseBone, box)
	local mins = box.mins
	local maxs = box.maxs

	if box.half then
		mins, maxs = SymmetricBounds(box.half)
	end

	return {
		bone = box.bone or baseBone,
		mins = mins,
		maxs = maxs,
		offset = box.offset or vector_origin,
		angle = box.angle or angle_zero
	}
end

local function RegisterBodyZone(store, name, boneOrData, mins, maxs, color, bleed)
	local entry

	if istable(boneOrData) and mins == nil then
		entry = table.Copy(boneOrData)
		entry.name = name
	else
		entry = {
			name = name,
			bone = boneOrData,
			mins = mins,
			maxs = maxs,
			color = color,
			bleed = bleed
		}
	end

	entry.color = entry.color or Color(255, 255, 255)
	entry.bleed = entry.bleed or 0
	entry.hitboxes = entry.hitboxes or {}

	if #entry.hitboxes == 0 and entry.bone and entry.mins and entry.maxs then
		entry.hitboxes[1] = {
			bone = entry.bone,
			mins = entry.mins,
			maxs = entry.maxs,
			offset = vector_origin,
			angle = angle_zero
		}
	end

	for i = 1, #entry.hitboxes do
		entry.hitboxes[i] = NormalizeZoneHitbox(entry.bone, entry.hitboxes[i])
	end

	if entry.hitboxes[1] then
		entry.bone = entry.bone or entry.hitboxes[1].bone
		entry.mins = entry.mins or entry.hitboxes[1].mins
		entry.maxs = entry.maxs or entry.hitboxes[1].maxs
	end

	table.insert(store, entry)
	return entry
end

function MuR.AddOrgan(name, boneOrData, mins, maxs, color, bleed)
	return RegisterBodyZone(MuR.Organs, name, boneOrData, mins, maxs, color, bleed)
end

function MuR.GetOrgan(name)
	for _, organ in ipairs(MuR.Organs) do
		if organ.name == name then return organ end
	end

	return nil
end

function MuR.AddBoneZone(name, boneOrData, mins, maxs, color)
	return RegisterBodyZone(MuR.BoneZones, name, boneOrData, mins, maxs, color, 0)
end

function MuR.GetBoneZone(name)
	for _, boneZone in ipairs(MuR.BoneZones) do
		if boneZone.name == name then return boneZone end
	end

	return nil
end

MuR.AddOrgan("Brain", {
	bone = "ValveBiped.Bip01_Head1",
	color = Color(255, 0, 0),
	bleed = 0,
	hitboxes = {
		BodyBox(Vector(4.8, -1.1, 0), Vector(1.15, 1.7, 1.6)),
		BodyBox(Vector(2.4, 0.4, 0), Vector(0.95, 1.2, 1.1))
	}
})

MuR.AddOrgan("Carotid Artery", {
	bone = "ValveBiped.Bip01_Neck1",
	color = Color(200, 20, 20),
	bleed = 2,
	hitboxes = {
		BodyBox(Vector(2.7, -1.8, 1.2), Vector(1.9, 0.4, 0.4)),
		BodyBox(Vector(2.7, -1.8, -1.2), Vector(1.9, 0.4, 0.4)),
		BodyBox(Vector(1.2, -1.6, 1.0), Vector(1.2, 0.35, 0.35)),
		BodyBox(Vector(1.2, -1.6, -1.0), Vector(1.2, 0.35, 0.35))
	}
})

MuR.AddOrgan("Neck", {
	bone = "ValveBiped.Bip01_Neck1",
	color = Color(240, 120, 0),
	bleed = 0.5,
	hitboxes = {
		BodyBox(Vector(2.0, -1.3, 0), Vector(1.6, 1.3, 1.35)),
		BodyBox(Vector(0.8, -0.7, 0), Vector(0.8, 0.9, 1.0))
	}
})

MuR.AddOrgan("Heart", {
	bone = "ValveBiped.Bip01_Spine2",
	color = Color(230, 140, 40),
	bleed = 0.5,
	hitboxes = {
		BodyBox(Vector(2.7, 2.7, 0.9), Vector(1.0, 1.3, 1.0)),
		BodyBox(Vector(3.8, 3.2, 0.2), Vector(0.75, 0.95, 0.85))
	}
})

MuR.AddOrgan("Right Lung", {
	bone = "ValveBiped.Bip01_Spine2",
	color = Color(100, 100, 250),
	bleed = 0.5,
	hitboxes = {
		BodyBox(Vector(4.9, 3.9, -2.8), Vector(3.0, 1.5, 1.8)),
		BodyBox(Vector(3.9, 1.8, -4.8), Vector(2.2, 1.3, 0.9))
	}
})

MuR.AddOrgan("Left Lung", {
	bone = "ValveBiped.Bip01_Spine2",
	color = Color(100, 100, 250),
	bleed = 0.5,
	hitboxes = {
		BodyBox(Vector(4.9, 3.9, 2.8), Vector(3.0, 1.5, 1.8)),
		BodyBox(Vector(3.9, 1.8, 4.8), Vector(2.2, 1.3, 0.9))
	}
})

MuR.AddOrgan("Liver", {
	bone = "ValveBiped.Bip01_Spine",
	color = Color(100, 50, 0),
	bleed = 1,
	hitboxes = {
		BodyBox(Vector(5.7, 3.1, -3.6), Vector(2.4, 1.9, 1.6)),
		BodyBox(Vector(3.6, 2.1, -4.6), Vector(1.5, 1.1, 1.0))
	}
})

MuR.AddOrgan("Spine", {
	bone = "ValveBiped.Bip01_Spine1",
	color = Color(200, 200, 200),
	bleed = 0,
	hitboxes = {
		BodyBox(Vector(0.9, 0, 0), Vector(0.75, 3.4, 4.6))
	}
})

MuR.AddOrgan("Right Brachial Artery", {
	bone = "ValveBiped.Bip01_R_UpperArm",
	color = Color(200, 20, 20),
	bleed = 1.5,
	hitboxes = {
		BodyBox(Vector(4.2, 0, 0.75), Vector(4.2, 0.45, 0.45)),
		BodyBox(Vector(5.0, 0, 0.7), Vector(5.0, 0.4, 0.4), "ValveBiped.Bip01_R_Forearm")
	}
})

MuR.AddOrgan("Left Brachial Artery", {
	bone = "ValveBiped.Bip01_L_UpperArm",
	color = Color(200, 20, 20),
	bleed = 1.5,
	hitboxes = {
		BodyBox(Vector(4.2, 0, -0.75), Vector(4.2, 0.45, 0.45)),
		BodyBox(Vector(5.0, 0, -0.7), Vector(5.0, 0.4, 0.4), "ValveBiped.Bip01_L_Forearm")
	}
})

MuR.AddOrgan("Right Femoral Artery", {
	bone = "ValveBiped.Bip01_R_Thigh",
	color = Color(200, 20, 20),
	bleed = 2.5,
	hitboxes = {
		BodyBox(Vector(5.6, 0.1, 0.85), Vector(5.0, 0.5, 0.5)),
		BodyBox(Vector(5.2, 0.1, 0.8), Vector(4.5, 0.45, 0.45), "ValveBiped.Bip01_R_Calf")
	}
})

MuR.AddOrgan("Left Femoral Artery", {
	bone = "ValveBiped.Bip01_L_Thigh",
	color = Color(200, 20, 20),
	bleed = 2.5,
	hitboxes = {
		BodyBox(Vector(5.6, 0.1, -0.85), Vector(5.0, 0.5, 0.5)),
		BodyBox(Vector(5.2, 0.1, -0.8), Vector(4.5, 0.45, 0.45), "ValveBiped.Bip01_L_Calf")
	}
})

MuR.AddBoneZone("Jaw Bone", {
	bone = "ValveBiped.Bip01_Head1",
	color = Color(240, 240, 200),
	fractureType = "jaw",
	hitboxes = {
		BodyBox(Vector(0, -3.5, 0), Vector(1.6, 0.9, 1.35)),
		BodyBox(Vector(0, -3, 0), Vector(0.8, 0.7, 1.0))
	}
})

MuR.AddBoneZone("Right Clavicle Bone", {
	bone = "ValveBiped.Bip01_R_Clavicle",
	color = Color(235, 235, 210),
	fractureType = "clavicle",
	hitboxes = {
		BodyBox(Vector(2.4, 0, 0), Vector(2.4, 0.55, 0.55))
	}
})

MuR.AddBoneZone("Left Clavicle Bone", {
	bone = "ValveBiped.Bip01_L_Clavicle",
	color = Color(235, 235, 210),
	fractureType = "clavicle",
	hitboxes = {
		BodyBox(Vector(2.4, 0, 0), Vector(2.4, 0.55, 0.55))
	}
})

MuR.AddBoneZone("Rib Cage", {
	bone = "ValveBiped.Bip01_Spine2",
	color = Color(230, 230, 210),
	fractureType = "ribs",
	hitboxes = {
		BodyBox(Vector(4.9, 4.2, 0), Vector(3.6, 0.55, 5.3)),
		BodyBox(Vector(4.2, 2.6, 5.0), Vector(2.6, 1.15, 0.65)),
		BodyBox(Vector(4.2, 2.6, -5.0), Vector(2.6, 1.15, 0.65))
	}
})

MuR.AddBoneZone("Pelvis Bone", {
	bone = "ValveBiped.Bip01_Spine1",
	color = Color(220, 220, 200),
	fractureType = "pelvis",
	hitboxes = {
		BodyBox(Vector(-5, 0, 0), Vector(1.6, 4.4, 4.8)),
		BodyBox(Vector(-7.0, 0, 0), Vector(0.9, 2.5, 2.8))
	}
})

MuR.AddBoneZone("Right Humerus Bone", {
	bone = "ValveBiped.Bip01_R_UpperArm",
	color = Color(230, 230, 210),
	fractureType = "arm",
	hitboxes = {
		BodyBox(Vector(4.2, 0, 0), Vector(4.2, 0.75, 0.75))
	}
})

MuR.AddBoneZone("Left Humerus Bone", {
	bone = "ValveBiped.Bip01_L_UpperArm",
	color = Color(230, 230, 210),
	fractureType = "arm",
	hitboxes = {
		BodyBox(Vector(4.2, 0, 0), Vector(4.2, 0.75, 0.75))
	}
})

MuR.AddBoneZone("Right Forearm Bone", {
	bone = "ValveBiped.Bip01_R_Forearm",
	color = Color(230, 230, 210),
	fractureType = "forearm",
	hitboxes = {
		BodyBox(Vector(5.0, 0, 0), Vector(5.0, 0.65, 0.65))
	}
})

MuR.AddBoneZone("Left Forearm Bone", {
	bone = "ValveBiped.Bip01_L_Forearm",
	color = Color(230, 230, 210),
	fractureType = "forearm",
	hitboxes = {
		BodyBox(Vector(5.0, 0, 0), Vector(5.0, 0.65, 0.65))
	}
})

MuR.AddBoneZone("Right Femur Bone", {
	bone = "ValveBiped.Bip01_R_Thigh",
	color = Color(225, 225, 205),
	fractureType = "leg",
	hitboxes = {
		BodyBox(Vector(5.6, 0, 0), Vector(5.6, 0.85, 0.85))
	}
})

MuR.AddBoneZone("Left Femur Bone", {
	bone = "ValveBiped.Bip01_L_Thigh",
	color = Color(225, 225, 205),
	fractureType = "leg",
	hitboxes = {
		BodyBox(Vector(5.6, 0, 0), Vector(5.6, 0.85, 0.85))
	}
})

MuR.AddBoneZone("Right Shin Bone", {
	bone = "ValveBiped.Bip01_R_Calf",
	color = Color(225, 225, 205),
	fractureType = "leg",
	hitboxes = {
		BodyBox(Vector(5.2, 0, 0), Vector(5.2, 0.75, 0.75))
	}
})

MuR.AddBoneZone("Left Shin Bone", {
	bone = "ValveBiped.Bip01_L_Calf",
	color = Color(225, 225, 205),
	fractureType = "leg",
	hitboxes = {
		BodyBox(Vector(5.2, 0, 0), Vector(5.2, 0.75, 0.75))
	}
})

MuR.AddBoneZone("Right Foot Bone", {
	bone = "ValveBiped.Bip01_R_Foot",
	color = Color(220, 220, 200),
	fractureType = "foot",
	hitboxes = {
		BodyBox(Vector(2.6, 0, 0), Vector(2.6, 0.8, 1.25))
	}
})

MuR.AddBoneZone("Left Foot Bone", {
	bone = "ValveBiped.Bip01_L_Foot",
	color = Color(220, 220, 200),
	fractureType = "foot",
	hitboxes = {
		BodyBox(Vector(2.6, 0, 0), Vector(2.6, 0.8, 1.25))
	}
})
