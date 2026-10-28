if !SERVER then return end

local ENT = FindMetaTable("Entity")

local CONVULSION_DURATION = 3
local CONVULSION_INTENSITY = 150
local CONVULSION_FREQUENCY = 0.08
local CONVULSION_DECAY = 0.7

local convulsion_bones = {
    "ValveBiped.Bip01_Head1",
    "ValveBiped.Bip01_Spine2",
    "ValveBiped.Bip01_R_Hand",
    "ValveBiped.Bip01_L_Hand",
    "ValveBiped.Bip01_R_Foot",
    "ValveBiped.Bip01_L_Foot",
    "ValveBiped.Bip01_R_Forearm",
    "ValveBiped.Bip01_L_Forearm",
    "ValveBiped.Bip01_R_Calf",
    "ValveBiped.Bip01_L_Calf",
}

function ENT:ZippyGoreMod3_StartConvulsions(intensity, duration)
    if self.ZGM3_NoConvulsions then return end
    if self.ZGM3_ConvulsionsActive then return end
    if self:GetClass() ~= "prop_ragdoll" then return end

    self.ZGM3_ConvulsionsActive = true
    self.ZGM3_ConvulsionStart = CurTime()
    self.ZGM3_ConvulsionDuration = duration or CONVULSION_DURATION
    self.ZGM3_ConvulsionIntensity = intensity or CONVULSION_INTENSITY

    local physBones = {}
    for _, boneName in ipairs(convulsion_bones) do
        local boneID = self:LookupBone(boneName)
        if boneID then
            local physBone = self:TranslateBoneToPhysBone(boneID)
            if physBone and physBone >= 0 then
                local phys = self:GetPhysicsObjectNum(physBone)
                if IsValid(phys) then
                    table.insert(physBones, {
                        phys = phys,
                        bone = boneName,
                        offset = math.Rand(0, math.pi * 2)
                    })
                end
            end
        end
    end

    if #physBones == 0 then
        self.ZGM3_ConvulsionsActive = false
        return
    end

    local timerName = "ZGM3_Convulsions_" .. self:EntIndex()
    timer.Create(timerName, CONVULSION_FREQUENCY, 0, function()
        if not IsValid(self) then
            timer.Remove(timerName)
            return
        end

        local elapsed = CurTime() - self.ZGM3_ConvulsionStart
        if elapsed > self.ZGM3_ConvulsionDuration then
            self.ZGM3_ConvulsionsActive = false
            timer.Remove(timerName)
            return
        end

        local progress = elapsed / self.ZGM3_ConvulsionDuration
        local decayMult = (1 - progress) ^ CONVULSION_DECAY

        for _, boneData in ipairs(physBones) do
            if not IsValid(boneData.phys) then continue end
            if self.ZippyGoreMod3_GibbedPhysBones and self.ZippyGoreMod3_GibbedPhysBones[self:TranslateBoneToPhysBone(self:LookupBone(boneData.bone) or 0)] then
                continue
            end

            local wave = math.sin(CurTime() * 15 + boneData.offset)
            local randomFactor = math.Rand(0.3, 1.0)
            local impulse = VectorRand(-1, 1) * self.ZGM3_ConvulsionIntensity * decayMult * wave * randomFactor

            if math.random(1, 8) == 1 then
                impulse = impulse * 2.5
            end

            boneData.phys:ApplyForceCenter(impulse)
        end
    end)

    self:CallOnRemove("ZGM3_StopConvulsions", function()
        timer.Remove(timerName)
    end)
end

function ENT:ZippyGoreMod3_StopConvulsions()
    self.ZGM3_ConvulsionsActive = false
    timer.Remove("ZGM3_Convulsions_" .. self:EntIndex())
end
