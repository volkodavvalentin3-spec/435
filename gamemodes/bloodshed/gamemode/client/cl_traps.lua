local T = MuR.Traps

MuR.TrapKnown = MuR.TrapKnown or {}
MuR.TrapPings = MuR.TrapPings or {}

local SLOT_FILE = "bloodshed_trap_slots.txt"
local SLOT_COUNT = 3

local Tier = "basic"
local Carried = {}
local ActiveCount = 0
local Selected = {sensor = nil, vector = nil, payload = nil, mods = {}}
local Hovered = nil
local StepIndex = 1

local function He(x) return x * (ScrH() / 1080) end
local function Wi(x) return x * (ScrW() / 1920) end

local function L(key, fallback)
	local lang = MuR.Language or {}
	return lang[key] or fallback or key
end

surface.CreateFont("MuR_Trap_Title", {font = "Courier New", size = He(26), weight = 700})
surface.CreateFont("MuR_Trap_Header", {font = "Courier New", size = He(19), weight = 700})
surface.CreateFont("MuR_Trap_Text", {font = "Courier New", size = He(16), weight = 500})
surface.CreateFont("MuR_Trap_Small", {font = "Courier New", size = He(13), weight = 400})

local COL_BG = Color(6, 14, 10, 245)
local COL_LINE = Color(0, 255, 136, 60)
local COL_MAIN = Color(0, 255, 136)
local COL_DIM = Color(136, 255, 170)
local COL_LOCK = Color(90, 100, 95)
local COL_BAD = Color(255, 90, 90)
local COL_WARN = Color(255, 170, 0)

--[[ ------------------------------------------------------------------
	Состояние чертежа
------------------------------------------------------------------ ]]--

local function Profile()
	return T.Profiles[Tier] or T.Profiles.basic
end

-- Шаг с модулями существует только у полного доступа.
local function Steps()
	if Profile().mods then
		return {"sensor", "vector", "payload", "mod", "summary"}
	end

	return {"sensor", "vector", "payload", "summary"}
end

local function CurrentStep()
	return Steps()[StepIndex] or "summary"
end

local function Store(kind)
	if kind == "sensor" then return T.Sensors, T.SensorList end
	if kind == "vector" then return T.Vectors, T.VectorList end
	if kind == "payload" then return T.Payloads, T.PayloadList end

	return T.Mods, T.ModList
end

local function BlueprintTable()
	return {sensor = Selected.sensor, vector = Selected.vector, payload = Selected.payload, mods = Selected.mods}
end

local function CurrentCost()
	return T:BlueprintCost(BlueprintTable())
end

local function IsComplete()
	return Selected.sensor ~= nil and Selected.vector ~= nil and Selected.payload ~= nil
end

local function IsAvailable(kind, id)
	local store = Store(kind)
	local data = store[id]
	if not data then return false, "trap_err_broken" end

	if not T:TierAllows(Tier, data.tier) then return false, "trap_menu_locked" end
	if kind == "mod" and not Profile().mods then return false, "trap_menu_locked" end
	if kind == "payload" and data.chem and not Profile().chem then return false, "trap_menu_locked" end
	if kind == "payload" and data.weapon and not Carried[id] then return false, "trap_menu_noitem" end

	-- Совместимость: вектор несёт не любую форму начинки и не с любым датчиком.
	if kind == "vector" then
		local sensor = Selected.sensor and T.Sensors[Selected.sensor]
		if sensor and not T:VectorTakesSensor(data, sensor) then return false, "trap_menu_reach" end
	end

	if kind == "payload" then
		local vector = Selected.vector and T.Vectors[Selected.vector]
		if vector and not T:VectorTakesPayload(vector, data) then return false, "trap_menu_form" end
	end

	return true
end

-- Смена датчика или вектора может обессмыслить то, что выбрано дальше.
local function DropInvalidSelections()
	if Selected.vector and not IsAvailable("vector", Selected.vector) then
		Selected.vector = nil
	end

	if Selected.payload and not IsAvailable("payload", Selected.payload) then
		Selected.payload = nil
	end
end

local function HasModSelected(id)
	return table.HasValue(Selected.mods, id)
end

local function ToggleMod(id)
	local mod = T.Mods[id]
	if not mod then return end

	if HasModSelected(id) then
		table.RemoveByValue(Selected.mods, id)
		return
	end

	-- Взаимоисключающие модули (например, две разные задержки).
	if mod.group then
		for _, otherID in ipairs(table.Copy(Selected.mods)) do
			local other = T.Mods[otherID]
			if other and other.group == mod.group then
				table.RemoveByValue(Selected.mods, otherID)
			end
		end
	end

	table.insert(Selected.mods, id)
end

local function ModuleLabel(kind, id)
	local store = Store(kind)
	local data = store[id]

	if kind == "payload" then return T:PayloadName(data) end

	return T:ModuleName(kind, id)
end

local function SpecLine()
	local parts = {}

	if Selected.sensor then parts[#parts + 1] = ModuleLabel("sensor", Selected.sensor) end
	if Selected.vector then parts[#parts + 1] = ModuleLabel("vector", Selected.vector) end
	if Selected.payload then parts[#parts + 1] = ModuleLabel("payload", Selected.payload) end

	if #parts == 0 then return L("trap_menu_empty") end

	return table.concat(parts, " / ")
end

--[[ ------------------------------------------------------------------
	Слоты чертежей — переживают раунд, лежат в data/
------------------------------------------------------------------ ]]--

local function LoadSlots()
	local raw = file.Read(SLOT_FILE, "DATA")
	if not raw then return {} end

	return util.JSONToTable(raw) or {}
end

local function SaveSlots(slots)
	file.Write(SLOT_FILE, util.TableToJSON(slots))
end

local function StoreSlot(index)
	local slots = LoadSlots()
	slots[tostring(index)] = BlueprintTable()
	SaveSlots(slots)
end

local function RecallSlot(index)
	local bp = LoadSlots()[tostring(index)]
	if not bp then return false end

	Selected.sensor = bp.sensor
	Selected.vector = bp.vector
	Selected.payload = bp.payload
	Selected.mods = {}

	-- Модули из чужого режима и связки, ставшие несовместимыми, отбрасываем.
	for _, id in ipairs(bp.mods or {}) do
		if IsAvailable("mod", id) then table.insert(Selected.mods, id) end
	end

	DropInvalidSelections()

	return true
end

local function SlotLabel(index)
	local bp = LoadSlots()[tostring(index)]
	if not bp or not bp.sensor then return L("trap_slot_empty") end

	local store = Store("payload")
	local payload = store[bp.payload]

	return T:ModuleName("sensor", bp.sensor) .. " / " .. (payload and T:PayloadName(payload) or "?")
end

--[[ ------------------------------------------------------------------
	Меню
------------------------------------------------------------------ ]]--

local function StepTitle(kind)
	return L("trap_menu_" .. (kind == "mod" and "mods" or kind))
end

local function DescribeModule(kind, id)
	local store = Store(kind)
	local data = store[id]
	if not data then return "", "" end

	if kind == "payload" and data.chem then
		local route = L("trap_route_" .. (data.route or "contact"), data.route or "")
		return T:PayloadName(data), L("trap_payload_chem_desc") .. "\n\n" .. L("trap_menu_route") .. route
	end

	return ModuleLabel(kind, id), T:ModuleDesc(kind, id)
end

local function WrapText(text, font, maxWidth)
	surface.SetFont(font)

	local lines = {}

	for _, paragraph in ipairs(string.Explode("\n", text)) do
		if paragraph == "" then
			lines[#lines + 1] = ""
		else
			local line = ""

			for _, word in ipairs(string.Explode(" ", paragraph)) do
				local test = line == "" and word or (line .. " " .. word)

				if surface.GetTextSize(test) > maxWidth and line ~= "" then
					lines[#lines + 1] = line
					line = word
				else
					line = test
				end
			end

			lines[#lines + 1] = line
		end
	end

	return lines
end

local function BuildList(parent, kind)
	parent:Clear()

	local store, list = Store(kind)
	local isMulti = kind == "mod"

	for _, id in ipairs(list) do
		local data = store[id]
		if not data then continue end

		local btn = parent:Add("DButton")
		btn:Dock(TOP)
		btn:SetTall(He(46))
		btn:DockMargin(0, 0, 0, He(4))
		btn:SetText("")

		btn.OnCursorEntered = function() Hovered = {kind = kind, id = id} end

		btn.Paint = function(_, w, h)
			local ok, reason = IsAvailable(kind, id)
			local chosen = isMulti and HasModSelected(id) or Selected[kind] == id

			surface.SetDrawColor(chosen and Color(0, 60, 35, 220) or Color(0, 0, 0, 140))
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(chosen and COL_MAIN or COL_LINE)
			surface.DrawOutlinedRect(0, 0, w, h)

			local textCol = ok and (chosen and COL_MAIN or COL_DIM) or COL_LOCK
			draw.SimpleText(ModuleLabel(kind, id), "MuR_Trap_Text", Wi(8), He(12), textCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			local note = ok and (L("trap_menu_cost") .. data.cost) or L(reason)
			draw.SimpleText(note, "MuR_Trap_Small", Wi(8), He(31), ok and COL_WARN or COL_LOCK, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			if kind == "payload" and data.chem and data.route then
				draw.SimpleText(L("trap_route_" .. data.route, data.route), "MuR_Trap_Small",
					w - Wi(8), He(31), COL_LOCK, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
			end
		end

		btn.DoClick = function()
			if not IsAvailable(kind, id) then
				surface.PlaySound("buttons/button10.wav")
				return
			end

			surface.PlaySound("buttons/button15.wav")

			if isMulti then
				ToggleMod(id)
			else
				Selected[kind] = id
				DropInvalidSelections()
			end
		end
	end
end

local function BuildSummary(parent)
	parent:Clear()

	local rows = {}

	rows[#rows + 1] = {L("trap_menu_sensor"), Selected.sensor and ModuleLabel("sensor", Selected.sensor) or "-"}
	rows[#rows + 1] = {L("trap_menu_vector"), Selected.vector and ModuleLabel("vector", Selected.vector) or "-"}
	rows[#rows + 1] = {L("trap_menu_payload"), Selected.payload and ModuleLabel("payload", Selected.payload) or "-"}

	if #Selected.mods > 0 then
		local names = {}
		for _, id in ipairs(Selected.mods) do names[#names + 1] = T:ModuleName("mod", id) end
		rows[#rows + 1] = {L("trap_menu_mods"), table.concat(names, ", ")}
	end

	rows[#rows + 1] = {L("trap_menu_time"), math.Round(T:AssembleTime(BlueprintTable()), 1) .. L("trap_hud_seconds")}

	for _, row in ipairs(rows) do
		local line = parent:Add("DPanel")
		line:Dock(TOP)
		line:SetTall(He(30))
		line:DockMargin(0, 0, 0, He(4))

		line.Paint = function(_, w, h)
			surface.SetDrawColor(0, 0, 0, 130)
			surface.DrawRect(0, 0, w, h)

			draw.SimpleText(row[1], "MuR_Trap_Small", Wi(8), h / 2, COL_LOCK, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			draw.SimpleText(row[2], "MuR_Trap_Text", w - Wi(8), h / 2, COL_DIM, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		end
	end

	-- Сохранение готовой схемы в слот.
	local save = parent:Add("DPanel")
	save:Dock(TOP)
	save:SetTall(He(64))
	save:DockMargin(0, He(12), 0, 0)

	save.Paint = function(_, w, h)
		draw.SimpleText(L("trap_slot_save"), "MuR_Trap_Small", 0, He(8), COL_LOCK, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	for i = 1, SLOT_COUNT do
		local btn = save:Add("DButton")
		btn:SetPos((i - 1) * Wi(102), He(22))
		btn:SetSize(Wi(96), He(32))
		btn:SetText("")

		btn.Paint = function(_, w, h)
			surface.SetDrawColor(0, 0, 0, 150)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(COL_LINE)
			surface.DrawOutlinedRect(0, 0, w, h)
			draw.SimpleText(L("trap_slot") .. i, "MuR_Trap_Small", w / 2, h / 2, COL_DIM, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end

		btn.DoClick = function()
			if not IsComplete() then
				surface.PlaySound("buttons/button10.wav")
				return
			end

			StoreSlot(i)
			surface.PlaySound("buttons/button9.wav")
		end
	end
end

local function OpenMenu()
	if IsValid(MuR.TrapMenu) then MuR.TrapMenu:Remove() end

	T:BuildChemPayloads()

	StepIndex = 1
	Hovered = nil

	local frame = vgui.Create("DFrame")
	MuR.TrapMenu = frame
	frame:SetSize(Wi(1080), He(720))
	frame:Center()
	frame:SetTitle("")
	frame:ShowCloseButton(false)
	frame:MakePopup()

	local content, sidebar, footer, refresh

	frame.Paint = function(_, w, h)
		surface.SetDrawColor(COL_BG)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(COL_MAIN)
		surface.DrawOutlinedRect(0, 0, w, h)

		draw.SimpleText(L("trap_menu_title"), "MuR_Trap_Title", w / 2, He(26), COL_MAIN, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		local tierLine = L(Tier == "advanced" and "trap_menu_tier_advanced" or "trap_menu_tier_basic")
		draw.SimpleText(tierLine, "MuR_Trap_Small", Wi(16), He(26), COL_DIM, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		local limit = L("trap_menu_active") .. ActiveCount .. "/" .. Profile().maxActive
		draw.SimpleText(limit, "MuR_Trap_Small", w - Wi(16), He(26), COL_DIM, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

		-- Полоса шагов.
		local steps = Steps()
		local x = Wi(16)

		for i, kind in ipairs(steps) do
			local done = i < StepIndex
			local here = i == StepIndex
			local col = here and COL_MAIN or (done and COL_DIM or COL_LOCK)
			local label = i .. ". " .. StepTitle(kind)

			draw.SimpleText(label, "MuR_Trap_Small", x, He(56), col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			surface.SetFont("MuR_Trap_Small")
			local tw = surface.GetTextSize(label)

			if i < #steps then
				draw.SimpleText("->", "MuR_Trap_Small", x + tw + Wi(8), He(56), COL_LOCK, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			end

			x = x + tw + Wi(28)
		end

		surface.SetDrawColor(COL_LINE)
		surface.DrawRect(Wi(16), He(70), w - Wi(32), 1)
	end

	local close = frame:Add("DButton")
	close:SetSize(He(24), He(24))
	close:SetPos(frame:GetWide() - He(30), He(6))
	close:SetText("")
	close.Paint = function(_, w, h)
		draw.SimpleText("X", "MuR_Trap_Header", w / 2, h / 2, COL_BAD, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	close.DoClick = function() frame:Close() end

	-- Порядок важен: BOTTOM создаётся раньше FILL, иначе панели наложатся.
	footer = frame:Add("DPanel")
	footer:Dock(BOTTOM)
	footer:SetTall(He(70))
	footer:DockMargin(Wi(16), He(8), Wi(16), He(12))

	local body = frame:Add("DPanel")
	body:Dock(FILL)
	body:DockMargin(Wi(16), He(80), Wi(16), 0)
	body.Paint = function() end

	sidebar = body:Add("DPanel")
	sidebar:Dock(RIGHT)
	sidebar:SetWide(Wi(400))
	sidebar:DockMargin(Wi(10), 0, 0, 0)

	sidebar.Paint = function(_, w, h)
		surface.SetDrawColor(0, 0, 0, 120)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(COL_LINE)
		surface.DrawOutlinedRect(0, 0, w, h)

		local target = Hovered

		if not target then
			local kind = CurrentStep()
			if kind ~= "summary" and Selected[kind] then target = {kind = kind, id = Selected[kind]} end
		end

		if not target then
			draw.SimpleText(L("trap_menu_pick"), "MuR_Trap_Small", w / 2, h / 2, COL_LOCK, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			return
		end

		local name, desc = DescribeModule(target.kind, target.id)

		draw.SimpleText(name, "MuR_Trap_Header", Wi(14), He(24), COL_MAIN, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		local y = He(52)

		for _, line in ipairs(WrapText(desc, "MuR_Trap_Small", w - Wi(28))) do
			draw.SimpleText(line, "MuR_Trap_Small", Wi(14), y, COL_DIM, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			y = y + He(17)
		end
	end

	content = body:Add("DScrollPanel")
	content:Dock(FILL)

	local vbar = content:GetVBar()
	vbar:SetWide(Wi(6))
	vbar.Paint = function() end
	vbar.btnUp.Paint = function() end
	vbar.btnDown.Paint = function() end
	vbar.btnGrip.Paint = function(_, w, h)
		surface.SetDrawColor(COL_LINE)
		surface.DrawRect(0, 0, w, h)
	end

	footer.Paint = function(_, w, h)
		surface.SetDrawColor(0, 0, 0, 140)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(COL_LINE)
		surface.DrawOutlinedRect(0, 0, w, h)
	end

	local function makeFooterButton(dockSide, width, labelFn, enabledFn, action)
		local btn = footer:Add("DButton")
		btn:Dock(dockSide)
		btn:SetWide(width)
		btn:DockMargin(Wi(6), He(12), Wi(6), He(12))
		btn:SetText("")

		btn.Paint = function(_, w, h)
			local on = enabledFn()

			surface.SetDrawColor(on and Color(0, 70, 40, 230) or Color(38, 38, 38, 200))
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(on and COL_MAIN or COL_LOCK)
			surface.DrawOutlinedRect(0, 0, w, h)

			draw.SimpleText(labelFn(), "MuR_Trap_Header", w / 2, h / 2,
				on and COL_MAIN or COL_LOCK, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end

		btn.DoClick = function()
			if not enabledFn() then
				surface.PlaySound("buttons/button10.wav")
				return
			end

			surface.PlaySound("buttons/button15.wav")
			action()
		end

		return btn
	end

	refresh = function()
		Hovered = nil

		local kind = CurrentStep()

		if kind == "summary" then
			BuildSummary(content)
		else
			BuildList(content, kind)
		end
	end

	makeFooterButton(LEFT, Wi(150),
		function() return L("trap_menu_back") end,
		function() return StepIndex > 1 end,
		function()
			StepIndex = StepIndex - 1
			refresh()
		end)

	makeFooterButton(RIGHT, Wi(210),
		function()
			return CurrentStep() == "summary" and L("trap_menu_build") or L("trap_menu_next")
		end,
		function()
			local kind = CurrentStep()

			if kind == "summary" then
				return IsComplete() and CurrentCost() <= Profile().budget
			end

			-- Модули необязательны, остальные шаги требуют выбора.
			if kind == "mod" then return true end

			return Selected[kind] ~= nil
		end,
		function()
			if CurrentStep() ~= "summary" then
				StepIndex = StepIndex + 1
				refresh()
				return
			end

			net.Start("MuR.TrapBuild")
			net.WriteString(Selected.sensor)
			net.WriteString(Selected.vector)
			net.WriteString(Selected.payload)
			net.WriteUInt(#Selected.mods, 4)
			for _, id in ipairs(Selected.mods) do net.WriteString(id) end
			net.SendToServer()

			frame:Close()
		end)

	-- Быстрая загрузка сохранённой схемы доступна на любом шаге.
	for i = SLOT_COUNT, 1, -1 do
		makeFooterButton(RIGHT, Wi(120),
			function() return L("trap_slot") .. i end,
			function() return LoadSlots()[tostring(i)] ~= nil end,
			function()
				if RecallSlot(i) then
					StepIndex = #Steps()
					refresh()
				end
			end)
			:SetTooltip(SlotLabel(i))
	end

	-- Сводка создаётся последней и занимает FILL: так она встаёт между
	-- кнопками, а не под ними.
	local info = footer:Add("DPanel")
	info:Dock(FILL)
	info:DockMargin(Wi(10), 0, Wi(10), 0)

	info.Paint = function(_, w, h)
		local cost = CurrentCost()
		local budget = Profile().budget

		draw.SimpleText(L("trap_menu_budget") .. cost .. " / " .. budget, "MuR_Trap_Header",
			0, He(22), cost > budget and COL_BAD or COL_MAIN, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		local spec = SpecLine()
		surface.SetFont("MuR_Trap_Small")

		-- Длинная спецификация обрезается, чтобы не лезть на кнопки.
		while surface.GetTextSize(spec) > w and #spec > 4 do
			spec = string.sub(spec, 1, #spec - 4) .. "…"
		end

		draw.SimpleText(spec, "MuR_Trap_Small", 0, He(48), COL_DIM, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	refresh()
end

--[[ ------------------------------------------------------------------
	Сеть
------------------------------------------------------------------ ]]--

net.Receive("MuR.TrapOpen", function()
	Tier = net.ReadString()
	ActiveCount = net.ReadUInt(4)
	Carried = net.ReadTable()

	OpenMenu()
end)

net.Receive("MuR.TrapNotify", function()
	local key = net.ReadString()

	if MuR:GetClient("blsd_nohud") then return end

	local isError = string.sub(key, 1, 9) == "trap_err_"
	notification.AddLegacy(L(key), isError and NOTIFY_ERROR or NOTIFY_GENERIC, 4)
	surface.PlaySound(isError and "buttons/button10.wav" or "buttons/button15.wav")
end)

net.Receive("MuR.TrapSpec", function()
	local index = net.ReadUInt(13)
	local sensor, vector, payload = net.ReadString(), net.ReadString(), net.ReadString()

	MuR.TrapKnown[index] = {sensor = sensor, vector = vector, payload = payload}
end)

--[[ ------------------------------------------------------------------
	Призрак устройства

	Собранное устройство надо куда-то приложить, и без превью непонятно, к
	чему именно оно прицепится. Рисуем ту же сборку полупрозрачной там, где
	она встанет: зелёной если поставить можно, красной если нет.
------------------------------------------------------------------ ]]--

local Ghost = {key = nil, models = {}}

local function ClearGhost()
	for _, ent in ipairs(Ghost.models) do
		if IsValid(ent) then ent:Remove() end
	end

	Ghost.models = {}
	Ghost.key = nil
end

local function BuildGhost(bp)
	local key = bp.sensor .. "|" .. bp.vector .. "|" .. bp.payload
	if Ghost.key == key then return end

	ClearGhost()
	Ghost.key = key

	local defs = {{model = T.ChassisModel, pos = vector_origin, ang = angle_zero, scale = T.ChassisScale}}

	for _, def in ipairs(T:CollectParts(bp.sensor, bp.vector, bp.payload)) do
		defs[#defs + 1] = def
	end

	for _, def in ipairs(defs) do
		if not util.IsValidModel(def.model) then continue end

		local mdl = ClientsideModel(def.model, RENDERGROUP_TRANSLUCENT)
		if not IsValid(mdl) then continue end

		mdl:SetNoDraw(true)
		mdl:SetModelScale(def.scale or 1)

		Ghost.models[#Ghost.models + 1] = mdl
		Ghost.models[#Ghost.models].GhostPos = def.pos
		Ghost.models[#Ghost.models].GhostAng = def.ang or angle_zero
	end
end

hook.Add("PostDrawTranslucentRenderables", "MuR.TrapGhost", function(_, sky)
	if sky then return end

	local ply = LocalPlayer()
	local bp = MuR.TrapPendingBP

	if not IsValid(ply) or not ply:Alive() or not bp then return ClearGhost() end
	if ply:GetNW2Bool("MuR_TrapAnchoring", false) then return ClearGhost() end

	local wep = ply:GetActiveWeapon()
	if not IsValid(wep) or wep:GetClass() ~= "mur_trap_kit" then return ClearGhost() end

	BuildGhost(bp)

	local tr, _, err = T:PlantTrace(ply, bp)
	local origin, angles = T:PlantTransform(tr)

	if err then
		render.SetColorModulation(1, 0.25, 0.2)
	else
		render.SetColorModulation(0.3, 1, 0.5)
	end

	render.SetBlend(0.45)

	for _, mdl in ipairs(Ghost.models) do
		if IsValid(mdl) then
			local pos, ang = LocalToWorld(mdl.GhostPos, mdl.GhostAng, origin, angles)

			mdl:SetPos(pos)
			mdl:SetAngles(ang)
			mdl:SetupBones()
			mdl:DrawModel()
		end
	end

	render.SetBlend(1)
	render.SetColorModulation(1, 1, 1)
end)

net.Receive("MuR.TrapReadyBP", function()
	local sensor, vector, payload = net.ReadString(), net.ReadString(), net.ReadString()

	if sensor == "" then
		MuR.TrapPendingBP = nil
		ClearGhost()
		return
	end

	MuR.TrapPendingBP = {sensor = sensor, vector = vector, payload = payload}
end)

net.Receive("MuR.TrapProximity", function()
	local index = net.ReadUInt(13)

	MuR.TrapPings[index] = CurTime()
	surface.PlaySound("buttons/button15.wav")
end)

-- Индексы энтить переиспользуются между раундами, поэтому чистим на смене состояния.
hook.Add("MuR.GameState", "MuR.TrapForgetKnown", function()
	MuR.TrapKnown = {}
	MuR.TrapPings = {}
end)

--[[ ------------------------------------------------------------------
	Маркеры своих ловушек — иначе три активных устройства не удержать в голове
------------------------------------------------------------------ ]]--

hook.Add("HUDPaint", "MuR.TrapMarkers", function()
	local ply = LocalPlayer()
	if not IsValid(ply) or not ply:Alive() then return end
	if MuR:GetClient("blsd_nohud") then return end

	local wep = ply:GetActiveWeapon()
	if not IsValid(wep) or wep:GetClass() ~= "mur_trap_kit" then return end

	for _, ent in ipairs(ents.FindByClass("mur_trap")) do
		local index = ent:EntIndex()
		local spec = MuR.TrapKnown[index]
		if not spec then continue end

		local dist = ply:GetPos():Distance(ent:GetPos())
		if dist > 1500 then continue end

		local screen = ent:WorldSpaceCenter():ToScreen()
		if not screen.visible then continue end

		local armed = ent:GetArmed()
		local pinged = (CurTime() - (MuR.TrapPings[index] or -99)) < 3
		local col = pinged and COL_WARN or (armed and COL_MAIN or COL_LOCK)

		local head = pinged and L("trap_hud_contact") or (armed and "[+]" or "[-]")

		draw.SimpleText(head, "MuR_Trap_Small", screen.x, screen.y, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText(T:ModuleName("sensor", spec.sensor) .. " / " .. T:ModuleName("vector", spec.vector),
			"MuR_Trap_Small", screen.x, screen.y + He(13), col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText(math.Round(dist / 16) .. L("trap_hud_meters"), "MuR_Trap_Small",
			screen.x, screen.y + He(26), COL_DIM, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
end)
