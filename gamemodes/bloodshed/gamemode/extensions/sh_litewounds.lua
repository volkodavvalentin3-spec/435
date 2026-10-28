LiteWounds = LiteWounds or {}
LiteWounds.DefaultGoreUndermodel = "models/player/skeleton.mdl"

LiteWounds.Bones = LiteWounds.Bones or {}

LiteWounds.PhysBoneBlacklistClass = {
	["npc_seagull"] = true,
	["npc_pigeon"] = true,
	["npc_crow"] = true,
	["npc_antlion"] = true,
	["npc_antlionguard"] = true
}

LiteWounds.Bones.Blacklist = {
	["valvebiped.bip01_forward"] = true,
	["valvebiped.forward"] = true,
}

LiteWounds.Bones.HitGroupSearch = {
	[HITGROUP_HEAD] = {"ValveBiped.Bip01_Head1", "ValveBiped.Bip01_Head", "ValveBiped.head"},
	[HITGROUP_CHEST] = {"ValveBiped.Bip01_Spine2", "ValveBiped.Bip01_Spine4", "ValveBiped.spine2", "ValveBiped.spine3"},
	[HITGROUP_STOMACH] = {"ValveBiped.Bip01_Spine2", "ValveBiped.Bip01_Spine1", "ValveBiped.Bip01_Spine", "ValveBiped.Bip01_Spine0", "ValveBiped.hips", "ValveBiped.spine1"},
	[HITGROUP_LEFTARM] = {"ValveBiped.Bip01_L_UpperArm", "ValveBiped.Bip01_L_Upperarm", "ValveBiped.Bip01_L_Forearm", "ValveBiped.Bip01_L_Lowerarm", "ValveBiped.Bip01_L_Hand", "ValveBiped.arm1_R", "ValveBiped.arm1_L"},
	[HITGROUP_RIGHTARM] = {"ValveBiped.Bip01_R_UpperArm", "ValveBiped.Bip01_R_Upperarm", "ValveBiped.Bip01_R_Forearm", "ValveBiped.Bip01_R_Lowerarm", "ValveBiped.Bip01_R_Hand", "ValveBiped.arm2_R", "ValveBiped.arm2_L"},
	[HITGROUP_LEFTLEG] = {"ValveBiped.Bip01_L_Thigh", "ValveBiped.Bip01_L_Calf", "ValveBiped.Bip01_L_Foot", "ValveBiped.Bip01_L_Toe0"},
	[HITGROUP_RIGHTLEG] = {"ValveBiped.Bip01_R_Thigh", "ValveBiped.Bip01_R_Calf", "ValveBiped.Bip01_R_Foot", "ValveBiped.Bip01_R_Toe0"}
}

LiteWounds.Bones.HitGroupGibs = {
	[HITGROUP_HEAD] = {"ValveBiped.Bip01_Head1", "ValveBiped.Bip01_Head", "ValveBiped.head"},
	[HITGROUP_CHEST] = {"ValveBiped.Bip01_Spine2", "ValveBiped.spine2"},
	[HITGROUP_STOMACH] = {"ValveBiped.Bip01_Spine", "ValveBiped.Bip01_Spine0", "ValveBiped.spine1"},
	[HITGROUP_LEFTARM] = {"ValveBiped.Bip01_L_UpperArm", "ValveBiped.Bip01_L_Upperarm", "ValveBiped.arm1_L"},
	[HITGROUP_RIGHTARM] = {"ValveBiped.Bip01_R_UpperArm", "ValveBiped.Bip01_R_Upperarm", "ValveBiped.arm1_R"},
	[HITGROUP_LEFTLEG] = {"ValveBiped.Bip01_L_Thigh", "ValveBiped.leg_bone1_L"},
	[HITGROUP_RIGHTLEG] = {"ValveBiped.Bip01_R_Thigh", "ValveBiped.leg_bone1_R"}
}

LiteWounds.BoneHitGroups = {
	["head"] = HITGROUP_HEAD,
	["neck"] = HITGROUP_HEAD,
	["spine"] = HITGROUP_CHEST,
	["pelvis"] = HITGROUP_STOMACH,
	["hips"] = HITGROUP_STOMACH,
	["clavical"] = HITGROUP_LEFTARM,
	["arm"] = HITGROUP_LEFTARM,
	["hand"] = HITGROUP_LEFTARM,
	["hip"] = HITGROUP_LEFTLEG,
	["thigh"] = HITGROUP_LEFTLEG,
	["calf"] = HITGROUP_LEFTLEG,
	["foot"] = HITGROUP_LEFTLEG,
	["leg"] = HITGROUP_LEFTLEG,
	["femur"] = HITGROUP_LEFTLEG
}

local function propogatePreSuf(prefix, min, max, suffix)
	local tbl = {}
	for i = min, max do
		tbl[#tbl + 1] = prefix .. tostring(i) .. suffix
	end
	return tbl
end

CHAN_LG = (CHAN_BODY and CHAN_BODY or 4) + 16

BLOOD_COLOR_SYNTH = BLOOD_COLOR_SYNTH or BLOOD_COLOR_ANTLION_WORKER + 2

LiteWounds.GoreModels = {
	["default"] = {
		["default"] = LiteWounds.DefaultGoreUndermodel,
		["head1"] = LiteWounds.DefaultGoreUndermodel,
		["head"] = LiteWounds.DefaultGoreUndermodel
	}
}

setmetatable(LiteWounds.GoreModels, {
	__index = function(t, k)
		local low = string.lower(k)
		if k ~= low and t[low] then
			return t[low]
		else
			return t["default"]
		end
	end
})

LiteWounds.WoundModels = {
	["default"] = {
		["default"] = {
			"models/Combine_Helicopter/helicopter_bomb01.mdl",
			["scale"] = 0.2,
			["clamp"] = 0.3
		},
		["head1"] = { ["clamp"] = 0.3 },
		["neck1"] = { ["clamp"] = 0.3 },
		["head"] = { ["clamp"] = 0.3 },
		["neck"] = { ["clamp"] = 0.3 },
		["spine4"] = { ["clamp"] = 0.4 },
		["spine3"] = { ["clamp"] = 0.4 },
		["spine2"] = { ["clamp"] = 0.4 },
		["spine1"] = { ["clamp"] = 0.4 },
		["spine0"] = { ["clamp"] = 0.4 },
		["spine"] = { ["clamp"] = 0.4 },
		["pelvis"] = { ["clamp"] = 0.4 },
		["r_thigh"] = { ["clamp"] = 0.35 },
		["r_calf"] = { ["clamp"] = 0.325 },
		["r_foot"] = { ["clamp"] = 0.3 },
		["l_thigh"] = { ["clamp"] = 0.35 },
		["l_calf"] = { ["clamp"] = 0.325 },
		["l_foot"] = { ["clamp"] = 0.3 },
		["r_upperarm"] = { ["clamp"] = 0.25 },
		["r_forearm"] = { ["clamp"] = 0.2 },
		["r_hand"] = { ["clamp"] = 0.15 },
		["l_upperarm"] = { ["clamp"] = 0.25 },
		["l_forearm"] = { ["clamp"] = 0.2 },
		["l_hand"] = { ["clamp"] = 0.15 }
	}
}

setmetatable(LiteWounds.WoundModels, {
	__index = function(t, k)
		local low = string.lower(k)
		if k ~= low and t[low] then
			return t[low]
		else
			return t["default"]
		end
	end
})

LiteWounds.WoundModelRadius = {
	["models/Combine_Helicopter/helicopter_bomb01.mdl"] = 16
}

LiteWounds.InteriorModels = {
	["valvebiped.bip01_head1"] = {model = "models/gore/gorehead.mdl", bone = "ValveBiped.Bip01_Head1", pos = Vector(0, 0, 0), ang = Angle(90, 0, 0), scale = 1},

	["valvebiped.bip01_spine4"] = {model = "models/gore/uppertorso.mdl", bone = "ValveBiped.Bip01_Spine2", pos = Vector(0, 0, 0), ang = Angle(0, 0, 0), scale = 1},
	["valvebiped.bip01_spine3"] = {model = "models/gore/uppertorso.mdl", bone = "ValveBiped.Bip01_Spine2", pos = Vector(0, 0, 0), ang = Angle(0, 0, 0), scale = 1},
	["valvebiped.bip01_spine2"] = {model = "models/gore/uppertorso.mdl", bone = "ValveBiped.Bip01_Spine2", pos = Vector(0, 0, 0), ang = Angle(0, 0, 0), scale = 1},
	["valvebiped.bip01_spine1"] = {model = "models/gore/uppertorso.mdl", bone = "ValveBiped.Bip01_Spine2", pos = Vector(0, 0, 0), ang = Angle(0, 0, 0), scale = 1},
	["valvebiped.bip01_spine"]  = {model = "models/gore/uppertorso.mdl", bone = "ValveBiped.Bip01_Spine2", pos = Vector(0, 0, 0), ang = Angle(0, 0, 0), scale = 1},

	["valvebiped.bip01_pelvis"] = {model = "models/gore/pelvis.mdl", bone = "ValveBiped.Bip01_Pelvis", pos = Vector(0, 0, 0), ang = Angle(0, 0, 0), scale = 1}
}

LiteWounds.WoundRadius = {
	["default"] = {
		["valvebiped.bip01_spine4"] = 10,
		["valvebiped.bip01_spine3"] = 10,
		["valvebiped.bip01_spine2"] = 10,
		["valvebiped.bip01_spine1"] = 10,
		["valvebiped.bip01_spine0"] = 10,
		["valvebiped.bip01_spine"] = 10,
		["valvebiped.bip01_pelvis"] = 10,
		["valvebiped.bip01_head1"] = 5,
		["default"] = 4
	},
	["models/combine_super_soldier.mdl"] = {
		["valvebiped.bip01_spine4"] = 18,
		["valvebiped.bip01_spine3"] = 18,
		["valvebiped.bip01_spine2"] = 16,
		["valvebiped.bip01_spine1"] = 14,
		["valvebiped.bip01_spine0"] = 14,
		["valvebiped.bip01_spine"] = 14,
		["valvebiped.bip01_pelvis"] = 8,
		["valvebiped.bip01_head1"] = 6,
		["default"] = 4
	},
	["models/combine_soldier_prisonguard.mdl"] = {
		["valvebiped.bip01_spine4"] = 18,
		["valvebiped.bip01_spine3"] = 18,
		["valvebiped.bip01_spine2"] = 16,
		["valvebiped.bip01_spine1"] = 14,
		["valvebiped.bip01_spine0"] = 14,
		["valvebiped.bip01_spine"] = 14,
		["valvebiped.bip01_pelvis"] = 8,
		["valvebiped.bip01_head1"] = 6,
		["default"] = 4
	},
	["models/combine_soldier.mdl"] = {
		["valvebiped.bip01_spine4"] = 18,
		["valvebiped.bip01_spine3"] = 18,
		["valvebiped.bip01_spine2"] = 16,
		["valvebiped.bip01_spine1"] = 14,
		["valvebiped.bip01_spine0"] = 14,
		["valvebiped.bip01_spine"] = 14,
		["valvebiped.bip01_pelvis"] = 8,
		["valvebiped.bip01_head1"] = 6,
		["default"] = 4
	},
	["models/barney.mdl"] = {
		["valvebiped.bip01_spine4"] = 14,
		["valvebiped.bip01_spine3"] = 14,
		["valvebiped.bip01_spine2"] = 14,
		["valvebiped.bip01_spine1"] = 14,
		["valvebiped.bip01_spine0"] = 14,
		["valvebiped.bip01_spine"] = 14,
		["valvebiped.bip01_pelvis"] = 8,
		["valvebiped.bip01_head1"] = 6,
		["default"] = 4
	},
	["models/police.mdl"] = {
		["valvebiped.bip01_spine4"] = 14,
		["valvebiped.bip01_spine3"] = 14,
		["valvebiped.bip01_spine2"] = 14,
		["valvebiped.bip01_spine1"] = 14,
		["valvebiped.bip01_spine0"] = 14,
		["valvebiped.bip01_spine"] = 14,
		["valvebiped.bip01_pelvis"] = 8,
		["valvebiped.bip01_head1"] = 6,
		["default"] = 4
	},
	["models/player/combine_super_soldier.mdl"] = {
		["valvebiped.bip01_spine4"] = 18,
		["valvebiped.bip01_spine3"] = 18,
		["valvebiped.bip01_spine2"] = 16,
		["valvebiped.bip01_spine1"] = 14,
		["valvebiped.bip01_spine0"] = 14,
		["valvebiped.bip01_spine"] = 14,
		["valvebiped.bip01_pelvis"] = 8,
		["valvebiped.bip01_head1"] = 6,
		["default"] = 4
	},
	["models/player/combine_soldier_prisonguard.mdl"] = {
		["valvebiped.bip01_spine4"] = 18,
		["valvebiped.bip01_spine3"] = 18,
		["valvebiped.bip01_spine2"] = 16,
		["valvebiped.bip01_spine1"] = 14,
		["valvebiped.bip01_spine0"] = 14,
		["valvebiped.bip01_spine"] = 14,
		["valvebiped.bip01_pelvis"] = 8,
		["valvebiped.bip01_head1"] = 6,
		["default"] = 4
	},
	["models/player/combine_soldier.mdl"] = {
		["valvebiped.bip01_spine4"] = 18,
		["valvebiped.bip01_spine3"] = 18,
		["valvebiped.bip01_spine2"] = 16,
		["valvebiped.bip01_spine1"] = 14,
		["valvebiped.bip01_spine0"] = 14,
		["valvebiped.bip01_spine"] = 14,
		["valvebiped.bip01_pelvis"] = 8,
		["valvebiped.bip01_head1"] = 6,
		["default"] = 4
	},
	["models/player/barney.mdl"] = {
		["valvebiped.bip01_spine4"] = 14,
		["valvebiped.bip01_spine3"] = 14,
		["valvebiped.bip01_spine2"] = 14,
		["valvebiped.bip01_spine1"] = 14,
		["valvebiped.bip01_spine0"] = 14,
		["valvebiped.bip01_spine"] = 14,
		["valvebiped.bip01_pelvis"] = 8,
		["valvebiped.bip01_head1"] = 6,
		["default"] = 4
	},
	["models/player/police.mdl"] = {
		["valvebiped.bip01_spine4"] = 14,
		["valvebiped.bip01_spine3"] = 14,
		["valvebiped.bip01_spine2"] = 14,
		["valvebiped.bip01_spine1"] = 14,
		["valvebiped.bip01_spine0"] = 14,
		["valvebiped.bip01_spine"] = 14,
		["valvebiped.bip01_pelvis"] = 8,
		["valvebiped.bip01_head1"] = 6,
		["default"] = 4
	},
	["models/player/police_fem.mdl"] = {
		["valvebiped.bip01_spine4"] = 14,
		["valvebiped.bip01_spine3"] = 14,
		["valvebiped.bip01_spine2"] = 14,
		["valvebiped.bip01_spine1"] = 14,
		["valvebiped.bip01_spine0"] = 14,
		["valvebiped.bip01_spine"] = 14,
		["valvebiped.bip01_pelvis"] = 8,
		["valvebiped.bip01_head1"] = 6,
		["default"] = 4
	}
}

setmetatable(LiteWounds.WoundRadius, {
	__index = function(t, k)
		local low = string.lower(k)
		if k ~= low and t[low] then
			return t[low]
		else
			return t["default"]
		end
	end
})

LiteWounds.WeaponDamageScales = LiteWounds.WeaponDamageScales or {
	["weapon_shotgun"] = 8
}

local entMeta = FindMetaTable("Entity")

if entMeta then
	local modelPhysBoneTranslateCache = {}

	if SERVER then
		function entMeta:SetupBones()
		end
	end

	if not entMeta.LG_OLD_TranslatePhysBoneToBone then
		entMeta.LG_OLD_TranslatePhysBoneToBone = entMeta.TranslatePhysBoneToBone
	end

	function entMeta:CachePhysBones(forced)
		local mdl = self:GetModel()
		if modelPhysBoneTranslateCache[mdl] and not forced then return end
		local t = {}
		for i = 0, self:GetBoneCount() - 1 do
			local phys = self:TranslateBoneToPhysBone(i)
			if not t[phys] then t[phys] = i end
		end

		modelPhysBoneTranslateCache[mdl] = t
		return modelPhysBoneTranslateCache[mdl]
	end

	function entMeta:TranslatePhysBoneToBone(b, ...)
		local md = self:GetModel()
		local t = modelPhysBoneTranslateCache[md]
		if not t then t = self:CachePhysBones() end
		return t[b] or self.LG_OLD_TranslatePhysBoneToBone(self, b, ...)
	end

	function entMeta:GetClosestBone(pos)
		local biggestDist = math.huge
		local b
		for i = 0, self:GetBoneCount() - 1 do
			local p = self:GetBoneCenter(i)
			local d = pos:Distance(p)
			if d < biggestDist then
				biggestDist = d
				b = i
			end
		end
		return b
	end

	function entMeta:GetClosestBoneInList(pos, list)
		if not list then return self:GetClosestBone(pos) end
		local biggestDist = math.huge
		local b = parentBone
		for _, boneName in ipairs(list) do
			local bone = isnumber(boneName) and boneName or self:LookupBone(boneName)
			if bone then
				local p = self:GetBoneCenter(bone)
				local d = pos:Distance(p)
				if d < biggestDist then
					biggestDist = d
					b = bone
				end
			end
		end

		if not b then return self:GetClosestBone(pos) end
		return b
	end

	function entMeta:GetBoneCenter(bone)
		self:SetupBones()
		local rootpos, rootang = self:GetBonePosition(bone)
		local t = self:GetChildBones(bone)
		if #t == 1 then
			local p = self:GetBonePosition(t[1])
			if self:BoneHasFlag(t[1], BONE_USED_BY_VERTEX_MASK) then return (p + rootpos) / 2 end
		else
			local par = self:GetBoneParent(bone)
			if par and par ~= -1 then
				local parpos = self:GetBonePosition(par)
				return rootpos + self:BoneLength(bone) * (rootpos - parpos):GetNormalized() / 2
			end
		end
		return rootpos + self:BoneLength(bone) * rootang:Forward() / 2
	end

	function entMeta:GetBloodColorLG()
		return BLOOD_COLOR_RED
	end
end

local btOverrides = {
	["npc_antlion"] = BLOOD_COLOR_ANTLION,
	["npc_antlionguard"] = BLOOD_COLOR_ANTLION,
	["npc_hunter"] = BLOOD_COLOR_SYNTH,
	["npc_turret_floor"] = DONT_BLEED
}

function LiteWounds.Precache()
	for _, v in ipairs(LiteWounds.WoundModels) do
		for _, b in pairs(v) do
			if b.model then util.PrecacheModel(b.model) end
		end
	end
end

hook.Add("InitPostEntity", "LightGibsPrecache", function()
	LiteWounds.Precache()
end)
