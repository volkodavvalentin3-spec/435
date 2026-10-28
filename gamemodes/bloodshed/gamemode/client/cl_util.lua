local meta = FindMetaTable("Player")

net.Receive("MuR.EntityPlayerColor", function()
	local ent = net.ReadEntity()
	local col = net.ReadVector()

	if IsValid(ent) and isvector(col) then
		function ent:GetPlayerColor()
			return col
		end
	end
end)

net.Receive("MuR.ExecuteString", function()
	RunString(net.ReadString())
end)

local logoicon = Material("murdered/logo.png", "noclamp")
local killedicon = Material("murdered/result/en/killed.png")
local losedicon = Material("murdered/result/en/losed.png")
local arrestedicon = Material("murdered/result/en/arrested.png")
local aliveicon = Material("murdered/result/en/alive.png")
local zombieicon = Material("murdered/result/en/infected.png")
if MuR.CurrentLanguage == "ru" then
	logoicon = Material("murdered/logo.png", "noclamp")
	killedicon = Material("murdered/result/ru/killed.png")
	losedicon = Material("murdered/result/ru/losed.png")
	arrestedicon = Material("murdered/result/ru/arrested.png")
	aliveicon = Material("murdered/result/ru/alive.png")
	zombieicon = Material("murdered/result/ru/infected.png")
end

local bd_bg = Color(10, 0, 0, 250)
local bd_grid = Color(100, 10, 10, 75)
local bd_primary = Color(200, 20, 20)
local bd_hover = Color(255, 50, 50)
local bd_panel_bg = Color(30, 10, 10, 180)
local bd_panel_border = Color(180, 20, 20, 200)

local function CreateFinishPanel(type, isvote)
	local text, plytext = "", ""

	if type == "innocent" then
		text = MuR.Language["innocentswin"]
	elseif type == "traitor" then
		text = MuR.Language["traitorwin"]
	elseif type == "tony" then
		text = MuR.Language["tony_win"]
	elseif type == "mafia" then
		text = MuR.Language["mafia_win"]
	elseif type == "survivor_win" then
		text = MuR.Language["survivor_win"]
	elseif type == "humans_win" then
		text = MuR.Language["humans_win"]
	elseif type == "zombies_win" then
		text = MuR.Language["zombies_win"]
	elseif type == "police_win" then
		text = MuR.Language["police_win"]
	elseif type == "rioters_win" then
		text = MuR.Language["rioters_win"]
	elseif type == "specops_win" then
		text = MuR.Language["specops_win"]
	elseif type == "terrorists_win" then
		text = MuR.Language["terrorists_win"]
	elseif type == "criminals_win" then
		text = MuR.Language["criminals_win"]
	elseif type == "combine_win" then
		text = MuR.Language["combine_win"]
	elseif type == "rebels_win" then
		text = MuR.Language["rebels_win"]
	elseif type == "prisoners_win" then
		text = MuR.Language["prisoners_win"]
	elseif type == "guards_win" then
		text = MuR.Language["guards_win"]
	elseif type == "draw" then
		text = MuR.Language["draw"]
	elseif type == "entity_win" then
		text = MuR.Language["entity_win"]
	elseif type == "fbi_win" then
		text = MuR.Language["fbi_win"]
	elseif type == "vip_dead" then
		text = MuR.Language["vip_dead"]
	elseif type == "vip_saved" then
		text = MuR.Language["vip_saved"]
	elseif type == "traitors_win" then
		text = MuR.Language["traitors_win"]
	elseif type == "pmc_wiped" then
		text = MuR.Language["pmc_wiped"]
	end

	if MuR.GamemodeCount != 18 then
		if LocalPlayer():GetNW2Bool("MuR.Dying", false) then
			plytext = MuR.Language["youincapacitated"]
			surface.PlaySound("murdered/theme/lose_theme.wav")
		elseif LocalPlayer():GetNW2Float('DeathStatus') == 0 then
			plytext = MuR.Language["yousurvived"]
			surface.PlaySound("murdered/theme/win_theme.wav")
		elseif LocalPlayer():GetNW2Float('DeathStatus') == 3 then
			plytext = MuR.Language["youjailed"]
			surface.PlaySound("murdered/theme/lose_theme.wav")
		else
			plytext = MuR.Language["youdied"]
			surface.PlaySound("murdered/theme/lose_theme.wav")
		end
	end

	hook.Add("Think", "ClickerFixMenu", function()
		gui.EnableScreenClicker(input.IsKeyDown(KEY_LALT))
	end)
	MuR.DrawHUD = false

	local dp = vgui.Create("DFrame")
	dp:SetPos(0, 0)
	dp:SetSize(ScrW(), ScrH())
	dp:SetTitle("")
	dp:ShowCloseButton(false)
	dp:SetDraggable(false)
    dp:SetAlpha(0)
    dp:AlphaTo(255, 1.5, 0)

	dp:AlphaTo(0, 2, 15, function()
		if IsValid(dp) then dp:Remove() end
		MuR.DrawHUD = true
		hook.Remove("Think", "ClickerFixMenu")
		gui.EnableScreenClicker(false)
	end)

    local textAnimStart = CurTime()
    local glitch_active = false
    local glitch_end_time, glitch_next_time = 0, CurTime() + math.Rand(3, 5)

    local function DrawShadowedText(txt, font, x, y, color, xalign, yalign)
        draw.SimpleText(txt, font, x + 2, y + 2, Color(0, 0, 0, 180), xalign, yalign)
        draw.SimpleText(txt, font, x, y, color, xalign, yalign)
    end

    local function DrawPlayerText(txt, font, x, y, color, xalign, yalign)
        draw.SimpleText(txt, font, x + 3, y + 3, Color(0, 0, 0, 255), xalign, yalign)
        draw.SimpleText(txt, font, x, y, color, xalign, yalign)
    end

    local voteButton, scrollPanel

	dp.Paint = function(self, w, h)
        if not glitch_active and CurTime() > glitch_next_time then
            glitch_active = true
            glitch_end_time = CurTime() + math.Rand(0.15, 0.4)
            glitch_next_time = CurTime() + math.Rand(2, 5)
        elseif CurTime() > glitch_end_time then
            glitch_active = false
        end

        local smooth_shake_x = math.sin(RealTime() * 2) * 2
        local smooth_shake_y = math.cos(RealTime() * 2) * 2

        local glitch_shake_x = glitch_active and math.Rand(-2, 2) or 0
        local glitch_shake_y = glitch_active and math.Rand(-2, 2) or 0

        local total_shake_x = smooth_shake_x + glitch_shake_x
        local total_shake_y = smooth_shake_y + glitch_shake_y

        if IsValid(scrollPanel) then scrollPanel:SetPos(We(50) + total_shake_x, He(250) + total_shake_y) end
        if IsValid(voteButton) then voteButton:SetPos(ScrW() / 2 + We(220) + total_shake_x, ScrH() - He(170) + total_shake_y) end

        draw.RoundedBox(0, total_shake_x - 10, total_shake_y - 10, w + 20, h + 20, bd_bg)
        local gridSize = 50
        surface.SetDrawColor(bd_grid)
        for i = 0, w / gridSize do surface.DrawRect(i * gridSize - (RealTime() * 15) % gridSize + total_shake_x, total_shake_y, 1, h) end
        for i = 0, h / gridSize do surface.DrawRect(total_shake_x, i * gridSize - (RealTime() * 15) % gridSize + total_shake_y, w, 1) end

        surface.SetDrawColor(255, 255, 255, 150)
        surface.SetMaterial(logoicon)
        surface.DrawTexturedRect(ScrW() / 2 - We(100) + total_shake_x, ScrH() / 2 - He(200) + total_shake_y, We(1542*0.5), He(824*0.5))

        surface.SetDrawColor(bd_primary)
        surface.DrawRect(We(50) + total_shake_x, He(170) + total_shake_y, We(500), 2)
        surface.DrawRect(We(598) + total_shake_x, total_shake_y, 2, h)

        DrawShadowedText(MuR.Language["roundended"], "MuR_Font6", We(50) + total_shake_x, He(50) + total_shake_y, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        DrawShadowedText(MuR.Language["peoplelist"], "MuR_Font2", We(50) + total_shake_x, He(210) + total_shake_y, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        DrawShadowedText(plytext, "MuR_Font3", ScrW() / 2 + We(300) + total_shake_x, ScrH() / 2 - He(250) + total_shake_y, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        DrawShadowedText(MuR.Language["holdalt"], "MuR_Font1", ScrW() / 2 + We(300) + total_shake_x, ScrH() - He(20) + total_shake_y, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)

        local timePassed = CurTime() - textAnimStart
        local charsToShow = math.min(string.len(text), math.floor(timePassed * 10))
        local partialText = utf8.sub(text, 1, charsToShow)
        if glitch_active then
            draw.SimpleText(partialText, "MuR_Font2", We(50) + total_shake_x + math.Rand(-5,5), He(100) + total_shake_y, Color(255,0,0,100), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end
        DrawShadowedText(partialText, "MuR_Font2", We(50) + total_shake_x, He(100) + total_shake_y, bd_primary, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

        if isvote then
            DrawShadowedText(MuR.Language["log_vote"], "MuR_Font1", ScrW() / 2 + We(300) + total_shake_x, ScrH() - He(200) + total_shake_y, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
            DrawShadowedText(MuR.Language["log_vote_info"]..MuR.Data["VoteLog"].."/"..player.GetCount(), "MuR_Font1", ScrW() / 2 + We(300) + total_shake_x, ScrH() - He(180) + total_shake_y, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
        end
	end

	if isvote then
		voteButton = vgui.Create("DButton", dp)
		voteButton:SetPos(ScrW() / 2 + We(220), ScrH() - He(170))
		voteButton:SetSize(We(160), He(40))
		voteButton:SetText("")
		voteButton.Paint = function(self, w, h)
            local color = self:IsHovered() and bd_hover or bd_primary
			draw.RoundedBox(4, 0, 0, w, h, Color(0,0,0,150))
            surface.SetDrawColor(color)
            surface.DrawOutlinedRect(0, 0, w, h, 2)
			DrawShadowedText(MuR.Language["log_vote_button"], "MuR_Font2", w/2, h/2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
		voteButton.DoClick = function(self)
			net.Start("MuR.ShowLogScreen")
			net.SendToServer()
			surface.PlaySound("buttons/combine_button1.wav")
			self:Remove()
		end
	end

	scrollPanel = vgui.Create("DScrollPanel", dp)
	scrollPanel:SetSize(We(500), He(850))
	scrollPanel:SetPos(We(60), He(280))
	scrollPanel.Paint = function() end
    local sbar = scrollPanel:GetVBar()
    sbar:SetSize(We(10), sbar:GetSize())
    sbar.Paint = function() end
    sbar.btnUp.Paint = function(s,w,h) draw.RoundedBox(2,0,0,w,h,bd_primary) end
    sbar.btnDown.Paint = function(s,w,h) draw.RoundedBox(2,0,0,w,h,bd_primary) end
    sbar.btnGrip.Paint = function(s,w,h) draw.RoundedBox(2,0,0,w,h,bd_hover) end

	for _, ply in player.Iterator() do
		local nwc = ply:GetNW2String("Class")
		local pname = ply:Nick() .. " (" .. ply:GetNWString("Name") .. ")"
		local classname = MuR.Language["civilian"]
		local jcolor = Color(100, 150, 200)

		local roleData = MuR:GetRole(nwc) or MuR:GetRole("Civilian")
		classname = MuR.Language[roleData.langName] or roleData.langName
		jcolor = roleData.color or Color(100, 150, 200)

		local playerPanel = vgui.Create("DPanel", scrollPanel)
		playerPanel:SetSize(We(480), He(64))
		playerPanel:Dock(TOP)
		playerPanel:DockMargin(0, 0, 10, 5)
		playerPanel.Paint = function(self, w, h)
			draw.RoundedBox(4, 0, 0, w, h, Color(0,0,0,50))
            surface.SetDrawColor(bd_panel_border)
            surface.DrawOutlinedRect(0, 0, w, h)
		end
		playerPanel.PaintOver = function(self, w, h)
			local icon
			if IsValid(ply) then
                local status = ply:GetNW2Float('DeathStatus')
                local class = ply:GetNW2String('Class')
                if class == 'Zombie' then icon = zombieicon
                elseif status == 0 and ply:Alive() or status == 4 then icon = aliveicon
                elseif status == 2 then icon = killedicon
                elseif status == 3 then icon = arrestedicon
                else icon = losedicon end
            else
                icon = losedicon
            end
            if icon then
                surface.SetDrawColor(255, 255, 255, 255)
                surface.SetMaterial(icon)
                surface.DrawTexturedRect(0, 0, w, h)
            end
		end

		local avatar = vgui.Create("AvatarImage", playerPanel)
		avatar:SetSize(He(48), He(48))
		avatar:SetPos(We(8), He(8))
		avatar:SetPlayer(ply, 64)

		local name = vgui.Create("DLabel", playerPanel)
		name:SetText("")
		name:SetPos(He(48) + We(16), He(16))
		name:SetSize(We(380), He(24))
        name.Paint = function(s,w,h)
			DrawPlayerText(pname, "MuR_FontDef", 0, 0, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		end

		local class = vgui.Create("DLabel", playerPanel)
		class:SetText("")
		class:SetPos(He(48) + We(16), He(32))
		class:SetSize(We(380), He(16))
        class.Paint = function(s,w,h)
			DrawPlayerText(classname, "MuR_FontDef", 0, 0, jcolor, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		end

		local b = vgui.Create("DButton", avatar)
		b:SetPos(0, 0)
		b:SetSize(He(48), He(48))
		b:SetText("")
		b.id = ply:SteamID64() or ""
		b.Paint = function() end
		b.DoClick = function(self)
			if self.id ~= "" then
				gui.OpenURL("https://steamcommunity.com/profiles/" .. self.id)
			end
		end
	end
end

net.Receive("MuR.FinalScreen", function()
	local str = net.ReadString()
	local vote = net.ReadBool()
	CreateFinishPanel(str, vote)
end)

local PUNCH_DAMPING = 9
local PUNCH_SPRING_CONSTANT = 65
local vp_is_calc = false
local vp_punch_angle = Angle()
local vp_punch_angle_velocity = Angle()
local vp_punch_angle_last = vp_punch_angle

hook.Add("Think", "mur_viewpunch_decay", function()
	if not vp_punch_angle:IsZero() or not vp_punch_angle_velocity:IsZero() then
		vp_punch_angle = vp_punch_angle + vp_punch_angle_velocity * FrameTime()
		local damping = 1 - (PUNCH_DAMPING * FrameTime())

		if damping < 0 then
			damping = 0
		end

		vp_punch_angle_velocity = vp_punch_angle_velocity * damping
		local spring_force_magnitude = math.Clamp(PUNCH_SPRING_CONSTANT * FrameTime(), 0, 0.2 / FrameTime())
		vp_punch_angle_velocity = vp_punch_angle_velocity - vp_punch_angle * spring_force_magnitude
		local x, y, z = vp_punch_angle:Unpack()
		vp_punch_angle = Angle(math.Clamp(x, -89, 89), math.Clamp(y, -179, 179), math.Clamp(z, -89, 89))
	else
		vp_punch_angle = Angle()
		vp_punch_angle_velocity = Angle()
	end
end)

hook.Add("Think", "mur_viewpunch_apply", function()
	if vp_punch_angle:IsZero() and vp_punch_angle_velocity:IsZero() then return end
	if LocalPlayer():InVehicle() then return end
	LocalPlayer():SetEyeAngles(LocalPlayer():EyeAngles() + vp_punch_angle - vp_punch_angle_last)
	vp_punch_angle_last = vp_punch_angle
end)

local function SetViewPunchAngles(angle)
	if not angle then return end
	vp_punch_angle = angle
end

local function SetViewPunchVelocity(angle)
	if not angle then return end
	vp_punch_angle_velocity = angle * 20
end

local function Viewpunch(angle)
	if not angle then return end
	local lp = LocalPlayer()
	if not IsValid(lp) or lp:GetObserverMode() > 0 then return end
	vp_punch_angle_velocity = vp_punch_angle_velocity + angle * 20
end

function meta:ViewPunchClient(angle)

	Viewpunch(angle)
end

net.Receive("MuR.ViewPunch", function()
	local ang = net.ReadAngle()
	Viewpunch(ang)
end)

net.Receive("MuR.SetHull", function()
	local tab = net.ReadTable()
	if !IsValid(LocalPlayer()) then return end
	LocalPlayer():SetHull(tab[1], tab[2])
	LocalPlayer():SetHullDuck(tab[3], tab[4])
end)

local function CreateCharacterVoicePanel()
	local frame = vgui.Create("DFrame")
	frame:SetSize(We(300), He(300))
	frame:Center()
	frame:SetTitle(MuR.Language["dialogue_menu"])
	frame:MakePopup()
	frame.Paint = function(self, w, h)
		draw.RoundedBox(0, 0, 0, w, h, Color(0, 0, 0, 150))
	end

	local scrollPanel = vgui.Create("DScrollPanel", frame)
	scrollPanel:Dock(FILL)

	if LocalPlayer():IsRolePolice() then
		for i = 101, 106 do
			local text = MuR.Language["dialogue_menu"..i]
			local button = scrollPanel:Add("DButton")
			button:SetText(text)
			button:Dock(TOP)
			button:DockMargin(2, 5, 2, 0)
			button.DoClick = function()
				net.Start("MuR.VoiceLines")
				net.WriteFloat(i)
				net.SendToServer()
				frame:Remove()
			end
		end
	else
		for i = 1, 14 do
			local text = MuR.Language["dialogue_menu"..i]
			local button = scrollPanel:Add("DButton")
			button:SetText(text)
			button:Dock(TOP)
			button:DockMargin(2, 5, 2, 0)
			button.DoClick = function()
				net.Start("MuR.VoiceLines")
				net.WriteFloat(i)
				net.SendToServer()
				frame:Remove()
			end
		end
	end
end
concommand.Add("mur_voicepanel", CreateCharacterVoicePanel)

local function ShowDisclaimer()
	local dp = vgui.Create("DFrame")
	dp:SetPos(0, 0)
	dp:SetSize(ScrW(), ScrH())
	dp:SetTitle("")
	dp:ShowCloseButton(false)
	dp:SetDraggable(false)
	dp:MakePopup()
	dp:SetAlpha(0)
	dp:AlphaTo(255, 1, 0)

	local glitch_active = false
	local glitch_end_time, glitch_next_time = 0, CurTime() + math.Rand(2, 4)
	local textAnimStart = CurTime()

	local disclaimerTitle = MuR.Language["disclaimer_title"] or "DISCLAIMER"
	local disclaimerText = MuR.Language["disclaimer_text"] or "This game mode is a work of fiction. All events, characters, and situations depicted are entirely fictional and do not reflect real events. This is a social experiment and artistic expression. By continuing, you acknowledge that you understand the fictional nature of this content."
	local disclaimerAccept = MuR.Language["disclaimer_accept"] or "I UNDERSTAND"

	local function DrawShadowedText(txt, font, x, y, color, xalign, yalign)
		draw.SimpleText(txt, font, x + 2, y + 2, Color(0, 0, 0, 180), xalign, yalign)
		draw.SimpleText(txt, font, x, y, color, xalign, yalign)
	end

	dp.Paint = function(self, w, h)
		if not glitch_active and CurTime() > glitch_next_time then
			glitch_active = true
			glitch_end_time = CurTime() + math.Rand(0.1, 0.3)
			glitch_next_time = CurTime() + math.Rand(2, 5)
		elseif CurTime() > glitch_end_time then
			glitch_active = false
		end

		local smooth_shake_x = math.sin(RealTime() * 2) * 2
		local smooth_shake_y = math.cos(RealTime() * 2) * 2
		local glitch_shake_x = glitch_active and math.Rand(-3, 3) or 0
		local glitch_shake_y = glitch_active and math.Rand(-3, 3) or 0
		local total_shake_x = smooth_shake_x + glitch_shake_x
		local total_shake_y = smooth_shake_y + glitch_shake_y

		draw.RoundedBox(0, total_shake_x - 10, total_shake_y - 10, w + 20, h + 20, Color(10, 0, 0, 250))

		local gridSize = 50
		surface.SetDrawColor(100, 10, 10, 75)
		for i = 0, w / gridSize do
			surface.DrawRect(i * gridSize - (RealTime() * 15) % gridSize + total_shake_x, total_shake_y, 1, h)
		end
		for i = 0, h / gridSize do
			surface.DrawRect(total_shake_x, i * gridSize - (RealTime() * 15) % gridSize + total_shake_y, w, 1)
		end

		surface.SetDrawColor(200, 20, 20)
		surface.DrawRect(w/2 - We(350) + total_shake_x, He(180) + total_shake_y, We(700), 2)
		surface.DrawRect(w/2 - We(350) + total_shake_x, h - He(250) + total_shake_y, We(700), 2)

		if glitch_active then
			DrawShadowedText(disclaimerTitle, "MuR_Font6", w/2 + math.Rand(-5, 5) + total_shake_x, He(100) + total_shake_y, Color(255, 0, 0, 100), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
		DrawShadowedText(disclaimerTitle, "MuR_Font6", w/2 + total_shake_x, He(100) + total_shake_y, Color(200, 20, 20), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		local timePassed = CurTime() - textAnimStart
		local charsToShow = math.min(utf8.len(disclaimerText), math.floor(timePassed * 40))
		local partialText = utf8.sub(disclaimerText, 1, charsToShow)

		local maxWidth = We(650)
		surface.SetFont("MuR_Font2")
		local words = string.Explode(" ", partialText)
		local lines = {}
		local currentLine = ""

		for _, word in ipairs(words) do
			local testLine = currentLine == "" and word or currentLine .. " " .. word
			local tw, _ = surface.GetTextSize(testLine)
			if tw > maxWidth then
				table.insert(lines, currentLine)
				currentLine = word
			else
				currentLine = testLine
			end
		end
		if currentLine ~= "" then
			table.insert(lines, currentLine)
		end

		local lineHeight = He(30)
		local startY = He(220) + total_shake_y
		for i, line in ipairs(lines) do
			if glitch_active then
				draw.SimpleText(line, "MuR_Font2", w/2 + math.Rand(-3, 3) + total_shake_x, startY + (i-1) * lineHeight, Color(255, 0, 0, 80), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
			end
			DrawShadowedText(line, "MuR_Font2", w/2 + total_shake_x, startY + (i-1) * lineHeight, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		end

		local warningY = h - He(300) + total_shake_y
		local warningText = "⚠"
		DrawShadowedText(warningText, "MuR_Font4", w/2 + total_shake_x, warningY, Color(200, 20, 20, 150 + math.sin(RealTime() * 3) * 50), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	local btn = vgui.Create("DButton", dp)
	btn:SetSize(We(250), He(60))
	btn:SetPos(ScrW()/2 - We(125), ScrH() - He(180))
	btn:SetText("")
	btn.Paint = function(self, w, h)
		local col = self:IsHovered() and Color(255, 50, 50) or Color(200, 20, 20)
		draw.RoundedBox(4, 0, 0, w, h, Color(0, 0, 0, 150))
		surface.SetDrawColor(col)
		surface.DrawOutlinedRect(0, 0, w, h, 2)
		draw.SimpleText(disclaimerAccept, "MuR_Font2", w/2, h/2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	btn.DoClick = function()
		surface.PlaySound("buttons/combine_button1.wav")
		dp:AlphaTo(0, 0.5, 0, function()
			if IsValid(dp) then dp:Remove() end
		end)
		cookie.Set("mur_disclaimer_accepted", "1")
	end
end

hook.Add("InitPostEntity", "MuR_ShowDisclaimer", function()
	timer.Simple(2, function()
		if cookie.GetString("mur_disclaimer_accepted", "0") ~= "1" then
			ShowDisclaimer()
		end
	end)
end)

hook.Add("InitPostEntity", "MuR_Check64Bit", function()
	if jit.arch != "x64" then
		local frame = vgui.Create("DFrame")
		frame:SetSize(ScrW(), ScrH())
		frame:SetTitle("")
		frame:ShowCloseButton(false)
		frame:SetDraggable(false)
		frame:MakePopup()
		frame.Paint = function(self, w, h)
			draw.RoundedBox(0, 0, 0, w, h, Color(0, 0, 0, 255))

			draw.SimpleText(MuR.Language["x64_check_title"], "MuR_Font3", w/2, h/2 - 100, Color(255, 50, 50), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

			local text = MuR.Language["x64_check_desc"]
			local font = "MuR_Font2"

			draw.DrawText(text, font, w/2, h/2 - 50, Color(255, 255, 255), TEXT_ALIGN_CENTER)
		end

		local btn = vgui.Create("DButton", frame)
		btn:SetSize(We(200), He(50))
		btn:SetPos(ScrW()/2 - We(100), ScrH()/2 + He(100))
		btn:SetText("")
		btn.Paint = function(self, w, h)
			local col = self:IsHovered() and Color(255, 50, 50) or Color(200, 20, 20)
			draw.RoundedBox(4, 0, 0, w, h, col)
			draw.SimpleText(MuR.Language["x64_check_button"], "MuR_Font2", w/2, h/2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
		btn.DoClick = function()
			RunConsoleCommand("disconnect")
			frame:Remove()
		end
	end
end)
