ENT.Base = "base_gmodentity"
ENT.Type = "anim"
ENT.PrintName = "Suicide Drone"
ENT.Spawnable = true
ENT.AutomaticFrameAdvance = true

ENT.BatteryCount = 60
ENT.HealthCount = 60

if CLIENT then
    local droneMat = Material("vgui/gradient-l")
    local scanlineMat = Material("pp/texturize")
    local noiseChars = {"█", "▓", "▒", "░", "▄", "▀", "■", "▪"}

    local function DrawScanlines(sw, sh, intensity)
        surface.SetDrawColor(0, 0, 0, intensity * 15)
        for i = 0, sh, 4 do
            surface.DrawRect(0, i, sw, 1)
        end
    end

    local function DrawGlitchNoise(sw, sh, intensity)
        if intensity < 0.3 then return end
        local glitchCount = math.floor((1 - intensity) * 50)
        surface.SetDrawColor(255, 255, 255, (1 - intensity) * 100)
        for i = 1, glitchCount do
            local x = math.random(0, sw)
            local y = math.random(0, sh)
            local w = math.random(20, 200)
            surface.DrawRect(x, y, w, 2)
        end
    end

    local function DrawCornerBrackets(x, y, w, h, size, thickness, col)
        surface.SetDrawColor(col)
        surface.DrawRect(x, y, size, thickness)
        surface.DrawRect(x, y, thickness, size)
        surface.DrawRect(x + w - size, y, size, thickness)
        surface.DrawRect(x + w - thickness, y, thickness, size)
        surface.DrawRect(x, y + h - thickness, size, thickness)
        surface.DrawRect(x, y + h - size, thickness, size)
        surface.DrawRect(x + w - size, y + h - thickness, size, thickness)
        surface.DrawRect(x + w - thickness, y + h - size, thickness, size)
    end

    local function DrawCrosshair(cx, cy, size, gap, thickness, col)
        surface.SetDrawColor(col)
        surface.DrawRect(cx - size, cy - thickness/2, size - gap, thickness)
        surface.DrawRect(cx + gap, cy - thickness/2, size - gap, thickness)
        surface.DrawRect(cx - thickness/2, cy - size, thickness, size - gap)
        surface.DrawRect(cx - thickness/2, cy + gap, thickness, size - gap)
    end

    local function DrawArcSegment(cx, cy, radius, startAng, endAng, thickness, segments, col)
        surface.SetDrawColor(col)
        local step = (endAng - startAng) / segments
        for i = 0, segments - 1 do
            local a1 = math.rad(startAng + i * step)
            local a2 = math.rad(startAng + (i + 1) * step)
            local x1 = cx + math.cos(a1) * radius
            local y1 = cy + math.sin(a1) * radius
            local x2 = cx + math.cos(a2) * radius
            local y2 = cy + math.sin(a2) * radius
            surface.DrawLine(x1, y1, x2, y2)
        end
    end

    local function DrawCircularBar(cx, cy, radius, frac, thickness, bgCol, fgCol)
        DrawArcSegment(cx, cy, radius, -90, 270, thickness, 32, bgCol)
        if frac > 0 then
            DrawArcSegment(cx, cy, radius, -90, -90 + 360 * frac, thickness, math.floor(32 * frac), fgCol)
        end
    end

    local function LoseDrone()
        surface.PlaySound("ambient/levels/prison/radio_random"..math.random(1,15)..".wav")
        local startTime = CurTime()
        hook.Add("HUDPaint", "DroneCamLost", function()
            if not LocalPlayer():Alive() then return end
            local sw, sh = ScrW(), ScrH()
            local elapsed = CurTime() - startTime
            local flicker = math.sin(elapsed * 30) > 0

            surface.SetDrawColor(15, 15, 20, 255)
            surface.DrawRect(0, 0, sw, sh)

            for i = 1, 150 do
                local px = math.random(0, sw)
                local py = math.random(0, sh)
                local ps = math.random(2, 8)
                local c = math.random(30, 80)
                surface.SetDrawColor(c, c, c, 255)
                surface.DrawRect(px, py, ps, ps)
            end

            DrawScanlines(sw, sh, 3)

            for i = 1, 20 do
                local y = math.random(0, sh)
                local w = math.random(sw * 0.3, sw)
                local x = math.random(0, sw - w)
                surface.SetDrawColor(40, 40, 45, 200)
                surface.DrawRect(x, y, w, math.random(1, 5))
            end

            local textCol = flicker and Color(255, 50, 50, 255) or Color(200, 40, 40, 200)
            draw.SimpleText("▌▌ CONNECTION LOST ▐▐", "MuR_Font5", sw/2, sh/2 - 30, textCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText("SIGNAL TERMINATED", "MuR_Font2", sw/2, sh/2 + 30, Color(150, 150, 150, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end)
        timer.Simple(2, function()
            hook.Remove("HUDPaint", "DroneCamLost")
        end)
    end
    net.Receive("MuR_DroneLost", LoseDrone)

    net.Receive("MuR_DroneCam", function()
        local ent = net.ReadEntity()
        local pulseAlpha = 0
        local pulseDir = 1
        local lastBattBeep = 0
        local lastDmgBeep = 0
        local startTime = CurTime()
        local smoothBatt = 1
        local smoothHP = 1
        local camShake = Vector(0, 0, 0)
        local camShakeDecay = 0

        local ppTab = {
            ["$pp_colour_addr"] = 0,
            ["$pp_colour_addg"] = 0.02,
            ["$pp_colour_addb"] = 0,
            ["$pp_colour_brightness"] = -0.03,
            ["$pp_colour_contrast"] = 1.15,
            ["$pp_colour_colour"] = 0.4,
            ["$pp_colour_mulr"] = 0,
            ["$pp_colour_mulg"] = 0.05,
            ["$pp_colour_mulb"] = 0
        }

        hook.Add("RenderScreenspaceEffects", "DroneCam", function()
            if not IsValid(ent) then return end
            local timeLeft = math.max(ent:GetNW2Float('RemoveTime') - CurTime(), 0)
            local battFrac = math.Clamp(timeLeft / ent.BatteryCount, 0, 1)

            if battFrac < 0.2 then
                ppTab["$pp_colour_addr"] = 0.1 * (1 - battFrac / 0.2)
                ppTab["$pp_colour_contrast"] = 1.15 + 0.2 * (1 - battFrac / 0.2)
            else
                ppTab["$pp_colour_addr"] = 0
                ppTab["$pp_colour_contrast"] = 1.15
            end

            DrawColorModify(ppTab)
            DrawSharpen(0.8, 0.8)
        end)

        hook.Add("HUDPaint", "DroneCam", function()
            if not IsValid(ent) then return end
            local sw, sh = ScrW(), ScrH()
            local cx, cy = sw / 2, sh / 2
            local time = CurTime()
            local elapsed = time - startTime

            pulseAlpha = pulseAlpha + pulseDir * FrameTime() * 400
            if pulseAlpha >= 255 then pulseDir = -1 pulseAlpha = 255
            elseif pulseAlpha <= 100 then pulseDir = 1 pulseAlpha = 100 end

            local timeLeft = math.max(ent:GetNW2Float('RemoveTime') - CurTime(), 0)
            local battFrac = math.Clamp(timeLeft / ent.BatteryCount, 0, 1)
            local hpFrac = math.Clamp(ent:Health() / ent.HealthCount, 0, 1)

            smoothBatt = Lerp(FrameTime() * 3, smoothBatt, battFrac)
            smoothHP = Lerp(FrameTime() * 5, smoothHP, hpFrac)

            local vel = ent:GetVelocity():Length()
            local spd = math.Round(vel * 0.068)
            local tr = util.TraceLine({start = ent:GetPos(), endpos = ent:GetPos() - Vector(0, 0, 10000), filter = ent})
            local agl = math.Round(ent:GetPos().z - tr.HitPos.z)
            local dist2 = LocalPlayer():GetPos():DistToSqr(ent:GetPos())
            local signal = math.Clamp(1 - (dist2 / (5000 * 5000)), 0, 1)
            local canDisarm = dist2 < 50000

            DrawScanlines(sw, sh, 32)
            DrawGlitchNoise(sw, sh, signal)

            local frameCol = Color(40, 255, 120, 120)
            DrawCornerBrackets(40, 40, sw - 80, sh - 80, 60, 3, frameCol)

            local crossCol = Color(40, 255, 120, pulseAlpha)
            DrawCrosshair(cx, cy, 25, 8, 2, crossCol)

            surface.SetDrawColor(40, 255, 120, 60)
            DrawArcSegment(cx, cy, 45, 0, 360, 1, 64, Color(40, 255, 120, 40))

            local targetDist = tr.HitPos:Distance(ent:GetPos())
            if targetDist < 500 then
                local lockCol = Color(255, 80, 60, pulseAlpha)
                DrawCrosshair(cx, cy, 35, 5, 3, lockCol)
                draw.SimpleText(string.format("%.1fm", targetDist * 0.0254), "MuR_Font2", cx, cy + 50, lockCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
            end

            draw.SimpleText("◈ FPV DRONE", "MuR_Font3", 80, 60, Color(40, 255, 120, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            draw.SimpleText(string.format("UPTIME %.1fs", elapsed), "MuR_Font1", 80, 95, Color(150, 150, 150, 200), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            draw.SimpleText(os.date("%H:%M:%S"), "MuR_Font1", 80, 115, Color(150, 150, 150, 200), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

            local telemX = sw - 80
            local spdCol = spd > 60 and Color(255, 200, 60) or Color(40, 255, 120)
            draw.SimpleText(string.format("%03d km/h", spd), "MuR_Font3", telemX, 60, spdCol, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
            draw.SimpleText("SPD", "MuR_Font1", telemX, 95, Color(100, 100, 100), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

            draw.SimpleText(string.format("%04d m", agl), "MuR_Font3", telemX, 120, Color(40, 255, 120), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
            draw.SimpleText("ALT", "MuR_Font1", telemX, 155, Color(100, 100, 100), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

            local sigCol = signal < 0.25 and Color(255, 60, 60) or (signal < 0.5 and Color(255, 200, 60) or Color(40, 255, 120))
            local sigBars = math.floor(signal * 5)
            local sigStr = string.rep("▮", sigBars) .. string.rep("▯", 5 - sigBars)
            draw.SimpleText(sigStr, "MuR_Font2", telemX, 180, sigCol, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
            draw.SimpleText(string.format("%d%%", math.Round(signal * 100)), "MuR_Font1", telemX, 210, sigCol, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

            local barW, barH = 250, 12
            local barX, barY = 80, sh - 180

            local battCol = smoothBatt < 0.2 and Color(255, 60, 60) or (smoothBatt < 0.4 and Color(255, 200, 60) or Color(40, 255, 120))
            surface.SetDrawColor(30, 30, 30, 200)
            surface.DrawRect(barX, barY, barW, barH)
            surface.SetDrawColor(battCol.r, battCol.g, battCol.b, 255)
            surface.DrawRect(barX + 2, barY + 2, (barW - 4) * smoothBatt, barH - 4)
            surface.SetDrawColor(battCol.r, battCol.g, battCol.b, 100)
            surface.DrawOutlinedRect(barX, barY, barW, barH, 1)
            draw.SimpleText(string.format("POWER %d%%", math.Round(smoothBatt * 100)), "MuR_Font1", barX, barY - 20, battCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
            draw.SimpleText(string.format("%.0fs", timeLeft), "MuR_Font1", barX + barW, barY - 20, Color(150, 150, 150), TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)

            barY = sh - 130
            local hpCol = smoothHP < 0.3 and Color(255, 60, 60) or (smoothHP < 0.6 and Color(255, 200, 60) or Color(40, 255, 120))
            surface.SetDrawColor(30, 30, 30, 200)
            surface.DrawRect(barX, barY, barW, barH)
            surface.SetDrawColor(hpCol.r, hpCol.g, hpCol.b, 255)
            surface.DrawRect(barX + 2, barY + 2, (barW - 4) * smoothHP, barH - 4)
            surface.SetDrawColor(hpCol.r, hpCol.g, hpCol.b, 100)
            surface.DrawOutlinedRect(barX, barY, barW, barH, 1)
            draw.SimpleText(string.format("INTEGRITY %d%%", math.Round(smoothHP * 100)), "MuR_Font1", barX, barY - 20, hpCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)

            local ctrlX, ctrlY = sw - 80, sh - 200
            local ctrlCol = Color(150, 150, 150, 200)
            draw.SimpleText("▶ [LMB] BOOST", "MuR_Font1", ctrlX, ctrlY, ctrlCol, TEXT_ALIGN_RIGHT)
            draw.SimpleText("▲ [SHIFT] UP", "MuR_Font1", ctrlX, ctrlY + 22, ctrlCol, TEXT_ALIGN_RIGHT)
            draw.SimpleText("▼ [CTRL] DOWN", "MuR_Font1", ctrlX, ctrlY + 44, ctrlCol, TEXT_ALIGN_RIGHT)

            if canDisarm then
                draw.SimpleText("◉ [R] RECALL", "MuR_Font1", ctrlX, ctrlY + 66, Color(40, 255, 120, 200), TEXT_ALIGN_RIGHT)
            else
                draw.SimpleText("✖ TOO FAR", "MuR_Font1", ctrlX, ctrlY + 66, Color(255, 100, 60, 200), TEXT_ALIGN_RIGHT)
            end

            if ent:GetNW2Bool('Boost') then
                local boostFlash = math.sin(time * 15) > 0 and 255 or 180
                draw.SimpleText("◀◀ BOOST ACTIVE ▶▶", "MuR_Font2", cx, sh - 100, Color(255, 200, 60, boostFlash), TEXT_ALIGN_CENTER)
            end

            if smoothBatt < 0.15 then
                local warnFlash = math.sin(time * 8) > 0 and 255 or 100
                draw.SimpleText("⚠ LOW POWER ⚠", "MuR_Font4", cx, 80, Color(255, 60, 60, warnFlash), TEXT_ALIGN_CENTER)
                if time > lastBattBeep then
                    surface.PlaySound("buttons/button17.wav")
                    lastBattBeep = time + 0.8
                end
            end

            if smoothHP < 0.25 then
                local dmgFlash = math.sin(time * 6) > 0 and 255 or 100
                draw.SimpleText("⚠ CRITICAL DAMAGE ⚠", "MuR_Font3", cx, 130, Color(255, 120, 60, dmgFlash), TEXT_ALIGN_CENTER)
                if time > lastDmgBeep then
                    surface.PlaySound("buttons/button10.wav")
                    lastDmgBeep = time + 1.5
                end
            end

            if signal < 0.2 then
                local sigFlash = math.sin(time * 10) > 0 and 255 or 100
                draw.SimpleText("◢◤ WEAK SIGNAL ◢◤", "MuR_Font3", cx, 180, Color(255, 80, 60, sigFlash), TEXT_ALIGN_CENTER)
            end
        end)

        hook.Add("CreateMove", "DroneCam", function(cmd)
            cmd:SetForwardMove(0)
            cmd:SetSideMove(0)
            cmd:RemoveKey(IN_JUMP)
            cmd:RemoveKey(IN_USE)
        end)

        hook.Add("CalcView", "DroneCam", function(ply, pos, angles, fov)
            if not IsValid(ent) then
                hook.Remove("CalcView", "DroneCam")
                hook.Remove("CreateMove", "DroneCam")
                hook.Remove("RenderScreenspaceEffects", "DroneCam")
                hook.Remove("HUDPaint", "DroneCam")
                return
            end

            local dronePos = ent:GetPos()
            local droneAng = ent:GetAngles()
            local droneVel = ent:GetVelocity()
            local speed = droneVel:Length()

            local timeLeft = math.max(ent:GetNW2Float('RemoveTime') - CurTime(), 0)
            local battFrac = math.Clamp(timeLeft / ent.BatteryCount, 0, 1)
            local hpFrac = math.Clamp(ent:Health() / ent.HealthCount, 0, 1)

            local baseOffset = Vector(-8, 0, -2)
            local speedOffset = math.Clamp(speed * 0.015, 0, 5)
            baseOffset.x = baseOffset.x - speedOffset

            local camPos = dronePos + ent:GetForward() * baseOffset.x + ent:GetUp() * baseOffset.z

            local camAng = Angle(droneAng.p, droneAng.y, droneAng.r)

            local time = CurTime()
            local bobScale = 0.3 + (1 - battFrac) * 0.5
            camAng.p = camAng.p + math.sin(time * 2.5) * bobScale
            camAng.r = camAng.r + math.cos(time * 1.8) * bobScale * 0.7

            if hpFrac < 0.3 then
                local shake = (0.3 - hpFrac) * 3
                camAng.p = camAng.p + math.Rand(-shake, shake)
                camAng.r = camAng.r + math.Rand(-shake, shake)
            end

            if battFrac < 0.15 then
                local flicker = (0.15 - battFrac) * 10
                camAng.p = camAng.p + math.sin(time * 20) * flicker
            end

            local baseFov = 40
            local speedFovBoost = math.Clamp(speed * 0.025, 0, 15)
            local dynamicFov = baseFov + speedFovBoost

            if ent:GetNW2Bool('Boost') then
                dynamicFov = dynamicFov + 10
            end

            return {
                origin = camPos,
                angles = camAng,
                fov = math.Clamp(dynamicFov, 70, 120),
                drawviewer = true
            }
        end)
    end)
end
