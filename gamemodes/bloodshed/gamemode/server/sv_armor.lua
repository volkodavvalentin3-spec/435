local plyMeta = FindMetaTable("Player")

util.AddNetworkString("MuR_ArmorPickup")
util.AddNetworkString("MuR_GetRagdollArmor")
util.AddNetworkString("MuR_ArmorHUD")

local boneToHitgroup = {
    ["ValveBiped.Bip01_Head1"] = HITGROUP_HEAD,
    ["ValveBiped.Bip01_Neck1"] = HITGROUP_HEAD,
    ["ValveBiped.Bip01_Spine"] = HITGROUP_STOMACH,
    ["ValveBiped.Bip01_Spine1"] = HITGROUP_CHEST,
    ["ValveBiped.Bip01_Spine2"] = HITGROUP_CHEST,
    ["ValveBiped.Bip01_Spine4"] = HITGROUP_CHEST,
    ["ValveBiped.Bip01_Pelvis"] = HITGROUP_STOMACH,
    ["ValveBiped.Bip01_L_Thigh"] = HITGROUP_LEFTLEG,
    ["ValveBiped.Bip01_R_Thigh"] = HITGROUP_RIGHTLEG,
    ["ValveBiped.Bip01_L_Calf"] = HITGROUP_LEFTLEG,
    ["ValveBiped.Bip01_R_Calf"] = HITGROUP_RIGHTLEG,
    ["ValveBiped.Bip01_L_Foot"] = HITGROUP_LEFTLEG,
    ["ValveBiped.Bip01_R_Foot"] = HITGROUP_RIGHTLEG,
    ["ValveBiped.Bip01_L_UpperArm"] = HITGROUP_LEFTARM,
    ["ValveBiped.Bip01_R_UpperArm"] = HITGROUP_RIGHTARM,
    ["ValveBiped.Bip01_L_Forearm"] = HITGROUP_LEFTARM,
    ["ValveBiped.Bip01_R_Forearm"] = HITGROUP_RIGHTARM,
    ["ValveBiped.Bip01_L_Hand"] = HITGROUP_LEFTARM,
    ["ValveBiped.Bip01_R_Hand"] = HITGROUP_RIGHTARM,
}

MuR.Armor.ImpactSounds = {}
function MuR.Armor.GetImpactSound(sndFolder)
    if not MuR.Armor.ImpactSounds[sndFolder] then
        local files, _ = file.Find("sound/murdered/armor/impact/" .. sndFolder .. "/*.wav", "GAME")
        MuR.Armor.ImpactSounds[sndFolder] = files
    end
    local tab = MuR.Armor.ImpactSounds[sndFolder]
    if istable(tab) and #tab > 0 then
        return "murdered/armor/impact/" .. sndFolder .. "/" .. table.Random(tab)
    end
    return nil
end

local function GetHitgroupFromBone(ent, boneName)
    if not boneName then return nil end
    return boneToHitgroup[boneName] or HITGROUP_GENERIC
end

local function GetArmorReductionValue(item, dmginfo)
    local reduction = item.damage_reduction or 0
    if dmginfo and dmginfo:IsDamageType(DMG_BULLET) and item.ammo_scaling then
        local ammoType = dmginfo:GetAmmoType()
        local ammoName = game.GetAmmoName(ammoType)
        if ammoName then
            ammoName = string.lower(ammoName)
            if item.ammo_scaling[ammoName] then
                reduction = item.ammo_scaling[ammoName]
            elseif item.ammo_scaling["others"] then
                reduction = item.ammo_scaling["others"]
            end
        end
    end
    return reduction
end

function plyMeta:InitArmorData()
    self.MuR_Armor = self.MuR_Armor or {}
    self.MuR_ArmorActive = self.MuR_ArmorActive or {}
end

function plyMeta:IsArmorActive(bodypart)
    self:InitArmorData()
    return self:GetNW2Bool("MuR_Armor_Active_" .. bodypart, false)
end

function plyMeta:SetArmorHidden(bodypart, hidden)
    self:SetNW2Bool("MuR_Armor_Hidden_" .. bodypart, hidden and true or false)

    local rd = self:GetRD()
    if IsValid(rd) then
        rd:SetNW2Bool("MuR_Armor_Hidden_" .. bodypart, hidden and true or false)
    end
end

function plyMeta:IsArmorHidden(bodypart)
    return self:GetNW2Bool("MuR_Armor_Hidden_" .. bodypart, false)
end

function plyMeta:SetArmorNoDrop(bodypart, noDrop)
    self:SetNW2Bool("MuR_Armor_NoDrop_" .. bodypart, noDrop and true or false)

    local rd = self:GetRD()
    if IsValid(rd) then
        rd:SetNW2Bool("MuR_Armor_NoDrop_" .. bodypart, noDrop and true or false)
    end
end

function plyMeta:IsArmorNoDrop(bodypart)
    return self:GetNW2Bool("MuR_Armor_NoDrop_" .. bodypart, false)
end

function plyMeta:EquipArmor(armorId, active)
    local item = MuR.Armor.GetItem(armorId)
    if not item then return false end

    self:InitArmorData()
    if active == nil then active = true end

    self:RemoveArmor(item.bodypart)

    self.MuR_Armor[item.bodypart] = armorId
    self.MuR_ArmorActive[item.bodypart] = active

    self:SetNW2String("MuR_Armor_" .. item.bodypart, armorId)
    self:SetNW2Bool("MuR_Armor_Active_" .. item.bodypart, active)

    local rd = self:GetRD()
    if IsValid(rd) then
        MuR:TransferArmorToRagdoll(self, rd)
    end

    return true
end

function plyMeta:SetArmorActive(bodypart, active)
    self:InitArmorData()
    if not self.MuR_Armor[bodypart] then return end

    self.MuR_ArmorActive[bodypart] = active
    self:SetNW2Bool("MuR_Armor_Active_" .. bodypart, active)

    local item = MuR.Armor.GetItem(self.MuR_Armor[bodypart])
    if item then
        local snd = active and item.equip_sound or item.unequip_sound
        if snd then
            self:EmitSound(snd, 60, 100)
        end
    end

    local rd = self:GetRD()
    if IsValid(rd) then
        rd:SetNW2Bool("MuR_Armor_Active_" .. bodypart, active)
    end
end

function plyMeta:RemoveArmor(bodypart)
    self:InitArmorData()

    self.MuR_Armor[bodypart] = nil
    self.MuR_ArmorActive[bodypart] = false
    self:SetNW2String("MuR_Armor_" .. bodypart, "")
    self:SetNW2Bool("MuR_Armor_Active_" .. bodypart, false)
    self:SetNW2Bool("MuR_Armor_Hidden_" .. bodypart, false)
    self:SetNW2Bool("MuR_Armor_NoDrop_" .. bodypart, false)

    local rd = self:GetRD()
    if IsValid(rd) then
        rd:SetNW2String("MuR_Armor_" .. bodypart, "")
        rd:SetNW2Bool("MuR_Armor_Hidden_" .. bodypart, false)
        rd:SetNW2Bool("MuR_Armor_NoDrop_" .. bodypart, false)
        if rd.MuR_Armor then
            rd.MuR_Armor[bodypart] = nil
        end
    end
end

function plyMeta:GetEquippedArmor()
    self:InitArmorData()
    return self.MuR_Armor
end

function plyMeta:GetArmorOnPart(bodypart)
    self:InitArmorData()
    return self.MuR_Armor[bodypart]
end

function plyMeta:HasGasProtection()
    self:InitArmorData()

    local totalProtection = 0
    for bodypart, armorId in pairs(self.MuR_Armor) do
        if not self:IsArmorActive(bodypart) then continue end

        local item = MuR.Armor.GetItem(armorId)
        if item and item.gas_protection then
            totalProtection = totalProtection + item.gas_protection
        end
    end

    return totalProtection >= 1.0
end

function plyMeta:GetGasProtectionLevel()
    self:InitArmorData()

    local totalProtection = 0
    for bodypart, armorId in pairs(self.MuR_Armor) do
        if not self:IsArmorActive(bodypart) then continue end

        local item = MuR.Armor.GetItem(armorId)
        if item and item.gas_protection then
            totalProtection = totalProtection + item.gas_protection
        end
    end

    return math.min(totalProtection, 1.0)
end

function plyMeta:GetPepperProtectionLevel()
    self:InitArmorData()

    local totalProtection = 0
    for bodypart, armorId in pairs(self.MuR_Armor) do
        if not self:IsArmorActive(bodypart) then continue end

        local item = MuR.Armor.GetItem(armorId)
        if item then
            totalProtection = totalProtection + (item.pepper_protection or 0)
        end
    end

    return math.min(totalProtection, 1.0)
end

function plyMeta:GetArmorDamageReduction(organName, dmginfo)
    self:InitArmorData()

    for bodypart, armorId in pairs(self.MuR_Armor) do
        if not self:IsArmorActive(bodypart) then continue end

        local item = MuR.Armor.GetItem(armorId)
        if item and MuR.Armor.IsOrganProtected(armorId, organName, dmginfo) then
            return GetArmorReductionValue(item, dmginfo)
        end
    end

    return 0
end

function plyMeta:GetArmorDamageReductionByHitgroup(hitgroup, dmginfo)
    self:InitArmorData()

    for bodypart, armorId in pairs(self.MuR_Armor) do
        if not self:IsArmorActive(bodypart) then continue end

        local item = MuR.Armor.GetItem(armorId)
        if item and MuR.Armor.IsHitgroupProtected(bodypart, hitgroup) then
            if not dmginfo or MuR.Armor.IsDamageTypeProtected(armorId, dmginfo) then
                return GetArmorReductionValue(item, dmginfo), bodypart
            end
        end
    end

    return 0, nil
end

function plyMeta:ClearAllArmor()
    self:InitArmorData()

    for bodypart, _ in pairs(self.MuR_Armor) do
        self:SetNW2String("MuR_Armor_" .. bodypart, "")
    end

    self.MuR_Armor = {}
end

function MuR:TransferArmorToRagdoll(ply, ragdoll)
    if not IsValid(ply) or not IsValid(ragdoll) then return end

    ply:InitArmorData()

    ragdoll.MuR_Armor = table.Copy(ply.MuR_Armor)

    if not ragdoll.Inventory then ragdoll.Inventory = {} end
    for bodypart, armorId in pairs(ply.MuR_Armor) do
        if armorId and armorId ~= "" and not ply:IsArmorNoDrop(bodypart) then
            local itemStr = "mur_armor_" .. armorId
            if not table.HasValue(ragdoll.Inventory, itemStr) then
                table.insert(ragdoll.Inventory, itemStr)
            end
        end
    end

    for bodypart, armorId in pairs(ply.MuR_Armor) do
        ragdoll:SetNW2String("MuR_Armor_" .. bodypart, armorId)
        ragdoll:SetNW2Bool("MuR_Armor_Active_" .. bodypart, ply:IsArmorActive(bodypart))
        ragdoll:SetNW2Bool("MuR_Armor_Hidden_" .. bodypart, ply:IsArmorHidden(bodypart))
        ragdoll:SetNW2Bool("MuR_Armor_NoDrop_" .. bodypart, ply:IsArmorNoDrop(bodypart))
    end
    timer.Simple(0.1, function()
        if !IsValid(ragdoll) then return end
        for bodypart, armorId in pairs(ply.MuR_Armor) do
            ragdoll:SetNW2String("MuR_Armor_" .. bodypart, armorId)
            ragdoll:SetNW2Bool("MuR_Armor_Active_" .. bodypart, ply:IsArmorActive(bodypart))
            ragdoll:SetNW2Bool("MuR_Armor_Hidden_" .. bodypart, ply:IsArmorHidden(bodypart))
            ragdoll:SetNW2Bool("MuR_Armor_NoDrop_" .. bodypart, ply:IsArmorNoDrop(bodypart))
        end
    end)

    ragdoll.HasTransferredArmor = true
end

hook.Add("PlayerDeath", "MuR_ArmorDeathRagdoll", function(ply)
    if not IsValid(ply) then return end
    local rd = ply:GetRD() or ply:GetNW2Entity("RD_EntCam")
    if IsValid(rd) then
        MuR:TransferArmorToRagdoll(ply, rd)
    end
end)

hook.Add("Think", "MuR_ArmorRagdollSync", function()
    for _, ply in player.Iterator() do
        if not ply.MuR_Armor or table.IsEmpty(ply.MuR_Armor) then continue end

        local rd = ply:GetRD()
        if IsValid(rd) and not rd.HasTransferredArmor then
            MuR:TransferArmorToRagdoll(ply, rd)
        end
    end
end)

net.Receive("MuR_ArmorPickup", function(len, ply)
    local action = net.ReadString()

    if action == "drop_from_ragdoll" then
        local ragdoll = net.ReadEntity()
        local bodypart = net.ReadString()

        if not IsValid(ragdoll) or not ragdoll:IsRagdoll() then return end
        if not MuR.Armor.BodyParts[bodypart] then return end
        if ply:GetPos():DistToSqr(ragdoll:GetPos()) > 40000 then return end

        MuR:DropArmorFromRagdoll(ragdoll, bodypart)
    elseif action == "unequip" then
        local bodypart = net.ReadString()
        if not MuR.Armor.BodyParts[bodypart] then return end
        if not ply:Alive() then return end
        if ply:IsArmorNoDrop(bodypart) then return end

        local armorId = ply:GetArmorOnPart(bodypart)
        if armorId and armorId ~= "" then
            local item = MuR.Armor.GetItem(armorId)
            local isActive = ply:IsArmorActive(bodypart)

            local tr = util.TraceLine({
                start = ply:EyePos(),
                endpos = ply:EyePos() + ply:GetForward() * 40,
                filter = ply
            })

            local dropPos = tr.HitPos + tr.HitNormal * 5
            local pickup = MuR:SpawnArmorPickup(dropPos, armorId)

            if IsValid(pickup) then
                local phys = pickup:GetPhysicsObject()
                if IsValid(phys) then
                    phys:SetVelocity(ply:GetForward() * 50 + Vector(0, 0, 20))
                end
            end

            ply:RemoveArmor(bodypart)

            if isActive and item and item.unequip_sound then
                ply:EmitSound(item.unequip_sound, 60, 100)
            end
        end
    elseif action == "toggle_active" then
        local bodypart = net.ReadString()
        local active = net.ReadBool()
        if not MuR.Armor.BodyParts[bodypart] then return end
        if not ply:Alive() then return end
        if ply:IsArmorNoDrop(bodypart) then return end

        ply:SetArmorActive(bodypart, active)
    end
end)

net.Receive("MuR_GetRagdollArmor", function(len, ply)
    local ragdoll = net.ReadEntity()
    if not IsValid(ragdoll) or not ragdoll:IsRagdoll() then return end

    local armorList = {}
    if ragdoll.MuR_Armor then
        for bodypart, armorId in pairs(ragdoll.MuR_Armor) do
            if armorId and armorId ~= "" and not ragdoll:GetNW2Bool("MuR_Armor_NoDrop_" .. bodypart, false) then
                table.insert(armorList, {bodypart = bodypart, armorId = armorId})
            end
        end
    end

    net.Start("MuR_GetRagdollArmor")
    net.WriteEntity(ragdoll)
    net.WriteTable(armorList)
    net.Send(ply)
end)

function MuR:DropArmorFromRagdoll(ragdoll, bodypart)
    if not IsValid(ragdoll) or not ragdoll.MuR_Armor then return end
    if ragdoll:GetNW2Bool("MuR_Armor_NoDrop_" .. bodypart, false) then return end

    local armorId = ragdoll.MuR_Armor[bodypart]
    if not armorId or armorId == "" then return end

    local pos = ragdoll:GetPos() + Vector(0, 0, 30)
    local pickup = MuR:SpawnArmorPickup(pos, armorId)

    ragdoll.MuR_Armor[bodypart] = nil
    ragdoll:SetNW2String("MuR_Armor_" .. bodypart, "")

    if ragdoll.Inventory then
        table.RemoveByValue(ragdoll.Inventory, "mur_armor_" .. armorId)
    end

    return pickup
end

hook.Add("EntityTakeDamage", "MuR_ArmorDamageReduction", function(ent, dmg)
    local ply = nil
    local hitgroup = nil

    if ent.isRDRag then
        return
    end

    if ent:IsPlayer() then
        ply = ent
        if ply.NoArmor then return end
        hitgroup = ent.LastDamageHitgroup
    end

    if not IsValid(ply) or not ply.MuR_Armor or table.IsEmpty(ply.MuR_Armor) then return end
    if not hitgroup or hitgroup == 0 then return end

    local reduction, bodypart = ply:GetArmorDamageReductionByHitgroup(hitgroup, dmg)
    if reduction > 0 then
        dmg:ScaleDamage(1 - reduction*0.5)
        local pos = dmg:GetDamagePosition()
        local dir = dmg:GetDamageForce()

        local effectdata = EffectData()
        effectdata:SetOrigin(pos)
        effectdata:SetNormal((dir:GetNormalized() * -1))
        effectdata:SetMagnitude(1)
        effectdata:SetScale(0.5)
        util.Effect("ManhackSparks", effectdata, true, true)

        local sndFolder = "other"
        if bodypart == "head" then
            sndFolder = "helmet"
        elseif bodypart == "body" then
            sndFolder = "armor"
        end

        local snd = MuR.Armor.GetImpactSound(sndFolder)
        if snd then
            ent:EmitSound(snd, 75, 100)
        end
    end
end)

hook.Add("EntityTakeDamage", "MuR_CorpseArmorSparks", function(ent, dmg)
    if not ent:IsRagdoll() then return end
    if not ent.MuR_Armor or table.IsEmpty(ent.MuR_Armor) then return end
    if IsValid(ent.Owner) and ent.Owner:IsPlayer() and ent.Owner:Alive() then return end

    local pos = dmg:GetDamagePosition()
    local dir = dmg:GetDamageForce()
    local boneName = ent.GetNearestBoneFromPos and ent:GetNearestBoneFromPos(pos, dir)

    local hitgroup = HITGROUP_GENERIC
    if boneName then
        if string.find(boneName, "Head") or string.find(boneName, "Neck") then
            hitgroup = HITGROUP_HEAD
        elseif string.find(boneName, "Spine") then
            hitgroup = HITGROUP_CHEST
        end
    end

    for bodypart, armorId in pairs(ent.MuR_Armor) do
        local item = MuR.Armor.GetItem(armorId)
        if item and MuR.Armor.IsHitgroupProtected(bodypart, hitgroup) then
            if MuR.Armor.IsDamageTypeProtected(armorId, dmg) then
                local effectdata = EffectData()
                effectdata:SetOrigin(pos)
                effectdata:SetNormal((dir:GetNormalized() * -1))
                effectdata:SetMagnitude(1)
                effectdata:SetScale(0.5)
                util.Effect("ManhackSparks", effectdata, true, true)

                local sndFolder = "other"
                if bodypart == "head" then
                    sndFolder = "helmet"
                elseif bodypart == "body" then
                    sndFolder = "armor"
                end

                local snd = MuR.Armor.GetImpactSound(sndFolder)
                if snd then
                    ent:EmitSound(snd, 75, 100)
                end
                break
            end
        end
    end
end)

hook.Add("MuR.HandleCustomHitgroup", "MuR_ArmorOrganProtection", function(victim, owner, organ, dmginfo)

end)

hook.Add("PlayerSpawn", "MuR_ArmorClearOnSpawn", function(ply)
    timer.Simple(0, function()
        if IsValid(ply) then
            ply:ClearAllArmor()
        end
    end)
end)

hook.Add("PlayerDeath", "MuR_ArmorTransferOnDeath", function(ply)
    timer.Simple(0.1, function()
        if not IsValid(ply) then return end
        local rd = ply:GetNW2Entity("RD_EntCam")
        if IsValid(rd) then
            MuR:TransferArmorToRagdoll(ply, rd)
        end
    end)
end)

--
-- Отладочные команды брони.
--
-- Раньше их мог звать ЛЮБОЙ игрок: mur_give_armor выдавал себе любую броню
-- бесплатно, мимо магазина и лута. Ни проверки прав, ни проверки существования
-- набора в команде не было вовсе.
--
-- IsValid(ply) == false означает вызов с серверной консоли — его пропускаем.
--
local function armorCmdAllowed(ply)
    if not IsValid(ply) then return true end

    return ply:IsAdmin()
end

concommand.Add("mur_give_armor", function(ply, cmd, args)
    if not armorCmdAllowed(ply) then return end
    if not IsValid(ply) then return end

    local armorId = args[1]
    if not armorId then return end

    ply:EquipArmor(armorId)
end)

concommand.Add("mur_remove_armor", function(ply, cmd, args)
    if not armorCmdAllowed(ply) then return end
    if not IsValid(ply) then return end

    local bodypart = args[1]
    if not bodypart then return end

    ply:RemoveArmor(bodypart)
end)

-- Снять с себя всё — единственная безобидная из трёх: она только отнимает.
concommand.Add("mur_clear_armor", function(ply, cmd, args)
    if not IsValid(ply) then return end
    ply:ClearAllArmor()
end)
