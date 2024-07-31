local BUTTON = {}

AccessorFunc(BUTTON, "Selected", "Selected", FORCE_BOOL)
AccessorFunc(BUTTON, "GreyedColor", "GreyedColor", FORCE_BOOL)
AccessorFunc(BUTTON, "Color", "NoGreyedColor", FORCE_BOOL)

function BUTTON:Init()
	self:SetFont("Trebuchet24")

	self:SetTextColor( Color(255, 182, 66, 255) )
	self.GreyedColor = self.GreyedColor or Color(78, 57, 25, 255)
end

function BUTTON:SetText(text)
    self.BaseClass.SetText(self, text)
	self:SizeToContents()
end

function BUTTON:Paint(w, h)
	if ( self.Greyed ) then return end

	if ( self.Hovered or self.Selected ) then
		local r, g, b = self:GetTextColor().r, self:GetTextColor().g, self:GetTextColor().b

		surface.SetDrawColor(Color(r,g,b,10))
		surface.DrawRect(0,0,w,h)

		surface.SetDrawColor(Color(r,g,b,245))
		surface.DrawRect(0, 0, w, 2)
		surface.DrawRect(0, h-2, w, 2)
		surface.DrawRect(0, 0, 2, h)
		surface.DrawRect(w-2, 0, 2, h)
	end
end

function BUTTON:Think()
	if ( not self.Greyed ) then
		if ( self.Hovered and not self.CallHover ) then
			self.CallHover = true
			self:OnHover()
		elseif ( not self.Hovered and self.CallHover ) then
			self.CallHover = false
		end
	end
	
	self.BaseClass.Think(self)
end

function BUTTON:SetGreyed(state)
	self.Greyed = state

	if ( state ) then
		self:SetTextColor( self.GreyedColor )
	else
		self:SetTextColor( self.Color )
	end
end

function BUTTON:GetGreyed()
	return self.Greyed or false
end

function BUTTON:OnMouseReleased(key)
	if ( self.Greyed ) then return end

	self:MouseCapture(false)
	
	if ( not self.Hovered ) then
		surface.PlaySound("forp/ui_menu_cancel.wav")
	end

	if ( key == MOUSE_LEFT and self.DoClick and self.Hovered ) then
		surface.PlaySound("forp/ui_menu_ok.wav")
		self:DoClick()
	end
end

function BUTTON:OnHover()
	surface.PlaySound("forp/ui_menu_focus.wav")
end

vgui.Register("lockpickingButton", BUTTON, "DButton")