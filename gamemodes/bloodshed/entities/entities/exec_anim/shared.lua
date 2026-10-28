ENT.Base = "base_anim"
ENT.Type = "anim"
ENT.RenderGroup = RENDERGROUP_BOTH
ENT.AutomaticFrameAdvance = true

function ENT:Initialize()
    if CLIENT then
        self:SetRenderBounds(Vector(-1000,-1000,-1000), Vector(1000,1000,1000))
    end
end
