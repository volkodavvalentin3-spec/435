AddCSLuaFile()
SWEP.Slot = 5
SWEP.DrawWeaponInfoBox = false
SWEP.UseHands = true
SWEP.ViewModel = Model("models/murdered/c_handlooker.mdl")
SWEP.ViewModelFOV = 90
SWEP.WorldModel = ""
SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"
SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = false
SWEP.PrintName = "Disguise"
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = false

function SWEP:SetupDataTables()
	self:NetworkVar("Float", 0, "NextIdle")
end

function SWEP:Initialize()
	self:SetWeaponHoldType("normal")
	self:SetNextIdle(0)
end

function SWEP:PrimaryAttack()
	local ply = self:GetOwner()

	local tr = util.TraceLine({
		start = ply:GetShootPos(),
		endpos = ply:GetShootPos() + ply:GetAimVector() * 64,
		filter = ply,
		mask = MASK_SHOT_HULL
	})

	local ent = tr.Entity

	if IsValid(ent) and ent.isRDRag and not IsValid(ent.Owner)
		and ent:GetNWString("Name", "") ~= MuR.UNIDENTIFIED_NAME then
		if SERVER then
			local name = ent:GetNWString("Name")
			local col = ent.PlyColor
			local p = ent.Male
			local mod = ent:GetModel()
			local name2 = ply:GetNWString("Name")
			local col2 = ply:GetPlayerColor()
			local p2 = ply.Male
			local mod2 = ply:GetModel()
			ply:SetNWString("Name", name)
			ply:SetPlayerColor(col)
			ply:SetModel(mod)
			ply:ScreenFade(SCREENFADE.IN, color_black, 1, 0.1)
			ply:SetupHands()
			ply:RemoveAllDecals()
		end

		local vm = ply:GetViewModel()
		vm:SendViewModelMatchingSequence(vm:LookupSequence("seq_admire_bms_old"))
		self:SetNextIdle(CurTime() + vm:SequenceDuration())
		self:SetNextPrimaryFire(CurTime() + 2)
		self:SetNextSecondaryFire(CurTime() + 1)
	end
end

function SWEP:CreateDisguiseMenu()
	local ply = self:GetOwner()
	if not IsValid(ply) then return end

	local frame = vgui.Create("DFrame")
	frame:SetSize(500, 370)
	frame:SetTitle(MuR.Language["disguise_menu"])
	frame:Center()
	frame:SetDraggable(true)
	frame:ShowCloseButton(true)
	frame:MakePopup()
	frame.Paint = function(self,w,h)
		surface.SetDrawColor(0,0,0,240)
		surface.DrawRect(0,0,w,h)
	end

	local nameLabel = vgui.Create("DLabel", frame)
	nameLabel:SetPos(20, 30)
	nameLabel:SetText(MuR.Language["disguise_menu_name"])
	nameLabel:SetSize(100, 20)

	local nameInput = vgui.Create("DTextEntry", frame)
	nameInput:SetPos(120, 30)
	nameInput:SetSize(200, 20)
	nameInput:SetValue(ply:GetNWString("Name", ""))

	local genderLabel = vgui.Create("DLabel", frame)
	genderLabel:SetPos(20, 60)
	genderLabel:SetText(MuR.Language["disguise_menu_gender"])
	genderLabel:SetSize(100, 20)

	local genderCombo = vgui.Create("DComboBox", frame)
	genderCombo:SetPos(120, 60)
	genderCombo:SetSize(200, 20)
	genderCombo:AddChoice(MuR.Language["gender_male"], true)
	genderCombo:AddChoice(MuR.Language["gender_female"], false)
	genderCombo:ChooseOptionID(1)

	local categoryLabel = vgui.Create("DLabel", frame)
	categoryLabel:SetPos(20, 90)
	categoryLabel:SetText(MuR.Language["disguise_menu_category"])
	categoryLabel:SetSize(100, 20)

	local categoryCombo = vgui.Create("DComboBox", frame)
	categoryCombo:SetPos(120, 90)
	categoryCombo:SetSize(200, 20)
	categoryCombo:AddChoice(MuR.Language["civilian"])
	categoryCombo:AddChoice(MuR.Language["officer"])
	categoryCombo:AddChoice(MuR.Language["security"])
	categoryCombo:AddChoice(MuR.Language["medic"])
	categoryCombo:AddChoice(MuR.Language["builder"])
	categoryCombo:ChooseOptionID(1)

	local modelList = vgui.Create("DListView", frame)
	modelList:SetPos(20, 120)
	modelList:SetSize(460, 200)
	modelList:SetMultiSelect(false)
	modelList:AddColumn(MuR.Language["disguise_menu_models"])

	local modelPreview = vgui.Create("DModelPanel", frame)
	modelPreview:SetPos(340, 30)
	modelPreview:SetSize(140, 80)
	modelPreview:SetModel(ply:GetModel())
	modelPreview:SetFOV(20)
	modelPreview:SetLookAt(Vector(0,0,64))

	local function UpdateModelList()
		modelList:Clear()

		local gender, genderData = genderCombo:GetSelected()
		local category = categoryCombo:GetSelected()
		local models = {}

		local roleName
		if category == MuR.Language["civilian"] then
			roleName = "Civilian"
		elseif category == MuR.Language["officer"] then
			roleName = "Officer"
		elseif category == MuR.Language["security"] then
			roleName = "Security"
		elseif category == MuR.Language["medic"] then
			roleName = "Medic"
		elseif category == MuR.Language["builder"] then
			roleName = "Builder"
		end

		if roleName then
			local role = MuR:GetRole(roleName)
			if role and role.models then
				local modelData = role.models
				if istable(modelData) then
					if modelData.male and modelData.female then
						if gender == MuR.Language["gender_male"] then
							models = modelData.male
						else
							models = modelData.female
						end
					else
						models = modelData
					end
				end
			end
		end

		for k, model in pairs(models) do
			modelList:AddLine(model)
		end
	end

	categoryCombo.OnSelect = function(self, index, text)
		UpdateModelList()
	end

	genderCombo.OnSelect = function(self, index, text)
		UpdateModelList()
	end

	UpdateModelList()

	modelList.OnClickLine = function(parent, line, selected)
		local model = line:GetValue(1)
		modelPreview:SetModel(model)
	end

	local applyButton = vgui.Create("DButton", frame)
	applyButton:SetPos(200, 330)
	applyButton:SetSize(100, 30)
	applyButton:SetText(MuR.Language["disguise_menu_apply"])
	applyButton.DoClick = function()
		local selectedName = nameInput:GetValue()
		local _, isMale = genderCombo:GetSelected()
		local modelPath = modelPreview:GetModel()

		local col = VectorRand(0, 1)

		net.Start("MuR_ApplyDisguise")
		net.WriteString(selectedName)
		net.WriteString(modelPath)
		net.WriteBool(isMale)
		net.WriteVector(col)
		net.SendToServer()

		frame:Close()

		local vm = self:GetOwner():GetViewModel()
		vm:SendViewModelMatchingSequence(vm:LookupSequence("seq_admire_bms_old"))
		self:SetNextIdle(CurTime() + vm:SequenceDuration())
		self:SetNextPrimaryFire(CurTime() + 1)
		self:SetNextSecondaryFire(CurTime() + 1)
	end
end

local checktab = {
	"Civilian",
	"Officer",
	"Security",
	"Medic",
	"Builder"
}

if SERVER then
	util.AddNetworkString("MuR_ApplyDisguise")

	net.Receive("MuR_ApplyDisguise", function(len, ply)
		--
		-- Право на маскировку даёт НАЛИЧИЕ СВЕПА, а не факт отправки сообщения.
		--
		-- Раньше проверок не было никаких: любой клиент мог послать это
		-- сообщение и сменить себе имя, модель и цвет, не имея маскировки
		-- вовсе. Свеп выдаётся ролями (ФБР, предатель, убийца), так что
		-- проверка владения ровно и означает "ему это положено".
		--
		if not IsValid(ply) or not ply:Alive() then return end
		if not ply:HasWeapon("mur_disguise") then return end

		--
		-- Откат тоже не работал: сравнивалось поле DelayBeforeDisguise, а
		-- писалось DelayBeforeDisguice — опечатка в одну букву, из-за которой
		-- условие всегда было ложным, а ограничение существовало только на бумаге.
		-- Плюс сравнивать надо со временем, а не с самим фактом записи.
		--
		if CurTime() < (ply.DelayBeforeDisguise or 0) then return end
		ply.DelayBeforeDisguise = CurTime() + 2

		local name = net.ReadString()
		local model = net.ReadString()
		local isMale = net.ReadBool()
		local col = net.ReadVector()

		local success = false
		for _, roleName in ipairs(checktab) do
			local role = MuR:GetRole(roleName)
			if role and role.models then
				local modelData = role.models
				local modelsToCheck = {}
				if istable(modelData) then
					if modelData.male and modelData.female then
						table.Add(modelsToCheck, modelData.male)
						table.Add(modelsToCheck, modelData.female)
					else
						modelsToCheck = modelData
					end
				end
				if table.HasValue(modelsToCheck, model) then
					success = true
					break
				end
			end
		end
		if !success then return end

		ply.Male = isMale
		ply:SetNewName(name)
		ply:SetPlayerColor(col)
		ply:SetModel(model)
		ply:RandomSkin()
		ply:ScreenFade(SCREENFADE.IN, color_black, 1, 0.1)
		ply:SetupHands()
		ply:RemoveAllDecals()
	end)
end

function SWEP:SecondaryAttack()
	if CLIENT and IsFirstTimePredicted() then
		self:CreateDisguiseMenu()
	end

	self:SetNextSecondaryFire(CurTime() + 1)
end

function SWEP:Reload()
	local vm = self:GetOwner():GetViewModel()
	vm:SendViewModelMatchingSequence(vm:LookupSequence("seq_admire_bms_old"))
	self:SetNextIdle(CurTime() + vm:SequenceDuration())
	self:GetOwner():RemoveAllDecals()
	self:GetOwner():ScreenFade(SCREENFADE.IN, color_black, 1, 0.1)
	self:SetNextPrimaryFire(CurTime() + 1)
	self:SetNextSecondaryFire(CurTime() + 1)
end

function SWEP:Think()
	local vm = self:GetOwner():GetViewModel()

	if self:GetNextIdle() ~= 0 and self:GetNextIdle() < CurTime() then
		vm:SendViewModelMatchingSequence(vm:LookupSequence("reference"))
		self:SetNextIdle(0)
	end
end

function SWEP:OnDrop()
	self:Remove()
end

function SWEP:Deploy()
	local vm = self:GetOwner():GetViewModel()
	vm:SendViewModelMatchingSequence(vm:LookupSequence("reference"))

	return true
end

function SWEP:DrawHUD()
	draw.SimpleText(MuR.Language["loot_disguise_1"], "MuR_Font1", ScrW() / 2, ScrH() - He(90), color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	draw.SimpleText(MuR.Language["loot_disguise_2"], "MuR_Font1", ScrW() / 2, ScrH() - He(75), color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	draw.SimpleText(MuR.Language["loot_disguise_3"], "MuR_Font1", ScrW() / 2, ScrH() - He(60), color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end
SWEP.Category = "Bloodshed - Illegal"
SWEP.Spawnable = true
