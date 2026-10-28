AddCSLuaFile()

ENT.Base = "base_anim"
ENT.Type = "anim"
ENT.PrintName = "NPC Weapon"
ENT.Author = "Hari"
ENT.Spawnable = false

ENT.IsBSNPCWeapon = true

--
-- Оружие в руке NPC. Не SWEP: nextbot их носить не умеет (Entity:Give есть
-- только у игрока и движкового NPC). Здесь только модель на attachment кисти,
-- вся стрельба живёт в bs_npc_human/sv_weapon.lua.
--
-- Класс отдельной сущностью, а не base_anim напрямую, нужен ради GetClass():
-- по нему геймдмод отличает оружие (sv_reverb, sh_kicks, режимы).
--

if CLIENT then
	function ENT:Draw()
		self:DrawModel()
	end

	return
end

function ENT:Initialize()
	self:SetSolid(SOLID_NONE)
	self:SetMoveType(MOVETYPE_NONE)
	self:DrawShadow(false)
end

-- Настраивается владельцем сразу после Spawn.
function ENT:Setup(npc, data)
	self.Data = data
	self.Clip = data.clip or 0

	self:SetModel(data.model)
	self:SetOwner(npc)
	self.Owner = npc

	if data.modelScale then self:SetModelScale(data.modelScale, 0) end

	self:AttachTo(npc, data)

	npc:DeleteOnRemove(self)
end

--
-- Крепление в руку.
--
-- Основной путь — кость ValveBiped.Bip01_R_Hand через FollowBone: ровно к ней
-- TFA привязывает world-модель, и её же смещения (bonePos/boneAng) мы забрали
-- при импорте. Пространство FollowBone совпадает с пространством кости, так что
-- цифры TFA применимы как есть — без этого ствол висел не в руке, потому что
-- смещения считались от attachment'а с другим базисом.
--
-- Запасной путь — attachment кисти: он есть у моделей без ValveBiped-скелета.
--
-- Движковый NPC не делает ни того, ни другого: его оружие остаётся в начале
-- координат NPC, а в руке рисуется клиентом по костям (замерено на
-- npc_metropolice: LocalPos нулевой, до кисти 42 юнита). Нам это недоступно.
--
function ENT:AttachTo(npc, data)
	local bone = npc:LookupBone(npc.WeaponBone or "ValveBiped.Bip01_R_Hand")

	if bone and data.bonePos then
		self:FollowBone(npc, bone)
		self:SetLocalPos(data.bonePos)
		self:SetLocalAngles(data.boneAng or angle_zero)

		return
	end

	local att = npc:LookupAttachment(npc.WeaponAttachment or "anim_attachment_rh")

	if att and att > 0 then
		self:SetParent(npc, att)
		self:SetLocalPos(data.offsetPos or npc.WeaponOffsetPos or Vector(2, 0, 2))
		self:SetLocalAngles(data.offsetAng or npc.WeaponOffsetAng or Angle(270, 90, 0))

		return
	end

	self:SetParent(npc)
	self:SetLocalPos(vector_origin)
	self:SetLocalAngles(angle_zero)
end

function ENT:GetData()
	return self.Data
end

function ENT:IsMelee()
	return self.Data ~= nil and self.Data.melee == true
end

function ENT:GetClip()
	return self.Clip or 0
end

function ENT:SetClip(n)
	self.Clip = n
end

function ENT:GetMaxClip()
	return self.Data and self.Data.clip or 0
end

-- Точка вылета пули. У world-моделей оружия attachment "muzzle" есть не всегда.
function ENT:GetMuzzlePos()
	local id = self:LookupAttachment("muzzle")
	if id and id > 0 then
		local att = self:GetAttachment(id)
		if att then return att.Pos, att.Ang end
	end

	return self:GetPos(), self:GetAngles()
end
