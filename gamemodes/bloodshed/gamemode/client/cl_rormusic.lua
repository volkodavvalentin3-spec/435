local calmTracks = {}
local intenseTracks = {}
for i=1,6 do
    table.insert(calmTracks, "sound/murdered/theme/ror/a"..i..".ogg")
    table.insert(intenseTracks, "sound/murdered/theme/ror/c"..i..".ogg")
end

local currentTrack = nil
local trackChannel = nil
local intense = false
local lastEnemySeen = 0
local transitionCooldown = 1
local nextMusicSwitch = 0
local mdelay = 0

local function PlayMusic(track)
    if trackChannel then
        trackChannel:SetVolume(0)
        trackChannel:Stop()
    end

    sound.PlayFile(track, "noplay", function(station, err, errname)
        if IsValid(station) then
            station:SetVolume(0)
            station:Play()
            trackChannel = station
        end
    end)
end

local function SelectMusic()
    if mdelay > CurTime() then return end
    mdelay = CurTime()+0.1

    local tracks = intense and intenseTracks or calmTracks
    local selected = tracks[math.random(#tracks)]

    if selected ~= currentTrack and CurTime() >= nextMusicSwitch then
        nextMusicSwitch = CurTime() + transitionCooldown

        if trackChannel then
            local fadeOutTime = 1
            local fadeTimer = 0
            local targetVolume = IsValid(trackChannel) and trackChannel:GetVolume() or 0
            hook.Add("Think", "FadeOutMusic", function()
                if not IsValid(trackChannel) then
                    hook.Remove("Think", "FadeOutMusic")
                    return
                end

                fadeTimer = fadeTimer + FrameTime()
                local volume = math.max( targetVolume * (1 - fadeTimer / fadeOutTime), 0)
                trackChannel:SetVolume(volume)

                if volume <= 0 then
                    trackChannel:Stop()
                    hook.Remove("Think", "FadeOutMusic")

                    sound.PlayFile(selected, "noplay", function(station, err, errname)
                        if IsValid(station) then
                            currentTrack = selected
                            station:SetVolume(0)
                            station:Play()
                            trackChannel = station
                        end
                    end)
                end
            end)
        else
            currentTrack = selected
            PlayMusic(currentTrack)
        end
    end
end

local function UpdateMusicState()
    local ply = LocalPlayer()

    if not IsValid(ply) then return end

    local enemySeenRecently = CurTime() - lastEnemySeen <= 16
    local newState = enemySeenRecently

    if newState ~= intense then
        intense = newState
        SelectMusic()
    end
end

local nextVisCheck = 0
local function CheckEnemyVisibility()
    local ply = LocalPlayer()
    if !ply:Alive() then
        lastEnemySeen = 0
        return
    end

    if nextVisCheck > CurTime() then return end
    nextVisCheck = CurTime() + 0.25

    for _, ent in ipairs(ents.FindInSphere(ply:GetPos(), 2000)) do
        if MuR.IsAI(ent) and ent:Health() > 0 then
            local trace = util.TraceLine({
                start = ply:EyePos(),
                endpos = ent:WorldSpaceCenter(),
                filter = ply
            })

            if trace.Entity == ent then
                lastEnemySeen = CurTime()
                break
            end
        end
    end
end

hook.Add("Think", "UpdateMusicSystem", function()
    if (!MuR.DrawHUD and LocalPlayer():IsFlagSet(FL_FROZEN)) or MuR.GamemodeCount != 14 then
        if IsValid(trackChannel) then
            trackChannel:Stop()
            trackChannel = nil
        end
        return
    end

    CheckEnemyVisibility()
    UpdateMusicState()

    if IsValid(trackChannel) and (trackChannel:GetState() == 0 or trackChannel:GetState() == 2) then
        SelectMusic()
    end

    if IsValid(trackChannel) then
        local targetVolume = GetConVar("snd_musicvolume"):GetFloat()*0.75
        local currentVolume = trackChannel:GetVolume()
        if currentVolume < targetVolume then
            trackChannel:SetVolume(math.min(currentVolume + FrameTime(), targetVolume))
        elseif currentVolume > targetVolume then
            trackChannel:SetVolume(math.max(currentVolume - FrameTime(), targetVolume))
        end
    else
        SelectMusic()
    end
end)
