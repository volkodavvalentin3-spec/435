AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Molotov Cocktail"
ENT.Spawnable = false

local FIRE_RADIUS = 72
local FIRE_DURATION = 8
local VFIRE_BALL_COUNT = 8
local VFIRE_SPLASH_RADIUS = 46
local VFIRE_MIN_LIFE = 10
local VFIRE_MAX_LIFE = 16
local VFIRE_MIN_FEED = 8
local VFIRE_MAX_FEED = 14

local BreakSound = Sound("physics/glass/glass_bottle_break2.wav")
local IgniteSound = Sound("ambient/fire/mtov_flame2.wav")

local function GetSplashBasis(normal)
    local right = normal:Cross(Vector(0, 0, 1))
    if right:LengthSqr() < 0.001 then
        right = normal:Cross(Vector(1, 0, 0))
    end

    right:Normalize()

    local forward = right:Cross(normal)
    forward:Normalize()

    return right, forward
end

local function SpawnVFireSplash(pos, normal, owner)
    local right, forward = GetSplashBasis(normal)
    local surfaceOffset = normal * 6

    for i = 1, VFIRE_BALL_COUNT do
        local angle = math.rad(((i - 1) / VFIRE_BALL_COUNT) * 360 + math.Rand(-18, 18))
        local dist = math.Rand(8, VFIRE_SPLASH_RADIUS)
        local dir = (right * math.cos(angle) + forward * math.sin(angle)):GetNormalized()
        local spawnPos = pos + surfaceOffset + dir * dist
        local velocity = dir * math.Rand(10, 35) + normal * math.Rand(2, 12)

        CreateVFireBall(
            math.Rand(VFIRE_MIN_LIFE, VFIRE_MAX_LIFE),
            math.Rand(VFIRE_MIN_FEED, VFIRE_MAX_FEED),
            spawnPos,
            velocity,
            owner
        )
    end

    CreateVFireBall(FIRE_DURATION + 6, VFIRE_MAX_FEED + 4, pos + surfaceOffset, normal * 8, owner)
end

function ENT:Initialize()
    self:SetModel("models/murdered/weapons/w_molotov.mdl")

    if SERVER then
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        self:SetCollisionGroup(COLLISION_GROUP_WEAPON)

        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:SetMass(1)
            phys:Wake()
            phys:SetMaterial("glass")
        end

        self.Armed = true
        self.HasExploded = false
    end

    if CLIENT then
        local emitter = ParticleEmitter(self:GetPos())
        if emitter then
            timer.Create("MolotovTrail_" .. self:EntIndex(), 0.05, 0, function()
                if not IsValid(self) then
                    timer.Remove("MolotovTrail_" .. self:EntIndex())
                    return
                end

                local particle = emitter:Add("particles/smokey", self:GetPos() + Vector(0, 0, 5))
                if particle then
                    particle:SetVelocity(VectorRand() * 20 + Vector(0, 0, 30))
                    particle:SetLifeTime(0)
                    particle:SetDieTime(0.5)
                    particle:SetStartAlpha(150)
                    particle:SetEndAlpha(0)
                    particle:SetStartSize(3)
                    particle:SetEndSize(8)
                    particle:SetColor(255, 150, 50)
                    particle:SetGravity(Vector(0, 0, 50))
                end
            end)
        end
    end
end

function ENT:PhysicsCollide(data, phys)
    if SERVER and self.Armed and not self.HasExploded then
        if data.Speed > 50 then
            self:Explode(data.HitPos, data.HitNormal)
        end
    end
end

function ENT:Explode(hitPos, hitNormal)
    if self.HasExploded then return end
    self.HasExploded = true

    local pos = hitPos or self:GetPos()
    local normal = hitNormal or Vector(0, 0, 1)

    self:EmitSound(BreakSound, 80, math.random(95, 105))

    timer.Simple(0.1, function()
        if not IsValid(self) then return end
        sound.Play(IgniteSound, pos, 85, math.random(95, 105))
    end)

    SpawnVFireSplash(pos, normal, self:GetOwner())

    local effectData = EffectData()
    effectData:SetOrigin(pos)
    effectData:SetNormal(normal)
    effectData:SetMagnitude(2)
    effectData:SetScale(1)
    util.Effect("GlassImpact", effectData)

    effectData:SetOrigin(pos)
    effectData:SetScale(FIRE_RADIUS)
    util.Effect("HelicopterMegaBomb", effectData)

    SafeRemoveEntity(self)
end

function ENT:OnRemove()
    if CLIENT then
        timer.Remove("MolotovTrail_" .. self:EntIndex())
    end
end

function ENT:Draw()
    self:DrawModel()
end
