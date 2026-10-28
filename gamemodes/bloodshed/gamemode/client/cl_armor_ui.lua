local We = We or function(x) return x * (ScrW() / 1920) end
local He = He or function(x) return x * (ScrH() / 1080) end

local UI = MuR.UI

local FRAME_W, FRAME_H = 540, 470
local SLOT_H = 54

local SLOTS = {
	{id = "head", label = "armor_slot_head"},
	{id = "face", label = "armor_slot_face"},
	{id = "body", label = "armor_slot_body"}
}

local function L(key)
	return (MuR.Language and MuR.Language[key]) or key
end

local function slotState(ply, bodypart)
	local armorId = ply:GetNW2String("MuR_Armor_" .. bodypart, "")
	if armorId == "" then return nil end

	return {
		id = armorId,
		item = MuR.Armor.GetItem(armorId),
		active = ply:GetNW2Bool("MuR_Armor_Active_" .. bodypart, false),
		locked = ply:GetNW2Bool("MuR_Armor_NoDrop_" .. bodypart, false)
	}
end

local function OpenArmorPanel()
	local ply = LocalPlayer()
	if not IsValid(ply) or not ply:Alive() then return end

	if IsValid(MuR.ArmorPanel) then MuR.ArmorPanel:Remove() end

	local frame = UI.Frame(We(FRAME_W), He(FRAME_H), {KEY_ESCAPE, KEY_Q})
	MuR.ArmorPanel = frame
	frame:Center()

	local selected = SLOTS[1].id
	local C = UI.Colors
	local pad = We(UI.PAD)

	frame.Paint = function(self, w, h)
		local worn = 0
		for _, slot in ipairs(SLOTS) do
			if slotState(ply, slot.id) then worn = worn + 1 end
		end

		UI.Chrome(w, h, L("armor_title"),
			worn .. " / " .. #SLOTS, L("armor_close_key"))
	end

	local list = vgui.Create("DPanel", frame)
	list:SetPos(0, He(UI.HEADER))
	list:SetSize(We(FRAME_W), He(SLOT_H * #SLOTS))
	list.Paint = function(self, w, h) UI.HLine(0, h - 1, w, C.line) end

	for i, slot in ipairs(SLOTS) do
		local row = vgui.Create("DButton", list)
		row:SetPos(0, (i - 1) * He(SLOT_H))
		row:SetSize(We(FRAME_W), He(SLOT_H))
		row:SetText("")

		row.Paint = function(self, w, h)
			local state = slotState(ply, slot.id)
			local isSel = selected == slot.id
			local hovered = self:IsHovered()

			if isSel then
				UI.Rect(0, 0, w, h, C.panel)
			elseif hovered then
				UI.Rect(0, 0, w, h, C.lineSoft)
			end

			if isSel then UI.Rect(0, 0, We(2), h, C.accent) end

			if i > 1 then UI.HLine(0, 0, w, C.lineSoft) end

			draw.SimpleText(L(slot.label), "MuR_Font0", pad, h / 2 - He(11),
				C.textFaint, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

			if state then
				local name = L("armor_item_" .. state.id)
				draw.SimpleText(name, "MuR_Font1", pad, h / 2 + He(2),
					state.active and C.text or C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

				local tag = state.active and L("armor_active") or L("armor_inactive")
				draw.SimpleText(tag, "MuR_Font0", w - pad, h / 2 - He(5),
					state.active and C.accent or C.textFaint,
					TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
			else
				draw.SimpleText(L("armor_empty"), "MuR_Font1", pad, h / 2 + He(2),
					C.textFaint, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			end
		end

		row.DoClick = function()
			surface.PlaySound("buttons/lightswitch2.wav")
			selected = slot.id
		end
	end

	local actionsH = He(56)
	local detail = vgui.Create("DPanel", frame)
	detail:SetPos(0, He(UI.HEADER + SLOT_H * #SLOTS))
	detail:SetSize(We(FRAME_W), He(FRAME_H - UI.HEADER - SLOT_H * #SLOTS) - actionsH)

	detail.Paint = function(self, w, h)
		local state = slotState(ply, selected)

		if not state then
			draw.SimpleText(L("armor_slot_empty_hint"), "MuR_Font1", w / 2, h / 2,
				C.textFaint, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			return
		end

		local item = state.item
		local y = He(16)

		draw.SimpleText(L("armor_item_" .. state.id), "MuR_Font2", pad, y,
			C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		y = y + He(30)

		local desc = L("armor_desc_" .. state.id)
		if desc ~= "armor_desc_" .. state.id then
			for _, lineText in ipairs(MuR.UI.WrapText(desc, "MuR_Font0", w - pad * 2)) do
				draw.SimpleText(lineText, "MuR_Font0", pad, y, C.textDim,
					TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
				y = y + He(15)
			end
		end

		y = y + He(10)
		UI.HLine(pad, y, w - pad * 2, C.lineSoft)
		y = y + He(14)

		if not item then return end

		local colW = (w - pad * 2) / 2

		UI.Field(pad, y, colW, L("armor_stat_reduction"),
			math.floor((item.damage_reduction or 0) * 100) .. "%")
		UI.Field(pad + colW, y, colW, L("armor_stat_gas"),
			math.floor((item.gas_protection or 0) * 100) .. "%")
		y = y + He(38)

		UI.Field(pad, y, colW, L("armor_stat_pepper"),
			math.floor((item.pepper_protection or 0) * 100) .. "%")
		y = y + He(38)

		if item.ammo_scaling then
			UI.HLine(pad, y - He(8), w - pad * 2, C.lineSoft)

			draw.SimpleText(L("armor_stat_bullets"), "MuR_Font0", pad, y,
				C.textFaint, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			y = y + He(16)

			local order = {"pistol", "smg1", "357", "ar2", "buckshot", "others"}
			local shown = 0

			for _, ammo in ipairs(order) do
				local value = item.ammo_scaling[ammo]
				if value then
					local col = shown % 3
					local x = pad + col * ((w - pad * 2) / 3)

					if col == 0 and shown > 0 then y = y + He(18) end

					draw.SimpleText(L("armor_ammo_" .. ammo) .. "  " ..
						math.floor(value * 100) .. "%", "MuR_Font0", x, y,
						value > 0 and C.text or C.textFaint, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

					shown = shown + 1
				end
			end
		end

		if state.locked then
			draw.SimpleText(L("armor_locked"), "MuR_Font0", pad, h - He(20),
				C.sev2, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		end
	end

	local actions = vgui.Create("DPanel", frame)
	actions:SetPos(0, He(FRAME_H) - actionsH)
	actions:SetSize(We(FRAME_W), actionsH)
	actions.Paint = function(self, w, h) UI.HLine(0, 0, w, C.line) end

	local function send(action, extra)
		net.Start("MuR_ArmorPickup")
			net.WriteString(action)
			net.WriteString(selected)
			if extra ~= nil then net.WriteBool(extra) end
		net.SendToServer()
	end

	local btnW = (We(FRAME_W) - pad * 3) / 2

	local toggle = UI.Button(actions, "", function()
		local state = slotState(ply, selected)
		if not state or state.locked then return end
		send("toggle_active", not state.active)
	end)
	toggle:SetPos(pad, He(10))
	toggle:SetSize(btnW, actionsH - He(20))

	local drop = UI.Button(actions, L("armor_drop"), function()
		local state = slotState(ply, selected)
		if not state or state.locked then return end

		if state.active and state.item and state.item.unequip_sound then
			surface.PlaySound(state.item.unequip_sound)
		end

		send("unequip")
	end)
	drop:SetPos(pad * 2 + btnW, He(10))
	drop:SetSize(btnW, actionsH - He(20))

	actions.Think = function()
		local state = slotState(ply, selected)
		local usable = state ~= nil and not state.locked

		toggle.Label = (state and state.active) and L("armor_take") or L("armor_put_on")
		toggle:SetEnabled(usable)
		drop:SetEnabled(usable)
	end
end

concommand.Add("mur_armor_panel", function()
	OpenArmorPanel()
end)

MuR.OpenArmorPanel = OpenArmorPanel
