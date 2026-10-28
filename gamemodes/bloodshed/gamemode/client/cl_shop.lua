local We = We or function(x) return x * (ScrW() / 1920) end
local He = He or function(x) return x * (ScrH() / 1080) end

local UI = MuR.UI

local shop_select_panel = nil

local FRAME_W, FRAME_H = 880, 620
local CARD_W, CARD_H = 400, 92

local function L(key)
	return (MuR.Language and MuR.Language[key]) or key
end

hook.Add("Think", "MuR_Shop", function()
	if input.IsKeyDown(KEY_F2) and not IsValid(shop_select_panel) then
		RunConsoleCommand("mur_shop")
	end
end)

net.Receive("MuR.SyncShopCounts", function()
	LocalPlayer().ShopPurchases = net.ReadTable()
end)

local CATEGORIES = {
	{id = "Civilian", label = "shop_cat_civilian", allowed = function() return true end},
	{
		id = "Killer", label = "shop_cat_killer",
		allowed = function()
			local ply = LocalPlayer()
			local class = ply:GetNW2String("Class")
			local restricted = class == "Maniac" or class == "Attacker"
				or class == "Terrorist2" or class == "Soldier"
			return (ply:IsKiller() and not restricted) or class == "Criminal"
		end
	},
	{
		id = "Soldier", label = "shop_cat_soldier",
		allowed = function()
			local class = LocalPlayer():GetNW2String("Class")
			return class == "Soldier" or (MuR.GamemodeCount == 24 and class == "PMCCommander")
		end
	}
}

local function currency()
	if MuR.GamemodeCount == 18 then
		return LocalPlayer():GetNWInt("MuR_ZombiesPoints", 0), " PTS", ""
	end
	if MuR.GamemodeCount == 24 then
		return LocalPlayer():GetNWInt("MuR_Mode24Points", 0), " PTS", ""
	end
	return LocalPlayer():GetNW2Float("Money", 0), "", "$"
end

local function priceOf(item)
	local price = ((MuR.GamemodeCount == 18 or MuR.GamemodeCount == 24) and item.zombieprice) or item.price

	if MuR.GamemodeCount == 18 and MuR.Mode18Client and MuR.Mode18Client.Powerups
		and MuR.Mode18Client.Powerups["Fire Sale"]
		and CurTime() < MuR.Mode18Client.Powerups["Fire Sale"] then
		price = math.floor(price * 0.5)
	end

	return price
end

local function purchasesOf(category, key)
	local store = LocalPlayer().ShopPurchases
	return (store and store[category] and store[category][key]) or 0
end

local function effectiveLimit(item)
	if MuR.GamemodeCount == 24 then return 0 end
	return item.limit or 1
end

local function visibleItems(category)
	local out = {}
	local ply = LocalPlayer()
	local class = ply:GetNW2String("Class")

	for key, item in pairs(MuR.Shop[category] or {}) do
		local hidden = category == "Killer" and (not ply:IsKiller() or class == "Criminal") and item.traitor
		local modeHidden = item.modes and not table.HasValue(item.modes, MuR.GamemodeCount)
		if not hidden and not modeHidden then out[#out + 1] = {key = key, item = item} end
	end

	table.sort(out, function(a, b) return priceOf(a.item) < priceOf(b.item) end)

	return out
end

function OpenShop()
	if not LocalPlayer():Alive() then return end
	if IsValid(shop_select_panel) then shop_select_panel:Remove() end

	local C = UI.Colors
	local pad = We(UI.PAD)

	local frame = UI.Frame(We(FRAME_W), He(FRAME_H), {KEY_ESCAPE, KEY_F2})
	shop_select_panel = frame
	frame:Center()

	local current = nil
	local body

	frame.Paint = function(self, w, h)
		UI.Chrome(w, h, L("shop"), current and L("shop_cat_" .. string.lower(current)) or "")

		local money, suffix, prefix = currency()
		draw.SimpleText(prefix .. math.floor(money) .. suffix, "MuR_Font2",
			w - pad - We(UI.CLOSE_RESERVE), He(16), C.accent, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
	end

	local tabStrip = vgui.Create("DPanel", frame)
	tabStrip:SetPos(0, He(UI.HEADER))
	tabStrip:SetSize(We(FRAME_W), He(UI.TAB))
	tabStrip.Paint = function(self, w, h) UI.HLine(0, h - 1, w, C.line) end

	body = vgui.Create("DPanel", frame)
	body:SetPos(0, He(UI.HEADER + UI.TAB))
	body:SetSize(We(FRAME_W), He(FRAME_H - UI.HEADER - UI.TAB))
	body.Paint = function() end

	local function buildCategory(category)
		body:Clear()

		local items = visibleItems(category)

		if #items == 0 then
			body.Paint = function(self, w, h)
				draw.SimpleText(L("shop_empty"), "MuR_Font1", w / 2, h / 2, C.textFaint,
					TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end
			return
		end

		body.Paint = function() end

		local scroll = vgui.Create("DScrollPanel", body)
		scroll:Dock(FILL)
		scroll:DockMargin(pad, He(12), pad, He(12))
		UI.Scrollbar(scroll)

		local grid = vgui.Create("DIconLayout", scroll)
		grid:Dock(TOP)
		grid:SetSpaceX(We(10))
		grid:SetSpaceY(He(10))

		for _, entry in ipairs(items) do
			local item, key = entry.item, entry.key
			local icon = item.icon and Material(item.icon) or nil

			local card = grid:Add("DButton")
			card:SetSize(We(CARD_W), He(CARD_H))
			card:SetText("")

			card.Paint = function(self, w, h)
				local money = currency()
				local price = priceOf(item)
				local limit = effectiveLimit(item)
				local bought = purchasesOf(category, key)
				local soldOut = limit ~= 0 and bought >= limit
				local affordable = money >= price and not soldOut

				local hovered = self:IsHovered()
				UI.Rect(0, 0, w, h, hovered and C.panelHov or C.panel)
				UI.Outline(0, 0, w, h, hovered and C.accent or C.line)

				if icon then
					surface.SetMaterial(icon)
					surface.SetDrawColor(255, 255, 255, affordable and 255 or 90)
					surface.DrawTexturedRect(pad, (h - He(48)) / 2, He(48), He(48))
				end

				local textX = pad + He(48) + We(14)

				draw.SimpleText(item.name, "MuR_Font1", textX, h / 2 - He(16),
					affordable and C.text or C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

				local _, suffix, prefix = currency()
				draw.SimpleText(prefix .. price .. suffix, "MuR_Font1", textX, h / 2 + He(4),
					affordable and C.accent or C.sev2, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

				local limitText = limit == 0 and L("shop_unlimited") or (bought .. " / " .. limit)
				draw.SimpleText(limitText, "MuR_Font0", w - pad, h / 2 - He(6),
					soldOut and C.sev2 or C.textFaint, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
			end

			card.DoClick = function()
				local money = currency()
				local price = priceOf(item)
				local limit = effectiveLimit(item)
				local bought = purchasesOf(category, key)

				if money < price or (limit ~= 0 and bought >= limit) then
					surface.PlaySound("murdered/vgui/ui_return.wav")
					return
				end

				surface.PlaySound("murdered/vgui/buy.wav")

				net.Start("MuR.UseShop")
					net.WriteString(category)
					net.WriteFloat(key)
				net.SendToServer()
			end
		end
	end

	local tabW = We(FRAME_W) / #CATEGORIES
	local buttons = {}

	local function selectCategory(category)
		current = category
		for _, b in ipairs(buttons) do b.Active = (b.CatId == category) end
		buildCategory(category)
	end

	for i, cat in ipairs(CATEGORIES) do
		local allowed = cat.allowed()

		local tab = UI.Tab(tabStrip, L(cat.label), function()
			if allowed then selectCategory(cat.id) end
		end)
		tab:SetPos((i - 1) * tabW, 0)
		tab:SetSize(tabW, He(UI.TAB))
		tab.CatId = cat.id
		tab:SetEnabled(allowed)

		if not allowed then
			tab.Paint = function(self, w, h)
				draw.SimpleText(self.Label or "", "MuR_Font1", w / 2, h / 2, C.textFaint,
					TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end
		end

		buttons[#buttons + 1] = tab

		if i > 1 then
			local sep = vgui.Create("DPanel", tabStrip)
			sep:SetPos((i - 1) * tabW, He(8))
			sep:SetSize(1, He(UI.TAB - 16))
			sep.Paint = function(self, w, h) UI.Rect(0, 0, w, h, C.line) end
		end
	end

	for _, cat in ipairs(CATEGORIES) do
		if cat.allowed() then selectCategory(cat.id) break end
	end
end

concommand.Add("mur_shop", function()
	OpenShop()
end)
