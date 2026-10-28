local ENT = FindMetaTable("Entity")

function ENT:ZippyGoreMod3_DamageRagdoll_Gibbing( dmginfo )
    local damage = dmginfo:GetDamage()
    local forceVec = dmginfo:GetDamageForce()

    if damage <= 0 then return end

    if dmginfo:ZippyGoreMod3_GibType() == ZGM3_GIB_NEVER then return end

    if bit.band( self:GetFlags(), FL_DISSOLVING ) == FL_DISSOLVING && !ZGM3_CVARS["zippygore3_gib_dissolving_ragdoll"] then return end

    if dmginfo:IsExplosionDamage() then
        damage = damage * ZGM3_CVARS["zippygore3_explosion_damage_mult"]
    end
    if dmginfo:IsDamageType(DMG_CRUSH) or dmginfo:IsDamageType(DMG_VEHICLE) then
        local att = dmginfo:GetAttacker()
        if ((att == game.GetWorld() and self:GetVelocity():Length() < 600) or IsValid(att) and att:GetClass() == "prop_ragdoll") then
            damage = 1
        end
        damage = damage * ZGM3_CVARS["zippygore3_phys_damage_mult"]
    end
    if dmginfo:IsBulletDamage() then
        if damage >= ZGM3_CVARS["zippygore3_bullet_damage_highest"] then
            damage = damage * 2
        end
        local forceMult = 0.15
        if damage >= 80 then
            forceMult = 0.4
        elseif damage >= 50 then
            forceMult = 0.3
        elseif damage >= 30 then
            forceMult = 0.2
        end
        forceVec = forceVec * forceMult
    end

    local dmgscale = 1
    local inf = dmginfo:GetInflictor()
    if IsValid(inf) and inf:IsWeapon() and inf.IsTFAWeapon and inf:GetPrimaryAmmoType() == 7 then
        dmgscale = 5
    elseif IsValid(inf) and inf:IsWeapon() and inf.IsTFAWeapon and inf.Melee then
        if inf.Primary.Blunt and damage >= 100 then
            dmgscale = 3
        elseif !inf.Primary.Blunt and damage >= 20 then
            dmgscale = 2
        end
        forceVec = forceVec * 0.1
    end

    local gib_type_aoe = dmginfo:ZippyGoreMod3_IsGibType(ZGM3_GIB_AOE)
    local gib_type_direct = dmginfo:ZippyGoreMod3_IsGibType(ZGM3_GIB_DIRECT)
    local gib_type_always = dmginfo:ZippyGoreMod3_IsGibType(ZGM3_GIB_ALWAYS)
    local gib_type_dismember = dmginfo:ZippyGoreMod3_IsGibType(ZGM3_GIB_DISMEMBER)
    local gib_type_bullet = dmginfo:ZippyGoreMod3_IsGibType(ZGM3_GIB_BULLET)
    local gib_type_explosion = dmginfo:ZippyGoreMod3_IsGibType(ZGM3_GIB_EXPLOSION)

    local _, phys_idx = dmginfo:ZippyGoreMod3_RagdollHitPhysBone( self )
    if phys_idx then
        local hit_bone_name = self:GetBoneName( self:TranslatePhysBoneToBone(phys_idx) )
        local dismemberEnabled = ZGM3_CVARS["zippygore3_dismemberment"]
        local shouldDismember = dismemberEnabled && gib_type_dismember &&
        !(gib_type_bullet && hit_bone_name == "ValveBiped.Bip01_Head1")

        if gib_type_aoe then

            local data = {
                damage = damage*dmgscale,
                forceVec = forceVec,
                dismember = shouldDismember,
                explosion = gib_type_explosion,
            }
            local hurt_pos = dmginfo:ZippyGoreMod3_RagdollHurtPosition( self )
            if hurt_pos then self:ZippyGoreMod3_PhysBonesAOEDamage( hurt_pos, data ) end
        end

        if (!gib_type_aoe && gib_type_direct) or gib_type_always then

            local data = {
                damage = gib_type_always && self.ZippyGoreMod3_PhysBoneHPs[phys_idx] or damage*dmgscale,
                forceVec = forceVec,
                dismember = shouldDismember,
            }
            self:ZippyGoreMod3_DamagePhysBone( phys_idx, data )
        end

        if dmginfo:IsExplosionDamage() and damage >= 2000 then
            local h = self:TranslateBoneToPhysBone(self:LookupBone("ValveBiped.Bip01_Spine2"))
            self:ZippyGoreMod3_BreakPhysBone(h, {damage = damage, forceVec = forceVec, dismember = true})
        end

        if hit_bone_name == "ValveBiped.Bip01_Pelvis" then
            local spine2Bone = self:LookupBone("ValveBiped.Bip01_Spine2")
            if spine2Bone then
                local spine2Phys = self:TranslateBoneToPhysBone(spine2Bone)
                if spine2Phys and spine2Phys >= 0 and spine2Phys ~= phys_idx then
                    local escl = dmginfo:IsExplosionDamage() and 1 or (dmginfo:IsDamageType(DMG_SLASH) or dmginfo:IsDamageType(DMG_BUCKSHOT)) and 2 or 0.5
                    local extraDamage = damage * dmgscale * escl
                    if extraDamage > 0 and self.ZippyGoreMod3_PhysBoneHPs and self.ZippyGoreMod3_PhysBoneHPs[spine2Phys] and self.ZippyGoreMod3_PhysBoneHPs[spine2Phys] > 0 then
                        self:ZippyGoreMod3_DamagePhysBone(spine2Phys, {
                            damage = extraDamage,
                            forceVec = forceVec,
                            dismember = shouldDismember,
                        })
                    end
                end
            end
        end
    end

end

function ENT:ZippyGoreMod3_GuessBloodColorFromDamage( dmginfo )
    local trStartPos = dmginfo:GetDamagePosition()
    local trEndPos = dmginfo:ZippyGoreMod3_RagdollHurtPosition( self )

    if trEndPos then
        local filterEnts = {} for _, v in ipairs(ents.FindInSphere( trStartPos, trStartPos:Distance(trEndPos) )) do if v != self then table.insert(filterEnts, v) end end
        local tr = util.TraceLine({
            start = trStartPos,
            endpos = trEndPos,
            ignoreworld = true,
            filter = filterEnts,
            mask = MASK_ALL,
        })

        local surfaceProp = util.GetSurfacePropName(tr.SurfaceProps)
        if surfaceProp == "flesh" or surfaceProp == "bloodyflesh" then
            return BLOOD_COLOR_RED
        elseif surfaceProp == "alienflesh" or surfaceProp == "antlion" or surfaceProp == "zombieflesh" then
            return BLOOD_COLOR_YELLOW
        elseif surfaceProp == "strider" or surfaceProp == "gunship" or surfaceProp == "hunter" then
            return BLOOD_COLOR_ZGM3SYNTH
        end
    end
end

function ENT:ZippyGoreMod3_NewBloodColorOnDamage( dmginfo )

    local newBloodCol = self:ZippyGoreMod3_GuessBloodColorFromDamage(dmginfo)
    if newBloodCol then
        self.ZippyGoreMod3_BloodColor = newBloodCol
        return true 
    end
end

function ENT:ZippyGoreMod3_DamageRagdoll( dmginfo )
    if self.ZippyGoreMod3_BloodColor or
    ( self:ZippyGoreMod3_NewBloodColorOnDamage(dmginfo) ) then
        self:ZippyGoreMod3_DamageRagdoll_Gibbing(dmginfo)

        if self.ZGM3_SetPainExpression and dmginfo:GetDamage() > 10 then
            local intensity = math.Clamp(dmginfo:GetDamage() / 100, 0.3, 1.0)
            self:ZGM3_SetPainExpression(intensity)
        end
    end
end

function ENT:ZippyGoreMod3_PhysBonesAOEDamage( pos, data )
    local phys_bones = {}

    for i = 0, self:GetPhysicsObjectCount()-1 do
        local phys = self:GetPhysicsObjectNum( i )
        if IsValid(phys) then
            local dist = phys:GetPos():DistToSqr( pos )
            table.insert(phys_bones, { phys_bone_idx = i, dist = dist })
        end
    end

    local phys_bones_sorted_dist = {}

    for i = 1, #phys_bones do
        local mindist
        local closest_phys_bone
        for k, v in ipairs(phys_bones) do
            if !mindist or v.dist < mindist then
                mindist = v.dist
                closest_phys_bone = v
            end
        end
        table.RemoveByValue(phys_bones, closest_phys_bone)
        table.insert(phys_bones_sorted_dist, closest_phys_bone.phys_bone_idx)
    end

    for i ,v in ipairs(phys_bones_sorted_dist) do
        local newData = {
            damage = data.damage / i,
            forceVec = data.forceVec,
            dismember = data.dismember && (!data.explosion or (data.explosion && math.random(1, 2) == 1)),
        }
        self:ZippyGoreMod3_DamagePhysBone( v, newData )
    end
end

function ENT:ZippyGoreMod3_DamagePhysBone( phys_bone_idx, data )
    local health = self.ZippyGoreMod3_PhysBoneHPs[phys_bone_idx]
    if health == -1 then return end

    self.ZippyGoreMod3_PhysBoneHPs[phys_bone_idx] = health - data.damage
    if self.ZippyGoreMod3_PhysBoneHPs[phys_bone_idx] <= 0 then
        self.ZippyGoreMod3_PhysBoneHPs[phys_bone_idx] = -1
        self:ZippyGoreMod3_BreakPhysBone( phys_bone_idx, data )
        self.GibbedRag = true
    end
end

function ENT:ZippyGoreMod3_StoreDMGInfo( dmg )

    local ammotype = dmg:GetAmmoType()
    local attacker = dmg:GetAttacker()
    local basedmg = dmg:GetBaseDamage()
    local damage = dmg:GetDamage()
    local dmgbonus = dmg:GetDamageBonus()
    local dmgcustom = dmg:GetDamageCustom()
    local dmgforce = dmg:GetDamageForce()
    local dmgtype = dmg:GetDamageType()
    local dmgpos = dmg:GetDamagePosition()
    local infl = dmg:GetInflictor()
    local maxdmg = dmg:GetMaxDamage()
    local reportedpos = dmg:GetReportedPosition()

    self.LastDMGINFOTbl = {
        ammotype = ammotype,
        attacker = attacker,
        basedmg = basedmg,
        damage = damage,
        dmgbonus = dmgbonus,
        dmgcustom = dmgcustom,
        dmgforce = dmgforce,
        dmgtype = dmgtype,
        dmgpos = dmgpos,
        infl = infl,
        maxdmg = maxdmg,
        reportedpos = reportedpos,
    }

end

function ENT:ZippyGoreMod3_LastDMGINFO( dmg )

    if !self.LastDMGINFOTbl then return end

    local lastdmginfo = DamageInfo()

    if IsValid(self.LastDMGINFOTbl.infl) then
        lastdmginfo:SetInflictor(self.LastDMGINFOTbl.infl)
    end

    if IsValid(self.LastDMGINFOTbl.attacker) then
        lastdmginfo:SetAttacker(self.LastDMGINFOTbl.attacker)
    end

    lastdmginfo:SetAmmoType(self.LastDMGINFOTbl.ammotype)
    lastdmginfo:SetDamage(self.LastDMGINFOTbl.damage)
    lastdmginfo:SetDamageBonus(self.LastDMGINFOTbl.dmgbonus or 1)
    lastdmginfo:SetDamageForce(self.LastDMGINFOTbl.dmgforce)
    lastdmginfo:SetDamageType(self.LastDMGINFOTbl.dmgtype)
    lastdmginfo:SetDamagePosition(self.LastDMGINFOTbl.dmgpos)

    return lastdmginfo

end

hook.Add("EntityTakeDamage", "zzzEntityTakeDamage_ZippyGoreMod3", function( ent, dmginfo )
    if ent:IsNPC() or ent:IsNextBot() then

        if ent:GetBloodColor() == -1 then
            local bloodColor = ent:ZippyGoreMod3_GuessBloodColorFromDamage( dmginfo )
            if bloodColor then
                ent.ZippyGoreMod3_BackupBloodColor = bloodColor
            end
        end

        ent:ZippyGoreMod3_StoreDMGInfo( dmginfo )
    end

    if ent.ZippyGoreMod3_Ragdoll then
        ent:ZippyGoreMod3_DamageRagdoll( dmginfo )
    end
end)

