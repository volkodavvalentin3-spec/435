local EFFECT = {}
local GORE_KIND = "organ"

local function SpendRender(particleCost, decalCost)
    return MuR
        and MuR.SpendGoreRenderBudget
        and MuR:SpendGoreRenderBudget(GORE_KIND, particleCost, decalCost, false)
end

local function TryDecal(pos, cooldown)
    return MuR
        and MuR.TryGoreDecalCell
        and MuR:TryGoreDecalCell(pos, cooldown)
end

function EFFECT:Init(data)
	-- Жидкая кровь из модуля gmcl_bsblood, если он стоит у игрока (client/cl_bsblood.lua).
	if MuR and MuR.BSBlood and MuR.BSBlood:Effect("mur_organ_bleed", data) then return end
    local pos = data:GetOrigin()
    local mag = data:GetMagnitude() or 1
    local profile = MuR and MuR.GetGoreQualityProfile and MuR:GetGoreQualityProfile()
    if not profile then return end

    if SpendRender(1, 0) then
        ParticleEffect("blood_impact_red_01", pos, Angle(0, 0, 0))
    end

    local emitter = ParticleEmitter(pos)
    if emitter then
        local requested = math.Clamp(2 + math.floor(mag), 2, 10)
        local count = math.max(1, math.floor(requested * profile.particleScale + 0.5))

        for i = 1, count do
            if not SpendRender(1, 0) then break end

            local p = emitter:Add("particle/smokesprites_0001", pos + VectorRand() * 2)
            if p then
                p:SetVelocity(VectorRand():GetNormalized() * (50 + mag * 30) + Vector(0, 0, -100))
                p:SetDieTime((0.8 + math.Rand(0, 0.6)) * profile.lifetimeScale)
                p:SetStartAlpha(200)
                p:SetEndAlpha(0)
                p:SetStartSize(3 + mag)
                p:SetEndSize(0)
                p:SetGravity(Vector(0, 0, -300))
                p:SetAirResistance(50)
                p:SetCollide(true)
                p:SetBounce(0.2)
                p:SetColor(160, 10, 10)
                p:SetCollideCallback(function(_, spos, snorm)
                    if not SpendRender(0, 1) or not TryDecal(spos, 0.12) then return end
                    util.Decal("Blood", spos - snorm, spos + snorm)
                end)
            end
        end
        emitter:Finish()
    end

    if SpendRender(0, 1) and TryDecal(pos, 0.12) then
        util.Decal("Blood", pos + Vector(0, 0, 8), pos - Vector(0, 0, 8))
    end
end

function EFFECT:Think() return false end
function EFFECT:Render() end

effects.Register(EFFECT, "mur_organ_bleed")
