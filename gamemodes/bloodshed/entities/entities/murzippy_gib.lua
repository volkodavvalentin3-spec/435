AddCSLuaFile()

ENT.Base = "base_gmodentity"
ENT.Type = "anim"
ENT.Author = "Zippy"
ENT.PrintName = "Gib"

if SERVER then
    ZippyGoreMod3_Gibs = {}
end

ENT.FadeTime = 2
ENT.FadeReps = 30

local GIB_STAIN_COOLDOWN = 0.18
local GIB_STAIN_LIMIT = 10
local GIB_STAIN_MIN_DISTANCE_SQR = 18 * 18
local GIB_STAIN_SPEED_STEP = 35

function ENT:Initialize()
    if SERVER then
        local ent = self.DoGibRagdoll && ents.Create("prop_ragdoll") or self
        if not IsValid(ent) or ent:IsMarkedForDeletion() then
            self:Remove()
            return
        end

        ent.BloodColor = self.BloodColor
        ent:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
        ent:SetNW2Int("ZippyGoreMod3_BloodColor", ent.BloodColor or BLOOD_COLOR_RED)

        if self.DoGibRagdoll then
            ent:SetModel(self:GetModel())
            ent:SetPos(self:GetPos())
            ent:SetAngles(self:GetAngles())
            ent.ZippyGoreMod3_IsGibRagdoll = true

            ent.FadeTime = self.FadeTime
            ent.FadeReps = self.FadeReps
            ent.Fade = self.Fade
            ent:AddCallback( "PhysicsCollide", self.PhysicsCollide )

            ent:Spawn()
            if not IsValid(ent) or ent:IsMarkedForDeletion() then
                self:Remove()
                return
            end

            self:SetParent(ent)
            self:SetNoDraw(true)
            self.Ragdoll = ent
        else
            ent:PhysicsInit( SOLID_VPHYSICS )
            local phys = ent:GetPhysicsObject()
            if IsValid(phys) then phys:Wake() end
        end

        if ent.BloodColor == BLOOD_COLOR_RED && ZGM3_INSANE_BLOOD_EFFECTS then
            local effectdata1 = EffectData()
            effectdata1:SetMagnitude( math.Rand(2, 3) )
            effectdata1:SetStart( ent:WorldSpaceCenter() )
            RealisticBlood_DoEffect("realisticblood_droplets", effectdata1, ent)
        end

        table.insert(ZippyGoreMod3_Gibs, ent)
        while #ZippyGoreMod3_Gibs > ZGM3_CVARS["zippygore3_gib_limit"] do
            if IsValid(ZippyGoreMod3_Gibs[1]) then
                ZippyGoreMod3_Gibs[1]:Fade()
            end
            table.remove(ZippyGoreMod3_Gibs, 1)
        end

        local lifetime = ZGM3_CVARS["zippygore3_gib_lifetime"]
        if lifetime != -1 then
            local timer_name = "ZippyGore3_GibFadeTime"..ent:EntIndex()
            timer.Create(timer_name, lifetime, 1, function()
                if IsValid(ent) then ent:Fade() end
            end)
            ent:CallOnRemove("ZippyGore3_GibFadeTime_Remove", function()
                if timer.Exists(timer_name) then timer.Remove(timer_name) end
            end)
        end
    end

    if CLIENT then
        local effectdata = EffectData()
        effectdata:SetEntity( self )
        util.Effect("mur_gib_blood", effectdata)
    end
end
function ENT:Fade()
    if !SERVER then return end

    self:SetRenderMode(RENDERMODE_TRANSALPHA)

    local timer_name = "ZippyGore3_GibFadeUpdate"..self:EntIndex()
    timer.Create(timer_name, self.FadeTime / self.FadeReps, self.FadeReps, function()
        if !IsValid(self) then
            timer.Remove(timer_name)
            return
        end

        local myCol = self:GetColor()
        local newCol = Color(myCol.r, myCol.g, myCol.b, myCol.a - (255 / self.FadeReps))
        if newCol.a <= 0 then
            self:SetNoDraw(true)
        else
            self:SetColor(newCol)
        end

        if timer.RepsLeft(timer_name) == 0 then self:Remove() end
    end)
end
function ENT:Use( activator )
    if ZGM3_CVARS["zippygore3_gib_edible"] && activator:Health() < activator:GetMaxHealth() then
        local health_to_give = ZGM3_CVARS["zippygore3_gib_heath_give"]
        local set_health = math.Clamp( activator:Health() + health_to_give, 0, activator:GetMaxHealth() )
        activator:SetHealth( set_health )
        local bc = self.BloodColor
        local effect = ( bc==BLOOD_COLOR_RED && "blood_impact_red_01_goop" ) or
        ( ( bc==BLOOD_COLOR_ANTLION or bc==BLOOD_COLOR_ANTLION_WORKER or bc==BLOOD_COLOR_GREEN or bc==BLOOD_COLOR_ZOMBIE or bc==BLOOD_COLOR_YELLOW ) && "blood_impact_yellow_01" )
        if effect then ParticleEffect(effect, self:WorldSpaceCenter(), self:GetAngles()) end
        self:EmitSound("ZippyGore3GibCollision")
        self:Remove()
    elseif activator:GetNW2String('Class') == 'Zombie' then
        local health_to_give = ZGM3_CVARS["zippygore3_gib_heath_give"]
        local set_health = math.Clamp( activator:Health() + health_to_give, 0, activator:GetMaxHealth() )
        activator:SetHealth( set_health )
        local bc = self.BloodColor
        local effect = ( bc==BLOOD_COLOR_RED && "blood_impact_red_01_goop" ) or
        ( ( bc==BLOOD_COLOR_ANTLION or bc==BLOOD_COLOR_ANTLION_WORKER or bc==BLOOD_COLOR_GREEN or bc==BLOOD_COLOR_ZOMBIE or bc==BLOOD_COLOR_YELLOW ) && "blood_impact_yellow_01" )
        if effect then ParticleEffect(effect, self:WorldSpaceCenter(), self:GetAngles()) end
        self:EmitSound("ZippyGore3GibCollision")
        self:Remove()
    end
end
function ENT:PhysicsCollide( data )
    local bc = self.BloodColor
    local decal = ( bc==BLOOD_COLOR_RED && "Blood" ) or
    ( ( bc==BLOOD_COLOR_ANTLION or bc==BLOOD_COLOR_ANTLION_WORKER or bc==BLOOD_COLOR_GREEN or bc==BLOOD_COLOR_ZOMBIE or bc==BLOOD_COLOR_YELLOW ) && "YellowBlood" )
    local speed = data and data.Speed or 0

    if speed > 200 then self:EmitSound("ZippyGore3GibCollision") end

    if speed <= 400 or not decal then return end

    local stainCount = self.BloodStainCount or 0
    if stainCount >= GIB_STAIN_LIMIT then return end

    local now = CurTime()
    if now < (self.NextBloodStain or 0) then return end

    local requiredSpeed = 400 + stainCount * GIB_STAIN_SPEED_STEP
    if speed <= requiredSpeed then return end

    local hitPos = data and data.HitPos or self:WorldSpaceCenter()
    if self.LastBloodStainPos
        and self.LastBloodStainPos:DistToSqr(hitPos) < GIB_STAIN_MIN_DISTANCE_SQR then

        return
    end

    self.NextBloodStain = now + GIB_STAIN_COOLDOWN
    self.BloodStainCount = stainCount + 1
    self.LastBloodStainPos = hitPos

    local effectdata = EffectData()
    effectdata:SetOrigin(self:WorldSpaceCenter())
    effectdata:SetNormal(VectorRand(-1,1))
    effectdata:SetMagnitude(1)
    effectdata:SetRadius(math.random(8,32))
    effectdata:SetEntity(self)
    util.Effect("mur_blood_splatter_effect", effectdata, true, true)
end
