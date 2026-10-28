local We = We or function(x) return x * (ScrW() / 1920) end
local He = He or function(x) return x * (ScrH() / 1080) end

local UI = MuR.UI
local C = UI.Colors

local function L(key)
	return MuR.Language[key] or key
end

local escapePanel = nil

local function SendResult(ok)
	net.Start("MuR.ZipEscapeResult")
	net.WriteBool(ok)
	net.SendToServer()
end

local function CreateEscapePanel(hits, needed)
	if IsValid(escapePanel) then escapePanel:Remove() end

	local w, h = We(460), He(190)

	local frame = UI.Frame(w, h)
	frame:Center()
	frame:SetKeyboardInputEnabled(true)
	frame:MakePopup()
	escapePanel = frame

	local trackW = w - We(UI.PAD) * 2
	local trackX = We(UI.PAD)
	local trackY = He(112)
	local trackH = He(14)

	local markerW = math.max(We(3), 2)
	local zoneW = We(52) * (1 - hits / needed * 0.35)
	local zoneX = math.Rand(zoneW, trackW - zoneW * 2)

	local pos = math.Rand(0, trackW - markerW)
	local speed = We(560) + We(70) * hits
	local dir = math.random(0, 1) == 0 and -1 or 1
	local active = true
	local resolved = false
	local status, statusColor = nil, C.textDim

	local function finish(ok)
		if resolved then return end

		active = false
		resolved = true
		status = L(ok and "ziptie_escape_pull" or "ziptie_escape_slip")
		statusColor = ok and C.accent or C.sev2
		surface.PlaySound(ok and "buttons/lightswitch2.wav" or "buttons/button10.wav")

		timer.Simple(0.4, function()
			if IsValid(frame) then frame:Remove() end
		end)

		SendResult(ok)
	end

	frame.OnRemove = function()
		if escapePanel == frame then escapePanel = nil end
		if not resolved then
			resolved = true
			SendResult(false)
		end
	end

	frame.Paint = function(self, fw, fh)
		UI.Rect(0, 0, fw, fh, C.bg)
		UI.Outline(0, 0, fw, fh, C.line)

		draw.SimpleText(L("ziptie_escape_title"), "MuR_Font1", We(UI.PAD), He(20),
			C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

		draw.SimpleText(status or L("ziptie_escape_space"), "MuR_Font0", We(UI.PAD), He(46),
			status and statusColor or C.textFaint, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

		UI.Meter(trackX, He(74), trackW, He(6), hits / needed, C.accent, 32)
		draw.SimpleText(hits .. " / " .. needed, "MuR_Font0", fw - We(UI.PAD), He(46),
			C.textDim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

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

net.Receive("MuR.ZipEscapeOpen", function()
	CreateEscapePanel(net.ReadUInt(4), net.ReadUInt(4))
end)

net.Receive("MuR.ZipEscapeState", function()
	local hits = net.ReadUInt(4)
	local needed = net.ReadUInt(4)

	timer.Simple(0.5, function()
		if not IsValid(LocalPlayer()) or not LocalPlayer():IsZipTied() then return end
		CreateEscapePanel(hits, needed)
	end)
end)

hook.Add("HUDPaint", "MuR.RestraintsHUD", function()
	local lp = LocalPlayer()
	if not IsValid(lp) or not lp:Alive() then return end

	local zipped = lp:IsZipTied()
	if not zipped and not lp:IsCuffed() then return end

	local text
	if zipped then
		text = lp:GetNW2Float("MuR.ZipProgress", 0) > 0
			and L("ziptie_being_freed") or L("ziptie_bound")
	elseif lp:GetNW2Float("MuR.CuffProgress", 0) > 0 then
		text = L("cuffs_being_freed")
	elseif lp:GetNW2Bool("MuR.CuffLawful", false) then
		text = L("cuffs_cuffed")
	else
		text = L("cuffs_cuffed_unlawful")
	end

	draw.SimpleText(text, "MuR_Font2", ScrW() / 2, ScrH() * 0.72, color_white,
		TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	if not zipped then return end

	local frac = lp:GetNW2Float("MuR.ZipEscape", 0)
	local w, h = We(280), He(6)
	local x, y = ScrW() / 2 - w / 2, ScrH() * 0.76

	UI.Meter(x, y, w, h, frac, C.accent, 32)
end)
