--if engine.ActiveGamemode() != "bloodshed" then return end

hook.Add("InitLoadAnimations", "wOS.DynaBase.MuR", function()
	wOS.DynaBase:RegisterSource({
		Name = "Bloodshed Anims",
		Type = WOS_DYNABASE.EXTENSION,
		Male = "models/murdered/pm_anims.mdl",
		Female = "models/murdered/pm_anims.mdl",
		Zombie = "models/murdered/pm_anims.mdl",
	})

	hook.Add("PreLoadAnimations", "wOS.DynaBase.MuR", function(gender)
		if gender == WOS_DYNABASE.SHARED then
			IncludeModel("models/murdered/pm_anims.mdl")
		end
	end)

	wOS.DynaBase:RegisterSource({
        Name = "Bloodshed Cover System Animations",
        Type = WOS_DYNABASE.EXTENSION,
        Male = "models/cover_system/pm_anim.mdl",
        Female = "models/cover_system/pm_anim.mdl",
        Zombie = "models/cover_system/pm_anim.mdl",
    })

    hook.Add("PreLoadAnimations", "wOS.DynaBase.CoverSystem", function(gender)
        if gender == WOS_DYNABASE.SHARED then
            IncludeModel("models/cover_system/pm_anim.mdl")
        end
    end)

	wOS.DynaBase:RegisterSource({
		Name = "Bloodshed: Redux - Kick Animations",
		Type = WOS_DYNABASE.EXTENSION,

		Shared = "models/murdered/kick_anim_m.mdl",
		Female = "models/murdered/kick_anim_f.mdl",
		Male   = "models/murdered/kick_anim_m.mdl"
	})

	hook.Add("PreLoadAnimations", "wOS.DynaBase.MountBloodshedKick", function(gender)
		if gender == WOS_DYNABASE.SHARED then
			IncludeModel("models/murdered/kick_anim_m.mdl")
		elseif gender == WOS_DYNABASE.FEMALE then
			IncludeModel("models/murdered/kick_anim_f.mdl")
		elseif gender == WOS_DYNABASE.MALE then
			IncludeModel("models/murdered/kick_anim_m.mdl")
		end
	end)
end)