AddCSLuaFile()

SWEP.PrintName = "Chemistry Tablet"
SWEP.DrawWeaponInfoBox = false

SWEP.Slot = 4
SWEP.SlotPos = 2

SWEP.Spawnable = true

SWEP.ViewModel = "models/murdered/v_item_pda.mdl"
SWEP.WorldModel = "models/props_lab/clipboard.mdl"
SWEP.ViewModelFOV = 100
SWEP.UseHands = true

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.DrawAmmo = false

SWEP.CraftingType = "basic"

function SWEP:Deploy()
	self.OpenedAnim = true
	self:CloseAnim()
	return true
end

function SWEP:Initialize()
	self:SetHoldType("slam")
end

function SWEP:CloseAnim()
	if !self.OpenedAnim then return end
	local vm = self:GetOwner():GetViewModel()
	local enum = vm:SelectWeightedSequence(ACT_VM_HOLSTER)
	vm:SendViewModelMatchingSequence(enum)
	self.OpenedAnim = false
	if CLIENT then
		net.Start("mur_craft_anim")
		net.WriteBool(false)
		net.SendToServer()
		surface.PlaySound("murdered/radio/off.mp3")
	end
end

function SWEP:OpenAnim()
	if self.OpenedAnim then return end
	local vm = self:GetOwner():GetViewModel()
	local enum = vm:SelectWeightedSequence(ACT_VM_DRAW)
	vm:SendViewModelMatchingSequence(enum)
	self.OpenedAnim = true
	if CLIENT then
		net.Start("mur_craft_anim")
		net.WriteBool(true)
		net.SendToServer()
		surface.PlaySound("murdered/radio/start.mp3")
	end
end

local lastAngles = Angle(0,0,0)
local lastPos = Vector(0,0,0)
function SWEP:CalcViewModelView(vm, oldeyepos, oldeyeang, eyepos, eyeang)
	if IsValid(vm) then
		local pos, viewAngles, fov = oldeyepos, oldeyeang, self.ViewModelFOV

		local seqAct = vm:GetSequenceActivity(vm:GetSequence())

		if seqAct == ACT_VM_DRAW then
			local targetAngle = Angle(-20, 0, 0)
			lastAngles = LerpAngle(FrameTime() * 5, lastAngles, targetAngle)
			viewAngles:Add(lastAngles)

			local targetPos = Vector(-3, 0, 1)
			lastPos = LerpVector(FrameTime() * 5, lastPos, targetPos)
			pos = pos + viewAngles:Forward() * lastPos.x + viewAngles:Right() * lastPos.y + viewAngles:Up() * lastPos.z
		elseif seqAct == ACT_VM_HOLSTER then
			local targetAngle = Angle(0, 0, 0)
			lastAngles = LerpAngle(FrameTime() * 5, lastAngles, targetAngle)
			viewAngles:Add(lastAngles)

			local targetPos = Vector(0, 0, 0)
			lastPos = LerpVector(FrameTime() * 5, lastPos, targetPos)
			pos = pos + viewAngles:Forward() * lastPos.x + viewAngles:Right() * lastPos.y + viewAngles:Up() * lastPos.z
		end

		return pos, viewAngles, fov
	end
end

function SWEP:Holster()
	if CLIENT then
		if IsValid(CraftingMenu) then
			CraftingMenu:Close()
		end
	end
	return true
end

function SWEP:PrimaryAttack()
	if CLIENT then
		RunConsoleCommand("mur_open_crafting", self.CraftingType)
	end

	self:SetNextPrimaryFire(CurTime() + 2)
end

function SWEP:SecondaryAttack()
end

function SWEP:Reload()
end

function SWEP:Think()
	if CLIENT and IsValid(self:GetOwner()) and self:GetOwner() == LocalPlayer() then
		local isOpen = IsValid(LocalPlayer().CraftingMenu)

		if isOpen then
			self:OpenAnim()
		else
			self:CloseAnim()
		end
	end
end

if CLIENT then
	local WorldModel = ClientsideModel(SWEP.WorldModel)
	WorldModel:SetNoDraw(true)

	function SWEP:DrawWorldModel()
		local owner = self:GetOwner()

		if IsValid(owner) then
			local offsetVec = Vector(3, -3, -2)
			local offsetAng = Angle(0, 90, 180)

			local boneid = owner:LookupBone("ValveBiped.Bip01_R_Hand")
			if !boneid then return end

			local matrix = owner:GetBoneMatrix(boneid)
			if !matrix then return end

			local newPos, newAng = LocalToWorld(offsetVec, offsetAng, matrix:GetTranslation(), matrix:GetAngles())

			WorldModel:SetPos(newPos)
			WorldModel:SetAngles(newAng)
			WorldModel:SetupBones()
		else
			WorldModel:SetPos(self:GetPos())
			WorldModel:SetAngles(self:GetAngles())
		end

		WorldModel:DrawModel()
	end

	function SWEP:DrawHUD()
		local lang = MuR.Language or {}
		draw.SimpleText(lang["craft_tablet_open"] or "LMB - Open Tablet", "DermaDefault", ScrW()/2, ScrH() - 50, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
end

SWEP.Category = "Bloodshed - Utility"
