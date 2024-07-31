local LABEL = {}

function LABEL:Init()
	self:SetFont("Trebuchet24")
	self:SetTextColor( Color(255, 182, 66, 255) )
end

function LABEL:SetText(text)
    self.BaseClass.SetText(self, text)
	self:SizeToContents()
end

vgui.Register("lockpickingLabel", LABEL, "DLabel")