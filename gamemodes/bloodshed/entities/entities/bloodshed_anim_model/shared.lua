AddCSLuaFile()

ENT.Base = "base_gmodentity"
ENT.Type = "anim"
ENT.PrintName = "Animated Model"
ENT.AutomaticFrameAdvance = true

function ENT:SetupDataTables()
	self:NetworkVar("String", 0, "Anim")
end

function ENT:UpdateTransmitState()
	return TRANSMIT_ALWAYS
end

function ENT:Think()
    local anim = self:GetAnim()
    if self:GetSequenceName(self:GetSequence()) != anim then
        self:ResetSequence(anim)
    end

    self:AddEFlags(EFL_FORCE_CHECK_TRANSMIT)
    self:NextThink(CurTime())
    return true
end
