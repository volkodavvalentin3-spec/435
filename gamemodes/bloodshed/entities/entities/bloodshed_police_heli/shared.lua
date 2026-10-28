ENT.Type = "anim"
ENT.PrintName = "Police Helicopter"
ENT.Author = "Hari"
ENT.Spawnable = true
ENT.Category = "Bloodshed"

ENT.Model = "models/murdered/vehicles/polmav/polmav_body.mdl"
ENT.RotorModel = "models/murdered/vehicles/polmav/polmav_rmain_slow.mdl"
ENT.Rotor2Model = "models/murdered/vehicles/polmav/polmav_rrear_slow.mdl"
ENT.RotorSoundPatch = "<murdered/pheli/loop.wav"
ENT.RotorPos = Vector(0,0,70)
ENT.Rotor2Pos = Vector(-249,15,21)
ENT.SpotlightPos = Vector(130,0,-40)
ENT.RedLightPos = Vector(-300,10,0)
ENT.GetQuote = function() return "<murdered/pheli/chopper"..math.random(1,20)..".wav" end
ENT.ShootSound = "<murdered/weapons/mini14/mini14_suppressed_fp.wav"

function ENT:SetupDataTables()
	self:NetworkVar("Entity",0,"Target")
	self:NetworkVar("Vector",0,"TarPos")
	self:NetworkVar("Bool",0,"TarMode")
end

function ENT:GetTargetPos()
	return self:GetTarMode() and self:GetTarPos() or self:GetTarget():EyePos()
end
