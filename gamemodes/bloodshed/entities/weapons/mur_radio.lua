if SERVER then
    AddCSLuaFile()
else
    SWEP.PrintName = "Radio"
    SWEP.Slot = 4
    SWEP.SlotPos = 1
    SWEP.DrawAmmo = false
    SWEP.DrawCrosshair = false
end

SWEP.DrawWeaponInfoBox = false
SWEP.ViewModel = "models/murdered/weapons/v_dp4800.mdl"
SWEP.WorldModel = "models/murdered/weapons/w_dp4800.mdl"
SWEP.ViewModelFOV = 60
SWEP.UseHands = true
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.Category = "Bloodshed - Civilian"
SWEP.TPIKForce = true
SWEP.TPIK_DisableLeftHand = true

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

local MAX_CHANNELS = 999
local POLICE_CHANNEL = 1024
local RADIO_RANGE = 8000

RADIO_CHAT_HISTORY = RADIO_CHAT_HISTORY or {}

local radioSounds = {
    on = ")murdered/radio/on.mp3",
    off = ")murdered/radio/off.mp3",
    switch = "murdered/radio/switch.mp3",
    static = "murdered/radio/static.wav",
    beep = "murdered/radio/message.mp3",
    click = "murdered/vgui/ui_click.wav",
    error = "murdered/vgui/ui_return.wav"
}

function SWEP:Initialize()
    self:SetHoldType("slam")
    self:SetNWBool("RadioOn", false)
    self:SetNWInt("RadioChannel", 1)

    if CLIENT then
        self.RadioGUI = nil
    end
end

function SWEP:Deploy()
    return true
end

function SWEP:Holster()
    if CLIENT and IsValid(self.RadioGUI) then
        self.RadioGUI:Remove()
        self.RadioGUI = nil
    end
    return true
end

function SWEP:OnRemove()
    if CLIENT and IsValid(self.RadioGUI) then
        self.RadioGUI:Remove()
        self.RadioGUI = nil
    end
end

function SWEP:Think()
    if SERVER then
        local ply = self:GetOwner()
        if IsValid(ply) and ply.IsRolePolice and ply:IsRolePolice() then
            if self:GetNWInt("RadioChannel", 1) ~= POLICE_CHANNEL then
                self:SetNWInt("RadioChannel", POLICE_CHANNEL)
            end
        end
    end
end

function SWEP:PrimaryAttack()
    if CLIENT then return end

    local ply = self:GetOwner()
    if not IsValid(ply) then return end

    local state = not self:GetNWBool("RadioOn", false)
    self:SetNWBool("RadioOn", state)

    self:SetNextPrimaryFire(CurTime() + 0.5)

    local sound = state and radioSounds.on or radioSounds.off
    ply:EmitSound(sound, 60, 100)
end

function SWEP:SecondaryAttack()
    if CLIENT then
        self:OpenRadioGUI()
    end
    self:SetNextSecondaryFire(CurTime() + 0.3)
end

function SWEP:Reload()
    return false
end

if SERVER then
    util.AddNetworkString("RadioChangeChannel")
    util.AddNetworkString("RadioChatMessage")
    util.AddNetworkString("RadioSyncHistory")
    util.AddNetworkString("RadioNoices")

    net.Receive("RadioChangeChannel", function(len, ply)
        if not IsValid(ply) then return end

        local wep = ply:GetActiveWeapon()
        if not IsValid(wep) or wep:GetClass() ~= "mur_radio" then return end

        local channel = net.ReadInt(16)
        if channel < 0 or channel > MAX_CHANNELS then return end

        if ply.IsRolePolice and ply:IsRolePolice() then
            return
        end

        wep:SetNWInt("RadioChannel", channel)
        wep:EmitSound(radioSounds.switch, 70, 100)
    end)

    net.Receive("RadioChatMessage", function(len, ply)
        if not IsValid(ply) then return end

        local wep = ply:GetActiveWeapon()
        if not IsValid(wep) or wep:GetClass() ~= "mur_radio" then return end

        if not wep:GetNWBool("RadioOn", false) then
            wep:EmitSound(radioSounds.error, 60, 100)
            return
        end

        local message = net.ReadString()
        if string.len(message) == 0 then return end

        local talkerChannel = wep:GetNWInt("RadioChannel", 1)
        local talkerPos = ply:GetPos()
        local talkerName = ply:Nick()

        if not RADIO_CHAT_HISTORY[talkerChannel] then
            RADIO_CHAT_HISTORY[talkerChannel] = {}
        end

        wep:EmitSound(radioSounds.beep, 70, 100)

        table.insert(RADIO_CHAT_HISTORY[talkerChannel], {
            sender = talkerName,
            text = message,
            time = os.time(),
            color = Color(150, 200, 255)
        })

        if #RADIO_CHAT_HISTORY[talkerChannel] > 50 then
            table.remove(RADIO_CHAT_HISTORY[talkerChannel], 1)
        end

        for _, listener in player.Iterator() do
            if IsValid(listener) then
                local listenerWep = listener:GetWeapon("mur_radio")
                if IsValid(listenerWep) then
                    local listenerChannel = listenerWep:GetNWInt("RadioChannel", 1)
                    local listenerOn = listenerWep:GetNWBool("RadioOn", false)

                    if listenerOn and listenerChannel == talkerChannel then
                        local dist = talkerPos:Distance(listener:GetPos())
                        if dist <= RADIO_RANGE then
                            if listener ~= ply then
                                listenerWep:EmitSound(radioSounds.beep, 60, 90)
                            end

                            net.Start("RadioSyncHistory")
                            net.WriteInt(talkerChannel, 16)
                            net.WriteString(talkerName)
                            net.WriteString(message)
                            net.WriteInt(os.time(), 32)
                            net.WriteColor(listener == ply and Color(150, 200, 255) or Color(100, 255, 150))
                            net.Send(listener)
                        end
                    end
                end
            end
        end
    end)

    hook.Add("PlayerSay", "RadioChat", function(ply, text, team)
        if not IsValid(ply) then return end

        local wep = ply:GetActiveWeapon()
        if not IsValid(wep) or wep:GetClass() ~= "mur_radio" then return end

        if not wep:GetNWBool("RadioOn", false) then return end

        local message = MuR.FilterSpeechText and MuR:FilterSpeechText(ply, text) or text
        if string.len(message) == 0 then return end

        local talkerChannel = wep:GetNWInt("RadioChannel", 1)
        local talkerPos = ply:GetPos()
        local talkerName = ply:Nick()

        wep:EmitSound(radioSounds.beep, 70, 100)

        if not RADIO_CHAT_HISTORY[talkerChannel] then
            RADIO_CHAT_HISTORY[talkerChannel] = {}
        end

        table.insert(RADIO_CHAT_HISTORY[talkerChannel], {
            sender = talkerName,
            text = message,
            time = os.time(),
            color = Color(150, 200, 255)
        })

        if #RADIO_CHAT_HISTORY[talkerChannel] > 50 then
            table.remove(RADIO_CHAT_HISTORY[talkerChannel], 1)
        end

        for _, listener in player.Iterator() do
            if IsValid(listener) then
                local listenerWep = listener:GetWeapon("mur_radio")
                if IsValid(listenerWep) then
                    local listenerChannel = listenerWep:GetNWInt("RadioChannel", 1)
                    local listenerOn = listenerWep:GetNWBool("RadioOn", false)

                    if listenerOn and listenerChannel == talkerChannel then
                        local dist = talkerPos:Distance(listener:GetPos())
                        if dist <= RADIO_RANGE then
                            if listener ~= ply then
                                listenerWep:EmitSound(radioSounds.beep, 60, 90)
                            end

                            net.Start("RadioSyncHistory")
                            net.WriteInt(talkerChannel, 16)
                            net.WriteString(talkerName)
                            net.WriteString(message)
                            net.WriteInt(os.time(), 32)
                            net.WriteColor(listener == ply and Color(150, 200, 255) or Color(100, 255, 150))
                            net.Send(listener)
                        end
                    end
                end
            end
        end

        return ""
    end)

    hook.Add("PlayerCanHearPlayersVoice", "RadioVoiceChat", function(listener, talker)
        if not IsValid(listener) or not IsValid(talker) then return end
        if listener == talker then return end
        if MuR.CanTalkNormally and not MuR:CanTalkNormally(talker) and talker:Alive() then return false end

        local listenerWep = listener:GetWeapon("mur_radio")
        local talkerWep = talker:GetActiveWeapon()

        if not IsValid(listenerWep) or not IsValid(talkerWep) then return end
        if talkerWep:GetClass() ~= "mur_radio" then return end

        local listenerOn = listenerWep:GetNWBool("RadioOn", false)
        local talkerOn = talkerWep:GetNWBool("RadioOn", false)

        if not listenerOn or not talkerOn then return end

        local listenerChannel = listenerWep:GetNWInt("RadioChannel", 1)
        local talkerChannel = talkerWep:GetNWInt("RadioChannel", 1)

        if listenerChannel ~= talkerChannel then return end

        local dist = listener:GetPos():Distance(talker:GetPos())
        if dist > RADIO_RANGE then return end

        return true, false
    end)
end

if CLIENT then
    hook.Add("PlayerDeath", "RadioGUIClose", function(victim, inflictor, attacker)
        if IsValid(victim) and victim == LocalPlayer() then
            local wep = victim:GetActiveWeapon()
            if IsValid(wep) and wep:GetClass() == "mur_radio" and IsValid(wep.RadioGUI) then
                wep.RadioGUI:Remove()
                wep.RadioGUI = nil
            end
        end
    end)

    local ownStaticSound = nil

    hook.Add("PlayerStartVoice", "RadioStartVoice", function(ply)
        if ply == LocalPlayer() then return end

        local wep = ply:GetActiveWeapon()
        if IsValid(wep) and wep:GetClass() == "mur_radio" and wep:GetNWBool("RadioOn", false) then
            surface.PlaySound("murdered/radio/start.mp3")

            if ownStaticSound then
                ownStaticSound:Stop()
            end

            ownStaticSound = CreateSound(ply, radioSounds.static)
            ownStaticSound:SetSoundLevel(0)
            ownStaticSound:PlayEx(1, 100)
        end
    end)

    hook.Add("PlayerEndVoice", "RadioEndVoice", function(ply)
        if ply == LocalPlayer() then return end

        local wep = ply:GetActiveWeapon()
        timer.Simple(0.1, function()
            if IsValid(wep) and wep:GetClass() == "mur_radio" and wep:GetNWBool("RadioOn", false) then
                surface.PlaySound("murdered/radio/end" .. math.random(1, 3) .. ".mp3")
            end
            if ownStaticSound then
                ownStaticSound:Stop()
                ownStaticSound = nil
            end
        end)
    end)

    net.Receive("RadioSyncHistory", function()
        local channel = net.ReadInt(16)
        local sender = net.ReadString()
        local text = net.ReadString()
        local time = net.ReadInt(32)
        local color = net.ReadColor()

        if not RADIO_CHAT_HISTORY[channel] then
            RADIO_CHAT_HISTORY[channel] = {}
        end

        table.insert(RADIO_CHAT_HISTORY[channel], {
            sender = sender,
            text = text,
            time = time,
            color = color
        })

        if #RADIO_CHAT_HISTORY[channel] > 50 then
            table.remove(RADIO_CHAT_HISTORY[channel], 1)
        end
    end)

    net.Receive("RadioNoices", function()
        LocalPlayer():EmitSound("murdered/radio/corrupt-0" .. math.random(1, 8) .. ".mp3", 0, math.random(80, 120), 1)
    end)

    function SWEP:OpenRadioGUI()
        if IsValid(self.RadioGUI) then
            self.RadioGUI:Remove()
            self.RadioGUI = nil
            return
        end

        local frame = vgui.Create("DFrame")
        frame:SetSize(We(300), He(200))
        frame:Center()
        frame:SetTitle("")
        frame:SetDraggable(true)
        frame:ShowCloseButton(false)
        frame:MakePopup()

        frame.Paint = function(s, w, h)
            draw.RoundedBox(8, 0, 0, w, h, Color(25, 25, 25, 250))
            draw.RoundedBox(6, 2, 2, w - 4, h - 4, Color(35, 35, 35, 200))

            local isOn = self:GetNWBool("RadioOn", false)
            local statusCol = isOn and Color(100, 255, 100) or Color(255, 100, 100)
            local statusText = isOn and "ON" or "OFF"

            draw.SimpleText(MuR.Language["radio_title"] or "RADIO", "MuR_Font2", w / 2, He(15), Color(220, 60, 60), TEXT_ALIGN_CENTER)
            draw.SimpleText(statusText, "MuR_Font1", w / 2, He(35), statusCol, TEXT_ALIGN_CENTER)

            surface.SetDrawColor(60, 15, 15, 150)
            surface.DrawLine(We(10), He(55), w - We(10), He(55))
        end

        local closeBtn = vgui.Create("DButton", frame)
        closeBtn:SetPos(We(260), He(10))
        closeBtn:SetSize(We(30), He(25))
        closeBtn:SetText("✕")
        closeBtn:SetTextColor(Color(220, 60, 60))
        closeBtn:SetFont("MuR_Font2")
        closeBtn.Paint = function(s, w, h)
            local col = s:IsHovered() and Color(80, 20, 20, 180) or Color(50, 15, 15, 120)
            draw.RoundedBox(4, 0, 0, w, h, col)
        end
        closeBtn.DoClick = function()
            frame:Remove()
        end

        frame.OnRemove = function()
            self.RadioGUI = nil
        end

        local currentCh = self:GetNWInt("RadioChannel", 1)

        local freqLabel = vgui.Create("DLabel", frame)
        freqLabel:SetPos(We(20), He(70))
        freqLabel:SetSize(We(260), He(20))
        freqLabel:SetText((MuR.Language["radio_frequency"] or "Frequency: ") .. "(0-" .. MAX_CHANNELS .. ")")
        freqLabel:SetTextColor(Color(200, 200, 200))
        freqLabel:SetFont("MuR_Font1")

        local freqEntry = vgui.Create("DTextEntry", frame)
        freqEntry:SetPos(We(20), He(95))
        freqEntry:SetSize(We(180), He(30))
        freqEntry:SetText(tostring(currentCh))
        freqEntry:SetNumeric(true)
        freqEntry.Paint = function(s, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 40))
            s:DrawTextEntryText(Color(255, 255, 255), Color(100, 200, 255), Color(255, 255, 255))
        end

        local setFreqBtn = vgui.Create("DButton", frame)
        setFreqBtn:SetPos(We(210), He(95))
        setFreqBtn:SetSize(We(70), He(30))
        setFreqBtn:SetText("")
        setFreqBtn.Paint = function(s, w, h)
            local col = s:IsHovered() and Color(80, 20, 20) or Color(60, 15, 15)
            draw.RoundedBox(4, 0, 0, w, h, col)
            draw.SimpleText(MuR.Language["radio_set"] or "SET", "MuR_Font1", w / 2, h / 2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        setFreqBtn.DoClick = function()
            local channel = tonumber(freqEntry:GetValue())
            if channel and channel >= 0 and channel <= MAX_CHANNELS then
                net.Start("RadioChangeChannel")
                net.WriteInt(channel, 16)
                net.SendToServer()
                surface.PlaySound(radioSounds.switch)
            else
                surface.PlaySound(radioSounds.error)
            end
        end

        freqEntry.OnEnter = function()
            setFreqBtn:DoClick()
        end

        local infoLabel = vgui.Create("DLabel", frame)
        infoLabel:SetPos(We(20), He(140))
        infoLabel:SetSize(We(260), He(50))
        infoLabel:SetText((MuR.Language["radio_instructions"] or "LMB: On/Off | RMB: Frequency") .. "\n" .. (MuR.Language["radio_control_chat"] or "Chat: /r <message>"))
        infoLabel:SetTextColor(Color(150, 150, 150))
        infoLabel:SetFont("MuR_Font1")
        infoLabel:SetWrap(true)

        self.RadioGUI = frame
    end

    hook.Add("HUDPaint", "RadioHUD", function()
        local ply = LocalPlayer()
        if not IsValid(ply) then return end

        local wep = ply:GetActiveWeapon()
        local radioWep = ply:GetWeapon("mur_radio")

        if IsValid(wep) and wep:GetClass() == "mur_radio" then
            local x, y = We(50), ScrH() - He(120)
            local w, h = We(200), He(60)

            draw.RoundedBox(8, x - We(5), y - He(5), w + We(10), h + He(10), Color(0, 0, 0, 100))
            draw.RoundedBox(6, x, y, w, h, Color(40, 10, 10, 200))

            local isOn = wep:GetNWBool("RadioOn", false)
            local channel = wep:GetNWInt("RadioChannel", 1)

            local statusCol = isOn and Color(100, 255, 100) or Color(255, 100, 100)

            draw.SimpleText(MuR.Language["radio_title"] or "RADIO", "MuR_Font2", x + We(10), y + He(8), Color(200, 50, 50))
            draw.SimpleText((isOn and "ON" or "OFF") .. " | CH: " .. channel, "MuR_Font1", x + We(10), y + He(30), statusCol)
        end

        if IsValid(radioWep) and radioWep:GetNWBool("RadioOn", false) then
            local channel = radioWep:GetNWInt("RadioChannel", 1)
            local history = RADIO_CHAT_HISTORY[channel]

            if history and #history > 0 then
                local x, y = We(50), ScrH() - He(300)
                local w = We(350)
                local lineHeight = He(22)
                local maxMessages = 5
                local fadeTime = 10

                local startIdx = math.max(1, #history - maxMessages + 1)
                local messagesShown = 0

                for i = startIdx, #history do
                    local msg = history[i]
                    if msg then
                        local age = os.time() - msg.time
                        if age < fadeTime then
                            local alpha = math.Clamp(1 - (age / fadeTime), 0.3, 1)
                            local bgAlpha = math.Clamp(alpha * 180, 50, 180)
                            local textAlpha = math.Clamp(alpha * 255, 100, 255)

                            local msgY = y + (messagesShown * lineHeight)

                            draw.RoundedBox(4, x - We(5), msgY - He(2), w, lineHeight, Color(20, 20, 20, bgAlpha))

                            local senderText = "[" .. msg.sender .. "]: "
                            local msgColor = Color(msg.color.r, msg.color.g, msg.color.b, textAlpha)
                            local textColor = Color(255, 255, 255, textAlpha)

                            surface.SetFont("MuR_Font1")
                            local senderW = surface.GetTextSize(senderText)

                            draw.SimpleText(senderText, "MuR_Font1", x, msgY, msgColor)
                            draw.SimpleText(msg.text, "MuR_Font1", x + senderW, msgY, textColor)

                            messagesShown = messagesShown + 1
                        end
                    end
                end
            end
        end
    end)
end
