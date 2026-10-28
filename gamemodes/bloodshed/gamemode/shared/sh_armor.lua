MuR = MuR or {}
MuR.Armor = MuR.Armor or {}

MuR.Armor.BodyParts = {
    ["face"] = {
        bone = "ValveBiped.Bip01_Head1",
        pos = Vector(4, -1, 0),
        ang = Angle(0, 90, 90),
        hitgroups = {HITGROUP_HEAD},
        organs = {"Brain"}
    },
    ["head"] = {
        bone = "ValveBiped.Bip01_Head1",
        pos = Vector(0, 0, 0),
        ang = Angle(0, 0, 0),
        hitgroups = {HITGROUP_HEAD},
        organs = {"Brain", "Carotid Artery", "Neck"}
    },
    ["body"] = {
        bone = "ValveBiped.Bip01_Spine2",
        pos = Vector(0, 0, 0),
        ang = Angle(0, 90, 0),
        hitgroups = {HITGROUP_CHEST, HITGROUP_STOMACH},
        organs = {"Heart", "Right Lung", "Left Lung", "Liver", "Spine"}
    }
}

MuR.Armor.Items = {

    ["pot"] = {
        bodypart = "head",
        model = "models/props_interiors/pot02a.mdl",
        scale = 1.15,
        pos_offset = Vector(6, 0.1, -6),
        ang_offset = Angle(0, 280, 90),
        armor = 5,
        damage_reduction = 0.2,
        concussion_reduction = 0.15,
        gas_protection = 0,
        protected_organs = {"Brain"},
        damage_types = {DMG_SLASH, DMG_CLUB},
        icon = "entities/mur_armor_pot.png",
        overlay = "bs_overlays/pot_overlay.png",
        equip_sound = "physics/metal/metal_solid_impact_hard1.wav",
        unequip_sound = "physics/metal/metal_solid_impact_soft1.wav"
    },
    ["gasmask"] = {
        bodypart = "face",
        model = "models/murdered/mask/Gas_Mask.mdl",
        scale = 1,
        pos_offset = Vector(0, 0, 0),
        ang_offset = Angle(0, 270, 270),
        armor = 5,
        damage_reduction = 0.1,
        concussion_reduction = 0.05,
        gas_protection = 1,
        pepper_protection = 1,
        protected_organs = {"Brain"},
        damage_types = {DMG_POISON, DMG_NERVEGAS, DMG_RADIATION, DMG_ACID, DMG_SLASH},
        icon = "entities/mur_armor_gasmask.png",
        overlay = "bs_overlays/gasmask_overlay.png",
        equip_sound = "murdered/armor/face_equip.wav",
        unequip_sound = "murdered/armor/face_unequip.wav"
    },
    ["moto_helmet"] = {
        bodypart = "head",
        model = "models/murdered/helmets/moto_helmet.mdl",
        scale = 1,
        pos_offset = Vector(4, 0, 0),
        ang_offset = Angle(-90, 270, 270),
        armor = 0,
        damage_reduction = 0.6,
        concussion_reduction = 0.3,
        gas_protection = 0.1,
        pepper_protection = 1,
        protected_organs = {"Brain"},
        damage_types = {DMG_SLASH, DMG_CLUB, DMG_BULLET, DMG_BLAST},
        ammo_scaling = {
            ["others"] = 0,
            ["buckshot"] = 0.2,
            ["pistol"] = 0.1,
        },
        icon = "entities/mur_armor_moto_helmet.png",
        overlay = "bs_overlays/motoh_overlay.png",
        equip_sound = "murdered/armor/helmet_equip.wav",
        unequip_sound = "murdered/armor/helmet_unequip.wav"
    },
    ["helmet_ulach"] = {
        bodypart = "head",
        model = "models/murdered/helmets/helmet_ulach.mdl",
        scale = 1,
        pos_offset = Vector(2, 0, 0),
        ang_offset = Angle(0, 270, 270),
        armor = 0,
        damage_reduction = 0.5,
        concussion_reduction = 0.45,
        ammo_scaling = {
            ["others"] = 0.15,
            ["buckshot"] = 0.8,
            ["pistol"] = 0.85,
            ["357"] = 0.3,
        },
        gas_protection = 0,
        protected_organs = {"Brain"},
        damage_types = {DMG_SLASH, DMG_CLUB, DMG_BULLET},
        icon = "entities/mur_armor_helmet_ulach.png",
        overlay = "bs_overlays/helm_overlay.png",
        equip_sound = "murdered/armor/helmet_equip.wav",
        unequip_sound = "murdered/armor/helmet_unequip.wav"
    },
    ["helmet_riot"] = {
        bodypart = "head",
        model = "models/murdered/helmets/helmet_riot.mdl",
        scale = 1,
        pos_offset = Vector(3, 0, 0),
        ang_offset = Angle(0, 270, 270),
        armor = 0,
        damage_reduction = 0.8,
        concussion_reduction = 0.5,
        gas_protection = 0.1,
        protected_organs = {"Brain"},
        damage_types = {DMG_SLASH, DMG_CLUB, DMG_BULLET},
        ammo_scaling = {
            ["others"] = 0,
            ["buckshot"] = 0.3,
            ["pistol"] = 0.1,
        },
        icon = "entities/mur_armor_helmet_riot.png",
        overlay = "bs_overlays/riot_overlay.png",
        equip_sound = "murdered/armor/helmet_equip.wav",
        unequip_sound = "murdered/armor/helmet_unequip.wav"
    },
    ["classI_armor"] = {
        bodypart = "body",
        model = "models/murdered/armors/classI_armor.mdl",
        scale = 1.05,
        pos_offset = Vector(2.4, -2, 0),
        ang_offset = Angle(180, 270, 270),
        armor = 0,
        damage_reduction = 0.75,
        concussion_reduction = 0.15,
        gas_protection = 0,
        protected_organs = {"Heart", "Right Lung", "Left Lung", "Liver", "Spine"},
        damage_types = {DMG_BLAST, DMG_BULLET, DMG_SLASH, DMG_CLUB},
        ammo_scaling = {
            ["others"] = 0,
            ["buckshot"] = 0.1,
            ["pistol"] = 0.1,
        },
        icon = "entities/mur_armor_classI_armor.png",
        equip_sound = "murdered/armor/armor_equip.wav",
        unequip_sound = "murdered/armor/armor_unequip.wav"
    },
    ["classII_armor"] = {
        bodypart = "body",
        model = "models/murdered/armors/classII_vest.mdl",
        scale = 1,
        pos_offset = Vector(2, -3, 0),
        ang_offset = Angle(90, 270, 270),
        armor = 0,
        damage_reduction = 0.5,
        concussion_reduction = 0.12,
        gas_protection = 0,
        protected_organs = {"Heart", "Right Lung", "Left Lung", "Liver", "Spine"},
        damage_types = {DMG_BLAST, DMG_BULLET, DMG_SLASH, DMG_CLUB},
        ammo_scaling = {
            ["others"] = 0.1,
            ["357"] = 0.3,
            ["pistol"] = 0.75,
            ["buckshot"] = 0.8,
        },
        icon = "entities/mur_armor_classII_armor.png",
        equip_sound = "murdered/armor/armor_equip.wav",
        unequip_sound = "murdered/armor/armor_unequip.wav"
    },
    ["classII_police"] = {
        bodypart = "body",
        model = "models/murdered/armors/classII_police.mdl",
        scale = 1,
        pos_offset = Vector(3, -2, 0),
        ang_offset = Angle(180, 270, 270),
        armor = 0,
        damage_reduction = 0.5,
        concussion_reduction = 0.12,
        gas_protection = 0,
        protected_organs = {"Heart", "Right Lung", "Left Lung", "Liver", "Spine"},
        damage_types = {DMG_BLAST, DMG_BULLET, DMG_SLASH, DMG_CLUB},
        ammo_scaling = {
            ["others"] = 0.1,
            ["357"] = 0.3,
            ["pistol"] = 0.75,
            ["buckshot"] = 0.8,
        },
        icon = "entities/mur_armor_classII_armor.png",
        equip_sound = "murdered/armor/armor_equip.wav",
        unequip_sound = "murdered/armor/armor_unequip.wav"
    },
    ["classIII_armor"] = {
        bodypart = "body",
        model = "models/murdered/armors/classIII_vest.mdl",
        scale = 1,
        pos_offset = Vector(2, -3, 0),
        ang_offset = Angle(90, 270, 270),
        armor = 0,
        damage_reduction = 0.75,
        concussion_reduction = 0.18,
        gas_protection = 0,
        protected_organs = {"Heart", "Right Lung", "Left Lung", "Liver", "Spine"},
        damage_types = {DMG_BLAST, DMG_BULLET, DMG_SLASH, DMG_CLUB},
        ammo_scaling = {
            ["others"] = 0.2,
            ["357"] = 0.6,
            ["pistol"] = 0.9,
            ["buckshot"] = 0.9,
            ["ar2"] = 0.35,
            ["smg1"] = 0.7,
        },
        icon = "entities/mur_armor_classIII_armor.png",
        equip_sound = "murdered/armor/armor_equip.wav",
        unequip_sound = "murdered/armor/armor_unequip.wav"
    },
    ["classIII_police"] = {
        bodypart = "body",
        model = "models/murdered/armors/classIII_police.mdl",
        scale = 1,
        pos_offset = Vector(2, -4, 0),
        ang_offset = Angle(180, 280, 270),
        armor = 0,
        damage_reduction = 0.75,
        concussion_reduction = 0.18,
        gas_protection = 0,
        protected_organs = {"Heart", "Right Lung", "Left Lung", "Liver", "Spine"},
        damage_types = {DMG_BLAST, DMG_BULLET, DMG_SLASH, DMG_CLUB},
        ammo_scaling = {
            ["others"] = 0.2,
            ["357"] = 0.6,
            ["pistol"] = 0.9,
            ["buckshot"] = 0.9,
            ["ar2"] = 0.35,
            ["smg1"] = 0.7,
        },
        icon = "entities/mur_armor_classIII_police.png",
        equip_sound = "murdered/armor/armor_equip.wav",
        unequip_sound = "murdered/armor/armor_unequip.wav"
    },
}

MuR.Armor.GasCategories = {
    "poison",
    "nerve_agent",
    "irritant"
}

function MuR.Armor.GetItem(armorId)
    return MuR.Armor.Items[armorId]
end

function MuR.Armor.GetBodyPart(partId)
    return MuR.Armor.BodyParts[partId]
end

function MuR.Armor.IsDamageTypeProtected(armorId, dmginfo)
    local item = MuR.Armor.Items[armorId]
    if not item or not item.damage_types then return false end

    for _, dt in ipairs(item.damage_types) do
        if dt == "all" then return true end
        if isnumber(dt) and dmginfo:IsDamageType(dt) then
            return true
        end
    end
    return false
end

function MuR.Armor.IsOrganProtected(armorId, organName, dmginfo)
    local item = MuR.Armor.Items[armorId]
    if not item then return false end

    if dmginfo and not MuR.Armor.IsDamageTypeProtected(armorId, dmginfo) then
        return false
    end

    if item.protected_organs then
        for _, org in ipairs(item.protected_organs) do
            if org == organName then
                return true
            end
        end
    end

    local part = MuR.Armor.BodyParts[item.bodypart]
    if part and part.organs then
        for _, org in ipairs(part.organs) do
            if org == organName then
                return true
            end
        end
    end

    return false
end

function MuR.Armor.IsHitgroupProtected(bodypart, hitgroup)
    local part = MuR.Armor.BodyParts[bodypart]
    if not part or not part.hitgroups then return false end

    for _, hg in ipairs(part.hitgroups) do
        if hg == hitgroup then
            return true
        end
    end
    return false
end

function MuR.Armor.GetItemsForBodyPart(bodypart)
    local items = {}
    for id, item in pairs(MuR.Armor.Items) do
        if item.bodypart == bodypart then
            items[#items + 1] = id
        end
    end
    return items
end
