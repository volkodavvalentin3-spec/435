if engine.ActiveGamemode() != "bloodshed" then return end

if CLIENT then
    local meta = FindMetaTable("Player")
    local TPIKBonesBase = {
        "ValveBiped.Bip01_L_Forearm",
        "ValveBiped.Bip01_R_Forearm",
        "ValveBiped.Bip01_L_Hand",
        "ValveBiped.Bip01_L_Finger4",
        "ValveBiped.Bip01_L_Finger41",
        "ValveBiped.Bip01_L_Finger42",
        "ValveBiped.Bip01_L_Finger3",
        "ValveBiped.Bip01_L_Finger31",
        "ValveBiped.Bip01_L_Finger32",
        "ValveBiped.Bip01_L_Finger2",
        "ValveBiped.Bip01_L_Finger21",
        "ValveBiped.Bip01_L_Finger22",
        "ValveBiped.Bip01_L_Finger1",
        "ValveBiped.Bip01_L_Finger11",
        "ValveBiped.Bip01_L_Finger12",
        "ValveBiped.Bip01_L_Finger0",
        "ValveBiped.Bip01_L_Finger01",
        "ValveBiped.Bip01_L_Finger02",
        "ValveBiped.Bip01_R_Hand",
        "ValveBiped.Bip01_R_Finger4",
        "ValveBiped.Bip01_R_Finger41",
        "ValveBiped.Bip01_R_Finger42",
        "ValveBiped.Bip01_R_Finger3",
        "ValveBiped.Bip01_R_Finger31",
        "ValveBiped.Bip01_R_Finger32",
        "ValveBiped.Bip01_R_Finger2",
        "ValveBiped.Bip01_R_Finger21",
        "ValveBiped.Bip01_R_Finger22",
        "ValveBiped.Bip01_R_Finger1",
        "ValveBiped.Bip01_R_Finger11",
        "ValveBiped.Bip01_R_Finger12",
        "ValveBiped.Bip01_R_Finger0",
        "ValveBiped.Bip01_R_Finger01",
        "ValveBiped.Bip01_R_Finger02",
    }

    local function GetZAng(ent)
        if ent != LocalPlayer() then return 0 end
        local pos, ang = ent:GetBonePosition(ent:LookupBone("ValveBiped.Bip01_Head1"))
        if not pos or not ang then return 0 end
        return ang.z+0
    end

    local function GetTPIKBones(wpn)
        if IsValid(wpn) and isstring(wpn.UseBonemergeHands) and wpn.UseBonemergeHands ~= "" then
            return {
                "ValveBiped.Bip01_L_Upperarm",
                "ValveBiped.Bip01_R_Upperarm",
                unpack(TPIKBonesBase)
            }
        end
        return TPIKBonesBase
    end

    local ZERO_SCALE = Vector(0, 0, 0)

    local function ApplyFWMBoneMods(model, wpn)
        if not IsValid(model) or not IsValid(wpn) then return end

        if istable(wpn.ViewModelBoneMods) then
            for k, v in pairs(wpn.ViewModelBoneMods) do
                local bone = model:LookupBone(k)
                if not bone then continue end
                if isvector(v.scale) then model:ManipulateBoneScale(bone, v.scale) end
                if isangle(v.angle) then model:ManipulateBoneAngles(bone, v.angle) end
                if isvector(v.pos) then model:ManipulateBonePosition(bone, v.pos) end
            end
        end

        if istable(wpn.TPIKHideBones) then
            for _, v in pairs(wpn.TPIKHideBones) do
                local bone = model:LookupBone(v)
                if not bone then continue end
                model:ManipulateBoneScale(bone, ZERO_SCALE)
            end
        end

        if wpn.IsTFAWeapon then return end
        if isstring(wpn.UseBonemergeHands) and wpn.UseBonemergeHands ~= "" then return end
        if wpn.TPIKKeepViewmodelHands then return end

        for bone = 0, model:GetBoneCount() - 1 do
            local name = model:GetBoneName(bone)
            if isstring(name) and string.sub(name, 1, 11) == "ValveBiped." then
                model:ManipulateBoneScale(bone, ZERO_SCALE)
            end
        end
    end

    local TPIKDisableHoldtypes = {
        normal = true,
        passive = true,
        magic = true
    }

    local RagdollTPIKOffset = Vector(0, 0, 6)
    local RagdollTPIKAngle = Angle(0, 0, 0)

    local function LookupMuzzle(ent)
        local muz = {'muzzle', '1', 'muzzle_flash'}
        for _, v in ipairs(muz) do
            local id = ent:LookupAttachment(v)
            if id > 0 then
                return id
            end
        end
        return 0
    end

    local HoldtypeOffsets = {
        default = { pos = Vector(4, -4, 4), ang = Angle(0, 0, 0) },
        pistol  = { pos = Vector(4, -4, 4), ang = Angle(0, 0, 0) },
        revolver= { pos = Vector(10, 2, 4), ang = Angle(0, 0, 0) },
        ar2     = { pos = Vector(4, -4, 4), ang = Angle(0, 0, 0) },
        smg     = { pos = Vector(4, -4, 4), ang = Angle(0, 0, 0) },
        shotgun = { pos = Vector(4, -4, 4), ang = Angle(0, 0, 0) },
        crossbow= { pos = Vector(4, -4, 4), ang = Angle(0, 0, 0) },
        melee   = { pos = Vector(-8, -2, 4), ang = Angle(0, 0, 0) },
        grenade = { pos = Vector(4, -4, 4), ang = Angle(0, 0, 0) },
        fist    = { pos = Vector(6, -0, 4), ang = Angle(0, 0, 0) },
        melee2   = { pos = Vector(-8, -2, 4), ang = Angle(0, 0, 0) },
        knife   = { pos = Vector(-8, -2, 0), ang = Angle(0, 0, 0) },
    }

    local function wepstate(bool, wpn)
        if !wpn.fwmdataeffects then
            wpn.fwmdataeffects = {wpn.LuaShellEject, wpn.MuzzleFlashEnabled}
        end
        local t = wpn.fwmdataeffects
        if bool then
            wpn.LuaShellEject = t[1]
            wpn.MuzzleFlashEnabled = t[2]
            wpn:SetNoDraw(false)
            wpn.InTPIK = false
        else
            wpn.LuaShellEject = false
            wpn.MuzzleFlashEnabled = false
            wpn:SetNoDraw(true)
            wpn.InTPIK = true
        end
    end

    local cached_children = {}
    local function recursive_get_children(ent, bone, bones, endbone)
        local bone = isstring(bone) and ent:LookupBone(bone) or bone

        if not bone or isstring(bone) or bone == -1 then return end

        local children = ent:GetChildBones(bone)
        if #children > 0 then
            local id
            for i = 1,#children do
                id = children[i]
                if id == endbone then continue end
                recursive_get_children(ent, id, bones, endbone)
                table.insert(bones, id)
            end
        end
    end

    local function get_children(ent, bone, endbone)
        local bones = {}

        local mdl = ent:GetModel()
        if cached_children[mdl] and cached_children[mdl][bone] then return cached_children[mdl][bone] end

        recursive_get_children(ent, bone, bones, endbone)

        cached_children[mdl] = cached_children[mdl] or {}
        cached_children[mdl][bone] = bones

        return bones
    end

    local function bone_apply_matrix(ent, bone, new_matrix, endbone)
        local bone = isstring(bone) and ent:LookupBone(bone) or bone

        if not bone or isstring(bone) or bone == -1 then return end

        local matrix = ent:GetBoneMatrix(bone)
        if not matrix then return end
        local inv_matrix = matrix:GetInverse()
        if not inv_matrix then return end

        local children = get_children(ent, bone, endbone)

        local translate = (new_matrix * inv_matrix)
        local id
        for i = 1,#children do
            id = children[i]
            local mat = ent:GetBoneMatrix(id)
            if not mat then continue end
            ent:SetBoneMatrix(id, translate * mat)
        end

        ent:SetBoneMatrix(bone, new_matrix)
    end

    function meta:Solve2PartIK(start_p, end_p, length0, length1, sign, angs)
        local length2 = (start_p - end_p):Length()
        local cosAngle0 = math.Clamp(((length2 * length2) + (length0 * length0) - (length1 * length1)) / (2 * length2 * length0), -1, 1)
        local angle0 = -math.deg(math.acos(cosAngle0))
        local cosAngle1 = math.Clamp(((length1 * length1) + (length0 * length0) - (length2 * length2)) / (2 * length1 * length0), -1, 1)
        local angle1 = -math.deg(math.acos(cosAngle1))

        local diff = end_p - start_p
        diff:Normalize()

        local angle2 = math.deg(math.atan2(-math.sqrt(diff.x * diff.x + diff.y * diff.y), diff.z)) - 90
        local angle3 = -math.deg(math.atan2(diff.x, diff.y)) - 90
        angle3 = math.NormalizeAngle(angle3)

        local axis = diff * 1
        axis:Normalize()

        local Joint0 = Angle(angle0 + angle2, angle3, 0)
        local diffa2 = 90 + (sign > 0 and -30 or 30)

        local torsoright = angs.y + 120 * sign

        Joint0:RotateAroundAxis(Joint0:Forward(), diffa2)
        Joint0:RotateAroundAxis(axis, angle3 - torsoright)
        local ang1 = -(-Joint0)

        local Joint0 = Joint0:Forward() * length0

        local Joint1 = Angle(angle0 + angle2 + 180 + angle1, angle3, 0)
        Joint1:RotateAroundAxis(Joint1:Forward(), diffa2)
        Joint1:RotateAroundAxis(axis, angle3 - torsoright)
        local ang2 = -(-Joint1)

        local Joint1 = Joint1:Forward() * length1

        local Joint0_F = start_p + Joint0
        local Joint1_F = Joint0_F + Joint1

        return Joint0_F, Joint1_F, ang1, ang2
    end

    function meta:GetHoldtypeOffset()
        local wpn = self:GetActiveWeapon()
        local ht = "default"

        if IsValid(wpn) and (wpn.IsTFAWeapon and (wpn.Base == "tfa_melee_base" or wpn.Base == "tfa_nmrimelee_base") or wpn:GetClass() == "mur_hands" and wpn:GetHoldType() == "fist") then
            ht = "melee"
            wpn:SetHoldType("revolver")
        end

        if IsValid(wpn) then
            local posOverride = wpn.TPIKPos
            local angOverride = wpn.TPIKAng
            if posOverride or angOverride then
                return posOverride or Vector(0, 0, 0), angOverride or Angle(0, 0, 0)
            end
        end

        if IsValid(wpn) and wpn.GetHoldType then
            local ok, res = pcall(function() return wpn:GetHoldType() end)
            if ok and isstring(res) and res ~= "" then
                ht = string.lower(res)
            end
        end

        local cfg = HoldtypeOffsets[ht] or HoldtypeOffsets.default
        return cfg.pos, cfg.ang
    end

    function meta:CreateFakeWorldModel(wpn)
        if IsValid(self.FakeWorldModel) then
            return self.FakeWorldModel
        end

        local vm = self:GetViewModel()
        if !IsValid(vm) then return end

        local model = ClientsideModel(vm:GetModel())
        model:SetParent(self)
        model:SetNoDraw(true)
        model.VElementsFWM = {}
        self.FakeWorldModel = model

        if istable(wpn.VElements) then
            for k, v in pairs(wpn.VElements) do
                if v.type != "Model" or v.size:Length() < 0.2 then continue end
                local att = ClientsideModel(v.model)
                att:SetParent(model)
                att:SetNoDraw(true)
                att:SetPos(model:GetPos())
                att:SetAngles(model:GetAngles())
                if v.bonemerge then
                    att:AddEffects(EF_BONEMERGE)
                    att:AddEffects(EF_BONEMERGE_FASTCULL)
                end
                att.Data = {bone = v.bone, pos = v.pos, angle = v.angle, size = v.size, color = v.color, material = v.material, skin = v.skin, bonemerge = v.bonemerge}

                table.insert(model.VElementsFWM, att)
            end
        end

        ApplyFWMBoneMods(model, wpn)

        local wpn = self:GetActiveWeapon()
        if IsValid(wpn) and isstring(wpn.UseBonemergeHands) and wpn.UseBonemergeHands ~= "" then
            SafeRemoveEntity(self.FWMHands)
            local hands = ClientsideModel(wpn.UseBonemergeHands)
            if IsValid(hands) then
                hands:SetNoDraw(true)
                hands:SetParent(model)
                if hands.AddEffects and EF_BONEMERGE then
                    hands:AddEffects(EF_BONEMERGE)
                    hands:AddEffects(EF_BONEMERGE_FASTCULL)
                end
                self.FWMHands = hands
            end
        end

        return model
    end

    function meta:GetFWM(isbool)
        return !isbool and self.FakeWorldModel or IsValid(self.FakeWorldModel)
    end

    function meta:UpdateBoneListWM()
        if not self.FWMBones then
            self.FWMBones = {}
        end
        self.FWMBones["spine4"] = self:LookupBone("ValveBiped.Bip01_Spine4")
    end

    function meta:UpdateFakeWorldModel()
        if !self:GetFWM(true) or !istable(self.FWMBones) then return end

        local fwm = self:GetFWM()
        local vm = self:GetViewModel()
        local pos = self:GetBonePosition(self.FWMBones["spine4"])
        local ang = self:GetAimVector():Angle()
        local oPos, oAng = self:GetHoldtypeOffset()
        local off = LocalToWorld(oPos or Vector(4, -4, 4), oAng or Angle(0, 0, 0), pos, ang)

        if fwm:GetModel() ~= vm:GetModel() then
            fwm:SetModel(vm:GetModel())
            ApplyFWMBoneMods(fwm, self:GetActiveWeapon())
        end
        fwm:SetPos(off)
        fwm:SetAngles(ang)
        fwm:SetSkin(vm:GetSkin())
        if fwm.GetNumBodyGroups and vm.GetNumBodyGroups then
            local cnt = math.min(vm:GetNumBodyGroups(), fwm:GetNumBodyGroups())
            for i = 0, cnt - 1 do
                local bg = vm:GetBodygroup(i)
                if isnumber(bg) then fwm:SetBodygroup(i, bg) end
            end
        end
        fwm:SetSequence(vm:GetSequence())
        fwm:SetCycle(vm:GetCycle())
        fwm:SetPlaybackRate(vm:GetPlaybackRate())
        fwm:InvalidateBoneCache()
        fwm:SetupBones()
        for k, v in ipairs(fwm.VElementsFWM) do
            local t = v.Data
            if !t.bonemerge then
                local bone = fwm:LookupBone(t.bone)
                if bone then
                    local m = fwm:GetBoneMatrix(bone)
                    if !m then continue end
                    local pos, ang = m:GetTranslation(), m:GetAngles()
                    v:SetPos(pos + ang:Forward() * t.pos.x + ang:Right() * t.pos.y + ang:Up() * t.pos.z)
                    ang:RotateAroundAxis(ang:Up(), t.angle.y)
                    ang:RotateAroundAxis(ang:Right(), t.angle.p)
                    ang:RotateAroundAxis(ang:Forward(), t.angle.r)
                    v:SetAngles(ang)
                    local matrix = Matrix()
                    matrix:Scale(t.size)
                    v:EnableMatrix("RenderMultiply", matrix)
                end
            end

			if t.material == "" then
				v:SetMaterial("")
			elseif v:GetMaterial() ~= t.material then
				v:SetMaterial(t.material)
			end

			if t.skin and t.skin ~= v:GetSkin() then
				v:SetSkin(t.skin)
			end

            v:DrawModel()
        end
    end

    function meta:UpdateFWMConnection()
        if !self:GetFWM(true) or !istable(self.FWMBones) then return end

        local wm = self:GetFWM()
        local wmSrc = IsValid(self.FWMHands) and self.FWMHands or wm
        wmSrc:SetupBones()
        self:SetupBones()
        if IsValid(self.FWMHands) then
            self.FWMHands:SetPos(wm:GetPos())
            self.FWMHands:SetAngles(wm:GetAngles())
        end

        local disableTPIK = false
        if not disableTPIK then
            local wm = wmSrc
            local ply_spine_index = self:LookupBone("ValveBiped.Bip01_Spine4")
            if !ply_spine_index then return end
            local ply_spine_matrix = self:GetBoneMatrix(ply_spine_index)
            local wmpos = ply_spine_matrix:GetTranslation()
            local eyeahg = self:EyeAngles()
            local wpn = self:GetActiveWeapon()
            if not IsValid(wpn) then return end
            local htype = wpn:GetHoldType()

            if htype == "passive" or htype == "normal" then
                eyeahg.y = eyeahg.y - (self:GetPoseParameter("aim_yaw") or 0) * 160 + 80 or 0
            end

            local function get_target(bone)
                local wm_boneindex = wm:LookupBone(bone)
                if !wm_boneindex then return end
                local wm_bonematrix = wm:GetBoneMatrix(wm_boneindex)
                if !wm_bonematrix then return end

                local bonepos = wm_bonematrix:GetTranslation()
                local boneang = wm_bonematrix:GetAngles()

                bonepos.x = math.Clamp(bonepos.x, wmpos.x - 38, wmpos.x + 38)
                bonepos.y = math.Clamp(bonepos.y, wmpos.y - 38, wmpos.y + 38)
                bonepos.z = math.Clamp(bonepos.z, wmpos.z - 38, wmpos.z + 38)

                return bonepos, boneang
            end

            local ply_r_upperarm_index = self:LookupBone("ValveBiped.Bip01_R_UpperArm")
            local ply_r_forearm_index = self:LookupBone("ValveBiped.Bip01_R_Forearm")
            local ply_r_hand_index = self:LookupBone("ValveBiped.Bip01_R_Hand")
            if !ply_r_upperarm_index or !ply_r_forearm_index or !ply_r_hand_index then return end

            local ply_l_upperarm_index = self:LookupBone("ValveBiped.Bip01_L_UpperArm")
            local ply_l_forearm_index = self:LookupBone("ValveBiped.Bip01_L_Forearm")
            local ply_l_hand_index = self:LookupBone("ValveBiped.Bip01_L_Hand")
            if !ply_l_upperarm_index or !ply_l_forearm_index or !ply_l_hand_index then return end

            local limblength = self:BoneLength(ply_l_forearm_index)
            if !limblength or limblength == 0 then limblength = 12 end
            local r_upperarm_length = limblength
            local r_forearm_length = limblength
            local l_upperarm_length = limblength
            local l_forearm_length = limblength

            local ply_r_upperarm_matrix = self:GetBoneMatrix(ply_r_upperarm_index)
            local ply_r_forearm_matrix = self:GetBoneMatrix(ply_r_forearm_index)
            local ply_r_hand_matrix = self:GetBoneMatrix(ply_r_hand_index)
            local r_target_pos, r_target_ang = get_target("ValveBiped.Bip01_R_Hand")
            if not r_target_pos then
                r_target_pos = ply_r_hand_matrix:GetTranslation()
            end
            if not r_target_ang then
                r_target_ang = ply_r_hand_matrix:GetAngles()
            end
            local ply_r_upperarm_pos, ply_r_forearm_pos, ply_r_upperarm_angle, ply_r_forearm_angle = self:Solve2PartIK(ply_r_upperarm_matrix:GetTranslation(), r_target_pos, r_upperarm_length, r_forearm_length, -1.3, eyeahg)

            ply_r_upperarm_matrix:SetAngles(ply_r_upperarm_angle)
            ply_r_forearm_matrix:SetTranslation(ply_r_upperarm_pos)
            ply_r_forearm_matrix:SetAngles(ply_r_forearm_angle)
            ply_r_hand_matrix:SetTranslation(ply_r_forearm_pos)
            ply_r_hand_matrix:SetAngles(r_target_ang)

            bone_apply_matrix(self, ply_r_upperarm_index, ply_r_upperarm_matrix, ply_r_forearm_index)
            bone_apply_matrix(self, ply_r_forearm_index, ply_r_forearm_matrix, ply_r_hand_index)
            bone_apply_matrix(self, ply_r_hand_index, ply_r_hand_matrix)

            if not wpn.TPIK_DisableLeftHand then
                local ply_l_upperarm_matrix = self:GetBoneMatrix(ply_l_upperarm_index)
                local ply_l_forearm_matrix = self:GetBoneMatrix(ply_l_forearm_index)
                local ply_l_hand_matrix = self:GetBoneMatrix(ply_l_hand_index)
                local l_target_pos, l_target_ang = get_target("ValveBiped.Bip01_L_Hand")
                if not l_target_pos then
                    l_target_pos = ply_l_hand_matrix:GetTranslation()
                end
                if not l_target_ang then
                    l_target_ang = ply_l_hand_matrix:GetAngles()
                end
                local ply_l_upperarm_pos, ply_l_forearm_pos, ply_l_upperarm_angle, ply_l_forearm_angle = self:Solve2PartIK(ply_l_upperarm_matrix:GetTranslation(), l_target_pos, l_upperarm_length, l_forearm_length, 1, eyeahg)

                ply_l_upperarm_matrix:SetAngles(ply_l_upperarm_angle)
                ply_l_forearm_matrix:SetTranslation(ply_l_upperarm_pos)
                ply_l_forearm_matrix:SetAngles(ply_l_forearm_angle)
                ply_l_hand_matrix:SetTranslation(ply_l_forearm_pos)
                ply_l_hand_matrix:SetAngles(l_target_ang)

                bone_apply_matrix(self, ply_l_upperarm_index, ply_l_upperarm_matrix, ply_l_forearm_index)
                bone_apply_matrix(self, ply_l_forearm_index, ply_l_forearm_matrix, ply_l_hand_index)
                bone_apply_matrix(self, ply_l_hand_index, ply_l_hand_matrix)
            end

            local wm = wm
            if IsValid(wm:GetParent()) and wm:GetParent() != self then
                wm = wm:GetParent()
            end

            local muz = LookupMuzzle(wm)
            if muz >= 0 then
                local att = wm:GetAttachment(muz)
                if istable(att) then
                    local muzbone = wm:GetBoneMatrix(att.Bone)
                    wm.MuzzleTPIKData = {
                        pos = muzbone:GetTranslation(),
                        ang = att.Ang or self:EyeAngles(),
                        att = muz
                    }
                end
            end
            self:TPIK_UpdateHeadAndEye()
        end

        wm:DrawModel()
    end

    function meta:TPIK_DoMuzzleFlash()
        if self.LastTPIKFlash and CurTime() - self.LastTPIKFlash < 0.05 then return end
        self.LastTPIKFlash = CurTime()

        local fwm = self:GetFWM()
        if not IsValid(fwm) and self.GetRagFWM then
            fwm = self:GetRagFWM()
        end
        if not IsValid(fwm) then return end

        fwm:SetupBones()
        local effectdata = EffectData()

        if istable(fwm.MuzzleTPIKData) then
            local pos, ang, att = fwm.MuzzleTPIKData.pos, fwm.MuzzleTPIKData.ang, fwm.MuzzleTPIKData.att
            effectdata:SetOrigin(pos)
            effectdata:SetAngles(ang)
            effectdata:SetNormal(ang:Forward())
            effectdata:SetEntity(fwm)
            effectdata:SetAttachment(att)
            effectdata:SetScale(1)
            local wpn = self:GetActiveWeapon()
            local eff = "MuzzleFlash"
            if IsValid(wpn) and wpn.MuzzleFlashEffect then
                eff = wpn.MuzzleFlashEffect
            end
            util.Effect(eff, effectdata)
        end
    end

    function meta:RemoveFWM()
        SafeRemoveEntity(self.FWMHands)
        SafeRemoveEntity(self:GetFWM())
        self.LastFWMwpn = nil
        local wpn = self:GetActiveWeapon()
        if IsValid(wpn) then
            wepstate(true, wpn)
        end
        if CLIENT then
            self._TPIK_AimFrac = 0
            self._TPIK_HeadTilt = 0
            if self.TPIK_ResetEyeFlex then
                self:TPIK_ResetEyeFlex(true)
            end
        end
    end

    function meta:DoFWM(wpn)
        if IsValid(self.LastFWMwpn) and self.LastFWMwpn != wpn then
            self:RemoveFWM()
            return
        end
        self.LastFWMwpn = wpn
        self:CreateFakeWorldModel(wpn)
        if !self:GetFWM(true) then return end
        if IsValid(wpn) then
            local bool = self == LocalPlayer() and !LocalPlayer():ShouldDrawLocalPlayer()
            wepstate(bool, wpn)
        end
        self:UpdateBoneListWM()
        self:UpdateFakeWorldModel()
        self:UpdateFWMConnection()
        self:AnimSetGestureWeight(0, 0)
    end

    function meta:ShouldFWM(wpn)
        local isHostage = self.IsInHostage and self:IsInHostage(true) or false
        return MuR:GetClient("blsd_tpik") and not isHostage and (wpn and (wpn.IsTFAWeapon or wpn.TPIKForce) and not wpn.TPIKDisabled and not TPIKDisableHoldtypes[wpn:GetHoldType()]) and (self:Alive() and not self:GetNoDraw() and self:GetSVAnim() == "") and (self:GetActiveWeapon() ~= wpn and EyePos():DistToSqr(wpn:GetPos()) < 1000000 or self:GetActiveWeapon() == wpn)
    end

    hook.Add("PrePlayerDraw", "UpdateFakeWorldModel", function(ply)
        local wpn = ply:GetActiveWeapon()
        if ply:ShouldFWM(wpn) then
            ply:DoFWM(wpn)
        else
            ply:RemoveFWM()
        end
    end)

    local cached_children = {}
    local function recursive_get_children(ent, bone, bones, endbone)
        local bone = isstring(bone) and ent:LookupBone(bone) or bone
        if not bone or isstring(bone) or bone == -1 then return end

        local children = ent:GetChildBones(bone)
        if #children > 0 then
            local id
            for i = 1,#children do
                id = children[i]
                if id == endbone then continue end
                recursive_get_children(ent, id, bones, endbone)
                table.insert(bones, id)
            end
        end
    end

    local function get_children(ent, bone, endbone)
        local bones = {}
        local mdl = ent:GetModel()
        if cached_children[mdl] and cached_children[mdl][bone] then return cached_children[mdl][bone] end
        recursive_get_children(ent, bone, bones, endbone)
        cached_children[mdl] = cached_children[mdl] or {}
        cached_children[mdl][bone] = bones
        return bones
    end

    local function bone_apply_matrix(ent, bone, new_matrix, endbone)
        local bone = isstring(bone) and ent:LookupBone(bone) or bone
        if not bone or isstring(bone) or bone == -1 then return end
        local matrix = ent:GetBoneMatrix(bone)
        if not matrix then return end
        local inv_matrix = matrix:GetInverse()
        if not inv_matrix then return end
        local children = get_children(ent, bone, endbone)
        local id
        for i = 1,#children do
            id = children[i]
            local mat = ent:GetBoneMatrix(id)
            if not mat then continue end
            ent:SetBoneMatrix(id, new_matrix * (inv_matrix * mat))
        end
        ent:SetBoneMatrix(bone, new_matrix)
    end

    function meta:BoneLength(bone)
        local p = self:GetBonePosition(bone)
        local c = self:GetChildBones(bone)[1]
        if not c then return 0 end
        local cp = self:GetBonePosition(c)
        return p:Distance(cp)
    end

    local vector_up = Vector(0,0,1)

    function meta:Solve2PartIK(start_p, end_p, length0, length1, sign, angs)
        local length2 = (start_p - end_p):Length()
        local cosAngle0 = math.Clamp(((length2 * length2) + (length0 * length0) - (length1 * length1)) / (2 * length2 * length0), -1, 1)
        local angle0 = -math.deg(math.acos(cosAngle0))
        local cosAngle1 = math.Clamp(((length1 * length1) + (length0 * length0) - (length2 * length2)) / (2 * length1 * length0), -1, 1)
        local angle1 = -math.deg(math.acos(cosAngle1))

        local diff = end_p - start_p
        diff:Normalize()

        local angle2 = math.deg(math.atan2(-math.sqrt(diff.x * diff.x + diff.y * diff.y), diff.z)) - 90
        local angle3 = -math.deg(math.atan2(diff.x, diff.y)) - 90
        angle3 = math.NormalizeAngle(angle3)

        local diff2 = -vector_up:Angle()

        local axis = diff * 1
        axis:Normalize()

        local torsoang = vector_up:Angle()

        local Joint0 = Angle(angle0 + angle2, angle3, 0)

        local asdot = -vector_up:Dot(torsoang:Up())
        local diffa = math.deg(math.acos(asdot)) + (sign < 0 and -0 or 0)
        local diffa2 = 90 + (sign > 0 and -30 or 30)

        local tors = torsoang:Up()
        local torsoright = -math.deg(math.atan2(tors.x, tors.y)) - 120 - 60 * sign
        torsoright = angs.y + 120 * sign

        Joint0:RotateAroundAxis(Joint0:Forward(), diffa2)
        Joint0:RotateAroundAxis(axis, angle3 - torsoright)
        local ang1 = -(-Joint0)

        local Joint0 = Joint0:Forward() * length0

        local Joint1 = Angle(angle0 + angle2 + 180 + angle1, angle3, 0)
        Joint1:RotateAroundAxis(Joint1:Forward(), diffa2)
        Joint1:RotateAroundAxis(axis, angle3 - torsoright)
        local ang2 = -(-Joint1)

        local Joint1 = Joint1:Forward() * length1

        local Joint0_F = start_p + Joint0
        local Joint1_F = Joint0_F + Joint1

        return Joint0_F, Joint1_F, ang1, ang2
    end

    function meta:IsRagdollMissingHand(rag)
        if not IsValid(rag) then return false end
        local l_hand = rag:LookupBone("ValveBiped.Bip01_L_Hand")
        local r_hand = rag:LookupBone("ValveBiped.Bip01_R_Hand")
        if l_hand and MuR.IsBoneScaleHidden(rag:GetManipulateBoneScale(l_hand)) then return true end
        if r_hand and MuR.IsBoneScaleHidden(rag:GetManipulateBoneScale(r_hand)) then return true end
        return false
    end

    function meta:ShouldRagdollTPIK(rag, wpn)
        if not MuR:GetClient("blsd_tpik") then return false end
        if not IsValid(rag) or not IsValid(wpn) then return false end
        if not (wpn.IsTFAWeapon or wpn.TPIKForce) then return false end
        if wpn.TPIKDisabled or TPIKDisableHoldtypes[wpn:GetHoldType()] then return false end
        if not self:Alive() then return false end
        if self:GetNW2Bool("IsUnconscious", false) then return false end
        if self:IsRagdollMissingHand(rag) then return false end
        return true
    end

    function meta:GetRagdollTPIKFrac()
        self._RagTPIKFrac = self._RagTPIKFrac or 0
        return self._RagTPIKFrac
    end

    function meta:SetRagdollTPIKFrac(val)
        self._RagTPIKFrac = val
    end

    function meta:DoRagdollFWM(rag, wpn)
        local shouldDo = self:ShouldRagdollTPIK(rag, wpn)
        local targetFrac = shouldDo and 1 or 0
        local currentFrac = self:GetRagdollTPIKFrac()
        local newFrac = math.Approach(currentFrac, targetFrac, FrameTime() * 4)
        self:SetRagdollTPIKFrac(newFrac)

        if newFrac < 0.01 then
            self:RemoveRagdollFWM(rag)
            return
        end

        local vm = self:GetViewModel()
        local wpnClass = IsValid(wpn) and wpn:GetClass() or nil

        if self._LastRagFWMEnt and self._LastRagFWMEnt ~= rag then
            self:RemoveRagdollFWM(rag)
        end
        self._LastRagFWMEnt = rag

        if self._LastRagFWMwpnClass and wpnClass and self._LastRagFWMwpnClass ~= wpnClass then
            self:RemoveRagdollFWM(rag)
        end

        if IsValid(self.RagFakeWorldModel) and IsValid(vm) and self.RagFakeWorldModel:GetModel() ~= vm:GetModel() then
            self:RemoveRagdollFWM(rag)
        end

        if self.LastRagFWMwpn ~= wpn then
            self:RemoveRagdollFWM(rag)
        end

        self.LastRagFWMwpn = wpn
        self._LastRagFWMwpnClass = wpnClass

        self:CreateRagdollFakeWorldModel(rag, wpn)
        if not self:GetRagFWM(true) then return end

        if IsValid(wpn) then
            local bool = self == LocalPlayer() and not LocalPlayer():ShouldDrawLocalPlayer()
            wepstate(bool, wpn)
        end

        self:UpdateRagdollBoneListWM(rag)
        self:UpdateRagdollFakeWorldModel(rag, wpn)
        self:UpdateRagdollFWMConnection(rag, newFrac)
    end

    function meta:CreateRagdollFakeWorldModel(rag, wpn)
        if IsValid(self.RagFakeWorldModel) then
            return self.RagFakeWorldModel
        end

        local vm = self:GetViewModel()
        if not IsValid(vm) then return end

        local model = ClientsideModel(vm:GetModel())
        model:SetParent(rag)
        model:SetNoDraw(true)
        model.VElementsFWM = {}
        self.RagFakeWorldModel = model

        if istable(wpn.VElements) then
            for k, v in pairs(wpn.VElements) do
                if v.type ~= "Model" or v.size:Length() < 0.2 then continue end
                local att = ClientsideModel(v.model)
                att:SetParent(model)
                att:SetNoDraw(true)
                att:SetPos(model:GetPos())
                att:SetAngles(model:GetAngles())
                if v.bonemerge then
                    att:AddEffects(EF_BONEMERGE)
                    att:AddEffects(EF_BONEMERGE_FASTCULL)
                end
                att.Data = {bone = v.bone, pos = v.pos, angle = v.angle, size = v.size, color = v.color, material = v.material, skin = v.skin, bonemerge = v.bonemerge}
                table.insert(model.VElementsFWM, att)
            end
        end

        ApplyFWMBoneMods(model, wpn)

        if IsValid(wpn) and isstring(wpn.UseBonemergeHands) and wpn.UseBonemergeHands ~= "" then
            SafeRemoveEntity(self.RagFWMHands)
            local hands = ClientsideModel(wpn.UseBonemergeHands)
            if IsValid(hands) then
                hands:SetNoDraw(true)
                hands:SetParent(model)
                if hands.AddEffects and EF_BONEMERGE then
                    hands:AddEffects(EF_BONEMERGE)
                    hands:AddEffects(EF_BONEMERGE_FASTCULL)
                end
                self.RagFWMHands = hands
            end
        end

        return model
    end

    function meta:GetRagFWM(isbool)
        return not isbool and self.RagFakeWorldModel or IsValid(self.RagFakeWorldModel)
    end

    function meta:RemoveRagdollFWM(rag)
        SafeRemoveEntity(self.RagFWMHands)
        SafeRemoveEntity(self:GetRagFWM())
        self.RagFakeWorldModel = nil
        self.LastRagFWMwpn = nil
        self._LastRagFWMwpnClass = nil
        self._LastRagFWMEnt = nil
        self._RagTPIKFrac = 0
        local wpn = self:GetActiveWeapon()
        if IsValid(wpn) then
            wepstate(true, wpn)
        end
    end

    function meta:UpdateRagdollBoneListWM(rag)
        if not self.RagFWMBones then
            self.RagFWMBones = {}
        end
        self.RagFWMBones["spine4"] = rag:LookupBone("ValveBiped.Bip01_Spine4")
    end

    function meta:UpdateRagdollFakeWorldModel(rag, wpn)
        if not self:GetRagFWM(true) or not istable(self.RagFWMBones) then return end

        local fwm = self:GetRagFWM()
        local vm = self:GetViewModel()
        if IsValid(self:GetNW2Entity("FWM_Proxy")) then
            vm = self:GetNW2Entity("FWM_Proxy")
        end
        if not IsValid(vm) then return end

        local pos = rag:GetBonePosition(self.RagFWMBones["spine4"])
        if not pos then return end
        local ang = self:GetAimVector():Angle()
        ang.z = GetZAng(rag)
        local oPos, oAng = self:GetHoldtypeOffset()
        local off = LocalToWorld((oPos or Vector(4, -4, 4)) + RagdollTPIKOffset, (oAng or Angle(0, 0, 0)) + RagdollTPIKAngle, pos, ang)

        if fwm:GetModel() ~= vm:GetModel() then
            fwm:SetModel(vm:GetModel())
            ApplyFWMBoneMods(fwm, wpn)
        end
        fwm:SetPos(off)
        fwm:SetAngles(ang)
        fwm:SetSkin(vm:GetSkin())
        if fwm.GetNumBodyGroups and vm.GetNumBodyGroups then
            local cnt = math.min(vm:GetNumBodyGroups(), fwm:GetNumBodyGroups())
            for i = 0, cnt - 1 do
                local bg = vm:GetBodygroup(i)
                if isnumber(bg) then fwm:SetBodygroup(i, bg) end
            end
        end
        fwm:SetSequence(vm:GetSequence())
        fwm:SetCycle(vm:GetCycle())
        fwm:SetPlaybackRate(vm:GetPlaybackRate())
        fwm:InvalidateBoneCache()
        fwm:SetupBones()

        if IsValid(self.RagFWMHands) then
            self.RagFWMHands:SetPos(fwm:GetPos())
            self.RagFWMHands:SetAngles(fwm:GetAngles())
            self.RagFWMHands:InvalidateBoneCache()
            self.RagFWMHands:SetupBones()
        end

        fwm:DrawModel()

        for k, v in ipairs(fwm.VElementsFWM) do
            local t = v.Data
            if not t.bonemerge then
                local bone = fwm:LookupBone(t.bone)
                if bone then
                    local m = fwm:GetBoneMatrix(bone)
                    if not m then continue end
                    local bpos, bang = m:GetTranslation(), m:GetAngles()
                    v:SetPos(bpos + bang:Forward() * t.pos.x + bang:Right() * t.pos.y + bang:Up() * t.pos.z)
                    bang:RotateAroundAxis(bang:Up(), t.angle.y)
                    bang:RotateAroundAxis(bang:Right(), t.angle.p)
                    bang:RotateAroundAxis(bang:Forward(), t.angle.r)
                    v:SetAngles(bang)
                    local matrix = Matrix()
                    matrix:Scale(t.size)
                    v:EnableMatrix("RenderMultiply", matrix)
                end
            end
            if t.material == "" then
                v:SetMaterial("")
            elseif v:GetMaterial() ~= t.material then
                v:SetMaterial(t.material)
            end
            if t.skin and t.skin ~= v:GetSkin() then
                v:SetSkin(t.skin)
            end
            v:DrawModel()
        end

        if IsValid(self.RagFWMHands) then
            self.RagFWMHands:DrawModel()
        end

        local muz = LookupMuzzle(fwm)
        if muz >= 0 then
            local att = fwm:GetAttachment(muz)
            if istable(att) and att.Bone then
                local muzbone = fwm:GetBoneMatrix(att.Bone)
                if muzbone then
                    fwm.MuzzleTPIKData = {
                        pos = muzbone:GetTranslation(),
                        ang = att.Ang or self:EyeAngles(),
                        att = muz
                    }
                end
            end
        end
    end

    function meta:UpdateRagdollFWMConnection(rag, frac)
        if not self:GetRagFWM(true) or not istable(self.RagFWMBones) then return end

        local wm = self:GetRagFWM()
        local wmSrc = IsValid(self.RagFWMHands) and self.RagFWMHands or wm
        wmSrc:SetupBones()
        rag:SetupBones()

        local wm_r_hand_check = wmSrc:LookupBone("ValveBiped.Bip01_R_Hand")
        local wm_l_hand_check = wmSrc:LookupBone("ValveBiped.Bip01_L_Hand")
        if not wm_r_hand_check and not wm_l_hand_check then

            return
        end

        local ply_spine_index = rag:LookupBone("ValveBiped.Bip01_Spine4")
        if not ply_spine_index then return end
        local ply_spine_matrix = rag:GetBoneMatrix(ply_spine_index)
        if not ply_spine_matrix then return end
        local wmpos = ply_spine_matrix:GetTranslation()
        local eyeang = self:EyeAngles()
        eyeang.z = GetZAng(rag)
        local wpn = self:GetActiveWeapon()
        if not IsValid(wpn) then return end
        local htype = wpn:GetHoldType()

        if htype == "passive" or htype == "normal" then
            eyeang.y = eyeang.y - (self:GetPoseParameter("aim_yaw") or 0) * 160 + 80 or 0
        end

        local function get_target(bone)
            local wm_boneindex = wmSrc:LookupBone(bone)
            if not wm_boneindex then return end
            local wm_bonematrix = wmSrc:GetBoneMatrix(wm_boneindex)
            if not wm_bonematrix then return end

            local bonepos = wm_bonematrix:GetTranslation()
            local boneang = wm_bonematrix:GetAngles()

            bonepos.x = math.Clamp(bonepos.x, wmpos.x - 38, wmpos.x + 38)
            bonepos.y = math.Clamp(bonepos.y, wmpos.y - 38, wmpos.y + 38)
            bonepos.z = math.Clamp(bonepos.z, wmpos.z - 38, wmpos.z + 38)

            return bonepos, boneang
        end

        local function apply_fingers(side_prefix, skip)
            if skip then return end
            for _, bone in ipairs(TPIKBonesBase) do
                if not string.find(bone, side_prefix) then continue end
                if not string.find(bone, "Finger") then continue end

                local wm_boneindex = wmSrc:LookupBone(bone)
                if not wm_boneindex then continue end
                local wm_bonematrix = wmSrc:GetBoneMatrix(wm_boneindex)
                if not wm_bonematrix then continue end

                local rag_boneindex = rag:LookupBone(bone)
                if not rag_boneindex then continue end
                local rag_bonematrix = rag:GetBoneMatrix(rag_boneindex)
                if not rag_bonematrix then continue end

                local bonepos = wm_bonematrix:GetTranslation()
                local boneang = wm_bonematrix:GetAngles()

                bonepos.x = math.Clamp(bonepos.x, wmpos.x - 38, wmpos.x + 38)
                bonepos.y = math.Clamp(bonepos.y, wmpos.y - 38, wmpos.y + 38)
                bonepos.z = math.Clamp(bonepos.z, wmpos.z - 38, wmpos.z + 38)

                local origPos = rag_bonematrix:GetTranslation()
                local origAng = rag_bonematrix:GetAngles()
                rag_bonematrix:SetTranslation(LerpVector(frac, origPos, bonepos))
                rag_bonematrix:SetAngles(LerpAngle(frac, origAng, boneang))

                rag:SetBoneMatrix(rag_boneindex, rag_bonematrix)
            end
        end

        local rag_r_upperarm_index = rag:LookupBone("ValveBiped.Bip01_R_UpperArm")
        local rag_r_forearm_index = rag:LookupBone("ValveBiped.Bip01_R_Forearm")
        local rag_r_hand_index = rag:LookupBone("ValveBiped.Bip01_R_Hand")

        local wm_r_hand_index = wmSrc:LookupBone("ValveBiped.Bip01_R_Hand")
        local wm_r_hand_matrix = wm_r_hand_index and wmSrc:GetBoneMatrix(wm_r_hand_index)

        if not rag_r_upperarm_index or not rag_r_forearm_index or not rag_r_hand_index or not wm_r_hand_matrix then return end

        local rag_l_upperarm_index = rag:LookupBone("ValveBiped.Bip01_L_UpperArm")
        local rag_l_forearm_index = rag:LookupBone("ValveBiped.Bip01_L_Forearm")
        local rag_l_hand_index = rag:LookupBone("ValveBiped.Bip01_L_Hand")

        local wm_l_hand_index = wmSrc:LookupBone("ValveBiped.Bip01_L_Hand")
        local wm_l_hand_matrix = wm_l_hand_index and wmSrc:GetBoneMatrix(wm_l_hand_index)

        if not rag_l_upperarm_index or not rag_l_forearm_index or not rag_l_hand_index then return end
        if (not wm_l_hand_matrix) and not (rag:GetNW2Bool("LeftHandHoldsObject", false) or wpn.TPIK_DisableLeftHand) then return end

        local limblength = self:BoneLength(rag_l_forearm_index)
        if not limblength or limblength == 0 then limblength = 12 end
        local r_upperarm_length = limblength
        local r_forearm_length = limblength
        local l_upperarm_length = limblength
        local l_forearm_length = limblength

        local rag_r_upperarm_matrix = rag:GetBoneMatrix(rag_r_upperarm_index)
        local rag_r_forearm_matrix = rag:GetBoneMatrix(rag_r_forearm_index)
        local rag_r_hand_matrix = rag:GetBoneMatrix(rag_r_hand_index)

        if rag_r_upperarm_matrix and rag_r_forearm_matrix and rag_r_hand_matrix then
            local target_r_pos, target_r_ang = get_target("ValveBiped.Bip01_R_Hand")
            if not target_r_pos then
                target_r_pos = wm_r_hand_matrix:GetTranslation()
            end
            if not target_r_ang then
                target_r_ang = wm_r_hand_matrix:GetAngles()
            end

            local rag_r_upperarm_pos, rag_r_forearm_pos, rag_r_upperarm_angle, rag_r_forearm_angle = self:Solve2PartIK(rag_r_upperarm_matrix:GetTranslation(), target_r_pos, r_upperarm_length, r_forearm_length, -1.1, eyeang)

            local orig_r_upper_ang = rag_r_upperarm_matrix:GetAngles()
            local orig_r_fore_pos = rag_r_forearm_matrix:GetTranslation()
            local orig_r_fore_ang = rag_r_forearm_matrix:GetAngles()
            local orig_r_hand_pos = rag_r_hand_matrix:GetTranslation()
            local orig_r_hand_ang = rag_r_hand_matrix:GetAngles()

            rag_r_upperarm_matrix:SetAngles(LerpAngle(frac, orig_r_upper_ang, rag_r_upperarm_angle))
            rag_r_forearm_matrix:SetTranslation(LerpVector(frac, orig_r_fore_pos, rag_r_upperarm_pos))
            rag_r_forearm_matrix:SetAngles(LerpAngle(frac, orig_r_fore_ang, rag_r_forearm_angle))

            rag_r_hand_matrix:SetTranslation(LerpVector(frac, orig_r_hand_pos, target_r_pos))
            rag_r_hand_matrix:SetAngles(LerpAngle(frac, orig_r_hand_ang, target_r_ang))

            bone_apply_matrix(rag, rag_r_upperarm_index, rag_r_upperarm_matrix, rag_r_forearm_index)
            bone_apply_matrix(rag, rag_r_forearm_index, rag_r_forearm_matrix, rag_r_hand_index)
            rag:SetBoneMatrix(rag_r_hand_index, rag_r_hand_matrix)

        end

        local rag_l_upperarm_matrix = rag:GetBoneMatrix(rag_l_upperarm_index)
        local rag_l_forearm_matrix = rag:GetBoneMatrix(rag_l_forearm_index)
        local rag_l_hand_matrix = rag:GetBoneMatrix(rag_l_hand_index)

        if rag_l_upperarm_matrix and rag_l_forearm_matrix and rag_l_hand_matrix and not rag:GetNW2Bool("LeftHandHoldsObject", false) and not wpn.TPIK_DisableLeftHand then
            local target_l_pos, target_l_ang = get_target("ValveBiped.Bip01_L_Hand")
            if not target_l_pos then
                target_l_pos = wm_l_hand_matrix:GetTranslation()
            end
            if not target_l_ang then
                target_l_ang = wm_l_hand_matrix:GetAngles()
            end

            local rag_l_upperarm_pos, rag_l_forearm_pos, rag_l_upperarm_angle, rag_l_forearm_angle = self:Solve2PartIK(rag_l_upperarm_matrix:GetTranslation(), target_l_pos, l_upperarm_length, l_forearm_length, 1.2, eyeang)

            local orig_l_upper_ang = rag_l_upperarm_matrix:GetAngles()
            local orig_l_fore_pos = rag_l_forearm_matrix:GetTranslation()
            local orig_l_fore_ang = rag_l_forearm_matrix:GetAngles()
            local orig_l_hand_pos = rag_l_hand_matrix:GetTranslation()
            local orig_l_hand_ang = rag_l_hand_matrix:GetAngles()

            rag_l_upperarm_matrix:SetAngles(LerpAngle(frac, orig_l_upper_ang, rag_l_upperarm_angle))
            rag_l_forearm_matrix:SetTranslation(LerpVector(frac, orig_l_fore_pos, rag_l_upperarm_pos))
            rag_l_forearm_matrix:SetAngles(LerpAngle(frac, orig_l_fore_ang, rag_l_forearm_angle))

            rag_l_hand_matrix:SetTranslation(LerpVector(frac, orig_l_hand_pos, target_l_pos))
            rag_l_hand_matrix:SetAngles(LerpAngle(frac, orig_l_hand_ang, target_l_ang))

            bone_apply_matrix(rag, rag_l_upperarm_index, rag_l_upperarm_matrix, rag_l_forearm_index)
            bone_apply_matrix(rag, rag_l_forearm_index, rag_l_forearm_matrix, rag_l_hand_index)
            rag:SetBoneMatrix(rag_l_hand_index, rag_l_hand_matrix)
        end

        apply_fingers("_R_", false)
        apply_fingers("_L_", rag:GetNW2Bool("LeftHandHoldsObject", false) or wpn.TPIK_DisableLeftHand)

        wm:DrawModel()
    end

    hook.Add("Think", "TPIK_Ragdoll_AssignRender", function()
        for _, ply in player.Iterator() do
            local rag = ply:GetNW2Entity("RD_EntCam")
            if IsValid(rag) and not rag:IsPlayer() and not rag.HasTPIKOverride then
                rag.HasTPIKOverride = true
                rag.RenderOverride = function(self)
                    if IsValid(ply) and ply:GetNW2Entity("RD_EntCam") == self then
                        local wpn = ply:GetActiveWeapon()
                        ply:DoRagdollFWM(self, wpn)
                    end

                    local wounds = self.LiteWoundsRender
                    if wounds then
                        wounds(self)
                    else
                        self:DrawModel()
                    end
                end
            end
        end
    end)

    local oldvm = meta.GetViewModel
    function meta:GetViewModel()
        if LocalPlayer() == self then
            return oldvm(self)
        else
            return self:GetNW2Entity("FWM_Proxy")
        end
    end

    function meta:TPIK_IsAiming()
        local wpn = self:GetActiveWeapon()
        if not IsValid(wpn) then return false end
        local ht = wpn.GetHoldType and wpn:GetHoldType() or ""
        if ht == "fist" or ht == "melee" or ht == "passive" or ht == "normal" then return false end
        local aiming = false
        local ok, res

        if wpn.IsTFAWeapon and wpn.GetIronSightsProgress then
            aiming = wpn:GetIronSightsProgress() > 0.5
        end

        return aiming and true or false
    end

    function meta:TPIK_InitEyeFlex()
        if self._TPIK_FlexReady then return end
        self._TPIK_FlexReady = true
        self._TPIK_LeftFlex = nil
        local flexCount = self:GetFlexNum() or 0
        for i = 0, flexCount - 1 do
            local name = self:GetFlexName(i)
            if not isstring(name) then continue end
            local lname = string.lower(name)
            if not self._TPIK_LeftFlex and (lname:find("left_lid_closer")) then
                self._TPIK_LeftFlex = i
            end
        end
    end

    function meta:TPIK_SetEyeClose(amount)
        self:TPIK_InitEyeFlex()
        amount = math.Clamp(amount or 0, 0, 1)
        if self._TPIK_LeftFlex then
            self:SetFlexWeight(self._TPIK_LeftFlex, amount)
        end
    end

    function meta:TPIK_ResetEyeFlex(hard)
        self:TPIK_InitEyeFlex()
        if self._TPIK_LeftFlex then self:SetFlexWeight(self._TPIK_LeftFlex, 0) end
    end

    function meta:TPIK_UpdateHeadAndEye()
        local ads = self:TPIK_IsAiming()
        self._TPIK_AimFrac = self._TPIK_AimFrac or 0
        local target = ads and 1 or 0
        local rate = FrameTime() * 8
        self._TPIK_AimFrac = math.Clamp(self._TPIK_AimFrac + (target - self._TPIK_AimFrac) * rate, 0, 1)
        self:TPIK_SetEyeClose(self._TPIK_AimFrac)
        local head = self:LookupBone("ValveBiped.Bip01_Head1") or self:LookupBone("ValveBiped.Bip01_Head")
        if head then
            local m = self:GetBoneMatrix(head)
            if m then
            local ang = m:GetAngles()
            ang:RotateAroundAxis(ang:Up(), -10 * self._TPIK_AimFrac)
            ang:RotateAroundAxis(ang:Right(), 20 * self._TPIK_AimFrac)
            m:SetAngles(ang)
                self:SetBoneMatrix(head, m)
            end
        end
    end

    net.Receive("TPIK_MuzzleFlash", function()
        local ply = net.ReadEntity()
        if IsValid(ply) and ply.TPIK_DoMuzzleFlash then
            local hasFWM = ply.GetFWM and ply:GetFWM(true)
            local hasRagFWM = ply.GetRagFWM and ply:GetRagFWM(true)
            if hasFWM or hasRagFWM then
                ply:TPIK_DoMuzzleFlash()
            end
        end
    end)
else
    util.AddNetworkString("TPIK_MuzzleFlash")

    hook.Add("PlayerPostThink", "SyncFWMThink", function(ply)
        local vm = ply:GetViewModel()
        if not IsValid(vm) or !isstring(vm:GetModel()) then return end

        if not IsValid(ply.VMProxy) then
            local proxy = ents.Create("mur_viewmodel")
            proxy:SetModel(vm:GetModel() or "")
            proxy:SetParent(ply)
            proxy:Spawn()
            proxy:SetNotSolid(true)
            proxy:SetRenderMode(10)

            ply.VMProxy = proxy
        end

        local proxy = ply.VMProxy
        if proxy:GetModel() ~= vm:GetModel() then
            proxy:SetModel(vm:GetModel())
        end
        if proxy:GetSequence() ~= vm:GetSequence() then
            proxy:ResetSequence(vm:GetSequence())
        end
        proxy:SetCycle(vm:GetCycle())
        proxy:SetPlaybackRate(vm:GetPlaybackRate())
        proxy:SetSkin(vm:GetSkin())
        for i = 0, vm:GetNumBodyGroups() - 1 do
            if proxy:GetBodygroup(i) ~= vm:GetBodygroup(i) then
                proxy:SetBodygroup(i, vm:GetBodygroup(i))
            end
        end

        local wpn = ply:GetActiveWeapon()
        if IsValid(wpn) and isstring(wpn.UseBonemergeHands) and wpn.UseBonemergeHands ~= "" then
            if not IsValid(proxy.Hands) or proxy.Hands:GetModel() ~= wpn.UseBonemergeHands then
                if IsValid(proxy.Hands) then proxy.Hands:Remove() end
                local hands = ents.Create("mur_viewmodel")
                hands:SetModel(wpn.UseBonemergeHands)
                hands:SetParent(proxy)
                hands:SetPos(proxy:GetPos())
                hands:SetAngles(proxy:GetAngles())
                hands:Spawn()
                hands:AddEffects(EF_BONEMERGE)
                hands:SetNotSolid(true)
                hands:SetRenderMode(10)
                proxy.Hands = hands
            end
        elseif IsValid(proxy.Hands) then
            proxy.Hands:Remove()
            proxy.Hands = nil
        end

        if ply:GetNW2Entity("FWM_Proxy") ~= proxy then
            ply:SetNW2Entity("FWM_Proxy", proxy)
        end
    end)
end
