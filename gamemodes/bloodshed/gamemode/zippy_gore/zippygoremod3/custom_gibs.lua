ZippyGoreMod3_BasicGib_Models = { "models/gore/Debris_GoreDebris02.mdl", "models/gore/Debris_GoreDebris03.mdl", "models/gore/Debris_GoreDebris04.mdl" }
ZippyGoreMod3_BasicGib_Scale = {1, 2}
ZippyGoreMod3_BasicGib_UseFleshMaterial = false

ZippyGoreMod3_CustomGibs = {
    ["ValveBiped.Bip01_Head1"] = {
        gibs = {
            {
                model = "models/gore/Head_Eye01.mdl",
                scale = 1,
		random_angle = false,
		random_pos = false,
            },
            {
                model = "models/gore/Head_Eye02.mdl",
                scale = 1,
		random_angle = false,
		random_pos = false,
            },
            {
                model = "models/gore/Head_HeadBitBackLeft.mdl",
                scale = 1,
		random_angle = false,
		random_pos = false,
            },
            {
                model = "models/gore/Head_HeadBitBackRight.mdl",
                scale = 1,
		random_angle = false,
		random_pos = false,
            },
            {
                model = "models/gore/Head_HeadBitFrontLeft.mdl",
                scale = 1,
		random_angle = false,
		random_pos = false,
            },
            {
                model = "models/gore/Head_HeadBitFrontRight.mdl",
                scale = 1,
		random_angle = false,
		random_pos = false,
            },
            {
                model = "models/gore/Head_HeadBitTopLeft.mdl",
                scale = 1,
		random_angle = false,
		random_pos = false,
            },
            {
                model = "models/gore/Head_HeadBitTopRight.mdl",
                scale = 1,
		random_angle = false,
		random_pos = false,
            },
            {
                model = "models/gore/Head_JawLo.mdl",
                scale = 1,
		random_angle = false,
		random_pos = false,
            },
        },
	basic_gib_mult = 4,
    },
    ["ValveBiped.Bip01_Spine2"] = {
        gibs = {
            {
		model = "models/gore/UpperTorso.mdl",
		scale = 1,
		random_angle = false,
		random_pos = false,

            },
	},
        basic_gib_mult = 2,
    },
    ["ValveBiped.Bip01_Pelvis"] = {
        gibs = {
            {
		model = "models/gore/Pelvis.mdl",
		scale = 1,
		random_angle = false,
		random_pos = false,
		is_ragdoll = true,
            },
        },
        basic_gib_mult = 2,
    },
    ["ValveBiped.Bip01_R_UpperArm"] = {
        gibs = {
            {
		model = "models/gore/RArm_ArmGoreUpperR.mdl",
		scale = 1,
		random_angle = false,
		random_pos = false,
            },
        },
        basic_gib_mult = 2,
    },
    ["ValveBiped.Bip01_R_Forearm"] = {
        gibs = {
            {
		model = "models/gore/RArm_ArmGoreLowerR.mdl",
		scale = 1,
		random_angle = false,
		random_pos = false,
            },
        },
        basic_gib_mult = 1,
    },
    ["ValveBiped.Bip01_R_Hand"] = {
        gibs = {
            {
		model = "models/gore/RArm_ArmGoreHandR.mdl",
		scale = 1,
		random_angle = false,
		random_pos = false,
            },
        },
        basic_gib_mult = 0.5,
    },
    ["ValveBiped.Bip01_L_UpperArm"] = {
        gibs = {
            {
		model = "models/gore/LArm_ArmGoreUpperL.mdl",
		scale = 1,
		random_angle = false,
		random_pos = false,
            },
        },
        basic_gib_mult = 2,
    },
    ["ValveBiped.Bip01_L_Forearm"] = {
        gibs = {
            {
		model = "models/gore/LArm_ArmGoreLowerL.mdl",
		scale = 1,
		random_angle = false,
		random_pos = false,
            },
        },
        basic_gib_mult = 1,
    },
    ["ValveBiped.Bip01_L_Hand"] = {
        gibs = {
            {
		model = "models/gore/LArm_ArmGoreHandL.mdl",
		scale = 1,
		random_angle = false,
		random_pos = false,
            },
        },
        basic_gib_mult = 0.5,
    },
    ["ValveBiped.Bip01_R_Thigh"] = {
        gibs = {
            {
		model = "models/gore/RLeg_MeatBit001R.mdl",
		scale = 1,
		random_angle = false,
		random_pos = false,
            },
            {
		model = "models/gore/RLeg_MeatBit002R.mdl",
		scale = 1,
		random_angle = false,
		random_pos = false,
            },
            {
		model = "models/gore/RLeg_MeatBit003R.mdl",
		scale = 1,
		random_angle = false,
		random_pos = false,
            },
            {
		model = "models/gore/RLeg_MeatBit004R.mdl",
		scale = 1,
		random_angle = false,
		random_pos = false,
            },
        },
        basic_gib_mult = 2,
    },
    ["ValveBiped.Bip01_R_Calf"] = {
        gibs = {
            {
		model = "models/gore/RLeg_LegPartMidR.mdl",
		scale = 1,
		random_angle = false,
		random_pos = false,
            },
            {
		model = "models/gore/RLeg_LegPartFootR002.mdl",
		scale = 1,
		random_angle = false,
		random_pos = false,
            },
        },
        basic_gib_mult = 1,
    },
    ["ValveBiped.Bip01_R_Foot"] = {
        gibs = {
            {
		model = "models/gore/RLeg_LegPartFootR001.mdl",
		scale = 1,
		random_angle = false,
		random_pos = false,
            },
        },
        basic_gib_mult = 0.5,
    },
    ["ValveBiped.Bip01_L_Thigh"] = {
        gibs = {
            {
		model = "models/gore/LLeg_MeatBit001L.mdl",
		scale = 1,
		random_angle = false,
		random_pos = false,
            },
            {
		model = "models/gore/LLeg_MeatBit002L.mdl",
		scale = 1,
		random_angle = false,
		random_pos = false,
            },
            {
		model = "models/gore/LLeg_MeatBit003L.mdl",
		scale = 1,
		random_angle = false,
		random_pos = false,
            },
            {
		model = "models/gore/LLeg_MeatBit004L.mdl",
		scale = 1,
		random_angle = false,
		random_pos = false,
            },
        },
        basic_gib_mult = 2,
    },
    ["ValveBiped.Bip01_L_Calf"] = {
        gibs = {
            {
		model = "models/gore/LLeg_LegPartMidL.mdl",
		scale = 1,
		random_angle = false,
		random_pos = false,
            },
            {
		model = "models/gore/LLeg_LegPartFootL002.mdl",
		scale = 1,
		random_angle = false,
		random_pos = false,
            },
        },
        basic_gib_mult = 1,
    },
    ["ValveBiped.Bip01_L_Foot"] = {
        gibs = {
            {
		model = "models/gore/LLeg_LegPartFootL001.mdl",
		scale = 1,
		random_angle = false,
		random_pos = false,
            },
        },
        basic_gib_mult = 0.5,
    },
}