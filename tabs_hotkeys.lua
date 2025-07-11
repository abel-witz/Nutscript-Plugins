PLUGIN.name = "Quick Tabs"
PLUGIN.author = "Abel Witz"
PLUGIN.desc = "This plugin adds quick tabs keys"

-- Buttons codes : http://wiki.garrysmod.com/page/Enums/BUTTON_CODE

--[[ Default nutscript tabs uniqueIds:
		business
		config
		help
		inv 
]]
	

PLUGIN.DefaultKeys = {
  --[BUTTON_CODE] = "tabId",
	[KEY_F4] = "inv",
}


if (CLIENT) then

function PLUGIN:GetNutMenu()
	if !IsValid(nut.gui.menu) && LocalPlayer():getChar() then
		nut.gui.menu = vgui.Create("nutMenu")
	end
	
	return nut.gui.menu
end

function PLUGIN:PlayerButtonDown( client, button )
	local bind = self.DefaultKeys[button]
	
	if bind then
		local menu = self:GetNutMenu()

		if IsValid(menu) then
			menu:setActiveTab(bind)
		end
	end
end

end