local CraftingMenu
local ItemDialog
local PlayerInventory = {}
local CurrentTab = "crafting"
local AnimProgress = 0
local SelectedWikiItem = nil
local SelectedRecipe = nil
local IsCrafting = false
local CraftStartTime = 0
local CraftDuration = 0
local CraftingRecipe = nil
local InventoryLimit = 16
local IsBasicMode = false

local glitchTime = 0
local scanlineOffset = 0

local function GetThemeColor(alpha)
	if IsBasicMode then
		return Color(100, 200, 255, alpha or 255)
	else
		return Color(0, 255, 136, alpha or 255)
	end
end

local function GetLang()
	return MuR.Language or {}
end

local categoryNames = {
	["opioids"] = function() return GetLang()["craft_cat_opioids"] or "Opioids" end,
	["hallucinogens"] = function() return GetLang()["craft_cat_hallucinogens"] or "Hallucinogens" end,
	["anesthetics"] = function() return GetLang()["craft_cat_anesthetics"] or "Anesthetics" end,
	["sedatives"] = function() return GetLang()["craft_cat_sedatives"] or "Sedatives" end,
	["stimulants"] = function() return GetLang()["craft_cat_stimulants"] or "Stimulants" end,
	["toxins"] = function() return GetLang()["craft_cat_toxins"] or "Toxins" end,
	["chemical_weapons"] = function() return GetLang()["craft_cat_chemical_weapons"] or "Chemical Weapons" end,
	["medical"] = function() return GetLang()["craft_cat_medical"] or "Medical" end,
}

local function GetIngredientName(itemID)
	local lang = GetLang()
	local key = "craft_ingredient_" .. itemID
	return lang[key] or itemID
end

local function GetWikiData(itemID)
	local lang = GetLang()
	local prefix = "craft_wiki_" .. itemID .. "_"
	local wikiItem = lang[prefix .. "name"]
	if not wikiItem then return nil end

	return {
		name = lang[prefix .. "name"] or itemID,
		formula = lang[prefix .. "formula"] or "N/A",
		latin = lang[prefix .. "latin"] or "N/A",
		category = lang[prefix .. "category"] or "unknown",
		desc = lang[prefix .. "desc"] or "",
		effects = lang[prefix .. "effects"] or {},
		dangers = lang[prefix .. "dangers"] or {},
		synthesis = lang[prefix .. "synthesis"] or "",
		history = lang[prefix .. "history"] or ""
	}
end

local function GetWikiCategories()
	local lang = GetLang()
	local categories = {}
	for k, _ in pairs(lang) do
		local cat = k:match("^craft_wiki_cat_(.+)")
		if cat then
			categories[cat] = true
		end
	end
	return categories
end

local function GetAllWikiItems(medicalOnly)
	local lang = GetLang()
	local items = {}
	local checkedItems = {}
	for k, _ in pairs(lang) do
		local itemID = k:match("^craft_wiki_(.+)%_name$")
		if itemID and not checkedItems[itemID] then
			local data = GetWikiData(itemID)
			if data and not (medicalOnly and data.category ~= "medical") then
				items[itemID] = data
			end
			checkedItems[itemID] = true
		end
	end
	return items
end

local function GetRecipeWikiData(recipeID)
	if not recipeID then return nil end
	local wikiID = recipeID
	if wikiID:sub(1, 4) == "mur_" then
		wikiID = wikiID:sub(5)
	end
	return GetWikiData(wikiID)
end

local function He(x)
	return x * (ScrH() / 1080)
end

local function Wi(x)
	return x * (ScrW() / 1920)
end

surface.CreateFont("MuR_Crafting_Title", {
	font = "Courier New",
	size = He(28),
	weight = 700,
	antialias = true,
})

surface.CreateFont("MuR_Crafting_Header", {
	font = "Courier New",
	size = He(20),
	weight = 700,
	antialias = true,
})

surface.CreateFont("MuR_Crafting_Text", {
	font = "Courier New",
	size = He(16),
	weight = 500,
	antialias = true,
})

surface.CreateFont("MuR_Crafting_Small", {
	font = "Courier New",
	size = He(12),
	weight = 400,
	antialias = true,
})

surface.CreateFont("MuR_Crafting_Mono", {
	font = "Courier New",
	size = He(16),
	weight = 500,
	antialias = true,
})

local blurMat = Material("pp/blurscreen")
local function DrawBlurredRect(x, y, w, h, intensity, passes)
	surface.SetDrawColor(255, 255, 255, 255)
	surface.SetMaterial(blurMat)

	for i = 1, (passes or 6) do
		blurMat:SetFloat("$blur", (i / (passes or 6)) * (intensity or 3))
		blurMat:Recompute()

		render.UpdateScreenEffectTexture()
		surface.DrawTexturedRect(x, y, w, h)
	end
end

local function DrawTabletGlitch(x, y, w, h)
	local ct = CurTime()

	if math.random() < 0.02 then
		glitchTime = ct + 0.1
	end

	if ct < glitchTime then
		local offset = math.random(-3, 3)
		surface.SetDrawColor(0, 255, 136, 2)
		surface.DrawRect(x + offset, y, w, h)
	end

	scanlineOffset = (scanlineOffset + FrameTime() * 200) % h
	for i = 0, h, 4 do
		local yPos = y + ((i + scanlineOffset) % h)
		surface.SetDrawColor(0, 0, 0, 200)
		surface.DrawRect(x, yPos, w, 1)
	end

	local corners = {
		{x, y},
		{x + w, y},
		{x, y + h},
		{x + w, y + h}
	}
	for _, corner in ipairs(corners) do
		surface.SetDrawColor(0, 255, 136, 2)
		surface.DrawRect(corner[1] - 1, corner[2] - 1, 2, 2)
	end
end

local function OpenCraftingMenu(recipes, inventory)
	if IsValid(CraftingMenu) then
		CraftingMenu:Remove()
	end

	PlayerInventory = inventory or {}
	local recipesByCategory = {}
	for _, v in ipairs(recipes) do
		if not recipesByCategory[v.category] then
			recipesByCategory[v.category] = {}
		end
		table.insert(recipesByCategory[v.category], v)
	end

	local scrW, scrH = ScrW(), ScrH()
	local frameW, frameH = Wi(1400), He(900)

	CraftingMenu = vgui.Create("DFrame")
	CraftingMenu:SetSize(frameW, frameH)
	CraftingMenu:SetPos((scrW - frameW) / 2, (scrH - frameH) / 2)
	CraftingMenu:SetTitle("")
	CraftingMenu:ShowCloseButton(false)
	CraftingMenu:SetDraggable(false)
	CraftingMenu:MakePopup()
	CraftingMenu:AlphaTo(0, 0)
	CraftingMenu:AlphaTo(255, 0.4, 0.8)
	LocalPlayer().CraftingMenu = CraftingMenu
	CraftingMenu.Paint = function(s, w, h)

		local anim = AnimProgress
		local easedAnim = anim < 0.5 and (2 * anim * anim) or (-1 + (4 - 2 * anim) * anim)

		DrawBlurredRect(0, 0, w, h, 4, 8)
		draw.RoundedBox(0, 0, 0, w, h, Color(10, 14, 26, 245))

		surface.SetDrawColor(Color(0, 255, 136, 255 * easedAnim))
		surface.DrawOutlinedRect(0, 0, w, h, 2)
		surface.DrawOutlinedRect(3, 3, w - 6, h - 6, 1)

		local lang = GetLang()
		local title = IsBasicMode and (lang["craft_title_basic"] or "◈ BASIC CHEMISTRY ◈") or (lang["craft_title_illegal"] or "◈ CHEMICAL SYNTHESIS ◈")
		local titleColor = IsBasicMode and Color(100, 200, 255, 255 * easedAnim) or Color(0, 255, 136, 255 * easedAnim)
		draw.SimpleText(title, "MuR_Crafting_Title", w / 2, He(35), titleColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		surface.SetDrawColor(IsBasicMode and Color(100, 200, 255, 255 * easedAnim) or Color(0, 255, 136, 255 * easedAnim))
		surface.DrawRect(Wi(30), He(55), w - Wi(60), He(2))
	end
	CraftingMenu.PaintOver = function(s, w, h)
		DrawTabletGlitch(0, 0, w, h)
	end

	local closeBtn = vgui.Create("DButton", CraftingMenu)
	closeBtn:SetSize(He(35), He(35))
	closeBtn:SetPos(frameW - He(50), He(10))
	closeBtn:SetText("")
	closeBtn.hoverAnim = 0
	closeBtn.Paint = function(s, w, h)
		local targetHover = s:IsHovered() and 1 or 0
		s.hoverAnim = Lerp(FrameTime() * 10, s.hoverAnim, targetHover)

		local bgColor = Color(255, 68, 68, s.hoverAnim * 200)
		draw.RoundedBox(0, 0, 0, w, h, bgColor)

		local borderColor = Color(255, 68, 68, 150 + s.hoverAnim * 105)
		surface.SetDrawColor(borderColor)
		surface.DrawOutlinedRect(0, 0, w, h, 2)

		local textColor = Color(255, 68 + s.hoverAnim * 187, 68 + s.hoverAnim * 187)
		draw.SimpleText("✕", "MuR_Crafting_Header", w/2, h/2, textColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	closeBtn.DoClick = function()
		if IsCrafting then
			net.Start("MuR_CancelCraft")
			net.SendToServer()
			IsCrafting = false
			CraftingRecipe = nil
		end

		local wep = LocalPlayer():GetActiveWeapon()
		if IsValid(wep) and (wep:GetClass() == "mur_chemistry_illegal" or wep:GetClass() == "mur_chemistry_basic") then
			wep:CloseAnim()
		end

		CraftingMenu:Close()
	end

	CraftingMenu.OnRemove = function()
		if IsCrafting then
			net.Start("MuR_CancelCraft")
			net.SendToServer()
			IsCrafting = false
			CraftingRecipe = nil
		end

		local wep = LocalPlayer():GetActiveWeapon()
		if IsValid(wep) and (wep:GetClass() == "mur_chemistry_illegal" or wep:GetClass() == "mur_chemistry_basic") then
			wep:CloseAnim()
		end
	end

	AnimProgress = 0
	local animStartTime = SysTime()
	CraftingMenu.Think = function(self)
		local elapsed = SysTime() - animStartTime
		AnimProgress = math.min(elapsed / 0.5, 1)
	end

	local lang = GetLang()
	local tabs = {
		{id = "crafting", name = lang["craft_tab_crafting"] or "SYNTHESIS", icon = "[SYNTH]"},
		{id = "wiki", name = lang["craft_tab_wiki"] or "WIKI", icon = "[WIKI]"},
		{id = "inventory", name = lang["craft_tab_inventory"] or "INVENTORY", icon = "[INV]"}
	}
	local tabContainer = vgui.Create("DPanel", CraftingMenu)
	tabContainer:SetPos(0, He(120))
	tabContainer:SetSize(frameW, frameH - He(120))
	tabContainer.Paint = function() end

	local currentTabPanel
	local function SwitchTab(tabId)

		if IsCrafting and CurrentTab ~= tabId then
			net.Start("MuR_CancelCraft")
			net.SendToServer()
			IsCrafting = false
			CraftingRecipe = nil
		end

		CurrentTab = tabId
		if IsValid(currentTabPanel) then
			currentTabPanel:Remove()
		end
		if tabId == "crafting" then
			currentTabPanel = CreateCraftingTab(tabContainer, recipesByCategory)
			CraftingMenu.CraftingTab = currentTabPanel
		elseif tabId == "wiki" then
			currentTabPanel = CreateWikiTab(tabContainer)
		elseif tabId == "inventory" then
			currentTabPanel = CreateInventoryTab(tabContainer)
		end
	end

	CraftingMenu.SwitchTab = SwitchTab

	for i, tabInfo in ipairs(tabs) do
		local tabButton = vgui.Create("DButton", CraftingMenu)
		local btnWidth = frameW / #tabs - We(5)
		local btnHeight = He(50)
		tabButton:SetPos((i - 1) * btnWidth + We(10), He(70))
		tabButton:SetSize(btnWidth - 2, btnHeight)
		tabButton:SetText("")
		tabButton.hoverAnim = 0

		tabButton.Paint = function(s, w, h)
			local targetHover = s:IsHovered() and 1 or 0
			s.hoverAnim = Lerp(FrameTime() * 8, s.hoverAnim, targetHover)

			local bgColor = CurrentTab == tabInfo.id and Color(0, 255, 136, 255) or Color(26, 31, 53, 255)
			if CurrentTab ~= tabInfo.id and s.hoverAnim > 0 then
				bgColor = Color(37, 43, 69, 255)
			end
			draw.RoundedBox(0, 0, 0, w, h, bgColor)

			if i < #tabs then
				surface.SetDrawColor(Color(0, 255, 136, 200))
				surface.DrawRect(w - 1, 0, 1, h)
			end

			surface.SetDrawColor(Color(0, 255, 136, 255))
			surface.DrawRect(0, h - 2, w, 2)

			local textColor = CurrentTab == tabInfo.id and Color(10, 14, 26) or Color(0, 255, 136)
			draw.SimpleText(tabInfo.icon .. " " .. tabInfo.name, "MuR_Crafting_Text", w / 2, h / 2, textColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end

		tabButton.DoClick = function()
			SwitchTab(tabInfo.id)
		end
	end

	SwitchTab("crafting")
end

net.Receive("MuR_OpenCrafting", function()
	local isBasic = net.ReadBool()
	local recipes = net.ReadTable()
	local inventory = net.ReadTable()
	local limit = net.ReadInt(8)
	InventoryLimit = limit
	IsBasicMode = isBasic
	OpenCraftingMenu(recipes, inventory)
end)

net.Receive("MuR_CraftingUpdate", function()
	PlayerInventory = net.ReadTable()
	if IsValid(CraftingMenu) and CraftingMenu.SwitchTab then

		CraftingMenu.SwitchTab(CurrentTab)
	end
end)

net.Receive("MuR.CraftingMessage", function()
	local msgKey = net.ReadString()
	local lang = GetLang()
	local message = lang[msgKey] or msgKey

	if msgKey == "craft_msg_item_dropped" or msgKey == "craft_msg_item_destroyed" then
		local itemID = net.ReadString()
		local itemName = GetIngredientName(itemID)
		chat.AddText(Color(255, 170, 0), "[SYNTH] ", Color(255, 255, 255), message, Color(0, 255, 136), itemName)
	elseif msgKey == "craft_msg_inventory_full" then
		local limit = net.ReadInt(8)
		chat.AddText(Color(255, 68, 68), "[SYNTH] ", Color(255, 255, 255), message .. limit)
	elseif msgKey == "craft_msg_inventory_partial" then
		local amount = net.ReadInt(8)
		local part2 = lang["craft_msg_inventory_partial2"] or " items (limit)"
		chat.AddText(Color(255, 170, 0), "[SYNTH] ", Color(255, 255, 255), message .. amount .. part2)
	elseif msgKey == "craft_msg_started" then
		local recipeName = net.ReadString()
		chat.AddText(Color(255, 170, 0), "[SYNTH] ", Color(255, 255, 255), message .. recipeName .. "...")
	elseif msgKey == "craft_msg_admin_gave" then
		local amount = net.ReadInt(16)
		local ingredient = net.ReadString()
		chat.AddText(Color(255, 170, 0), "[SYNTH] ", Color(255, 255, 255), message .. amount .. "x " .. ingredient)
	else
		chat.AddText(Color(255, 170, 0), "[SYNTH] ", Color(255, 255, 255), message)
	end
end)

net.Receive("MuR_CraftComplete", function()
	local success = net.ReadBool()
	local recipeName = net.ReadString()
	local lang = GetLang()

	IsCrafting = false
	CraftingRecipe = nil
	CraftStartTime = 0
	CraftDuration = 0

	if success then
		chat.AddText(Color(0, 255, 136), "[SYNTH] ", Color(255, 255, 255), lang["craft_msg_success"] or "Successfully crafted: ", Color(0, 255, 136), recipeName)
		surface.PlaySound("items/battery_pickup.wav")
	else
		chat.AddText(Color(255, 68, 68), "[SYNTH] ", Color(255, 255, 255), lang["craft_msg_failed"] or "Crafting failed: ", Color(255, 68, 68), recipeName)
		surface.PlaySound("buttons/button10.wav")
	end
end)

net.Receive("MuR_CraftCancelled", function()
	IsCrafting = false
	CraftingRecipe = nil
	CraftStartTime = 0
	CraftDuration = 0
end)

function CreateCraftingTab(parent, recipesByCategory)
	local panel = vgui.Create("DPanel", parent)
	panel:Dock(FILL)
	panel.Paint = function() end

	local listWidth = Wi(300)

	local listPanel = vgui.Create("DPanel", panel)
	listPanel:Dock(LEFT)
	listPanel:SetWide(listWidth)
	listPanel:DockMargin(Wi(20), He(20), Wi(10), He(20))
	listPanel.Paint = function(s, w, h)
		draw.RoundedBox(0, 0, 0, w, h, Color(26, 31, 53, 255))
		surface.SetDrawColor(Color(0, 255, 136, 255))
		surface.DrawOutlinedRect(0, 0, w, h, 1)
	end

	local scroll = vgui.Create("DScrollPanel", listPanel)
	scroll:Dock(FILL)
	scroll:DockMargin(Wi(10), He(10), Wi(10), He(10))

	local sbar = scroll:GetVBar()
	sbar:SetWide(He(8))
	sbar:SetHideButtons(true)
	function sbar:Paint(w, h)
		draw.RoundedBox(0, 0, 0, w, h, Color(10, 14, 26, 255))
	end
	function sbar.btnGrip:Paint(w, h)
		draw.RoundedBox(0, 0, 0, w, h, Color(0, 255, 136, 200))
	end

	local infoPanel = vgui.Create("DPanel", panel)
	infoPanel:Dock(FILL)
	infoPanel:DockMargin(Wi(10), He(20), Wi(20), He(20))
	infoPanel.Paint = function(s, w, h)
		draw.RoundedBox(0, 0, 0, w, h, Color(26, 31, 53, 255))
		surface.SetDrawColor(Color(0, 255, 136, 255))
		surface.DrawOutlinedRect(0, 0, w, h, 1)

		if not SelectedRecipe then
			local lang = GetLang()
			draw.SimpleText(lang["craft_select_recipe"] or "Select a recipe from the list", "MuR_Crafting_Header", w/2, h/2, Color(136, 255, 170), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		else
			local recipe = SelectedRecipe
			local pad = He(25)
			local yPos = pad
			local lang = GetLang()
	 		local wikiData = GetRecipeWikiData(recipe.id)

			local displayName = wikiData and wikiData.name or recipe.name
			draw.SimpleText(displayName, "MuR_Crafting_Title", pad, yPos, Color(0, 255, 136), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			yPos = yPos + He(40)

			if wikiData then
				if wikiData.formula and wikiData.formula ~= "" then
					draw.SimpleText(wikiData.formula, "MuR_Crafting_Header", pad, yPos, Color(0, 255, 204), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
					yPos = yPos + He(25)
				end
				if wikiData.latin and wikiData.latin ~= "" then
					draw.SimpleText(wikiData.latin, "MuR_Crafting_Small", pad, yPos, Color(136, 255, 170), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
					yPos = yPos + He(30)
				end
			end

			draw.SimpleText(lang["craft_recipe_description"] or "DESCRIPTION", "MuR_Crafting_Text", pad, yPos, Color(0, 255, 136), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			yPos = yPos + He(25)
			local displayDesc = (wikiData and wikiData.desc) or recipe.desc
			local descLines = WrapText(displayDesc, "MuR_Crafting_Small", w - pad * 2)
			for _, line in ipairs(descLines) do
				draw.SimpleText(line, "MuR_Crafting_Small", pad, yPos, Color(136, 255, 170), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
				yPos = yPos + He(18)
			end
			yPos = yPos + He(25)

			draw.SimpleText("▸ " .. (lang["craft_recipe_difficulty"] or "Difficulty") .. ": " .. math.floor(recipe.difficulty * 100) .. "%", "MuR_Crafting_Text", pad, yPos, Color(255, 170, 0), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			yPos = yPos + He(35)

			draw.SimpleText(lang["craft_recipe_ingredients"] or "REQUIRED INGREDIENTS", "MuR_Crafting_Text", pad, yPos, Color(0, 255, 136), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			yPos = yPos + He(25)

			if recipe.reqs and #recipe.reqs > 0 then
				for i, req in ipairs(recipe.reqs) do
					local has = PlayerInventory[req.item] or 0
					local color = has >= req.amount and Color(0, 255, 136) or Color(255, 68, 68)
					local icon = has >= req.amount and "[+]" or "[-]"
					local statusText = has >= req.amount and (lang["craft_has"] or "HAS") or (lang["craft_missing"] or "MISSING")

					local ingredientName = GetIngredientName(req.item)

					draw.SimpleText(icon .. " " .. ingredientName, "MuR_Crafting_Small", pad, yPos, color, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
					draw.SimpleText(has .. "/" .. req.amount, "MuR_Crafting_Small", w - pad - Wi(100), yPos, color, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
					draw.SimpleText(statusText, "MuR_Crafting_Small", w - pad, yPos, color, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
					yPos = yPos + He(22)
				end
			else
				draw.SimpleText(lang["craft_msg_no_ingredients"] or "No ingredients required", "MuR_Crafting_Small", pad, yPos, Color(136, 255, 170), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
				yPos = yPos + He(22)
			end
		end
	end

	local buyButton = vgui.Create("DButton", infoPanel)
	buyButton:SetSize(Wi(300), He(60))
	buyButton:SetText("")
	buyButton.hoverAnim = 0

	buyButton.Think = function(s)
		local _, ph = infoPanel:GetSize()
		s:SetPos(He(25), ph - He(180))
	end

	buyButton.Paint = function(s, w, h)
		if not SelectedRecipe then return end
		if IsCrafting then return end

		local missingCount = 0
		local totalCount = 0

		if SelectedRecipe.reqs then
			for _, req in ipairs(SelectedRecipe.reqs) do
				totalCount = totalCount + req.amount
				local has = PlayerInventory[req.item] or 0
				if has < req.amount then
					missingCount = missingCount + (req.amount - has)
				end
			end
		end

		if missingCount == 0 then return end

		local price = math.ceil(200 * (missingCount / totalCount))
		local canAfford = LocalPlayer():GetNW2Float("Money") >= price

		local targetHover = s:IsHovered() and 1 or 0
		s.hoverAnim = Lerp(FrameTime() * 8, s.hoverAnim, targetHover)

		local col = canAfford and Color(0, 200, 255) or Color(255, 68, 68)
		local bgCol = Color(26, 31, 53, 255)

		draw.RoundedBox(0, 0, 0, w, h, bgCol)

		if s:IsHovered() and canAfford then
			draw.RoundedBox(0, 0, 0, w, h, Color(0, 200, 255, 20))
		end

		surface.SetDrawColor(col)
		surface.DrawOutlinedRect(0, 0, w, h, 2)

		local lang = GetLang()
		draw.SimpleText(lang["craft_buy_reagents"] or "BUY REAGENTS", "MuR_Crafting_Text", w/2, h/2 - He(10), col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText(price .. "$", "MuR_Crafting_Small", w/2, h/2 + He(15), Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	buyButton.DoClick = function(s)
		if not SelectedRecipe then return end

		local missingCount = 0
		local totalCount = 0

		if SelectedRecipe.reqs then
			for _, req in ipairs(SelectedRecipe.reqs) do
				totalCount = totalCount + req.amount
				local has = PlayerInventory[req.item] or 0
				if has < req.amount then
					missingCount = missingCount + (req.amount - has)
				end
			end
		end

		if missingCount == 0 then return end

		local price = math.ceil(200 * (missingCount / totalCount))
		if LocalPlayer():GetNW2Float("Money") >= price then
			net.Start("MuR_BuyReagents")
			net.WriteString(SelectedRecipe.id)
			net.SendToServer()
			surface.PlaySound("murdered/vgui/ui_click.wav")
		else
			surface.PlaySound("buttons/button10.wav")
		end
	end

	local craftButton = vgui.Create("DButton", infoPanel)
	craftButton:SetSize(Wi(300), He(80))
	craftButton:SetText("")
	craftButton.hoverAnim = 0

	craftButton.Think = function(s)
		local _, ph = infoPanel:GetSize()
		s:SetPos(He(25), ph - He(110))
	end

	craftButton.Paint = function(s, w, h)
		if not SelectedRecipe then return end

		local targetHover = s:IsHovered() and 1 or 0
		s.hoverAnim = Lerp(FrameTime() * 8, s.hoverAnim, targetHover)
		local lang = GetLang()

		local isCraftingThis = IsCrafting and CraftingRecipe and CraftingRecipe.id == SelectedRecipe.id

		if isCraftingThis then

			local progress = math.Clamp((CurTime() - CraftStartTime) / CraftDuration, 0, 1)

			draw.RoundedBox(0, 0, 0, w, h, Color(26, 31, 53, 255))

			local barW = (w - 4) * progress
			draw.RoundedBox(0, 2, 2, barW, h - 4, Color(0, 255, 136, 100))

			surface.SetDrawColor(Color(0, 255, 136, 255))
			surface.DrawOutlinedRect(0, 0, w, h, 2)

			local timeLeft = math.ceil(CraftDuration - (CurTime() - CraftStartTime))
			draw.SimpleText((lang["craft_status_crafting"] or "[CRAFTING]"), "MuR_Crafting_Text", w/2, h/2 - He(15), Color(0, 255, 136), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText(math.floor(progress * 100) .. "% - " .. timeLeft .. (lang["craft_recipe_sec"] or " sec"), "MuR_Crafting_Small", w/2, h/2 + He(5), Color(136, 255, 170), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText((lang["craft_status_cancel_hint"] or "[CLICK TO CANCEL]"), "MuR_Crafting_Small", w/2, h/2 + He(25), Color(255, 136, 136, 150), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

			return
		end

		local canCraft = true
		if SelectedRecipe.reqs and #SelectedRecipe.reqs > 0 then
			for _, req in ipairs(SelectedRecipe.reqs) do
				if (PlayerInventory[req.item] or 0) < req.amount then
					canCraft = false
					break
				end
			end
		end

		local bgColor = canCraft and Color(0, 0, 0, 0) or Color(0, 0, 0, 0)
		local borderColor = canCraft and Color(0, 255, 136, 255) or Color(255, 68, 68, 255)
		local textCol = canCraft and Color(0, 255, 136) or Color(255, 136, 136)

		if canCraft and s.hoverAnim > 0 then
			bgColor = Color(0, 255, 136, 255)
			textCol = Color(10, 14, 26)
		end

		draw.RoundedBox(0, 0, 0, w, h, bgColor)
		surface.SetDrawColor(borderColor)
		surface.DrawOutlinedRect(0, 0, w, h, 2)
		draw.SimpleText("[CRAFT]", "MuR_Crafting_Text", w/2, h/2 - He(10), textCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText((lang["craft_button_craft"] or "SYNTHESIZE"), "MuR_Crafting_Small", w/2, h/2 + He(10), textCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	craftButton.DoClick = function()
		if not SelectedRecipe then return end

		if IsCrafting and CraftingRecipe and CraftingRecipe.id == SelectedRecipe.id then
			net.Start("MuR_CancelCraft")
			net.SendToServer()
			IsCrafting = false
			CraftingRecipe = nil
			return
		end

		local canCraft = true
		if SelectedRecipe.reqs and #SelectedRecipe.reqs > 0 then
			for _, req in ipairs(SelectedRecipe.reqs) do
				if (PlayerInventory[req.item] or 0) < req.amount then
					canCraft = false
					break
				end
			end
		end

		if not IsCrafting and canCraft then
			net.Start("MuR_StartCraft")
			net.WriteString(SelectedRecipe.id)
			net.SendToServer()

			IsCrafting = true
			CraftStartTime = CurTime()
			CraftDuration = SelectedRecipe.craftTime or 10
			CraftingRecipe = SelectedRecipe
		end
	end

	local y = 0
	local sortedCategories = {}
	for catId, _ in pairs(recipesByCategory) do
		table.insert(sortedCategories, catId)
	end
	table.sort(sortedCategories, function(a, b)
		local nameA = categoryNames[a] and categoryNames[a]() or a
		local nameB = categoryNames[b] and categoryNames[b]() or b
		return nameA < nameB
	end)

	for _, catId in ipairs(sortedCategories) do
		local catName = categoryNames[catId] and categoryNames[catId]() or catId
		local header = vgui.Create("DLabel", scroll)
		header:SetPos(0, y)
		header:SetFont("MuR_Crafting_Text")
		header:SetText("▸ " .. catName)
		header:SetTextColor(Color(0, 255, 136))
		header:SizeToContents()
		y = y + header:GetTall() + He(5)

		table.sort(recipesByCategory[catId], function(a, b)
			local wikiA = GetRecipeWikiData(a.id)
			local wikiB = GetRecipeWikiData(b.id)
			local nameA = (wikiA and wikiA.name) or a.name or ""
			local nameB = (wikiB and wikiB.name) or b.name or ""
			return nameA < nameB
		end)

		for _, recipe in ipairs(recipesByCategory[catId]) do
			local recipeButton = vgui.Create("DButton", scroll)
			recipeButton:SetPos(Wi(10), y)
			recipeButton:SetSize(Wi(250), He(30))
			recipeButton:SetText("")
			recipeButton.hoverAnim = 0
			recipeButton.Paint = function(s, w, h)
				local isHovered = s:IsHovered()
				local targetHover = isHovered and 1 or 0
				s.hoverAnim = Lerp(FrameTime() * 10, s.hoverAnim, targetHover)

				local bgColor
				if SelectedRecipe and SelectedRecipe.id == recipe.id then
					bgColor = Color(0, 255, 136, 255)
				elseif isHovered or s.hoverAnim > 0.01 then
					local alpha = math.floor(255 * s.hoverAnim)
					bgColor = Color(37, 43, 69, alpha)
				else
					bgColor = Color(26, 31, 53, 255)
				end
				draw.RoundedBox(0, 0, 0, w, h, bgColor)

				surface.SetDrawColor(Color(0, 255, 136, 100))
				surface.DrawRect(0, h - 1, w, 1)

				local textColor = (SelectedRecipe and SelectedRecipe.id == recipe.id) and Color(10, 14, 26) or Color(136, 255, 170)
				local wikiData = GetRecipeWikiData(recipe.id)
				local displayName = (wikiData and wikiData.name) or recipe.name
				draw.SimpleText(displayName, "MuR_Crafting_Small", He(10), h/2, textColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			end
			recipeButton.DoClick = function()
				SelectedRecipe = recipe
			end
			y = y + recipeButton:GetTall() + He(5)
		end
		y = y + He(10)
	end

	return panel
end

function CreateWikiTab(parent)
	local panel = vgui.Create("DPanel", parent)
	panel:Dock(FILL)
	panel.Paint = function() end

	local listWidth = Wi(300)

	local listPanel = vgui.Create("DPanel", panel)
	listPanel:Dock(LEFT)
	listPanel:SetWide(listWidth)
	listPanel:DockMargin(Wi(20), He(20), Wi(10), He(20))
	listPanel.Paint = function(s, w, h)
		draw.RoundedBox(0, 0, 0, w, h, Color(26, 31, 53, 255))
		surface.SetDrawColor(Color(0, 255, 136, 255))
		surface.DrawOutlinedRect(0, 0, w, h, 1)
	end

	local scroll = vgui.Create("DScrollPanel", listPanel)
	scroll:Dock(FILL)
	scroll:DockMargin(Wi(10), He(10), Wi(10), He(10))

	local sbar = scroll:GetVBar()
	sbar:SetWide(He(8))
	sbar:SetHideButtons(true)
	function sbar:Paint(w, h)
		draw.RoundedBox(0, 0, 0, w, h, Color(10, 14, 26, 255))
	end
	function sbar.btnGrip:Paint(w, h)
		draw.RoundedBox(0, 0, 0, w, h, Color(0, 255, 136, 200))
	end

	local infoPanel = vgui.Create("DPanel", panel)
	infoPanel:Dock(FILL)
	infoPanel:DockMargin(Wi(10), He(20), Wi(20), He(20))
	infoPanel.Paint = function(s, w, h)
		draw.RoundedBox(0, 0, 0, w, h, Color(26, 31, 53, 255))
		surface.SetDrawColor(Color(0, 255, 136, 255))
		surface.DrawOutlinedRect(0, 0, w, h, 1)

		if not SelectedWikiItem then
			local lang = GetLang()
			draw.SimpleText(lang["craft_select_item"] or "Select an item from the list", "MuR_Crafting_Header", w/2, h/2, Color(136, 255, 170), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		else
			local item = GetWikiData(SelectedWikiItem)
			if not item then return end

			local pad = He(25)
			local yPos = pad
			local lang = GetLang()

			draw.SimpleText(item.name, "MuR_Crafting_Title", pad, yPos, Color(0, 255, 136), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			yPos = yPos + He(35)

			draw.SimpleText(item.formula, "MuR_Crafting_Header", pad, yPos, Color(0, 255, 204), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			yPos = yPos + He(25)
			draw.SimpleText(item.latin, "MuR_Crafting_Small", pad, yPos, Color(136, 255, 170), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			yPos = yPos + He(30)

			draw.SimpleText(lang["craft_wiki_description"] or "DESCRIPTION", "MuR_Crafting_Text", pad, yPos, Color(0, 255, 136), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			yPos = yPos + He(25)
			local descLines = WrapText(item.desc, "MuR_Crafting_Small", w - pad * 2)
			for _, line in ipairs(descLines) do
				draw.SimpleText(line, "MuR_Crafting_Small", pad, yPos, Color(136, 255, 170), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
				yPos = yPos + He(18)
			end
			yPos = yPos + He(20)

			local col1 = pad
			local col2 = w / 2 + pad/2
			local colWidth = w/2 - pad*1.5

			draw.SimpleText(lang["craft_wiki_effects_title"] or "[!] EFFECTS", "MuR_Crafting_Text", col1, yPos, Color(0, 255, 136), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			local effY = yPos + He(25)
			if item.effects and #item.effects > 0 then
				for _, effect in ipairs(item.effects) do
					draw.SimpleText("• " .. effect, "MuR_Crafting_Small", col1, effY, Color(136, 255, 170), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
					effY = effY + He(18)
				end
			end

			draw.SimpleText(lang["craft_wiki_dangers_title"] or "[!] DANGERS", "MuR_Crafting_Text", col2, yPos, Color(255, 170, 0), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			local danY = yPos + He(25)
			if item.dangers and #item.dangers > 0 then
				for _, danger in ipairs(item.dangers) do
					draw.SimpleText("• " .. danger, "MuR_Crafting_Small", col2, danY, Color(255, 170, 0), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
					danY = danY + He(18)
				end
			end

			yPos = math.max(effY, danY) + He(25)

			draw.SimpleText(lang["craft_wiki_synthesis"] or "SYNTHESIS METHODS", "MuR_Crafting_Text", pad, yPos, Color(0, 255, 136), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			yPos = yPos + He(25)
			local synthLines = WrapText(item.synthesis, "MuR_Crafting_Small", w - pad * 2)
			for _, line in ipairs(synthLines) do
				draw.SimpleText(line, "MuR_Crafting_Small", pad, yPos, Color(136, 255, 170), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
				yPos = yPos + He(18)
			end
			yPos = yPos + He(25)

			draw.SimpleText(lang["craft_wiki_history"] or "HISTORY", "MuR_Crafting_Text", pad, yPos, Color(0, 255, 136), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			yPos = yPos + He(25)
			local histLines = WrapText(item.history, "MuR_Crafting_Small", w - pad * 2)
			for _, line in ipairs(histLines) do
				draw.SimpleText(line, "MuR_Crafting_Small", pad, yPos, Color(136, 255, 170), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
				yPos = yPos + He(18)
			end
		end
	end

	local y = 0
	local wikiData = GetAllWikiItems(IsBasicMode)
	local sortedWiki = {}
	for id, data in pairs(wikiData) do
		table.insert(sortedWiki, {id = id, name = data.name, category = data.category})
	end
	table.sort(sortedWiki, function(a, b) return a.name < b.name end)

	local itemsByCategory = {}
	for _, item in ipairs(sortedWiki) do
		if not itemsByCategory[item.category] then
			itemsByCategory[item.category] = {}
		end
		table.insert(itemsByCategory[item.category], item)
	end

	local sortedCategories = {}
	for catId, _ in pairs(itemsByCategory) do
		table.insert(sortedCategories, catId)
	end
	table.sort(sortedCategories, function(a, b)
		local nameA = categoryNames[a] and categoryNames[a]() or a
		local nameB = categoryNames[b] and categoryNames[b]() or b
		return nameA < nameB
	end)

	for _, catId in ipairs(sortedCategories) do
		local catName = categoryNames[catId] and categoryNames[catId]() or catId
		local header = vgui.Create("DLabel", scroll)
		header:SetPos(0, y)
		header:SetFont("MuR_Crafting_Text")
		header:SetText("▸ " .. catName)
		header:SetTextColor(Color(0, 255, 136))
		header:SizeToContents()
		y = y + header:GetTall() + He(5)

		for _, item in ipairs(itemsByCategory[catId]) do
			local itemButton = vgui.Create("DButton", scroll)
			itemButton:SetPos(Wi(10), y)
			itemButton:SetSize(Wi(250), He(30))
			itemButton:SetText("")
			itemButton.hoverAnim = 0
			itemButton.Paint = function(s, w, h)
				local isHovered = s:IsHovered()
				local targetHover = isHovered and 1 or 0
				s.hoverAnim = Lerp(FrameTime() * 10, s.hoverAnim, targetHover)

				local bgColor
				if SelectedWikiItem == item.id then
					bgColor = Color(0, 255, 136, 255)
				elseif isHovered or s.hoverAnim > 0.01 then
					local alpha = math.floor(255 * s.hoverAnim)
					bgColor = Color(37, 43, 69, alpha)
				else
					bgColor = Color(26, 31, 53, 255)
				end
				draw.RoundedBox(0, 0, 0, w, h, bgColor)

				surface.SetDrawColor(Color(0, 255, 136, 100))
				surface.DrawRect(0, h - 1, w, 1)

				local textColor = SelectedWikiItem == item.id and Color(10, 14, 26) or Color(136, 255, 170)
				draw.SimpleText(item.name, "MuR_Crafting_Small", He(10), h/2, textColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			end
			itemButton.DoClick = function()
				SelectedWikiItem = item.id
			end
			y = y + itemButton:GetTall() + He(5)
		end
		y = y + He(10)
	end

	return panel
end

function CreateInventoryTab(parent)
	local panel = vgui.Create("DPanel", parent)
	panel:Dock(FILL)
	panel.Paint = function(s, w, h)
		local lang = GetLang()
		draw.RoundedBox(0, Wi(20), He(20), w - Wi(40), h - He(40), Color(26, 31, 53, 255))
		surface.SetDrawColor(Color(0, 255, 136, 255))
		surface.DrawOutlinedRect(Wi(20), He(20), w - Wi(40), h - He(40), 1)
		draw.SimpleText(lang["craft_inventory_player"] or "PLAYER INVENTORY", "MuR_Crafting_Header", w/2, He(50), Color(0, 255, 136), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		local totalItems = 0
		for _, count in pairs(PlayerInventory) do
			totalItems = totalItems + count
		end

		local countText = (lang["craft_inventory_items"] or "Items: ") .. totalItems .. " / " .. InventoryLimit
		draw.SimpleText(countText, "MuR_Crafting_Text", w/2, He(80), Color(136, 255, 170), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	local scroll = vgui.Create("DScrollPanel", panel)
	scroll:Dock(FILL)
	scroll:DockMargin(Wi(40), He(110), Wi(40), He(40))

	local sbar = scroll:GetVBar()
	sbar:SetWide(He(10))
	sbar:SetHideButtons(true)
	function sbar:Paint(w, h)
		draw.RoundedBox(0, 0, 0, w, h, Color(10, 14, 26, 255))
	end
	function sbar.btnGrip:Paint(w, h)
		draw.RoundedBox(0, 0, 0, w, h, Color(0, 255, 136, 200))
	end

	local grid = vgui.Create("DIconLayout", scroll)
	grid:Dock(FILL)
	grid:SetSpaceY(He(20))
	grid:SetSpaceX(He(20))

	local itemSize = He(120)
	for item, count in pairs(PlayerInventory) do
		if count > 0 then
			local itemPanel = vgui.Create("DButton", grid)
			itemPanel:SetSize(itemSize, itemSize)
			itemPanel:SetText("")
			itemPanel.hoverAnim = 0
			itemPanel.Paint = function(s, w, h)
				local targetHover = s:IsHovered() and 1 or 0
				s.hoverAnim = Lerp(FrameTime() * 8, s.hoverAnim, targetHover)

				draw.RoundedBox(0, 0, 0, w, h, Color(26, 31, 53, 255))
				local borderColor = Color(0, 255, 136, 150 + s.hoverAnim * 105)
				surface.SetDrawColor(borderColor)
				surface.DrawOutlinedRect(0, 0, w, h, 2)

				local iconSize = He(60)
				local iconX = (w - iconSize) / 2
				local iconY = He(15)
				draw.RoundedBox(0, iconX, iconY, iconSize, iconSize, Color(10, 14, 26, 255))
				surface.SetDrawColor(Color(0, 255, 136, 255))
				surface.DrawOutlinedRect(iconX, iconY, iconSize, iconSize, 1)
				draw.SimpleText("◈ "..count, "MuR_Crafting_Title", w/2, iconY + iconSize/2, Color(0, 255, 136), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

				local displayName = GetIngredientName(item)
				draw.SimpleText(displayName, "MuR_Crafting_Small", w/2, h - He(25), Color(136, 255, 170), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end
			itemPanel.DoClick = function()
				OpenItemDialog(item, count)
			end
		end
	end

	return panel
end

function OpenItemDialog(itemID, itemCount)
	if IsValid(ItemDialog) then
		ItemDialog:Remove()
	end

	local dialogW = Wi(500)
	local dialogH = He(320)

	ItemDialog = vgui.Create("DFrame")
	ItemDialog:SetSize(dialogW, dialogH)
	ItemDialog:Center()
	ItemDialog:SetTitle("")
	ItemDialog:SetDraggable(true)
	ItemDialog:ShowCloseButton(false)
	ItemDialog:MakePopup()
	ItemDialog.Paint = function(s, w, h)

		DrawBlurredRect(0, 0, w, h, 3)

		draw.RoundedBox(0, 0, 0, w, h, Color(10, 14, 26, 240))

		surface.SetDrawColor(Color(0, 255, 136, 255))
		surface.DrawOutlinedRect(0, 0, w, h, 2)

		draw.RoundedBox(0, 0, 0, w, He(60), Color(0, 255, 136, 20))
		surface.SetDrawColor(Color(0, 255, 136, 255))
		surface.DrawLine(0, He(60), w, He(60))

		local itemName = GetIngredientName(itemID)
		draw.SimpleText(itemName, "MuR_Crafting_Header", w/2, He(30), Color(0, 255, 136), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	local closeBtn = vgui.Create("DButton", ItemDialog)
	closeBtn:SetSize(He(35), He(35))
	closeBtn:SetPos(dialogW - He(40), He(5))
	closeBtn:SetText("")
	closeBtn.hoverAnim = 0
	closeBtn.Paint = function(s, w, h)
		local targetHover = s:IsHovered() and 1 or 0
		s.hoverAnim = Lerp(FrameTime() * 10, s.hoverAnim, targetHover)

		local bgAlpha = 50 + s.hoverAnim * 100
		draw.RoundedBox(0, 0, 0, w, h, Color(255, 68, 68, bgAlpha))
		surface.SetDrawColor(Color(255, 68, 68, 255))
		surface.DrawOutlinedRect(0, 0, w, h, 1)

		local crossColor = Color(255, 200, 200, 255)
		surface.SetDrawColor(crossColor)
		local pad = He(8)
		surface.DrawLine(pad, pad, w - pad, h - pad)
		surface.DrawLine(w - pad, pad, pad, h - pad)
	end
	closeBtn.DoClick = function()
		ItemDialog:Remove()
	end

	local lang = GetLang()
	local infoText = vgui.Create("DLabel", ItemDialog)
	infoText:SetPos(He(20), He(80))
	infoText:SetSize(dialogW - He(40), He(80))
	infoText:SetFont("MuR_Crafting_Text")
	infoText:SetTextColor(Color(136, 255, 170))
	infoText:SetText((lang["craft_item_quantity"] or "Quantity: ") .. itemCount .. (lang["craft_item_count"] or " pcs.") .. "\n\n" .. (lang["craft_item_action"] or "Select an action:"))
	infoText:SetContentAlignment(7)

	local dropBtn = vgui.Create("DButton", ItemDialog)
	dropBtn:SetSize(dialogW - He(40), He(60))
	dropBtn:SetPos(He(20), He(180))
	dropBtn:SetText("")
	dropBtn.hoverAnim = 0
	dropBtn.Paint = function(s, w, h)
		local targetHover = s:IsHovered() and 1 or 0
		s.hoverAnim = Lerp(FrameTime() * 8, s.hoverAnim, targetHover)

		local bgColor = Color(0, 0, 0, 0)
		local borderColor = Color(0, 255, 136, 255)
		local textCol = Color(0, 255, 136)

		if s.hoverAnim > 0 then
			bgColor = Color(0, 255, 136, math.floor(50 * s.hoverAnim))
		end

		local lang = GetLang()
		draw.RoundedBox(0, 0, 0, w, h, bgColor)
		surface.SetDrawColor(borderColor)
		surface.DrawOutlinedRect(0, 0, w, h, 2)
		draw.SimpleText((lang["craft_button_drop_full"] or "[DROP] DROP ITEM"), "MuR_Crafting_Text", w/2, h/2, textCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	dropBtn.DoClick = function()
		net.Start("MuR_DropItem")
		net.WriteString(itemID)
		net.SendToServer()
		ItemDialog:Remove()
	end

	local destroyBtn = vgui.Create("DButton", ItemDialog)
	destroyBtn:SetSize(dialogW - He(40), He(60))
	destroyBtn:SetPos(He(20), He(250))
	destroyBtn:SetText("")
	destroyBtn.hoverAnim = 0
	destroyBtn.Paint = function(s, w, h)
		local targetHover = s:IsHovered() and 1 or 0
		s.hoverAnim = Lerp(FrameTime() * 8, s.hoverAnim, targetHover)

		local bgColor = Color(0, 0, 0, 0)
		local borderColor = Color(255, 68, 68, 255)
		local textCol = Color(255, 136, 136)

		if s.hoverAnim > 0 then
			bgColor = Color(255, 68, 68, math.floor(50 * s.hoverAnim))
		end

		local lang = GetLang()
		draw.RoundedBox(0, 0, 0, w, h, bgColor)
		surface.SetDrawColor(borderColor)
		surface.DrawOutlinedRect(0, 0, w, h, 2)
		draw.SimpleText((lang["craft_button_destroy_full"] or "[DELETE] DESTROY ITEM"), "MuR_Crafting_Text", w/2, h/2, textCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	destroyBtn.DoClick = function()
		net.Start("MuR_DestroyItem")
		net.WriteString(itemID)
		net.SendToServer()
		ItemDialog:Remove()
	end
end

function WrapText(text, font, maxWidth)
	if not text or text == "" then return {} end

	local lines = {}
	local currentLine = ""
	local words = string.Split(text, " ")

	surface.SetFont(font)
	for _, word in ipairs(words) do
		local testLine = currentLine == "" and word or (currentLine .. " " .. word)
		local w, _ = surface.GetTextSize(testLine)
		if w > maxWidth then
			if currentLine ~= "" then
				table.insert(lines, currentLine)
			end
			currentLine = word
		else
			currentLine = testLine
		end
	end
	if currentLine ~= "" then
		table.insert(lines, currentLine)
	end
	return lines
end

local blackScreenAlpha = 0
hook.Add("HUDPaint", "MuR_DrawCraftingMenuBlackBehind", function()
	local targetAlpha = IsValid(LocalPlayer().CraftingMenu) and LocalPlayer().CraftingMenu:GetAlpha() > 0 and 240 or 0
	blackScreenAlpha = Lerp(FrameTime() * 8, blackScreenAlpha, targetAlpha)

	if blackScreenAlpha > 1 then
		surface.SetDrawColor(0, 0, 0, blackScreenAlpha)
		surface.DrawRect(0, 0, ScrW(), ScrH())
	end
end)
