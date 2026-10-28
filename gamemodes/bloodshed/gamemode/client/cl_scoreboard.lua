local We = We or function(x) return x * (ScrW() / 1920) end
local He = He or function(x) return x * (ScrH() / 1080) end

local UI = MuR.UI

local scoreboard = nil

local PANEL_W, PANEL_MAX_H = 620, 700
local ROW_H = 56

local function L(key)
	return (MuR.Language and MuR.Language[key]) or key
end

local function pingColor(ping)
	local C = UI.Colors
	if ping >= 200 then return C.sev3 end
	if ping >= 100 then return C.sev2 end
	return C.textDim
end

local function drawSpeaker(x, y, size, muted)
	local C = UI.Colors
	local col = muted and C.textFaint or C.text
	local unit = size / 5

	for i = 1, 3 do
		local barH = unit * (i + 1)
		UI.Rect(x + (i - 1) * unit * 1.5, y + size - barH, unit, barH, col)
	end

	if muted then
		surface.SetDrawColor(C.sev3)
		surface.DrawLine(x - unit, y + size, x + size, y)
	end
end

local function CreateScoreboard()
	if IsValid(scoreboard) then return end

	local C = UI.Colors
	local pad = We(UI.PAD)

	local players = player.GetAll()
	table.sort(players, function(a, b) return a:Ping() < b:Ping() end)

	local height = math.Clamp(He(UI.HEADER + 8) + #players * He(ROW_H),
		He(UI.HEADER + ROW_H), He(PANEL_MAX_H))

	scoreboard = vgui.Create("DPanel")
	scoreboard:SetSize(We(PANEL_W), height)
	scoreboard:Center()
	scoreboard:MakePopup()
	scoreboard:SetKeyboardInputEnabled(false)

	local modeName = "None"
	if MuR.EnableDebug then
		modeName = "Sandbox"
	elseif MuR.GamemodeCount and MuR.GamemodeCount > 0 then
		modeName = L("gamename" .. MuR.GamemodeCount)
	end

	scoreboard.Paint = function(self, w, h)
		UI.Chrome(w, h, L("plylist"), L("startscreen_gamemode") .. modeName,
			#player.GetAll() .. " / " .. game.MaxPlayers())
	end

	local scroll = vgui.Create("DScrollPanel", scoreboard)
	scroll:SetPos(0, He(UI.HEADER))
	scroll:SetSize(We(PANEL_W), height - He(UI.HEADER))
	UI.Scrollbar(scroll)

	for index, ply in ipairs(players) do
		local row = vgui.Create("DPanel", scroll)
		row:Dock(TOP)
		row:SetTall(He(ROW_H))
		row:DockMargin(0, 0, We(6), 0)

		row.Paint = function(self, w, h)
			if not IsValid(ply) then return end

			local isSelf = ply == LocalPlayer()

			if isSelf then
				UI.Rect(0, 0, w, h, C.panel)
				UI.Rect(0, 0, We(2), h, C.accent)
			elseif index > 1 then
				UI.HLine(0, 0, w, C.lineSoft)
			end

			local textX = pad + He(36) + We(12)

			draw.SimpleText(ply:Nick(), "MuR_Font1", textX, h / 2 - He(13),
				C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

			local guilt = ply:GetNW2Float("Guilt", 0)
			draw.SimpleText(L("guilt:") .. math.floor(guilt) .. "%", "MuR_Font0", textX,
				h / 2 + He(4), guilt > 0 and C.sev2 or C.textFaint,
				TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

			local ping = ply:Ping()
			draw.SimpleText(ping .. " ms", "MuR_Font0", w - pad, h / 2 - He(6),
				pingColor(ping), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
		end

		local avatar = vgui.Create("AvatarImage", row)
		avatar:SetPos(pad, He((ROW_H - 36) / 2))
		avatar:SetSize(He(36), He(36))
		avatar:SetPlayer(ply, 64)

		local profile = vgui.Create("DButton", row)
		profile:SetPos(pad, He((ROW_H - 36) / 2))
		profile:SetSize(He(36), He(36))
		profile:SetText("")
		profile.Paint = function(self, w, h)
			if self:IsHovered() then UI.Outline(0, 0, w, h, C.accent) end
		end
		profile.DoClick = function()
			if IsValid(ply) then gui.OpenURL("https://steamcommunity.com/profiles/" .. (ply:SteamID64() or "")) end
		end

		if ply ~= LocalPlayer() then
			local mute = vgui.Create("DButton", row)
			mute:SetSize(He(22), He(22))
			mute:SetText("")

			mute.PerformLayout = function(self)
				self:SetPos(row:GetWide() - pad - We(70), He((ROW_H - 22) / 2))
			end

			mute.Paint = function(self, w, h)
				if not IsValid(ply) then return end
				if self:IsHovered() then UI.Outline(-2, -2, w + 4, h + 4, C.accent) end
				drawSpeaker(0, 0, h, ply:IsMuted())
			end

			mute.DoClick = function()
				if not IsValid(ply) then return end
				ply:SetMuted(not ply:IsMuted())
				surface.PlaySound("murdered/vgui/ui_click.wav")
			end
		end
	end
end

hook.Add("ScoreboardShow", "ShowScoreboard", function()
	CreateScoreboard()
	return true
end)

hook.Add("ScoreboardHide", "HideScoreboard", function()
	if IsValid(scoreboard) then scoreboard:Remove() end
	scoreboard = nil
end)
