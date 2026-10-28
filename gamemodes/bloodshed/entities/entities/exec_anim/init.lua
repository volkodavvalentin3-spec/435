AddCSLuaFile('shared.lua')
AddCSLuaFile('cl_init.lua')
include("shared.lua")

function ENT:Think()
	local ply = self.Target
	if IsValid(ply) then
		local newpos = ply:GetPos() + ply:GetUp() * 1
		local cycle = ply:GetCycle()

		self:SetCycle(cycle)
		self:SetPos(newpos)
		self:SetAngles(ply:GetAngles())
		if !ply:IsExecuting() then
			self:Remove()
		end
	else
		if self:GetCycle() >= 1 then
			self:Remove()
		end
	end

	self:NextThink(CurTime())
	return true
end
