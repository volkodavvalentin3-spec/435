local We = We or function(x) return x * (ScrW() / 1920) end
local He = He or function(x) return x * (ScrH() / 1080) end

local UI = MuR.UI
local C = UI.Colors

local function L(key)
	return (MuR.BodyMenuL and MuR.BodyMenuL(key)) or MuR.Language[key] or key
end

local function GetWeaponInfo(class)
	if string.StartWith(class, "mur_armor_") then
		local armorId = string.sub(class, 11)
		local item = MuR.Armor.GetItem(armorId)
		if item then
			local name = MuR.Language["armor_item_" .. armorId] or armorId
			return name, item.icon or "entities/shield.png"
		end
	end

	local swep = weapons.Get(class)
	local icon = file.Exists("materials/entities/" .. class .. ".png", "GAME")
		and "entities/" .. class .. ".png" or "entities/question.png"

	if MuR.Language then
		if MuR.Language["craft_ingredient_" .. class] then
			return MuR.Language["craft_ingredient_" .. class], icon
		elseif MuR.Language["craft_recipe_name_" .. class] then
			return MuR.Language["craft_recipe_name_" .. class], icon
		end
	end

	if string.find(class, "_food_") then icon = "entities/food.png" end

	if swep then
		return swep.PrintName or class, icon
	elseif MuR.CustomLootEntityIcons[class] then
		return MuR.CustomLootEntityIcons[class][1], MuR.CustomLootEntityIcons[class][2]
	end

	return class, icon
end

local searchedItems = {}
MuR.SearchFrames = MuR.SearchFrames or {}

local function CreateTimingMinigame(callback, failCallback, dimFrame)
	local w, h = We(440), He(150)

	local frame = UI.Frame(w, h)
	frame:Center()
	frame:SetKeyboardInputEnabled(true)
	frame.OnKeyCodePressed = nil

	if IsValid(dimFrame) then dimFrame:SetAlpha(60) end

	local trackW = w - We(UI.PAD) * 2
	local trackX = We(UI.PAD)
	local trackY = He(78)
	local trackH = He(14)

	local markerW = math.max(We(3), 2)
	local zoneW = We(58)
	local zoneX = trackW / 2 - zoneW / 2

	local pos = math.Rand(0, trackW - markerW)
	local speed = We(620)
	local dir = math.random(0, 1) == 0 and -1 or 1
	local active = true
	local resolved = false
	local status, statusColor = nil, C.textDim

	frame.OnRemove = function()
		if IsValid(dimFrame) then dimFrame:SetAlpha(255) end
		if not resolved then
			resolved = true
			failCallback()
		end
	end

	local function finish(ok)
		active = false
		resolved = true
		status = L(ok and "search_newhud_perfect" or "search_newhud_missed")
		statusColor = ok and C.accent or C.sev2
		surface.PlaySound(ok and "buttons/lightswitch2.wav" or "buttons/button10.wav")

		timer.Simple(0.45, function()
			if IsValid(frame) then frame:Remove() end
			if IsValid(dimFrame) then dimFrame:SetAlpha(255) end
			if ok then callback() else failCallback() end
		end)

	end

	frame.Paint = function(self, fw, fh)
		UI.Rect(0, 0, fw, fh, C.bg)
		UI.Outline(0, 0, fw, fh, C.line)

		draw.SimpleText(L("search_newhud_tt"), "MuR_Font1", We(UI.PAD), He(20),
			C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

		draw.SimpleText(status or L("search_newhud_space"), "MuR_Font0", We(UI.PAD), He(46),
			status and statusColor or C.textFaint, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

		UI.Rect(trackX, trackY, trackW, trackH, C.lineSoft)

		UI.Rect(trackX + zoneX, trackY, zoneW, trackH, C.accentDim)
		UI.VLine(trackX + zoneX, trackY, trackH, C.accent)
		UI.VLine(trackX + zoneX + zoneW - 1, trackY, trackH, C.accent)

		UI.Outline(trackX, trackY, trackW, trackH, C.line)

		if active then
			UI.Rect(trackX + pos, trackY - He(5), markerW, trackH + He(10), C.text)
		end
	end

	frame.Think = function()
		if not active then return end

		pos = pos + speed * FrameTime() * dir
		if pos <= 0 then
			pos = 0
			dir = 1
		elseif pos >= trackW - markerW then
			pos = trackW - markerW
			dir = -1
		end
	end

	frame.OnKeyCodePressed = function(self, key)
		if key ~= KEY_SPACE or not active then return end

		local centre = pos + markerW / 2
		finish(centre >= zoneX and centre <= zoneX + zoneW)
	end

	return frame
end

MuR.UI.TimingMinigame = CreateTimingMinigame

local CELL = 96
local GAP = 8

local function buildGrid(parent, weaponTable, body, dimFrame)
	local bodyID = body:EntIndex()
	searchedItems[bodyID] = searchedItems[bodyID] or {}

	local pad = We(UI.PAD)

	local header = vgui.Create("DPanel", parent)
	header:Dock(TOP)
	header:SetTall(He(30))
	header:DockMargin(pad, He(12), pad, 0)
	header.Paint = function(self, w, h)
		local found = #weaponTable
		draw.SimpleText(found .. L("search_newhud_found"), "MuR_Font1", 0, h / 2,
			found > 0 and C.text or C.textFaint, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		UI.HLine(0, h - 1, w, C.lineSoft)
	end

	if #weaponTable == 0 then
		local empty = vgui.Create("DPanel", parent)
		empty:Dock(FILL)
		empty.Paint = function(self, w, h)
			draw.SimpleText(L("search_newhud_empty"), "MuR_Font1", w / 2, h / 2,
				C.textFaint, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
		return
	end

	local scroll = vgui.Create("DScrollPanel", parent)
	scroll:Dock(FILL)
	scroll:DockMargin(pad, He(10), pad, He(10))
	UI.Scrollbar(scroll)

	local grid = vgui.Create("DIconLayout", scroll)
	grid:Dock(TOP)
	grid:SetSpaceX(We(GAP))
	grid:SetSpaceY(He(GAP))

	for _, class in ipairs(weaponTable) do
		local name, icon = GetWeaponInfo(class)

		local cell = grid:Add("DButton")
		cell:SetSize(We(CELL), He(CELL + 22))
		cell:SetText("")
		cell.classwep = class
		cell.searched = searchedItems[bodyID][class] or false

		local img = vgui.Create("DImage", cell)
		img:SetSize(We(48), He(48))
		img:SetPos((We(CELL) - We(48)) / 2, He(18))

		local function refresh()
			if cell.searched then
				img:SetImage(icon)
				img:SetVisible(true)
			else
				img:SetVisible(false)
			end
		end

		cell.Paint = function(self, w, h)
			local owned = LocalPlayer():HasWeapon(class)
			local hovered = self:IsHovered() and self:IsEnabled()

			UI.Rect(0, 0, w, h, hovered and C.panelHov or C.panel)

			local border = C.line
			if owned then border = C.lineHot
			elseif hovered then border = C.accent end
			UI.Outline(0, 0, w, h, border)

			if not self.searched then
				draw.SimpleText("?", "MuR_Font4", w / 2, He(42), C.textFaint,
					TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				draw.SimpleText(L("search_newhud_click"), "MuR_Font0", w / 2,
					h - He(14), hovered and C.accent or C.textFaint,
					TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				return
			end

			local col = owned and C.textFaint or C.text
			draw.SimpleText(name, "MuR_Font0", w / 2, h - He(14), col,
				TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end

		local function take()
			if LocalPlayer():HasWeapon(class) then
				surface.PlaySound("buttons/button10.wav")
				return
			end

			surface.PlaySound("buttons/lightswitch2.wav")

			net.Start("MuR.BodySearch")
				net.WriteEntity(body)
				net.WriteString(class)
			net.SendToServer()

			if IsValid(cell) then
				cell:Remove()
				grid:InvalidateLayout(true)
			end
		end

		cell.DoClick = function()
			if cell.searched then take() return end

			if LocalPlayer():HasWeapon(class) then
				surface.PlaySound("buttons/button10.wav")
				return
			end

			cell:SetEnabled(false)

			CreateTimingMinigame(function()
				if not IsValid(cell) then return end
				cell.searched = true
				searchedItems[bodyID][class] = true
				cell:SetEnabled(true)
				refresh()
			end, function()
				if IsValid(cell) then cell:SetEnabled(true) end
			end, dimFrame)
		end

		refresh()
	end
end

local function ShowSearchResults(weaponTable, body)
	local menu = MuR.RagdollMenuOpen

	if IsValid(menu) and menu.Entity == body and MuR.BodyMenuDeliver then
		MuR.BodyMenuDeliver("search", function()
			if not IsValid(menu) or not IsValid(menu.Body) then return end
			menu.Body:Clear()
			menu.Body.Paint = function() end
			buildGrid(menu.Body, weaponTable, body, menu)
		end)
		return
	end

	local bodyID = body:EntIndex()
	if IsValid(MuR.SearchFrames[bodyID]) then MuR.SearchFrames[bodyID]:Remove() end

	local columns = math.Clamp(math.ceil(math.sqrt(math.max(#weaponTable, 1))), 3, 5)
	local w = We(UI.PAD * 2 + columns * CELL + (columns - 1) * GAP + 16)
	local rows = math.max(math.ceil(#weaponTable / columns), 1)
	local h = math.min(He(UI.HEADER + 60 + rows * (CELL + 22 + GAP)), ScrH() * 0.8)

	local frame = UI.Frame(w, h, {KEY_ESCAPE, KEY_E})
	frame:Center()
	MuR.SearchFrames[bodyID] = frame
	frame.OnRemove = function(self)
		MuR.SearchFrames[bodyID] = nil
		UI.ReportPanelClosed(self)
	end

	local subject = UI.SubjectName(body, L("ragdoll_menu_subject_unknown"))

	frame.Paint = function(self, fw, fh)
		UI.Chrome(fw, fh, L("gui_searchmenu"), subject, L("ragdoll_menu_close_key"))
	end

	local content = vgui.Create("DPanel", frame)
	content:SetPos(0, He(UI.HEADER))
	content:SetSize(w, h - He(UI.HEADER))
	content.Paint = function() end

	buildGrid(content, weaponTable, body, frame)
end

net.Receive("MuR.BodySearch", function()
	local tab = net.ReadTable()
	local ent = net.ReadEntity()
	if not IsValid(ent) then return end

	ShowSearchResults(tab, ent)
end)

net.Receive("MuR.RemoveItemFromSearch", function()
	local ent = net.ReadEntity()
	local class = net.ReadString()
	if not IsValid(ent) then return end

	local roots = {MuR.SearchFrames[ent:EntIndex()], MuR.RagdollMenuOpen}

	local function findAndRemove(parent)
		if not IsValid(parent) then return false end

		for _, child in pairs(parent:GetChildren()) do
			if child.classwep == class then
				local layout = child:GetParent()
				child:Remove()
				if IsValid(layout) and layout.InvalidateLayout then
					layout:InvalidateLayout(true)
				end
				return true
			end

			if findAndRemove(child) then return true end
		end

		return false
	end

	for _, root in ipairs(roots) do
		if findAndRemove(root) then break end
	end
end)

net.Receive("MuR.TripwireMinigame", function()
	local ent = net.ReadEntity()
	if not IsValid(ent) then return end

	local function report(ok)
		if not IsValid(ent) then return end
		net.Start("MuR.TripwireResult")
			net.WriteEntity(ent)
			net.WriteBool(ok)
		net.SendToServer()
	end

	CreateTimingMinigame(function() report(true) end, function() report(false) end)
end)
