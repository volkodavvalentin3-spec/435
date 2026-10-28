AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "mur_editor_volume"
ENT.Spawnable = false
ENT.AdminOnly = true
ENT.DisableDuplicator = true
ENT.RenderGroup = RENDERGROUP_OTHER

function ENT:Draw()
end

function ENT:Initialize()
	if not SERVER then return end

	local mins = self.EditorMins
	local maxs = self.EditorMaxs
	if not isvector(mins) or not isvector(maxs) then
		self:Remove()
		return
	end

	local center = (mins + maxs) * 0.5
	local localMins = mins - center
	local localMaxs = maxs - center

	self:SetPos(center)
	self:SetAngles(angle_zero)
	self:SetModel("models/props_junk/PopCan01a.mdl")
	self:SetNoDraw(true)
	self:SetMoveType(MOVETYPE_NONE)
	self:SetCollisionBounds(localMins, localMaxs)

	if MuR.IsEditorObjectClip(self.EditorType) then
		self:PhysicsInitBox(localMins, localMaxs)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_NONE)
		self:SetCollisionBounds(localMins, localMaxs)
	else
		self:SetSolid(SOLID_BBOX)
		self:SetTrigger(true)
	end

	self.TouchCooldown = {}
end

local function IsAI(entity)
	return IsValid(entity) and ((MuR.IsAI and MuR.IsAI(entity)) or entity:IsNPC() or entity:IsNextBot())
end

local function IsTarget(entity)
	return IsValid(entity) and (entity:IsPlayer() or IsAI(entity))
end

local function CanTrigger(entity, target)
	if not IsTarget(target) then return false end

	local index = target:EntIndex()
	local now = CurTime()
	if entity.TouchCooldown[index] and entity.TouchCooldown[index] > now then return false end
	entity.TouchCooldown[index] = now + 0.5
	return true
end

function ENT:ActivateTarget(target)
	if not CanTrigger(self, target) then return end

	if self.EditorType == "triggerkill" then
		if target:IsPlayer() then
			if target:Alive() then target:Kill() end
		elseif IsAI(target) then
			local health = target:Health()
			if isnumber(health) and health > 0 then
				target:TakeDamage(health + 100, self, self)
			else
				target:Remove()
			end
		end
	elseif self.EditorType == "trigger_teleport" then
		if not isvector(self.EditorDestination) then return end
		target:SetPos(self.EditorDestination)
		target:SetVelocity(-target:GetVelocity())
	end
end

function ENT:StartTouch(target)
	if not MuR.IsEditorObjectTrigger(self.EditorType) then return end
	self:ActivateTarget(target)
end

function ENT:Touch(target)
	if not MuR.IsEditorObjectTrigger(self.EditorType) then return end
	self:ActivateTarget(target)
end

function ENT:OnRemove()
	self.TouchCooldown = nil
end

if SERVER then
	hook.Add("ShouldCollide", "MuR.EditorVolume.ShouldCollide", function(first, second)
		local volume = nil
		local target = nil

		if IsValid(first) and first:GetClass() == "mur_editor_volume" then
			volume, target = first, second
		elseif IsValid(second) and second:GetClass() == "mur_editor_volume" then
			volume, target = second, first
		else
			return
		end

		if not IsValid(volume) or volume.EditorObjectID == nil then return false end
		if not IsValid(target) or target:GetClass() == "mur_editor_volume" then return false end
		if not MuR.IsEditorObjectClip(volume.EditorType) then return false end

		local player = target:IsPlayer()
		local ai = IsAI(target)
		local prop = not player and not ai and IsValid(target:GetPhysicsObject())

		if volume.EditorType == "clip" then return player or ai or prop end
		if volume.EditorType == "playerclip" then return player end
		if volume.EditorType == "npcclip" then return ai end
		if volume.EditorType == "propclip" then return prop end

		return false
	end)
end
