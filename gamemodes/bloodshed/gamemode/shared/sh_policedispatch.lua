local phrases = {
    ["unknown"] = {
        {"DISPATCH_INTRO_01.wav"},
        {"ATTENTION_ALL_UNITS_01.wav", "ATTENTION_ALL_UNITS_02.wav", "ATTENTION_ALL_UNITS_03.wav", "ATTENTION_ALL_UNITS_04.wav", "ATTENTION_ALL_UNITS_05.wav"},
        {"WE_HAVE.wav", "WEVE_GOT.wav"},
        {"REPORT_OF_CRIMINAL_ACTIVITY.wav"},
        {"RESPOND_CODE_3.wav"},
        {"OUTRO_01.wav", "OUTRO_02.wav", "OUTRO_03.wav"},
    },
    ["gunfire"] = {
        {"DISPATCH_INTRO_01.wav"},
        {"ATTENTION_ALL_UNITS_01.wav", "ATTENTION_ALL_UNITS_02.wav", "ATTENTION_ALL_UNITS_03.wav", "ATTENTION_ALL_UNITS_04.wav", "ATTENTION_ALL_UNITS_05.wav"},
        {"WE_HAVE.wav", "WEVE_GOT.wav"},
        {"CRIME_GUNFIRE_01.wav", "CRIME_GUNFIRE_02.wav", "CRIME_GUNFIRE_03.wav"},
        {"RESPOND_CODE_3.wav"},
        {"OUTRO_01.wav", "OUTRO_02.wav", "OUTRO_03.wav"},
    },
    ["homicide"] = {
        {"DISPATCH_INTRO_01.wav"},
        {"ATTENTION_ALL_UNITS_01.wav", "ATTENTION_ALL_UNITS_02.wav", "ATTENTION_ALL_UNITS_03.wav", "ATTENTION_ALL_UNITS_04.wav", "ATTENTION_ALL_UNITS_05.wav"},
        {"WE_HAVE.wav", "WEVE_GOT.wav"},
        {"HOMICIDE.wav"},
        {"RESPOND_CODE_3.wav"},
        {"OUTRO_01.wav", "OUTRO_02.wav", "OUTRO_03.wav"},
    },
    ["assault"] = {
        {"DISPATCH_INTRO_01.wav"},
        {"ATTENTION_ALL_UNITS_01.wav", "ATTENTION_ALL_UNITS_02.wav", "ATTENTION_ALL_UNITS_03.wav", "ATTENTION_ALL_UNITS_04.wav", "ATTENTION_ALL_UNITS_05.wav"},
        {"WE_HAVE.wav", "WEVE_GOT.wav"},
        {"ASSAULT_ON_A_CIVILIAN.wav"},
        {"RESPOND_CODE_3.wav"},
        {"OUTRO_01.wav", "OUTRO_02.wav", "OUTRO_03.wav"},
    },
    ["officer"] = {
        {"DISPATCH_INTRO_01.wav"},
        {"ALL_UNITS_RESPOND_CODE_99_EMERGENCY.wav"},
        {"WE_HAVE.wav", "WEVE_GOT.wav"},
        {"OFFICER_NOT_RESPONDING.wav"},
        {"OUTRO_01.wav", "OUTRO_02.wav", "OUTRO_03.wav"},
    },
    ["maniac"] = {
        {"DISPATCH_INTRO_01.wav"},
        {"ATTENTION_ALL_UNITS_01.wav", "ATTENTION_ALL_UNITS_02.wav", "ATTENTION_ALL_UNITS_03.wav", "ATTENTION_ALL_UNITS_04.wav", "ATTENTION_ALL_UNITS_05.wav"},
        {"WE_HAVE.wav", "WEVE_GOT.wav"},
        {"CRIME_STABBING.wav"},
        {"RESPOND_CODE_3.wav"},
        {"OUTRO_01.wav", "OUTRO_02.wav", "OUTRO_03.wav"},
    },
    ["shooter"] = {
        {"DISPATCH_INTRO_01.wav"},
        {"ATTENTION_ALL_UNITS_01.wav", "ATTENTION_ALL_UNITS_02.wav", "ATTENTION_ALL_UNITS_03.wav", "ATTENTION_ALL_UNITS_04.wav", "ATTENTION_ALL_UNITS_05.wav"},
        {"WE_HAVE.wav", "WEVE_GOT.wav"},
        {"PERSON_WITH_FIREARM.wav"},
        {"RESPOND_CODE_3.wav"},
        {"OUTRO_01.wav", "OUTRO_02.wav", "OUTRO_03.wav"},
    },
    ["terrorist"] = {
        {"DISPATCH_INTRO_01.wav"},
        {"ALL_UNITS_RESPOND_CODE_99_EMERGENCY.wav"},
        {"WE_HAVE.wav", "WEVE_GOT.wav"},
        {"CRIME_POSSIBLE_TERRORIST_ACTIVITY.wav"},
        {"OUTRO_01.wav", "OUTRO_02.wav", "OUTRO_03.wav"},
    },
    ["raidstart"] = {
        {"DISPATCH_INTRO_01.wav"},
        {"ALL_UNITS_RESPOND_CODE_99_EMERGENCY.wav"},
        {"WE_HAVE.wav", "WEVE_GOT.wav"},
        {"CRIME_OFFICER_UNDER_FIRE.wav"},
        {"PERSON_WITH_FIREARM.wav"},
        {"OUTRO_01.wav", "OUTRO_02.wav", "OUTRO_03.wav"},
    },
    ["heli"] = {
        {"DISPATCH_INTRO_01.wav"},
        {"HELI_APPROACHING_DISPATCH_01.wav", "HELI_APPROACHING_DISPATCH_02.wav"},
        {"OUTRO_01.wav", "OUTRO_02.wav", "OUTRO_03.wav"},
    },
    ["sniper"] = {
        {"DISPATCH_INTRO_01.wav"},
        {"UNIT_RESPONDING_DISPATCH_01.wav", "UNIT_RESPONDING_DISPATCH_02.wav"},
        {"OUTRO_01.wav", "OUTRO_02.wav", "OUTRO_03.wav"},
    },
}

if SERVER then
    util.AddNetworkString("MuR_PlayDispatchSound")

    function MuR:PlayDispatch(phraseKey)
        if not phrases[phraseKey] then return end
        net.Start("MuR_PlayDispatchSound")
        net.WriteString(phraseKey)
        net.Broadcast()
    end
else
    local path = "murdered/dispatch/"
    net.Receive("MuR_PlayDispatchSound", function()
        local phraseKey = net.ReadString()
        local phraseGroups = phrases[phraseKey]
        if not phraseGroups then return end

        local function PlayNextPhrase(index)
            if not phraseGroups[index] then return end
            local phraseTable = phraseGroups[index]
            local soundFile = phraseTable[math.random(#phraseTable)]

            surface.PlaySound(path..soundFile)

            timer.Simple(SoundDuration(path..soundFile), function()
                PlayNextPhrase(index + 1)
            end)
        end

        PlayNextPhrase(1)
    end)
end
