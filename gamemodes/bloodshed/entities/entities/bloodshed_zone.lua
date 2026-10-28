AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Shrink Zone"
ENT.Author = "Hari"
ENT.Spawnable = true
ENT.InitialRadius = 3500
ENT.MinimumRadius = 1
ENT.ShrinkDuration = 240
ENT.CheckInterval = 2

function ENT:SetupDataTables()
	self:NetworkVar("Float", 0, "Radius")

	if SERVER then
		self:SetRadius(self.InitialRadius)
	end
end

function ENT:Initialize()
    if SERVER then
        self:SetModel("models/props_junk/PopCan01a.mdl")
        self:SetNotSolid(true)

        self.SpawnPos = self:GetPos()

        self.ShrinkStartTime = CurTime()
        self.ShrinkEndTime = self.ShrinkStartTime + self.ShrinkDuration

        self.NextPlayerCheck = CurTime()+2
    else
        self:SetRenderBounds(Vector(-32000,-32000,-32000), Vector(32000,32000,32000))
    end
end

function ENT:Think()
    if SERVER then
        local now = CurTime()

        local frac = math.Clamp((now - self.ShrinkStartTime) / self.ShrinkDuration, 0, 1)
        self:SetRadius(Lerp(frac, self.InitialRadius, self.MinimumRadius))
        if now >= self.NextPlayerCheck then
            self:CheckPlayers()
            self.NextPlayerCheck = now + self.CheckInterval
        end

        self:AddEFlags( EFL_FORCE_CHECK_TRANSMIT )
        self:NextThink(CurTime())
        return true
    end
end

function ENT:UpdateTransmitState()
	return TRANSMIT_ALWAYS
end

function ENT:CheckPlayers()
    for _, ply in player.Iterator() do
        if not IsValid(ply) or not ply:Alive() then continue end

        local dist = ply:EyePos():Distance(self.SpawnPos)
        if dist > self:GetRadius() then
            if ply:GetNW2Bool("Gasmask") then continue end
            local dmg = DamageInfo()
            dmg:SetDamage(15)
            dmg:SetDamageType(DMG_NERVEGAS)
            dmg:SetAttacker(self)
            dmg:SetInflictor(self)
            ply:TakeDamageInfo(dmg)
            ply.RandomPlayerSound = 0
            ply:MakeRandomSound(true)
            ply:ScreenFade(SCREENFADE.IN, Color(100, 150, 100, 150), 1, 2)
        end
    end
end

if CLIENT then
    local gasNextEmit = 0
    function ENT:Draw()
        render.CullMode(1)
        render.SetColorMaterial()
        render.DrawSphere(self:GetPos(), self:GetRadius() or 1, 32, 32, Color(100, 150, 100, 50))
        render.CullMode(0)

        if CurTime() < gasNextEmit or self:GetRadius() < 100 then return end
        gasNextEmit = CurTime() + 0.1

        local center = self:GetPos()
        local radius = self:GetRadius() or 1000
        local outerRadius = radius + radius/2 + 50

        for i = 1, 15 do
            local angle = math.rad(math.Rand(0, 360))
            local x = math.cos(angle) * outerRadius
            local y = math.sin(angle) * outerRadius
            local pos = center + Vector(x, y, math.Rand(0, 300))

            local emitter = ParticleEmitter(pos)
            local particle = emitter:Add("particles/smokey", pos)
            if particle then
                particle:SetVelocity(Vector(0, 0, math.Rand(5, 20)))
                particle:SetDieTime(2)
                particle:SetStartAlpha(50)
                particle:SetEndAlpha(0)
                particle:SetStartSize(math.max(radius,400))
                particle:SetEndSize(math.max(radius,400))
                particle:SetRoll(math.Rand(0, 360))
                particle:SetColor(100, 150, 100)
                particle:SetAirResistance(10)
            end
            emitter:Finish()
        end
    end
end
