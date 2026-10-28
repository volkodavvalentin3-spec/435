local UI = MuR.UI

local We = function(x) return x * (ScrW() / 1920) end
local He = function(x) return x * (ScrH() / 1080) end

local function L(key, fallback)
	return MuR.Language and MuR.Language[key] or fallback or key
end

local Tools = {}

for _, kind in ipairs(MuR.SpawnKinds) do
	Tools[#Tools + 1] = {
		id = kind.id,
		kind = kind,
		name = kind.name,
		color = kind.color,
		category = "spawn",
	}
end

for _, objectType in ipairs(MuR.EditorObjectTypes) do
	Tools[#Tools + 1] = {
		id = objectType.id,
		objectType = objectType,
		name = objectType.name,
		color = objectType.color,
		category = objectType.category,
	}
end

local Editor = {
	open = false,
	tool = 1,
	points = {},
	objects = {},
	panel = nil,
	chance = MuR.SpawnItemChance,
	pendingStart = nil,
	pendingBounds = nil,
	pendingDestination = nil,
}

MuR.SpawnEditor = Editor

local function CurrentTool()
	return Tools[Editor.tool]
end

local function CurrentKind()
	local tool = CurrentTool()
	return tool and tool.kind
end

local function CurrentObjectType()
	local tool = CurrentTool()
	return tool and tool.objectType
end

local function SetTool(index)
	if Tools[index] then
		Editor.tool = index
		Editor.pendingStart = nil
		Editor.pendingBounds = nil
		Editor.pendingDestination = nil
	end
end

local function CountOf(kindID)
	local list = Editor.points[kindID]
	return list and #list or 0
end

local function CountObjects(category)
	local total = 0
	for _, object in ipairs(Editor.objects) do
		if not category or MuR.EditorObjectCategoryByID[object.type] == category then total = total + 1 end
	end
	return total
end

local function SendSpawnEdit(action, extra)
	local kind = CurrentKind()
	if not kind then return end

	net.Start("MuR.SpawnEditor.Edit")
	net.WriteString(action)
	net.WriteString(kind.id)
	if extra then extra() end
	net.SendToServer()
end

local function SendObjectEdit(action, extra)
	net.Start("MuR.EditorObject.Edit")
	net.WriteString(action)
	if extra then extra() end
	net.SendToServer()
end

local function AimSpot()
	local ply = LocalPlayer()
	if not IsValid(ply) then return nil end

	local trace = util.TraceLine({
		start = ply:EyePos(),
		endpos = ply:EyePos() + ply:GetAimVector() * 4096,
		filter = ply,
	})

	if not trace.Hit then return nil end
	return trace.HitPos + Vector(0, 0, 2)
end

local function BoundsFromPoints(first, second)
	if not isvector(first) or not isvector(second) then return nil end

	local mins = Vector(
		math.min(first.x, second.x),
		math.min(first.y, second.y),
		math.min(first.z, second.z)
	)
	local maxs = Vector(
		math.max(first.x, second.x),
		math.max(first.y, second.y),
		math.max(first.z, second.z)
	)

	for _, axis in ipairs({"x", "y", "z"}) do
		local extent = maxs[axis] - mins[axis]
		if extent < MuR.EditorMinExtent then
			local center = (mins[axis] + maxs[axis]) * 0.5
			mins[axis] = center - MuR.EditorMinExtent * 0.5
			maxs[axis] = center + MuR.EditorMinExtent * 0.5
		elseif extent > MuR.EditorMaxExtent then
			return nil
		end
	end

	return mins, maxs
end

local function AddPoint()
	local pos = AimSpot()
	local kind = CurrentKind()
	if not pos or not kind then return end

	local angle = (pos - LocalPlayer():GetPos()):Angle().y
	local chance = MuR.SpawnItemChance
	if kind.id == "items" then
		chance = math.Clamp(math.Round(Editor.chance or MuR.SpawnItemChance), 0, 100)
	end

	SendSpawnEdit("add", function()
		net.WriteVector(pos)
		net.WriteFloat(angle)
		net.WriteUInt(chance, 7)
	end)
end

local function RemovePoint()
	local pos = AimSpot()
	if not pos then return end
	SendSpawnEdit("remove", function() net.WriteVector(pos) end)
end

local function AddObject()
	local objectType = CurrentObjectType()
	local aim = AimSpot()
	if not objectType or not aim then return end

	if not Editor.pendingStart then
		Editor.pendingStart = aim
		return
	end

	if not Editor.pendingBounds then
		local mins, maxs = BoundsFromPoints(Editor.pendingStart, aim)
		if not mins or not maxs then
			Editor.pendingStart = nil
			return
		end

		if objectType.id == "trigger_teleport" then
			Editor.pendingBounds = {mins = mins, maxs = maxs}
			return
		end

		SendObjectEdit("add", function()
			net.WriteString(objectType.id)
			net.WriteVector(mins)
			net.WriteVector(maxs)
		end)
		Editor.pendingStart = nil
		return
	end

	Editor.pendingDestination = aim
	SendObjectEdit("add", function()
		net.WriteString(objectType.id)
		net.WriteVector(Editor.pendingBounds.mins)
		net.WriteVector(Editor.pendingBounds.maxs)
		net.WriteVector(Editor.pendingDestination)
	end)
	Editor.pendingStart = nil
	Editor.pendingBounds = nil
	Editor.pendingDestination = nil
end

local function RemoveObject()
	local pos = AimSpot()
	if not pos then return end
	SendObjectEdit("remove", function() net.WriteVector(pos) end)
end

local function ClearCurrent()
	local kind = CurrentKind()
	if kind then
		SendSpawnEdit("clear")
		return
	end

	local objectType = CurrentObjectType()
	if objectType then
		SendObjectEdit("clear", function() net.WriteString(objectType.category) end)
	end
end

local function CancelPlacement()
	Editor.pendingStart = nil
	Editor.pendingBounds = nil
	Editor.pendingDestination = nil
end

local function DrawMarker(pos, angle, color, active, label)
	render.SetColorMaterial()
	cam.Start3D2D(pos + Vector(0, 0, 1), Angle(0, 0, 0), 0.5)
		draw.NoTexture()
		surface.SetDrawColor(color.r, color.g, color.b, active and 110 or 45)
		local poly = {}
		for index = 0, 24 do
			local radians = math.rad(index / 24 * 360)
			poly[#poly + 1] = {x = math.cos(radians) * 44, y = math.sin(radians) * 44}
		end
		surface.DrawPoly(poly)
	cam.End3D2D()

	local top = pos + Vector(0, 0, 72)
	render.DrawLine(pos, top, color, true)
	local facing = Angle(0, angle, 0)
	local forward, right = facing:Forward(), facing:Right()
	local base = pos + Vector(0, 0, 4)
	local tip = base + forward * 48
	render.DrawLine(base, tip, color, true)
	render.DrawLine(tip, tip - forward * 14 + right * 10, color, true)
	render.DrawLine(tip, tip - forward * 14 - right * 10, color, true)

	if label then
		cam.Start3D2D(top + Vector(0, 0, 8), Angle(0, EyeAngles().y - 90, 90), 0.15)
			draw.SimpleText(label, "MuR_Font1", 0, 0, color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		cam.End3D2D()
	end
end

local function DrawObject(object, active)
	local objectType = MuR.EditorObjectTypeByID[object.type]
	if not objectType then return end

	local center = (object.mins + object.maxs) * 0.5
	local localMins = object.mins - center
	local localMaxs = object.maxs - center
	render.SetColorMaterial()
	render.DrawBox(center, angle_zero, localMins, localMaxs, Color(objectType.color.r, objectType.color.g, objectType.color.b, active and 28 or 15), true)
	render.DrawWireframeBox(center, angle_zero, localMins, localMaxs, Color(objectType.color.r, objectType.color.g, objectType.color.b, active and 210 or 90), true)

	cam.Start3D2D(object.maxs + Vector(0, 0, 8), Angle(0, EyeAngles().y - 90, 90), 0.15)
		draw.SimpleText("#" .. object.id, "MuR_Font1", 0, 0, objectType.color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	cam.End3D2D()

	if object.destination and object.type == "trigger_teleport" then
		render.DrawLine(center, object.destination, objectType.color, true)
		render.DrawLine(object.destination, object.destination + Vector(0, 0, 64), objectType.color, true)
	end
end

local function DrawPreview()
	local objectType = CurrentObjectType()
	if not objectType then return end

	local aim = AimSpot()
	if not aim then return end

	local mins, maxs = Editor.pendingBounds and Editor.pendingBounds.mins, Editor.pendingBounds and Editor.pendingBounds.maxs
	if not mins and Editor.pendingStart then mins, maxs = BoundsFromPoints(Editor.pendingStart, aim) end
	if mins and maxs then
		local center = (mins + maxs) * 0.5
		render.SetColorMaterial()
		render.DrawBox(center, angle_zero, mins - center, maxs - center, Color(objectType.color.r, objectType.color.g, objectType.color.b, 35), true)
		render.DrawWireframeBox(center, angle_zero, mins - center, maxs - center, Color(objectType.color.r, objectType.color.g, objectType.color.b, 230), true)
		if objectType.id == "trigger_teleport" and Editor.pendingBounds then
			render.DrawLine(center, aim, objectType.color, true)
			render.DrawLine(aim, aim + Vector(0, 0, 64), objectType.color, true)
		end
	elseif Editor.pendingStart then
		render.DrawLine(Editor.pendingStart, aim, objectType.color, true)
	end
end

hook.Add("PostDrawTranslucentRenderables", "MuR.SpawnEditor.Draw", function(_, sky)
	if sky or not Editor.open then return end
	local ply = LocalPlayer()
	if not IsValid(ply) then return end

	local origin = ply:GetPos()
	local radiusSqr = MuR.EditorDrawRadius * MuR.EditorDrawRadius
	local tool = CurrentTool()
	local activeID = tool and tool.id

	for _, kind in ipairs(MuR.SpawnKinds) do
		local active = activeID == kind.id
		for _, point in ipairs(Editor.points[kind.id] or {}) do
			if point.pos:DistToSqr(origin) <= radiusSqr then
				local label = kind.id == "items" and math.Round(point.chance or 0) .. "%" or nil
				DrawMarker(point.pos, point.ang or 0, kind.color, active, label)
			end
		end
	end

	for _, object in ipairs(Editor.objects) do
		local center = (object.mins + object.maxs) * 0.5
		if center:DistToSqr(origin) <= radiusSqr then DrawObject(object, activeID == object.type) end
	end

	DrawPreview()
end)

local function BuildPanel()
	local c = UI.Colors
	local panel = vgui.Create("DFrame")
	panel:SetSize(We(330), He(560))
	panel:SetPos(We(24), ScrH() * 0.5 - He(280))
	panel:SetTitle("")
	panel:ShowCloseButton(false)
	panel:SetDraggable(false)
	panel:SetMouseInputEnabled(false)
	panel:SetKeyboardInputEnabled(false)

	panel.Paint = function(self, w, h)
		UI.Chrome(w, h, L("editor_title", "MAP EDITOR"), game.GetMap())
		local y = He(68)
		local category = nil
		for index, tool in ipairs(Tools) do
			if category ~= tool.category then
				category = tool.category
				local sectionKey = category == "spawn" and "editor_section_spawns" or "editor_section_" .. category
				draw.SimpleText(L(sectionKey, category), "MuR_Font0", We(14), y, c.textFaint, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
				y = y + He(18)
			end

			local active = Editor.tool == index
			if active then UI.Rect(We(8), y - He(2), w - We(16), He(24), c.panelHov) end
			UI.Rect(We(14), y + He(5), We(8), He(8), tool.color)
			draw.SimpleText(index .. "  " .. L(tool.name, tool.id), "MuR_Font0", We(32), y, active and c.text or c.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			local count = tool.kind and CountOf(tool.id) or CountObjects(tool.category)
			draw.SimpleText(count, "MuR_Font0", w - We(16), y, active and c.text or c.textFaint, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
			y = y + He(24)
		end

		UI.HLine(We(12), y + He(2), w - We(24), c.lineSoft)
		y = y + He(14)
		local current = CurrentKind()
		if current and current.id == "items" then
			local chance = math.Round(Editor.chance or MuR.SpawnItemChance)
			draw.SimpleText(chance .. "%", "MuR_Font0", w - We(16), y, c.text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
			draw.SimpleText("← →", "MuR_Font0", We(14), y, c.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			y = y + He(20)
		end

		local pending
		if Editor.pendingBounds then
			pending = L("editor_stage_destination", "Destination")
		elseif Editor.pendingStart then
			pending = L("editor_stage_second", "Second point")
		end
		if pending then
			draw.SimpleText(pending, "MuR_Font0", We(14), y, c.accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			y = y + He(19)
		end

		for _, key in ipairs({"editor_action_add", "editor_action_remove", "editor_action_select", "editor_action_save", "editor_action_clear", "editor_action_cancel"}) do
			draw.SimpleText(L(key, key), "MuR_Font0", We(14), y, c.textFaint, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			y = y + He(17)
		end
	end

	panel.Refresh = function() end
	return panel
end

local function SetOpen(on)
	if on == Editor.open then return end
	Editor.open = on
	if on then
		Editor.chance = Editor.chance or MuR.SpawnItemChance
		Editor.panel = BuildPanel()
	else
		CancelPlacement()
		if IsValid(Editor.panel) then Editor.panel:Remove() end
		Editor.panel = nil
	end

	net.Start("MuR.SpawnEditor.Toggle")
	net.WriteBool(on)
	net.SendToServer()
end

hook.Add("ShutDown", "MuR.SpawnEditor.Close", function()
	if Editor.open then SetOpen(false) end
end)

local function ToggleEditor()
	SetOpen(not Editor.open)
	if Editor.open then chat.AddText(Color(219, 52, 48), "[bloodshed] ", color_white, L("editor_title", "MAP EDITOR")) end
end

concommand.Add("mur_editor", ToggleEditor)
concommand.Add("mur_spawneditor", ToggleEditor)

net.Receive("MuR.SpawnEditor.Sync", function()
	Editor.points = net.ReadTable() or {}
end)

net.Receive("MuR.EditorObject.Sync", function()
	local count = net.ReadUInt(10)
	Editor.objects = {}
	for _ = 1, count do
		local id = net.ReadUInt(32)
		local objectType = net.ReadString()
		local mins = net.ReadVector()
		local maxs = net.ReadVector()
		local destination = net.ReadBool() and net.ReadVector() or nil
		if MuR.IsEditorObjectType(objectType) and isvector(mins) and isvector(maxs) then
			Editor.objects[#Editor.objects + 1] = {id = id, type = objectType, mins = mins, maxs = maxs, destination = destination}
		end
	end
end)

local prevAttack, prevAttack2, prevReload = false, false, false

hook.Add("CreateMove", "MuR.SpawnEditor.Input", function(cmd)
	if not Editor.open then
		prevAttack, prevAttack2, prevReload = false, false, false
		return
	end

	local buttons = cmd:GetButtons()
	local attack = bit.band(buttons, IN_ATTACK) ~= 0
	local attack2 = bit.band(buttons, IN_ATTACK2) ~= 0
	local reload = bit.band(buttons, IN_RELOAD) ~= 0

	if attack and not prevAttack then
		if CurrentKind() then AddPoint() else AddObject() end
	end
	if attack2 and not prevAttack2 then
		if Editor.pendingStart then CancelPlacement()
		elseif CurrentKind() then RemovePoint()
		else RemoveObject() end
	end
	if reload and not prevReload then
		net.Start("MuR.SpawnEditor.Save")
		net.SendToServer()
	end

	prevAttack, prevAttack2, prevReload = attack, attack2, reload
	cmd:SetButtons(bit.band(buttons, bit.bnot(bit.bor(IN_ATTACK, IN_ATTACK2, IN_RELOAD))))

	local wheel = cmd:GetMouseWheel()
	if wheel ~= 0 then SetTool(((Editor.tool - 1 - wheel) % #Tools) + 1) end
end)

hook.Add("PlayerButtonDown", "MuR.SpawnEditor.Keys", function(ply, button)
	if not Editor.open or ply ~= LocalPlayer() then return end

	if button >= KEY_1 and button <= KEY_5 then
		SetTool(button - KEY_1 + 1)
		return
	end
	if button >= KEY_6 and button <= KEY_9 then
		SetTool(button - KEY_1 + 1)
		return
	end
	if button == KEY_0 then
		SetTool(10)
		return
	end
	if KEY_MINUS and button == KEY_MINUS then
		SetTool(11)
		return
	end
	if button == KEY_ESCAPE then
		CancelPlacement()
		return
	end
	if button == KEY_DELETE then
		CancelPlacement()
		ClearCurrent()
		return
	end

	local current = CurrentKind()
	if not current or current.id ~= "items" then return end
	if button == KEY_LEFT then
		Editor.chance = math.Clamp((Editor.chance or MuR.SpawnItemChance) - 5, 0, 100)
	elseif button == KEY_RIGHT then
		Editor.chance = math.Clamp((Editor.chance or MuR.SpawnItemChance) + 5, 0, 100)
	end
end)
