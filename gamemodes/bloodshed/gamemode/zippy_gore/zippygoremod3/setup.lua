local ENT = FindMetaTable("Entity")

ZGM3_RAGDOLLS = {}

local vj_red_blood_decals = {
    ["Blood"] = BLOOD_COLOR_RED,
    ["VJ_Blood_Red"] = BLOOD_COLOR_RED,
    ["VJ_L4D_Blood"] = BLOOD_COLOR_RED,
    ["VJ_LNR_Blood_Red"] = BLOOD_COLOR_RED,
    ["VJ_Manhunt_Blood_Red"] = BLOOD_COLOR_RED,
    ["VJ_Manhunt_Blood_DarkRed"] = BLOOD_COLOR_RED,
    ["VJ_Green_Blood"] = BLOOD_COLOR_RED, 
    ["VJ_Infected_Blood"] = BLOOD_COLOR_RED, 
    ["YellowBlood"] = BLOOD_COLOR_YELLOW,
    ["VJ_Blood_Yellow"] = BLOOD_COLOR_YELLOW,
    ["VJ_Blood_White"] = BLOOD_COLOR_ZGM3SYNTH,
}

function ENT:ZippyGoreMod3_GetEngineBloodFromVJBlood()
    return self.IsVJBaseSNPC && self.CustomBlood_Decal && self.CustomBlood_Decal[1] && vj_red_blood_decals[ self.CustomBlood_Decal[1] ]
end

function ENT:ZippyGoreMod3_BecomeGibbableRagdoll( blood_color )
    self.ZippyGoreMod3_Ragdoll = true
    table.insert(ZGM3_RAGDOLLS, self)
    self:CallOnRemove("RemoveFrom_ZGM3_RAGDOLLS", function()
        table.RemoveByValue(ZGM3_RAGDOLLS, self)
    end)

    self.ZippyGoreMod3_BloodColor = blood_color
    if blood_color == false then self.ZippyGore3_VariableBloodColor = true end

    self.ZippyGoreMod3_PhysBoneHPs = {}

    local root_health_mult = ZGM3_CVARS["zippygore3_root_bone_health_mult"]
    local misc_mult = ZGM3_CVARS["zippygore3_misc_bones_health_mult"]
    local spine2Bone = self:LookupBone("ValveBiped.Bip01_Spine2")
    local spine2Phys = spine2Bone and self:TranslateBoneToPhysBone(spine2Bone) or -1
    local spine2_mult = misc_mult * 0.5
    for i = 0, self:GetPhysicsObjectCount()-1 do
        local mult
        if i == 0 then
            mult = root_health_mult
        elseif i == spine2Phys and spine2Phys >= 0 then
            mult = spine2_mult
        else
            mult = misc_mult
        end
        local phys = self:GetPhysicsObjectNum(i)
        if IsValid(phys) then
            self.ZippyGoreMod3_PhysBoneHPs[i] = phys:GetSurfaceArea() * 0.25 * mult
        else
            self.ZippyGoreMod3_PhysBoneHPs[i] = 0
        end
    end

    if self.ZippyGoreMod3_StartConvulsions and math.random(1, 3) <= 2 then
        local intensity = math.Rand(100, 200)
        local duration = math.Rand(1.5, 4)
        timer.Simple(0.1, function()
            if IsValid(self) and self.ZippyGoreMod3_StartConvulsions then
                self:ZippyGoreMod3_StartConvulsions(intensity, duration)
            end
        end)
    end

    if self.ZGM3_SetDeathExpression and not self:GetNW2Bool("MuR.IsLivingRagdoll", false) then
        timer.Simple(0.05, function()
            if IsValid(self) and self.ZGM3_SetDeathExpression then
                self:ZGM3_SetDeathExpression(false)
            end
        end)
    end
end

hook.Add("CreateEntityRagdoll", "CreateEntityRagdoll_ZippyGoreMod3", function( own, rag )
    if ZGM3_CVARS["zippygore3_enable"] == false then return end

    if (own:IsNPC() or own:IsNextBot()) and !own.DisableMuRGibs then
        local e_blood_color = own:GetBloodColor()

        local blood_color_to_use = (e_blood_color != -1 && e_blood_color) or (own.UsesRealisticBlood && 0) or (own:ZippyGoreMod3_GetEngineBloodFromVJBlood()) or (own.ZippyGoreMod3_BackupBloodColor)

        if blood_color_to_use && blood_color_to_use != -1 && blood_color_to_use != BLOOD_COLOR_MECH then

            rag:ZippyGoreMod3_BecomeGibbableRagdoll( blood_color_to_use )

            local lastDMGinfo = own:ZippyGoreMod3_LastDMGINFO()
            if lastDMGinfo then
                rag:ZippyGoreMod3_DamageRagdoll( lastDMGinfo )
            end
        end
    end
end)

hook.Add("OnEntityCreated", "OnEntityCreated_ZippyGoreMod3", function( ent )
    if MuR.IsAI(ent) and (string.find(ent:GetClass(), "vj_smod") or string.find(ent:GetClass(), "zombie")) then
        ent.DisableMuRGibs = true
    end

    if ZGM3_CVARS["zippygore3_enable"] == false then return end
    if ZGM3_CVARS["zippygore3_gib_any_ragdoll"] == false or ent:GetClass() != "prop_ragdoll" then return end

    timer.Simple(0, function()
        if IsValid(ent) && !ent.ZippyGoreMod3_Ragdoll && !ent.ZippyGoreMod3_IsGibRagdoll then
            ent:ZippyGoreMod3_BecomeGibbableRagdoll( false )
        end
    end)
end)
