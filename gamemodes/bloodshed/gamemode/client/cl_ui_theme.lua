if not CLIENT then return end

MuR = MuR or {}
MuR.UI = MuR.UI or {}

local UI = MuR.UI

local We = We or function(x) return x * (ScrW() / 1920) end
local He = He or function(x) return x * (ScrH() / 1080) end

UI.Colors = {
	bg        = Color(13, 13, 14, 246),
	panel     = Color(21, 21, 23),
	panelHov  = Color(31, 31, 34),
	panelDown = Color(10, 10, 11),

	line      = Color(46, 46, 50),
	lineSoft  = Color(32, 32, 35),
	lineHot   = Color(96, 96, 102),

	text      = Color(226, 226, 229),
	textDim   = Color(126, 126, 133),
	textFaint = Color(78, 78, 84),

	accent    = Color(219, 52, 48),
	accentDim = Color(219, 52, 48, 46),

	sev1      = Color(126, 126, 133),
	sev2      = Color(196, 154, 74),
	sev3      = Color(146, 46, 40)
}

function UI.U(n) return He(8 * n) end

UI.PAD = 20
UI.HEADER = 56

UI.CLOSE = 26
UI.CLOSE_RESERVE = 38
UI.TAB = 40
UI.ROW = 44

function UI.SeverityColor(sev)
	local c = UI.Colors
	if not sev or sev <= 1 then return c.sev1 end
	if sev == 2 then return c.sev2 end
	return c.sev3
end

function UI.Rect(x, y, w, h, col)
	surface.SetDrawColor(col)
	surface.DrawRect(x, y, w, h)
end

function UI.Outline(x, y, w, h, col, thickness)
	surface.SetDrawColor(col)
	surface.DrawOutlinedRect(x, y, w, h, thickness or 1)
end

function UI.HLine(x, y, w, col)
	surface.SetDrawColor(col or UI.Colors.line)
	surface.DrawRect(x, y, w, 1)
end

function UI.VLine(x, y, h, col)
	surface.SetDrawColor(col or UI.Colors.line)
	surface.DrawRect(x, y, 1, h)
end

function UI.Chrome(w, h, title, subtitle, hint)
	local c = UI.Colors
	UI.Rect(0, 0, w, h, c.bg)
	UI.Outline(0, 0, w, h, c.line)

	local pad = We(UI.PAD)

	if title then
		draw.SimpleText(title, "MuR_Font2", pad, He(16), c.text,
			TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	end

	if subtitle then
		draw.SimpleText(subtitle, "MuR_Font1", pad, He(40), c.textDim,
			TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	end

	if hint then
		draw.SimpleText(hint, "MuR_Font1", w - pad - We(UI.CLOSE_RESERVE), He(22),
			c.textFaint, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
	end

	UI.HLine(0, He(UI.HEADER), w, c.line)
end

function UI.Field(x, y, w, label, value, valueColor, valueFont)
	local c = UI.Colors
	draw.SimpleText(label, "MuR_Font0", x, y, c.textFaint,
		TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	draw.SimpleText(value, valueFont or "MuR_Font1", x, y + He(15), valueColor or c.text,
		TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
end

function UI.TextClip(text, font, maxWidth)
	text = tostring(text or "")
	surface.SetFont(font)

	if surface.GetTextSize(text) <= maxWidth then return text end

	local ellipsis = "..."
	local budget = maxWidth - surface.GetTextSize(ellipsis)

	if budget <= 0 then return "" end

	local chars = utf8.len(text)

	if not chars then
		local out = text
		while #out > 1 and surface.GetTextSize(out) > budget do
			out = string.sub(out, 1, #out - 1)
		end
		return out .. ellipsis
	end

	local lo, hi, best = 0, chars, 0
	while lo <= hi do
		local mid = math.floor((lo + hi) / 2)
		local prefix = mid == 0 and "" or string.sub(text, 1, (utf8.offset(text, mid + 1) or (#text + 1)) - 1)

		if surface.GetTextSize(prefix) <= budget then
			best = mid
			lo = mid + 1
		else
			hi = mid - 1
		end
	end

	if best == 0 then return ellipsis end

	return string.sub(text, 1, (utf8.offset(text, best + 1) or (#text + 1)) - 1) .. ellipsis
end

function UI.WrapText(text, font, maxWidth)
	surface.SetFont(font)

	local lines, line = {}, ""

	for word in string.gmatch(tostring(text or ""), "%S+") do
		local candidate = line == "" and word or (line .. " " .. word)

		if surface.GetTextSize(candidate) > maxWidth and line ~= "" then
			lines[#lines + 1] = line
			line = word
		else
			line = candidate
		end
	end

	if line ~= "" then lines[#lines + 1] = line end

	return lines
end

function UI.Meter(x, y, w, h, frac, col, segments)
	local c = UI.Colors
	segments = segments or 24
	frac = math.Clamp(frac or 0, 0, 1)

	local gap = math.max(We(2), 1)
	local segW = (w - gap * (segments - 1)) / segments
	local lit = frac * segments

	for i = 0, segments - 1 do
		local fill = math.Clamp(lit - i, 0, 1)
		local sx = x + i * (segW + gap)

		UI.Rect(sx, y, segW, h, c.lineSoft)
		if fill > 0 then
			UI.Rect(sx, y, segW * fill, h, col or c.accent)
		end
	end
end

function UI.Button(parent, label, onClick)
	local c = UI.Colors
	local btn = vgui.Create("DButton", parent)
	btn:SetText("")

	btn.Paint = function(self, w, h)
		local hovered = self:IsHovered() and self:IsEnabled()
		local down = self:IsDown()

		UI.Rect(0, 0, w, h, down and c.panelDown or (hovered and c.panelHov or c.panel))
		UI.Outline(0, 0, w, h, hovered and c.accent or c.line)

		local col = c.text
		if not self:IsEnabled() then col = c.textFaint
		elseif hovered then col = c.accent end

		draw.SimpleText(self.Label or "", "MuR_Font1", w / 2, h / 2, col,
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	btn.Label = label
	btn.DoClick = function(self)
		surface.PlaySound("buttons/lightswitch2.wav")
		if onClick then onClick(self) end
	end

	return btn
end

function UI.Tab(parent, label, onClick)
	local c = UI.Colors
	local tab = vgui.Create("DButton", parent)
	tab:SetText("")
	tab.Active = false
	tab.Label = label

	tab.Paint = function(self, w, h)
		local hovered = self:IsHovered()

		if self.Active then
			UI.Rect(0, 0, w, h, c.panel)
		elseif hovered then
			UI.Rect(0, 0, w, h, c.lineSoft)
		end

		local col = self.Active and c.accent or (hovered and c.text or c.textDim)
		draw.SimpleText(self.Label or "", "MuR_Font1", w / 2, h / 2, col,
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		if self.Active then
			UI.Rect(0, h - He(2), w, He(2), c.accent)
		end
	end

	tab.DoClick = function(self)
		surface.PlaySound("buttons/lightswitch2.wav")
		if onClick then onClick(self) end
	end

	return tab
end

function UI.Scrollbar(scroll)
	local c = UI.Colors
	local bar = scroll:GetVBar()
	bar:SetHideButtons(true)
	bar:SetWide(We(3))

	bar.Paint = function(self, w, h) UI.Rect(0, 0, w, h, c.lineSoft) end
	bar.btnGrip.Paint = function(self, w, h) UI.Rect(0, 0, w, h, c.lineHot) end
	bar.btnUp.Paint = function() end
	bar.btnDown.Paint = function() end

	return bar
end

function UI.Frame(w, h, closeKeys)
	local c = UI.Colors
	local frame = vgui.Create("DFrame")
	frame:SetSize(w, h)
	frame:SetTitle("")
	frame:ShowCloseButton(false)
	frame:SetDraggable(false)
	frame:MakePopup()

	frame.CloseKeys = closeKeys or {KEY_ESCAPE}

	local close = vgui.Create("DButton", frame)
	close:SetText("")
	close:SetSize(We(UI.CLOSE), We(UI.CLOSE))
	close:SetPos(w - We(UI.PAD) - We(UI.CLOSE), He(15))

	close.Paint = function(self, bw, bh)
		local hovered = self:IsHovered()
		UI.Outline(0, 0, bw, bh, hovered and c.sev3 or c.line)

		local inset = bw * 0.3
		surface.SetDrawColor(hovered and c.sev3 or c.textDim)
		surface.DrawLine(inset, inset, bw - inset, bh - inset)
		surface.DrawLine(bw - inset, inset, inset, bh - inset)
	end

	close.DoClick = function()
		surface.PlaySound("buttons/lightswitch2.wav")
		frame:Remove()
	end

	frame.CloseButton = close

	frame.OnKeyCodePressed = function(self, key)
		for _, k in ipairs(self.CloseKeys) do
			if key == k then self:Remove() return end
		end
	end

	UI.frameSerial = (UI.frameSerial or 0) + 1
	local hookName = "MuR.UICloseKeys." .. UI.frameSerial

	local wasDown = false
	for _, k in ipairs(frame.CloseKeys) do
		if input.IsKeyDown(k) then wasDown = true break end
	end

	hook.Add("Think", hookName, function()
		if not IsValid(frame) then hook.Remove("Think", hookName) return end

		local down = false
		for _, k in ipairs(frame.CloseKeys) do
			if input.IsKeyDown(k) then down = true break end
		end

		if down and not wasDown then frame:Remove() end
		wasDown = down
	end)

	return frame
end

function UI.ReportPanelClosed(panel)
	if IsValid(panel) and panel.MuR_SuppressCloseReport then return end

	net.Start("MuR.BodyPanelClosed")
	net.SendToServer()
end

function UI.SubjectName(ent, unknownText)
	if not IsValid(ent) then return unknownText or "" end

	local name = ent.GetNWString and ent:GetNWString("Name", "") or ""

	if name == MuR.UNIDENTIFIED_NAME then return unknownText or name end
	if name ~= "" then return name end

	return unknownText or ""
end

function UI.PositionExamine(frame)
	frame:SetPos(ScrW() * 0.62, (ScrH() - frame:GetTall()) * 0.5)
end

function UI.Row(parent, label, height)
	local c = UI.Colors
	local row = vgui.Create("DPanel", parent)
	row:Dock(TOP)
	row:SetTall(height or He(46))
	row:DockMargin(0, 0, 0, 0)

	row.Label = label
	row.Paint = function(self, w, h)
		UI.HLine(0, h - 1, w, c.lineSoft)

		local reserved = We(UI.PAD) * 2
		for _, child in ipairs(self:GetChildren()) do
			if child:IsVisible() then reserved = reserved + child:GetWide() + We(10) end
		end

		draw.SimpleText(UI.TextClip(self.Label or "", "MuR_Font1", w - reserved),
			"MuR_Font1", We(UI.PAD), h / 2, c.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	return row
end

function UI.Checkbox(parent, convar)
	local c = UI.Colors
	local box = vgui.Create("DButton", parent)
	box:SetText("")
	box:SetSize(He(20), He(20))

	local cv = GetConVar(convar)

	box.Paint = function(self, w, h)
		local on = cv and cv:GetBool()
		UI.Outline(0, 0, w, h, self:IsHovered() and c.accent or c.line)
		if on then UI.Rect(He(4), He(4), w - He(8), h - He(8), c.accent) end
	end

	box.DoClick = function()
		if not cv then return end
		RunConsoleCommand(convar, cv:GetBool() and "0" or "1")
		surface.PlaySound("buttons/lightswitch2.wav")
	end

	return box
end

function UI.Slider(parent, convar, minv, maxv, decimals)
	local c = UI.Colors
	local slider = vgui.Create("DPanel", parent)
	slider:SetSize(We(260), He(28))

	local cv = GetConVar(convar)
	decimals = decimals or 0
	minv, maxv = minv or 0, maxv or 100

	local dragging = false

	local function valueToFrac(v)
		return math.Clamp((v - minv) / math.max(maxv - minv, 0.001), 0, 1)
	end

	local function setFromX(x, w)
		local frac = math.Clamp(x / math.max(w, 1), 0, 1)
		local value = minv + frac * (maxv - minv)
		if decimals == 0 then value = math.Round(value) end
		RunConsoleCommand(convar, tostring(value))
	end

	slider.Paint = function(self, w, h)
		local value = cv and cv:GetFloat() or minv
		local frac = valueToFrac(value)
		local trackY = h / 2 - He(2)
		local knobW = We(4)
		local usable = w - We(60) - knobW

		UI.Rect(0, trackY, usable, He(3), c.lineSoft)
		UI.Rect(0, trackY, usable * frac, He(3), c.accent)
		UI.Rect(usable * frac, h / 2 - He(9), knobW, He(18), c.text)

		draw.SimpleText(decimals == 0 and tostring(math.Round(value)) or string.format("%." .. decimals .. "f", value),
			"MuR_Font1", w, h / 2, c.accent, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end

	slider.OnMousePressed = function(self)
		dragging = true
		self:MouseCapture(true)
	end

	slider.OnMouseReleased = function(self)
		dragging = false
		self:MouseCapture(false)
	end

	slider.Think = function(self)
		if not dragging then return end
		local x = self:CursorPos()
		setFromX(x, self:GetWide() - We(60) - We(4))
	end

	return slider
end

function UI.TextEntry(parent, convar)
	local c = UI.Colors
	local entry = vgui.Create("DTextEntry", parent)
	entry:SetSize(We(220), He(26))
	entry:SetFont("MuR_Font1")
	entry:SetDrawBackground(false)

	local cv = GetConVar(convar)
	if cv then entry:SetValue(cv:GetString()) end

	entry.Paint = function(self, w, h)
		UI.Rect(0, 0, w, h, c.panelDown)
		UI.Outline(0, 0, w, h, self:IsEditing() and c.accent or c.line)
		self:DrawTextEntryText(c.text, c.accentDim, c.accent)
	end

	entry.OnValueChange = function(self, value)
		RunConsoleCommand(convar, value)
	end

	return entry
end

function UI.Menu(parent)
	local c = UI.Colors
	local menu = DermaMenu(false, parent)

	menu.Paint = function(self, w, h)
		UI.Rect(0, 0, w, h, c.bg)
		UI.Outline(0, 0, w, h, c.line)
	end

	local addOption = menu.AddOption
	menu.AddOption = function(self, text, func)
		local option = addOption(self, text, func)
		option:SetFont("MuR_Font1")
		option:SetTextColor(c.text)
		option.Paint = function(pnl, w, h)
			if pnl:IsHovered() then
				UI.Rect(0, 0, w, h, c.panelHov)
				UI.Rect(0, 0, We(2), h, c.accent)
			end
		end
		return option
	end

	return menu
end

function UI.ComboBox(parent, options, convar)
	local c = UI.Colors
	local combo = vgui.Create("DButton", parent)
	combo:SetSize(We(220), He(26))
	combo:SetText("")

	local cv = GetConVar(convar)

	local function currentLabel()
		if not cv then return "" end
		local value = cv:GetString()
		return options[value] or value
	end

	combo.Paint = function(self, w, h)
		UI.Rect(0, 0, w, h, c.panelDown)
		UI.Outline(0, 0, w, h, self:IsHovered() and c.accent or c.line)
		draw.SimpleText(UI.TextClip(currentLabel(), "MuR_Font1", w - We(28)),
			"MuR_Font1", We(8), h / 2, c.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		UI.Rect(w - We(16), h / 2 - He(1), We(8), He(2), c.textDim)
	end

	combo.DoClick = function(self)
		local menu = UI.Menu(self)
		for value, label in SortedPairsByValue(options) do
			menu:AddOption(label, function() RunConsoleCommand(convar, value) end)
		end
		menu:Open()
	end

	return combo
end

function UI.Binder(parent, initialKey, onChange)
	local c = UI.Colors
	local binder = vgui.Create("DBinder", parent)
	binder:SetSize(We(180), He(26))

	binder:SetText("")
	binder.UpdateText = function(self) self:SetText("") end

	binder:SetValue(initialKey or KEY_NONE)

	binder.Paint = function(self, w, h)
		UI.Rect(0, 0, w, h, c.panelDown)

		local waiting = self.Trapping == true
		UI.Outline(0, 0, w, h, (waiting or self:IsHovered()) and c.accent or c.line)

		local key = self:GetValue() or KEY_NONE
		local text = "-"
		if waiting then
			text = "..."
		elseif key ~= KEY_NONE then
			text = input.GetKeyName(key) or "-"
		end

		draw.SimpleText(text, "MuR_Font1", w / 2, h / 2,
			waiting and c.accent or c.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	binder.OnChange = function(self, num)
		if onChange then onChange(num) end
	end

	return binder
end
