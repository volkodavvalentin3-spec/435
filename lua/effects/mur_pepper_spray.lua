-- Lightweight pepper spray stream effect

EFFECT.Mat = Material("particle/particle_smokegrenade")

function EFFECT:Init(data)
    local startPos = data:GetOrigin()
    local endPos = data:GetStart()
    local normal = data:GetNormal() or vector_origin

    if not endPos or endPos == vector_origin then
        endPos = startPos + normal * 160
    end

    local dir = (endPos - startPos):GetNormalized()
    local dist = startPos:Distance(endPos)
    local steps = math.Clamp(math.floor(dist / 24), 3, 8)

    local emitter = ParticleEmitter(startPos)
    if not emitter then return end

    for i=0, steps do
        local t = i / steps
        local pos = LerpVector(t, startPos, endPos) + VectorRand() * 2
        local count = 6
        for j=1, count do
            local p = emitter:Add(self.Mat, pos)
            if p then
                local spread = dir + VectorRand() * 0.06
                p:SetVelocity(spread * math.Rand(120, 220))
                p:SetDieTime(math.Rand(1, 2))
                p:SetStartAlpha(180)
                p:SetEndAlpha(0)
                p:SetStartSize(1)
                p:SetEndSize(math.Rand(4, 6))
                p:SetRoll(math.Rand(-10,10))
                p:SetRollDelta(math.Rand(-1,1))
                p:SetColor(240, 160, 40)
                p:SetAirResistance(140)
                p:SetGravity(Vector(0,0,-24))
                p:SetLighting(true)
            end
        end
    end

    emitter:Finish()
end

function EFFECT:Think()
    return false
end

function EFFECT:Render()
end
