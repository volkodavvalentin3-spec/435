MuR = MuR or {}
MuR.Armor = MuR.Armor or {}
MuR.Armor.ClientModels = MuR.Armor.ClientModels or {}

local function GetArmorModel(ent, bodypart, armorId)
    if not IsValid(ent) then return nil end
    local entIndex = ent:EntIndex()
    MuR.Armor.ClientModels[entIndex] = MuR.Armor.ClientModels[entIndex] or {}
    local key = bodypart .. "_" .. armorId
    local existing = MuR.Armor.ClientModels[entIndex][key]
    if IsValid(existing) then return existing end
    local item = MuR.Armor.GetItem(armorId)
    if not item or not item.model then return nil end
    local mdl = ClientsideModel(item.model, RENDERGROUP_OPAQUE)
    if not IsValid(mdl) then return nil end
    mdl:SetNoDraw(true)
    mdl:SetModelScale(item.scale or 1)
    MuR.Armor.ClientModels[entIndex][key] = mdl
    return mdl
end

local function CleanupArmorModels(entIndex)
    if not MuR.Armor.ClientModels[entIndex] then return end
    for key, mdl in pairs(MuR.Armor.ClientModels[entIndex]) do
        if IsValid(mdl) then mdl:Remove() end
    end
    MuR.Armor.ClientModels[entIndex] = nil
end

local function DrawArmorOnEntity(ent)
    if not IsValid(ent) then return end
    for bodypart, partData in pairs(MuR.Armor.BodyParts) do
        local armorId = ent:GetNW2String("MuR_Armor_" .. bodypart, "")
        local isActive = ent:GetNW2Bool("MuR_Armor_Active_" .. bodypart, false)
        local isHidden = ent:GetNW2Bool("MuR_Armor_Hidden_" .. bodypart, false)
        if armorId ~= "" and isActive and not isHidden then
            local item = MuR.Armor.GetItem(armorId)
            if item then
                local mdl = GetArmorModel(ent, bodypart, armorId)
                if IsValid(mdl) then
                    local boneId = ent:LookupBone(partData.bone)
                    if boneId then
                        local boneScale = ent:GetManipulateBoneScale(boneId)
                        if MuR.IsBoneScaleHidden(boneScale) then continue end

                        local bonePos, boneAng
                        if ent:IsRagdoll() then
                            bonePos, boneAng = ent:GetBonePosition(boneId)
                        else
                            local mtx = ent:GetBoneMatrix(boneId)
                            if mtx then
                                bonePos = mtx:GetTranslation()
                                boneAng = mtx:GetAngles()
                            end
                        end

                        if bonePos and boneAng then
                            local offset = item.pos_offset or Vector(0, 0, 0)
                            local angOffset = item.ang_offset or Angle(0, 0, 0)
                            local pos = bonePos + boneAng:Forward() * offset.x + boneAng:Right() * offset.y + boneAng:Up() * offset.z
                            boneAng:RotateAroundAxis(boneAng:Up(), angOffset.y)
                            boneAng:RotateAroundAxis(boneAng:Right(), angOffset.p)
                            boneAng:RotateAroundAxis(boneAng:Forward(), angOffset.r)
                            mdl:SetPos(pos)
                            mdl:SetAngles(boneAng)
                            mdl:SetupBones()
                            mdl:DrawModel()
                        end
                    end
                end
            end
        end
    end
end

local function DrawArmorOnEntitySkipHead(ent, skipHead)
    if not IsValid(ent) then return end
    for bodypart, partData in pairs(MuR.Armor.BodyParts) do
        if skipHead and (bodypart == "head" or bodypart == "face") then continue end
        local armorId = ent:GetNW2String("MuR_Armor_" .. bodypart, "")
        local isActive = ent:GetNW2Bool("MuR_Armor_Active_" .. bodypart, false)
        local isHidden = ent:GetNW2Bool("MuR_Armor_Hidden_" .. bodypart, false)
        if armorId ~= "" and isActive and not isHidden then
            local item = MuR.Armor.GetItem(armorId)
            if item then
                local mdl = GetArmorModel(ent, bodypart, armorId)
                if IsValid(mdl) then
                    local boneId = ent:LookupBone(partData.bone)
                    if boneId then
                        local boneScale = ent:GetManipulateBoneScale(boneId)
                        if MuR.IsBoneScaleHidden(boneScale) then continue end
                        local bonePos, boneAng = ent:GetBonePosition(boneId)
                        if bonePos and boneAng then
                            local offset = item.pos_offset or Vector(0, 0, 0)
                            local angOffset = item.ang_offset or Angle(0, 0, 0)
                            local pos = bonePos + boneAng:Forward() * offset.x + boneAng:Right() * offset.y + boneAng:Up() * offset.z
                            boneAng:RotateAroundAxis(boneAng:Up(), angOffset.y)
                            boneAng:RotateAroundAxis(boneAng:Right(), angOffset.p)
                            boneAng:RotateAroundAxis(boneAng:Forward(), angOffset.r)
                            mdl:SetPos(pos)
                            mdl:SetAngles(boneAng)
                            mdl:SetupBones()
                            mdl:DrawModel()
                        end
                    end
                end
            end
        end
    end
end

hook.Add("PostPlayerDraw", "MuR_ArmorRenderPlayer", function(ply)
    if not IsValid(ply) then return end
    if ply == LocalPlayer() then
        local mode = MuR:GetClient("blsd_viewperson")
        if mode == 2 then
            DrawArmorOnEntity(ply)
        elseif mode == 1 then
            DrawArmorOnEntitySkipHead(ply, true)
        end
        return
    end
    DrawArmorOnEntity(ply)
end)

hook.Add("PostDrawOpaqueRenderables", "MuR_ArmorRenderRagdolls", function(depth, skybox)
    local lp = LocalPlayer()
    for _, ply in player.Iterator() do
        if not IsValid(ply) or not ply:Alive() then continue end
        local rd = ply:GetNW2Entity("RD_Ent")
        if IsValid(rd) and rd:IsRagdoll() then
            local isLocalPlayerRagdoll = (ply == lp)
            DrawArmorOnEntitySkipHead(rd, isLocalPlayerRagdoll)
        end
    end
    local ragdolls = ents.FindByClass("prop_ragdoll")
    if ragdolls then
        for _, ent in ipairs(ragdolls) do
            if not IsValid(ent) then continue end
            if ent:GetNW2Bool("MuR.IsMode18ZombieRag", false) then continue end
            //if not ent.isRDRag then continue end
            DrawArmorOnEntity(ent)
        end
    end
end)

hook.Add("PostDrawBody", "MuR_ArmorRenderFirstPerson", function(body)
    if not IsValid(body) then return end
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    if MuR:GetClient("blsd_viewperson") == 0 then return end
    for bodypart, partData in pairs(MuR.Armor.BodyParts) do
        if bodypart == "head" or bodypart == "face" then continue end
        local armorId = ply:GetNW2String("MuR_Armor_" .. bodypart, "")
        local isActive = ply:GetNW2Bool("MuR_Armor_Active_" .. bodypart, false)
        local isHidden = ply:GetNW2Bool("MuR_Armor_Hidden_" .. bodypart, false)
        if armorId ~= "" and isActive and not isHidden then
            local item = MuR.Armor.GetItem(armorId)
            if item then
                local mdl = GetArmorModel(ply, bodypart .. "_fp", armorId)
                if IsValid(mdl) then
                    local boneId = body:LookupBone(partData.bone)
                    if boneId then
                        local bonePos, boneAng = body:GetBonePosition(boneId)
                        if bonePos and boneAng then
                            local offset = item.pos_offset or Vector(0, 0, 0)
                            local angOffset = item.ang_offset or Angle(0, 0, 0)
                            local pos = bonePos + boneAng:Forward() * offset.x + boneAng:Right() * offset.y + boneAng:Up() * offset.z
                            local ang = boneAng + angOffset
                            mdl:SetPos(pos)
                            mdl:SetAngles(ang)
                            mdl:SetupBones()
                            mdl:DrawModel()
                        end
                    end
                end
            end
        end
    end
end)

hook.Add("EntityRemoved", "MuR_ArmorCleanup", function(ent)
    if not IsValid(ent) then return end
    CleanupArmorModels(ent:EntIndex())
end)

hook.Add("OnReloaded", "MuR_ArmorCleanupOnReload", function()
    for entIndex, models in pairs(MuR.Armor.ClientModels) do
        for key, mdl in pairs(models) do
            if IsValid(mdl) then mdl:Remove() end
        end
    end
    MuR.Armor.ClientModels = {}
end)

local overlayMaterials = {}
local function GetOverlayMaterial(matPath)
    if not matPath then return nil end
    if overlayMaterials[matPath] then return overlayMaterials[matPath] end
    local mat = Material(matPath)
    if mat and not mat:IsError() then
        overlayMaterials[matPath] = mat
        return mat
    end
    return nil
end

hook.Add("HUDPaintBackground", "MuR_ArmorOverlay", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end
    if MuR:GetClient("blsd_viewperson") == 2 then return end

    for _, bodypart in ipairs({"face", "head"}) do
        local armorId = ply:GetNW2String("MuR_Armor_" .. bodypart, "")
        local isActive = ply:GetNW2Bool("MuR_Armor_Active_" .. bodypart, false)
        if armorId ~= "" and isActive then
            local item = MuR.Armor.GetItem(armorId)
            if item and item.overlay then
                local mat = GetOverlayMaterial(item.overlay)
                if mat then
                    surface.SetDrawColor(255, 255, 255, 255)
                    surface.SetMaterial(mat)
                    surface.DrawTexturedRect(0, 0, ScrW(), ScrH())
                end
            end
        end
    end
end)
