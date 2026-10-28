local m = Material("vignette/vignette.png")
local m_w = Material("vignette/vignette_white.png")
local alphanew = 0

hook.Add("RenderScreenspaceEffects", "mursupp_vignette", function()
	if (!render.SupportsPixelShaders_2_0()) then return end
	alphanew = Lerp(6 * FrameTime(), alphanew, LocalPlayer():GetNW2Float("EffectAMT"))
	local a = alphanew*0.25
	render.SetMaterial(m)
	m:SetFloat("$alpha", a)
	for i = 1, 4 do render.DrawScreenQuad() end
end)