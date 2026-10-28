MuR.RegisterMode(12, {
	name = "Terrorists vs SWAT",
	chance = 20,
	need_players = 4,
	disables = true,
	no_default_roles = true,
	win_condition = "specops",
	custom_spawning = true,
	no_guilt = true,
	timer = 300,
	countdown_on_start = true,
	kteam = "Terrorist2",
	dteam = "SWAT",
	OnModeStarted = function(mode)
		if SERVER then
			SetGlobalFloat("MuR.Mode12.BuyTimeEnd", CurTime() + 45)

			for _, ply in player.Iterator() do
				local budget = 4200 + math.random(-500, 800)
				budget = math.Clamp(math.Round(budget / 10) * 10, 3200, 5800)

				ply:SetNW2Int("MuR.Mode12.Money", budget)
			end
		end
	end
})

local ITEM_PRICES = {

	["tfa_bs_glock"] = 350,
	["tfa_bs_usp"] = 400,
	["tfa_bs_p320"] = 450,
	["tfa_bs_walther"] = 400,
	["tfa_bs_deagle"] = 700,
	["tfa_bs_m9"] = 350,
	["tfa_bs_cobra"] = 550,
	["tfa_bs_mateba"] = 600,
	["tfa_bs_colt"] = 300,
	["tfa_bs_ruger"] = 400,
	["tfa_bs_pm"] = 200,

	["tfa_bs_mp5a5"] = 1100,
	["tfa_bs_ump"] = 1200,
	["tfa_bs_vector"] = 1600,
	["tfa_bs_uzi"] = 900,
	["tfa_bs_mac11"] = 850,
	["tfa_bs_mp7"] = 1400,

	["tfa_bs_nova"] = 1200,
	["tfa_bs_m1014"] = 1600,
	["tfa_bs_izh43"] = 900,
	["tfa_bs_izh43sw"] = 800,
	["tfa_bs_m590"] = 1400,
	["tfa_bs_spas"] = 1500,
	["tfa_bs_m500"] = 1200,
	["tfa_bs_m37"] = 1200,
	["tfa_bs_ks23"] = 1600,

	["tfa_bs_akm"] = 2100,
	["tfa_bs_hk416"] = 2450,
	["tfa_bs_val"] = 2200,
	["tfa_bs_ak74"] = 1950,
	["tfa_bs_l1a1"] = 2300,
	["tfa_bs_aug"] = 2400,
	["tfa_bs_m4a1"] = 2400,
	["tfa_bs_mk17"] = 2700,
	["tfa_bs_m16"] = 2050,
	["tfa_bs_draco"] = 1800,
	["tfa_bs_ak12"] = 2250,
	["tfa_bs_aks74u"] = 1750,
	["tfa_bs_badger"] = 2200,
	["tfa_bs_acr"] = 2500,
	["tfa_bs_sg552"] = 2200,
	["tfa_bs_aug"] = 2400,

	["tfa_bs_sks"] = 2000,
	["tfa_bs_sr25"] = 2700,

	["tfa_bs_m24"] = 3200,
	["tfa_bs_svd"] = 3000,
	["tfa_bs_kar98"] = 2300,
	["tfa_bs_mosin"] = 2500,
	["tfa_bs_m82"] = 3600,

	["tfa_bs_m249"] = 3600,
	["tfa_bs_pkm"] = 3800,
	["tfa_bs_rpk"] = 3400,

	["mur_f1"] = 250,
	["mur_m67"] = 250,
	["mur_beartrap"] = 600,
	["tfa_bs_police_shield"] = 1200,
	["mur_flashbang"] = 200,
	["mur_doorlooker"] = 300,

	["mur_loot_bandage"] = 200,
	["mur_loot_tourniquet"] = 350,
	["mur_loot_medkit"] = 500,
	["mur_loot_adrenaline"] = 600,

	["mur_armor_classI_armor"] = 650,
	["mur_armor_classII_armor"] = 950,
	["mur_armor_classIII_armor"] = 1350,
	["mur_armor_helmet_ulach"] = 350
}

local BLOCKED_WEAPONS = {
	["tfa_bs_colt_nz"] = true,
	["tfa_bs_glock_t"] = true,
	["tfa_bs_vp9"] = true
}

local OTHERS_ITEMS = {
	["Terrorist2"] = {
		{class = "mur_f1", name = "F1 Grenade"},
		{class = "mur_m67", name = "M67 Grenade"},
		{class = "mur_flashbang", name = "Flashbang"}
	},
	["SWAT"] = {
		{class = "mur_flashbang", name = "Flashbang"},
		{class = "mur_f1", name = "F1 Grenade"},
		{class = "mur_m67", name = "M67 Grenade"}
	}
}

if SERVER then
	util.AddNetworkString("MuR.Mode12.Buy")
	util.AddNetworkString("MuR.Mode12.BuyAmmo")

	net.Receive("MuR.Mode12.Buy", function(len, ply)
		if MuR.Gamemode != 12 then return end
		if CurTime() > GetGlobalFloat("MuR.Mode12.BuyTimeEnd", 0) then
			ply:ChatPrint("[Bloodshed] Buy time is over!")
			return
		end
		if not ply:Alive() then return end

		local class = net.ReadString()

		if BLOCKED_WEAPONS[class] then return end

		local price = 0
		local found = false

		if ITEM_PRICES[class] then
			price = ITEM_PRICES[class]
			found = true
		end

		if found then
			local teamName = ply:GetNW2String("Class")

			local isRestrictedItem = false
			local myTeamHasItem = false

			for tName, items in pairs(OTHERS_ITEMS) do
				for _, item in ipairs(items) do
					if item.class == class then
						isRestrictedItem = true
						if tName == teamName then
							myTeamHasItem = true
						end
					end
				end
			end

			if isRestrictedItem and not myTeamHasItem then
				found = false
			end
		end

		if not found then return end

		local money = ply:GetNW2Int("MuR.Mode12.Money", 0)
		if money >= price then
			ply:SetNW2Int("MuR.Mode12.Money", money - price)
			if string.StartWith(class, "mur_armor_") then
				local armorId = string.sub(class, 11)
				if MuR.Armor and MuR.Armor.GetItem and MuR.Armor.GetItem(armorId) then
					ply:EquipArmor(armorId)
				else
					return
				end
			else
				ply:GiveWeapon(class)
			end
			MuR:PlaySoundOnClient("items/ammo_pickup.wav", ply)
		else
			MuR:GiveAnnounce(MuR.Language and MuR.Language["mode12_not_enough_money"] or "Not enough money!", ply)
		end
	end)

	net.Receive("MuR.Mode12.BuyAmmo", function(len, ply)
		if MuR.Gamemode != 12 then return end
		if CurTime() > GetGlobalFloat("MuR.Mode12.BuyTimeEnd", 0) then return end
		if not ply:Alive() then return end

		local class = net.ReadString()
		local wep = ply:GetWeapon(class)
		if not IsValid(wep) then return end

		local money = ply:GetNW2Int("MuR.Mode12.Money", 0)
		if money < 50 then
			MuR:GiveAnnounce(MuR.Language and MuR.Language["mode12_not_enough_money"] or "Not enough money!", ply)
			return
		end

		local ammoType = wep:GetPrimaryAmmoType()
		if ammoType == -1 then return end

		local clipSize = wep:GetMaxClip1()
		if clipSize <= 0 then clipSize = 30 end

		ply:SetNW2Int("MuR.Mode12.Money", money - 50)
		ply:GiveAmmo(clipSize, ammoType, true)
		MuR:PlaySoundOnClient("items/ammo_pickup.wav", ply)
	end)

	hook.Add("ShowSpare1", "MuR.Mode12.OpenMenu", function(ply)
		if MuR.Gamemode == 12 and CurTime() < GetGlobalFloat("MuR.Mode12.BuyTimeEnd", 0) then
			ply:ConCommand("mur_mode12_buymenu")
			return false
		end
	end)
end

if CLIENT then
	local BLOCKED_WEAPONS_CL = {
		["tfa_bs_colt_nz"] = true,
		["tfa_bs_glock_t"] = true,
		["tfa_bs_vp9"] = true
	}

	local function We(x) return x / 1920 * ScrW() end
	local function He(y) return y / 1080 * ScrH() end

	hook.Add("HUDPaint", "MuR.Mode12.HUD", function()
		if MuR.GamemodeCount == 12 and CurTime() < GetGlobalFloat("MuR.Mode12.BuyTimeEnd", 0) then
			local timeLeft = math.ceil(math.max(0, GetGlobalFloat("MuR.Mode12.BuyTimeEnd", 0) - CurTime()))
			local text = string.format(MuR.Language["mode12_hud_buy"] or "F3 TO BUY - %s SECONDS LEFT", timeLeft)
			draw.SimpleText(text, "MuR_Font2", ScrW() / 2, ScrH() / 2 + He(200), Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	end)

	local NO_AMMO_ITEMS = {
		["mur_f1"] = true,
		["mur_m67"] = true,
		["mur_beartrap"] = true,
		["mur_flashbang"] = true,
		["tfa_bs_police_shield"] = true,
		["mur_doorlooker"] = true,
		["mur_loot_bandage"] = true,
		["mur_loot_tourniquet"] = true,
		["mur_loot_medkit"] = true,
		["mur_loot_adrenaline"] = true
	}

	local TEAM_CATEGORIES = {
		SWAT = {
			Sidearms = {"tfa_bs_usp", "tfa_bs_glock", "tfa_bs_p320", "tfa_bs_m9", "tfa_bs_deagle"},
			SMGs = {"tfa_bs_mp5a5", "tfa_bs_ump", "tfa_bs_mp7", "tfa_bs_vector"},
			Shotguns = {"tfa_bs_m590", "tfa_bs_nova", "tfa_bs_m1014"},
			Rifles = {"tfa_bs_m4a1", "tfa_bs_hk416", "tfa_bs_aug", "tfa_bs_sg552"},
			Snipers = {"tfa_bs_sr25", "tfa_bs_m24"},
			Grenades = {"mur_flashbang", "mur_f1", "mur_m67"},
			Medical = {"mur_loot_bandage", "mur_loot_tourniquet", "mur_loot_medkit", "mur_loot_adrenaline"},
			Armor = {"mur_armor_classI_armor", "mur_armor_classII_armor", "mur_armor_classIII_armor", "mur_armor_helmet_ulach"}
		},
		Terrorist2 = {
			Sidearms = {"tfa_bs_pm", "tfa_bs_colt", "tfa_bs_ruger", "tfa_bs_cobra", "tfa_bs_deagle"},
			SMGs = {"tfa_bs_uzi", "tfa_bs_mac11", "tfa_bs_mp7"},
			Shotguns = {"tfa_bs_izh43", "tfa_bs_izh43sw", "tfa_bs_m37", "tfa_bs_m500", "tfa_bs_spas", "tfa_bs_ks23"},
			Rifles = {"tfa_bs_akm", "tfa_bs_ak74", "tfa_bs_ak12", "tfa_bs_aks74u", "tfa_bs_draco", "tfa_bs_val"},
			Snipers = {"tfa_bs_sks", "tfa_bs_svd", "tfa_bs_mosin", "tfa_bs_kar98"},
			Grenades = {"mur_flashbang", "mur_f1", "mur_m67"},
			Medical = {"mur_loot_bandage", "mur_loot_tourniquet", "mur_loot_medkit", "mur_loot_adrenaline"},
			Armor = {"mur_armor_classI_armor", "mur_armor_classII_armor", "mur_armor_helmet_ulach"}
		}
	}

	concommand.Add("mur_mode12_buymenu", function()
		if MuR.GamemodeCount != 12 then return end
		if CurTime() > GetGlobalFloat("MuR.Mode12.BuyTimeEnd", 0) then
			chat.AddText(Color(255, 50, 50), MuR.Language["mode12_buy_time_over"] or "[Bloodshed] Buy time is over!")
			return
		end

		local frame = vgui.Create("DFrame")
		local headerH = He(60)
		local frameW, frameH, animTime, animDelay, animEase = We(1000), He(700), 0.3, 0, 0.1
		local animating = true
		frame:SetSize(frameW, He(0))
		frame:SetTitle("")
		frame:MakePopup()
		frame:ShowCloseButton(false)
		frame:Center()
		frame:SizeTo(frameW, frameH, animTime, animDelay, animEase, function()
			animating = false
		end)
		frame.Paint = function(self, w, h)
			draw.RoundedBox(8, 0, 0, w, h, Color(15, 15, 20, 250))
			draw.RoundedBox(8, 0, 0, w, headerH, Color(25, 25, 30, 255))
			surface.SetDrawColor(Color(180, 40, 40))
			surface.DrawRect(0, headerH, w, He(2))

			local money = LocalPlayer():GetNW2Int("MuR.Mode12.Money", 0)
			draw.SimpleText("$" .. money, "MuR_Font3", w - We(120), headerH / 2, Color(180, 40, 40), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		end
		frame.Think = function(self)
			if animating then
				self:Center()
			end
			if CurTime() > GetGlobalFloat("MuR.Mode12.BuyTimeEnd", 0) then
				self:Close()
			end
		end

		local sidebar = vgui.Create("DPanel", frame)
		sidebar:SetPos(0, headerH)
		sidebar:SetSize(We(250), frameH - headerH)
		sidebar.Paint = function(self, w, h)
			draw.RoundedBox(0, 0, 0, w, h, ColorAlpha(Color(25, 25, 30, 255), 220))
			surface.SetDrawColor(Color(180, 40, 40))
			surface.DrawRect(w - 2, 0, 2, h)
		end

		local content = vgui.Create("DScrollPanel", frame)
		content:SetPos(We(260), headerH + He(10))
		content:SetSize(frameW - We(270), frameH - headerH - He(20))

		local sbar = content:GetVBar()
		sbar:SetWide(We(8))
		function sbar:Paint(w, h)
			draw.RoundedBox(4, 0, 0, w, h, Color(25, 25, 30, 100))
		end
		function sbar.btnGrip:Paint(w, h)
			draw.RoundedBox(4, 0, 0, w, h, Color(180, 40, 40))
		end

		local list = vgui.Create("DListLayout", content)
		list:Dock(FILL)
		list:DockMargin(We(8), He(8), We(8), He(8))

		local closeBtn = vgui.Create("DButton", frame)
		closeBtn:SetSize(We(32), He(32))
		closeBtn:SetPos(frameW - We(42), He(14))
		closeBtn:SetText("")
		closeBtn.Paint = function(self, w, h)
			local hovered = self:IsHovered()
			local color = hovered and Color(220, 50, 50) or Color(25, 25, 30, 255)
			local symbolColor = hovered and Color(255, 255, 255) or Color(200, 200, 200)

			draw.RoundedBox(4, 0, 0, w, h, color)
			draw.SimpleText("X", "MuR_Font3", w/2, h/2, symbolColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
		closeBtn.DoClick = function()
			surface.PlaySound("murdered/vgui/ui_click.wav")
			frame:Close()
		end

		local shopItems = {}

		local myTeam = LocalPlayer():GetNW2String("Class")
		local categories = TEAM_CATEGORIES[myTeam] or {}

		for catName, classList in pairs(categories) do
			shopItems[catName] = shopItems[catName] or {}
			for _, className in ipairs(classList) do
				if BLOCKED_WEAPONS_CL[className] then continue end
				if not ITEM_PRICES[className] then continue end

				local name = className
				local model = "models/error.mdl"
				local ammo = nil

				if string.StartWith(className, "mur_armor_") then
					local armorId = string.sub(className, 11)
					local armorItem = MuR.Armor and MuR.Armor.GetItem and MuR.Armor.GetItem(armorId)
					if armorItem then
						name = (MuR.Language and MuR.Language["armor_item_" .. armorId]) or armorId
						model = armorItem.model or model
					end
				else
					local wep = weapons.GetStored(className)
					if wep then
						name = wep.PrintName or className
						model = wep.WorldModel or model
						ammo = wep.Primary and wep.Primary.Ammo
					end
				end

				if className == "mur_f1" then model = "models/simpnades/w_f1.mdl" end
				if className == "mur_m67" then model = "models/simpnades/w_m67.mdl" end
				if className == "mur_flashbang" then model = "models/simpnades/w_m84.mdl" end

				table.insert(shopItems[catName], {
					class = className,
					name = name,
					price = ITEM_PRICES[className],
					model = model,
					ammo = ammo
				})
			end
		end

		local categoryOrder = {
			"Sidearms", "SMGs", "Shotguns", "Rifles", "Snipers", "Grenades", "Medical", "Armor"
		}

		local currentCategory = nil

		local function RebuildGrid(category)
			list:Clear()
			content:GetVBar():SetScroll(0)
			currentCategory = category

			local items = shopItems[category] or {}
			for _, item in ipairs(items) do
				local card = list:Add("DPanel")
				card:SetTall(He(90))
				card:DockMargin(0, 0, 0, He(8))
				card.Paint = function(self, w, h)
					draw.RoundedBox(8, 0, 0, w, h, Color(25, 25, 30, 255))

					local hovered = self:IsHovered() or self:IsChildHovered()
					if hovered then
						surface.SetDrawColor(180, 40, 40, 30)
						draw.RoundedBox(8, 0, 0, w, h, Color(180, 40, 40, 30))
					end
				end

				local nameLabel = vgui.Create("DLabel", card)
				nameLabel:SetText(item.name)
				nameLabel:SetFont("MuR_Font3")
				nameLabel:SetTextColor(Color(255, 255, 255))
				nameLabel:SetPos(We(110), He(18))
				nameLabel:SetSize(We(420), He(20))

				local priceLabel = vgui.Create("DLabel", card)
				priceLabel:SetText("$" .. item.price)
				priceLabel:SetFont("MuR_Font2")
				priceLabel:SetTextColor(Color(40, 180, 120))
				priceLabel:SetPos(We(110), He(48))
				priceLabel:SetSize(We(200), He(18))

				local modelPanel = vgui.Create("DModelPanel", card)
				modelPanel:SetSize(We(80), He(70))
				modelPanel:SetPos(We(12), He(10))
				modelPanel:SetModel(item.model or "models/error.mdl")
				modelPanel:SetFOV(35)
				modelPanel:SetCamPos(Vector(50, 50, 50))
				modelPanel:SetLookAt(Vector(0, 0, 0))
				modelPanel:SetMouseInputEnabled(false)

				function modelPanel:LayoutEntity(Entity)
					Entity:SetAngles(Angle(0, RealTime() * 30 % 360, 0))
				end

				local buyBtn = vgui.Create("DButton", card)
				buyBtn:SetText(MuR.Language["buy"] or "BUY")
				buyBtn:SetFont("MuR_Font1")
				buyBtn.Paint = function(self, w, h)
					local hovered = self:IsHovered()
					local baseCol = Color(33, 33, 38, 255)
					draw.RoundedBox(4, 0, 0, w, h, baseCol)
					if hovered then
						surface.SetDrawColor(180, 40, 40, 30)
						draw.RoundedBox(4, 0, 0, w, h, Color(180, 40, 40, 30))
					end
				end
				buyBtn:SetTextColor(Color(255, 255, 255))
				buyBtn.DoClick = function()
					net.Start("MuR.Mode12.Buy")
					net.WriteString(item.class)
					net.SendToServer()
					surface.PlaySound("murdered/vgui/ui_click.wav")
				end

				local hasAmmo = item.ammo and item.ammo ~= "none"
				local ammoBtn = nil
				if hasAmmo and not NO_AMMO_ITEMS[item.class] then
					ammoBtn = vgui.Create("DButton", card)
					ammoBtn:SetText(MuR.Language["mode12_buy_ammo"] or "MAG $50")
					ammoBtn:SetFont("MuR_Font1")
					ammoBtn.Paint = function(self, w, h)
						local hovered = self:IsHovered()
						local baseCol = Color(33, 33, 38, 255)
						draw.RoundedBox(4, 0, 0, w, h, baseCol)
						if hovered then
							surface.SetDrawColor(180, 40, 40, 30)
							draw.RoundedBox(4, 0, 0, w, h, Color(180, 40, 40, 30))
						end
					end
					ammoBtn:SetTextColor(Color(255, 255, 255))
					ammoBtn.DoClick = function()
						net.Start("MuR.Mode12.BuyAmmo")
						net.WriteString(item.class)
						net.SendToServer()
						surface.PlaySound("murdered/vgui/ui_click.wav")
					end
				end

				card.PerformLayout = function(self, w, h)
					local right = w - We(12)
					if IsValid(buyBtn) then
						buyBtn:SetSize(We(70), He(26))
						buyBtn:SetPos(right - buyBtn:GetWide(), (h - buyBtn:GetTall()) / 2)
						right = right - buyBtn:GetWide() - We(8)
					end
					if IsValid(ammoBtn) then
						ammoBtn:SetSize(We(110), He(26))
						ammoBtn:SetPos(right - ammoBtn:GetWide(), (h - ammoBtn:GetTall()) / 2)
					end
				end
			end
		end

		local y = 10
		for _, cat in ipairs(categoryOrder) do
			if shopItems[cat] and #shopItems[cat] > 0 then
				local btn = vgui.Create("DButton", sidebar)
				btn:SetText(cat)
				btn:SetPos(We(10), y)
				btn:SetSize(We(230), 40)
				btn:SetFont("MuR_Font2")
				btn:SetTextColor(Color(255, 255, 255))
				btn.Paint = function(self, w, h)
					local selected = currentCategory == cat
					local baseAlpha = selected and 255 or 200
					draw.RoundedBox(6, 0, 0, w, h, ColorAlpha(Color(25, 25, 30, 255), baseAlpha))

					if self:IsHovered() or selected then
						surface.SetDrawColor(180, 40, 40, 40)
						draw.RoundedBox(6, 0, 0, w, h, Color(180, 40, 40, 40))

						surface.SetDrawColor(180, 40, 40, 180)
						surface.DrawRect(0, 0, We(3), h)
					end
				end
				btn.DoClick = function()
					surface.PlaySound("murdered/vgui/ui_click.wav")
					RebuildGrid(cat)
				end
				y = y + 50
			end
		end

		for _, cat in ipairs(categoryOrder) do
			if shopItems[cat] and #shopItems[cat] > 0 then
				RebuildGrid(cat)
				break
			end
		end
	end)
end
