-- Compact impact puff for pepper spray

EFFECT.Mat = Material("particle/particle_smokegrenade")

function EFFECT:Init(data)
    local pos = data:GetOrigin()
    local nrm = data:GetNormal() or Vector(0,0,1)
    local emitter = ParticleEmitter(pos)
    if not emitter then return end

    for i=1, 14 do
        local p = emitter:Add(self.Mat, pos + VectorRand()*2)
        if p then
            p:SetVelocity(nrm * math.Rand(40, 120) + VectorRand()*60)
            p:SetDieTime(math.Rand(0.25, 0.5))
            p:SetStartAlpha(180)
            p:SetEndAlpha(0)
            p:SetStartSize(math.Rand(2, 4))
            p:SetEndSize(math.Rand(6, 8))
            p:SetRoll(math.Rand(-10,10))
            p:SetRollDelta(math.Rand(-1,1))
            p:SetColor(245, 170, 50)
            p:SetLighting(true)
            p:SetAirResistance(120)
            p:SetGravity(Vector(0,0,0))
        end
    end

    emitter:Finish()
end

function EFFECT:Think()
    return false
end

function EFFECT:Render()
end
