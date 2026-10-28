local We = We or function(x) return x * (ScrW() / 1920) end
local He = He or function(x) return x * (ScrH() / 1080) end

local UI = MuR.UI
local C = UI.Colors

MuR.RagdollMenuOpen = nil
MuR.RagdollActionInProgress = false
MuR.BodyMenu = MuR.BodyMenu or {}

local Menu = MuR.BodyMenu

local livePanels = {}

local function closeAllPanels(silent)
	for panel in pairs(livePanels) do
		if IsValid(panel) then
			panel.MuR_SuppressCloseReport = silent
			panel:Remove()
		end
		livePanels[panel] = nil
	end
end

Menu.CloseAll = closeAllPanels

local function L(key)
	local value = MuR.Language[key]
	if value then return value end

	if MuR.LoadLanguage and MuR.CurrentLanguage then
		MuR.LoadLanguage(MuR.CurrentLanguage)
		value = MuR.Language[key]
		if value then return value end
	end

	return key
end

MuR.BodyMenuL = L

local FRAME_W, FRAME_H = 470, 540

local TABS = {
	{id = "wounds", label = "ragdoll_menu_wounds", action = "wounds", duration = 5,
	 progress = "ragdoll_menu_examining_wounds"},
	{id = "pulse", label = "ragdoll_menu_pulse", action = "pulse", duration = 2,
	 progress = "ragdoll_menu_checking_pulse"},
	{id = "search", label = "ragdoll_menu_search", action = "search", duration = 2,
	 progress = "ragdoll_menu_searching"}
}

function Menu.IsOpen()
	return IsValid(MuR.RagdollMenuOpen)
end

function Menu.SetContent(builder)
	local frame = MuR.RagdollMenuOpen
	if not IsValid(frame) or not IsValid(frame.Body) then return end

	frame.Body:Clear()
	frame.Body.Paint = function(self, w, h)
		if builder then builder(self, w, h) end
	end

	frame.ContentBuilder = builder
end

local function setTabState(id, state)
	local frame = MuR.RagdollMenuOpen
	if not IsValid(frame) then return end
	frame.TabState[id] = state
end

local function viewIdle(hintKey)
	return function(self, w, h)
		draw.SimpleText(L(hintKey), "MuR_Font1", w / 2, h / 2, C.textFaint,
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
end

local function viewDenied(reasonKey)
	return function(self, w, h)
		draw.SimpleText(L(reasonKey), "MuR_Font1", w / 2, h / 2, C.sev3,
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
end

local function viewProgress(startTime, duration, labelKey, sharedKey, entity)
	return function(self, w, h)
		local pad = We(UI.PAD)

		local frac
		if sharedKey and IsValid(entity) then
			frac = math.Clamp(entity:GetNW2Float(sharedKey, 0) / duration, 0, 1)
		else
			frac = math.Clamp((CurTime() - startTime) / duration, 0, 1)
		end

		local y = h / 2 - He(30)

		draw.SimpleText(L(labelKey), "MuR_Font1", w / 2, y, C.textDim,
			TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

		UI.Meter(pad, y + He(30), w - pad * 2, He(6), frac, C.accent, 32)

		draw.SimpleText(math.floor(frac * 100) .. "%", "MuR_Font1", w / 2, y + He(48),
			C.accent, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

		draw.SimpleText(L("ragdoll_menu_cancel_hint"), "MuR_Font0", w / 2, h - He(24),
			C.textFaint, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
	end
end

local function buildWounds(woundsData)
	if not woundsData or #woundsData == 0 then
		Menu.SetContent(function(self, w, h)
			draw.SimpleText(L("ragdoll_menu_no_wounds"), "MuR_Font1", w / 2, h / 2,
				C.textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end)
		return
	end

	local frame = MuR.RagdollMenuOpen
	if not IsValid(frame) or not IsValid(frame.Body) then return end

	frame.Body:Clear()
	frame.Body.Paint = function() end

	local pad = We(UI.PAD)
	local scroll = vgui.Create("DScrollPanel", frame.Body)
	scroll:Dock(FILL)
	scroll:DockMargin(pad, He(12), pad, He(12))
	UI.Scrollbar(scroll)

	for i, wound in ipairs(woundsData) do
		local text = wound.locKey and L(wound.locKey) or wound.text
		local sev = wound.severity or 1

		local row = vgui.Create("DPanel", scroll)
		row:Dock(TOP)
		row:SetTall(He(UI.ROW))
		row:DockMargin(0, 0, We(10), 0)

		row.Paint = function(self, w, h)
			if i > 1 then UI.HLine(0, 0, w, C.lineSoft) end

			draw.SimpleText(string.format("%02d", i), "MuR_Font0", 0, h / 2, C.textFaint,
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			draw.SimpleText(text, "MuR_Font1", We(30), h / 2, C.text,
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			local tag = L("ui_sev_" .. math.Clamp(sev, 1, 3))
			draw.SimpleText(tag, "MuR_Font0", w, h / 2, UI.SeverityColor(sev),
				TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		end
	end
end

local PULSE_ABSENT, PULSE_THREADY, PULSE_WEAK, PULSE_RACING, PULSE_STRONG = 0, 1, 2, 3, 4

local PULSE_INFO = {
	[PULSE_ABSENT]  = {key = "ragdoll_pulse_absent",  sev = 3, frac = 0},
	[PULSE_THREADY] = {key = "ragdoll_pulse_thready", sev = 3, frac = 0.2},
	[PULSE_WEAK]    = {key = "ragdoll_pulse_weak",    sev = 2, frac = 0.45},
	[PULSE_RACING]  = {key = "ragdoll_pulse_racing",  sev = 2, frac = 0.8},
	[PULSE_STRONG]  = {key = "ragdoll_pulse_strong",  sev = 1, frac = 1}
}

local function viewPulse(quality, bpm)
	local info = PULSE_INFO[quality] or PULSE_INFO[PULSE_STRONG]
	local col = UI.SeverityColor(info.sev)
	local beat = 0

	return function(self, w, h)
		local pad = We(UI.PAD)
		local top = He(40)

		if quality == PULSE_ABSENT then
			draw.SimpleText(L("ragdoll_pulse_no_reading"), "MuR_Font3", w / 2, top + He(30),
				col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		else
			beat = (beat + FrameTime() * (bpm / 60)) % 1
			local pulseAlpha = 150 + math.max(0, math.sin(beat * math.pi * 2)) * 105

			draw.SimpleText(tostring(bpm), "MuR_Font6", w / 2, top + He(34),
				ColorAlpha(col, pulseAlpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

			draw.SimpleText(L("ragdoll_pulse_bpm"), "MuR_Font0", w / 2,
				top + He(72), C.textFaint, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end

		UI.Meter(pad, top + He(100), w - pad * 2, He(8), info.frac, col, 20)

		UI.HLine(pad, top + He(132), w - pad * 2, C.lineSoft)

		UI.Field(pad, top + He(150), w - pad * 2, L("ragdoll_pulse_quality_label"),
			L(info.key), col)
	end
end

local function runAction(tab)
	local frame = MuR.RagdollMenuOpen
	if not IsValid(frame) then return end
	if MuR.RagdollActionInProgress then return end
	if not IsValid(frame.Entity) then return end

	net.Start("MuR.RagdollAction")
		net.WriteEntity(frame.Entity)
		net.WriteString(tab.action)
	net.SendToServer()

	local startTime = CurTime()
	MuR.RagdollActionInProgress = true
	frame.ActiveAction = tab.id
	frame.ActionStart = startTime
	frame.ActionDuration = tab.duration

	setTabState(tab.id, "busy")
	Menu.SetContent(viewProgress(startTime, tab.duration, tab.progress, tab.shared_progress, frame.Entity))
end

local function viewConfirm(tab)
	local frame = MuR.RagdollMenuOpen
	if not IsValid(frame) or not IsValid(frame.Body) then return end

	frame.Body:Clear()
	frame.Body.Paint = function(self, w, h)
		draw.SimpleText(L(tab.label), "MuR_Font2", w / 2, h / 2 - He(70), C.text,
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		draw.SimpleText(L(tab.confirm), "MuR_Font1", w / 2, h / 2 - He(36), C.textDim,
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		draw.SimpleText(string.format("%s: %ds", L("ragdoll_menu_duration"), tab.duration),
			"MuR_Font0", w / 2, h / 2 - He(12), C.textFaint, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	local btn = UI.Button(frame.Body, L(tab.label), function()
		runAction(tab)
	end)

	btn:SetSize(We(220), He(38))
	btn:SetPos(frame.Body:GetWide() / 2 - We(110), frame.Body:GetTall() / 2 + He(16))
end

function Menu.CancelAction(silent)
	local frame = MuR.RagdollMenuOpen
	if not MuR.RagdollActionInProgress then return end

	MuR.RagdollActionInProgress = false

	net.Start("MuR.RagdollActionCancel")
	net.SendToServer()

	if not silent then surface.PlaySound("buttons/button10.wav") end

	if IsValid(frame) then
		local id = frame.ActiveAction
		frame.ActiveAction = nil
		if id then
			setTabState(id, "idle")
			if frame.CurrentTab == id then
				Menu.SetContent(viewIdle("ragdoll_menu_cancelled"))
			end
		end
	end
end

local function CreateRagdollMenu(ragdoll)
	if MuR.RagdollActionInProgress then return end

	closeAllPanels(true)

	local tabs = {}
	for _, tab in ipairs(TABS) do tabs[#tabs + 1] = tab end

	if ragdoll:GetNW2Bool("MuR.Cuffed", false) then
		tabs[#tabs + 1] = {id = "cuffs", label = "ragdoll_menu_uncuff", action = "cuffs",
			duration = 10, progress = "ragdoll_menu_uncuffing", confirm = "ragdoll_menu_uncuff_warn",
			shared_progress = "MuR.CuffProgress"}
	elseif ragdoll:GetNW2Bool("MuR.Zipped", false) then
		tabs[#tabs + 1] = {id = "cuffs", label = "ragdoll_menu_unzip", action = "cuffs",
			duration = 5, progress = "ragdoll_menu_unzipping", confirm = "ragdoll_menu_unzip_warn",
			shared_progress = "MuR.ZipProgress"}
	end

	local frameW = FRAME_W + math.max(0, #tabs - 3) * 90

	local frame = UI.Frame(We(frameW), He(FRAME_H), {KEY_ESCAPE, KEY_E})
	frame.MuR_IsBodyPanel = true
	livePanels[frame] = true
	MuR.RagdollMenuOpen = frame
	UI.PositionExamine(frame)

	frame.Entity = ragdoll
	frame.TabState = {}
	frame.CurrentTab = nil
	frame.Results = {}

	local subject = UI.SubjectName(ragdoll, L("ragdoll_menu_subject_unknown"))

	frame.Paint = function(self, w, h)
		UI.Chrome(w, h, L("ragdoll_menu_title"), subject, L("ragdoll_menu_close_key"))
	end

	frame.OnRemove = function(self)
		livePanels[self] = nil
		if MuR.RagdollActionInProgress then Menu.CancelAction(true) end
		UI.ReportPanelClosed(self)
	end

	frame.Think = function(self)
		if MuR.RagdollActionInProgress and LocalPlayer():GetVelocity():Length() > 50 then
			Menu.CancelAction()
			return
		end

		if MuR.RagdollActionInProgress and self.ActionStart then
			if CurTime() >= self.ActionStart + self.ActionDuration + 8 then
				MuR.RagdollActionInProgress = false
				self.ActiveAction = nil
				Menu.SetContent(viewIdle("ragdoll_menu_no_response"))
			end
		end
	end

	local tabStrip = vgui.Create("DPanel", frame)
	tabStrip:SetPos(0, He(UI.HEADER))
	tabStrip:SetSize(We(frameW), He(UI.TAB))
	tabStrip.Paint = function(self, w, h) UI.HLine(0, h - 1, w, C.line) end

	local body = vgui.Create("DPanel", frame)
	body:SetPos(0, He(UI.HEADER + UI.TAB))
	body:SetSize(We(frameW), He(FRAME_H - UI.HEADER - UI.TAB))
	body.Paint = function() end
	frame.Body = body

	local tabW = We(frameW) / #tabs
	local buttons = {}

	local function selectTab(tab)
		if MuR.RagdollActionInProgress then return end

		frame.CurrentTab = tab.id
		for _, b in ipairs(buttons) do b.Active = (b.TabId == tab.id) end

		local stored = frame.Results[tab.id]
		if stored then
			stored()
		elseif tab.confirm then
			viewConfirm(tab)
		else
			runAction(tab)
		end
	end

	for i, tab in ipairs(tabs) do
		local btn = UI.Tab(tabStrip, L(tab.label), function() selectTab(tab) end)
		btn:SetPos((i - 1) * tabW, 0)
		btn:SetSize(tabW, He(UI.TAB))
		btn.TabId = tab.id
		buttons[#buttons + 1] = btn

		if i > 1 then
			local sep = vgui.Create("DPanel", tabStrip)
			sep:SetPos((i - 1) * tabW, He(8))
			sep:SetSize(1, He(UI.TAB - 16))
			sep.Paint = function(self, w, h) UI.Rect(0, 0, w, h, C.line) end
		end
	end

	frame.Buttons = buttons
	frame.SelectTab = selectTab

	Menu.SetContent(viewIdle("ragdoll_menu_pick_action"))
end

Menu.Create = CreateRagdollMenu

local function deliver(tabId, builder)
	local frame = MuR.RagdollMenuOpen
	MuR.RagdollActionInProgress = false

	if not IsValid(frame) then return end

	frame.ActiveAction = nil
	setTabState(tabId, "done")
	frame.Results[tabId] = builder

	if frame.CurrentTab == tabId then builder() end
end

MuR.BodyMenuDeliver = deliver

net.Receive("MuR.RagdollMenu", function()
	local ragdoll = net.ReadEntity()
	if not IsValid(ragdoll) then return end
	CreateRagdollMenu(ragdoll)
end)

net.Receive("MuR.RagdollPulseResult", function()
	local quality = net.ReadUInt(3)
	local bpm = net.ReadUInt(8)

	deliver("pulse", function()
		Menu.SetContent(viewPulse(quality, bpm))
	end)

	surface.PlaySound("buttons/lightswitch2.wav")
end)

net.Receive("MuR.RagdollWoundsResult", function()
	local count = net.ReadUInt(8)
	local woundsData = {}
	for i = 1, count do
		woundsData[i] = {locKey = net.ReadString(), severity = net.ReadUInt(2)}
	end

	deliver("wounds", function()
		buildWounds(woundsData)
	end)

	surface.PlaySound("buttons/lightswitch2.wav")
end)

net.Receive("MuR.RagdollSearchResult", function()
	local canSearch = net.ReadBool()
	local reason = net.ReadString()

	MuR.RagdollActionInProgress = false

	if not canSearch then
		local frame = MuR.RagdollMenuOpen
		if IsValid(frame) then
			frame.ActiveAction = nil
			setTabState("search", "idle")
			if frame.CurrentTab == "search" then
				Menu.SetContent(viewDenied(reason))
			end
		else
			notification.AddLegacy(L(reason), NOTIFY_ERROR, 3)
		end

		surface.PlaySound("buttons/button10.wav")
	end
end)

net.Receive("MuR.RagdollBeingChecked", function()
	local action = net.ReadString()
	local checker = net.ReadEntity()

	local text
	if action == "pulse" then
		text = L("ragdoll_being_pulsed")
	elseif action == "wounds" then
		text = L("ragdoll_being_examined")
	elseif action == "search" then
		text = L("ragdoll_being_searched")
	end

	if text then notification.AddLegacy(text, NOTIFY_HINT, 3) end
end)

net.Receive("MuR.CuffsFreed", function()
	MuR.RagdollActionInProgress = false

	local frame = MuR.RagdollMenuOpen
	if IsValid(frame) then frame.ActiveAction = nil end

	Menu.CloseAll(false)

	notification.AddLegacy(L("cuffs_freed_done"), NOTIFY_GENERIC, 4)
	surface.PlaySound("buttons/lightswitch2.wav")
end)

net.Receive("MuR.CuffsAborted", function()
	local reason = net.ReadString()
	MuR.RagdollActionInProgress = false

	local frame = MuR.RagdollMenuOpen
	if not IsValid(frame) then
		notification.AddLegacy(L(reason), NOTIFY_ERROR, 3)
		return
	end

	frame.ActiveAction = nil
	setTabState("cuffs", "idle")
	if frame.CurrentTab == "cuffs" then
		Menu.SetContent(viewDenied(reason))
	end

	surface.PlaySound("buttons/button10.wav")
end)
