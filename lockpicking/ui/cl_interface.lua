------------------
-- [[ Sizing ]] --
------------------
local padding = 42
local infoPadding = 28
local infoHorizontalBorderWidth = 448
local infoVerticalBorderWidth = 197
local infoBorderHeight = 2
local informationOffset = 30

-- Compute lock sizes when game resolution is set
local lockSizes = lockSizes or {}

hook.Add("LoadFonts", "lockpickingLoadFonts", function()
	local sizeFactor = ( ScrH() / 1080 ) * 0.75

    lockSizes.bobbypinWidth = 858 * 1.11 * sizeFactor
    lockSizes.bobbypinHeight = 38 * 1.11 * sizeFactor
    lockSizes.lockInnerWidth = 1037 * sizeFactor
    lockSizes.lockInnerHeight = 1037 * sizeFactor
    lockSizes.backgroundWidth = 730 * sizeFactor
    lockSizes.backgroundHeight = 730 * sizeFactor
    lockSizes.lockOuterWidth = 1037 * sizeFactor
    lockSizes.lockOuterHeight = 1037 * sizeFactor

	-- Close interface to prevent panel elements from being misaligned
	if (LockpickingPlugin.ClientSession) then
		LockpickingPlugin.ClientSession:Stop(true)
	end
end)

-------------------------------
-- [[ Display/Hide cursor ]] --
-------------------------------
local enableScreenClicker = enableScreenClicker or gui.EnableScreenClicker
local function showCursor()
	gui.EnableScreenClicker(true)
	gui.EnableScreenClicker = function() end
end

-- Disable cursor
local function hideCursor()
	gui.EnableScreenClicker = enableScreenClicker
	gui.EnableScreenClicker(false)
end

------------------------------------
-- [[ Frame, label and buttons ]] --
------------------------------------
local PANEL = {}

function PANEL:Init()
	if ( LockpickingPlugin.Panel ) then
		LockpickingPlugin.Panel:Remove()
	end
	LockpickingPlugin.Panel = self
	
	self:SetSize(ScrW(), ScrH())

	showCursor()

	local interface = LockpickingPlugin.ClientSession

	-- Exit button
	local exitButton = self:Add("lockpickingButton")
	exitButton:SetText(L("lockpickingExit").." E)")
	exitButton:SetPos(ScrW() - padding - exitButton:GetWide(), ScrH() - padding - infoPadding - exitButton:GetTall())
    exitButton.DoClick = function(this)
        interface:Stop(true)
	end

	-- Bobby pin information
	local bobbypinTitle = self:Add("lockpickingLabel")
	bobbypinTitle:SetText(L"lockpickingPins")
	bobbypinTitle:SetPos(padding + infoBorderHeight + infoPadding, ScrH() - padding - infoBorderHeight - infoPadding - bobbypinTitle:GetTall())

	self.bobbypinValue = self:Add("lockpickingLabel")
	self.bobbypinValue:SetText(interface.Item:GetQuantity())
	self.bobbypinValue:SetPos(padding + infoBorderHeight + infoHorizontalBorderWidth - self.bobbypinValue:GetWide(), ScrH() - padding - infoBorderHeight - infoPadding - self.bobbypinValue:GetTall())
end

function PANEL:OnRemove()
	hideCursor()
end

function PANEL:Paint(w, h)
	-- Background blur
	Derma_DrawBackgroundBlur(self)

	-- Paint borders
	surface.SetDrawColor( Color(255, 182, 66, 255) )
	surface.DrawRect( padding, ScrH() - padding, infoHorizontalBorderWidth, infoBorderHeight)
	surface.DrawRect( padding, ScrH() - padding - infoVerticalBorderWidth, infoBorderHeight, infoVerticalBorderWidth)

	-- Update information
	self.bobbypinValue:SetText(LockpickingPlugin.ClientSession.Item:GetQuantity())
	self.bobbypinValue:SetX(padding + infoBorderHeight + infoHorizontalBorderWidth - self.bobbypinValue:GetWide())

	-- Method that draws the lock
	self:DrawLock()
end

-------------------------------------
-- [[ Display lock and bobbypin ]] --
-------------------------------------
local materialLockInner = Material( "vgui/fallout/lockpicking/inner.png" )
local materialLock = Material( "vgui/fallout/lockpicking/outer.png" )
local materialBobbypin = Material( "vgui/fallout/lockpicking/pick.png" )

local nextVib = 0
local vib = false

-- Draw a rotated texture with center as rotating point
function drawTexturedRectRotatedPoint(x, y, w, h, rot, x0, y0)
	local c = math.cos( math.rad( rot ) )
	local s = math.sin( math.rad( rot ) )
	local newx = y0 * s - x0 * c
	local newy = y0 * c + x0 * s

	surface.DrawTexturedRectRotated(x + newx, y + newy, w, h, rot)
end

function PANEL:DrawLock()
	local cfg = LockpickingPlugin.Config

	local interface = LockpickingPlugin.ClientSession
	if ( not interface.Freeze ) then
		interface:Think()
	end

	-- Draw a black background to avoid transparency behing the lock
	surface.SetDrawColor( color_black )
	surface.DrawRect( (ScrW() / 2) - (lockSizes.backgroundWidth / 2), (ScrH() / 2) - (lockSizes.backgroundHeight / 2), lockSizes.backgroundWidth, lockSizes.backgroundHeight )
	
	-- Draw the outter lock
	surface.SetDrawColor( 200, 200, 200, 255 )
	surface.SetMaterial( materialLock )
	surface.DrawTexturedRect( (ScrW() / 2) - (lockSizes.lockInnerWidth / 2), (ScrH() / 2) - (lockSizes.lockInnerHeight / 2), lockSizes.lockOuterWidth, lockSizes.lockOuterHeight)


	-- Lock vibration
	local lockRotationToDraw = interface.InnerLockAngle
	if (interface.exceedMax) then
		if (CurTime() > nextVib) then
			nextVib = CurTime() + 0.035
			vib = !vib
		end

		if (vib) then
			lockRotationToDraw = interface.InnerLockAngle + 1
		end
	end

	-- Draw the inner lock
	surface.SetDrawColor( 200, 200, 200, 255 )
	surface.SetMaterial( materialLockInner )
	surface.DrawTexturedRectRotated( ScrW() / 2, ScrH() / 2, lockSizes.lockInnerWidth, lockSizes.lockInnerHeight, lockRotationToDraw)
	
	if (not interface.ChangingPin) then
		surface.SetDrawColor( 200, 200, 200, 255 )
		surface.SetMaterial( materialBobbypin )
		drawTexturedRectRotatedPoint( ScrW() / 2, ScrH() / 2, lockSizes.bobbypinWidth, lockSizes.bobbypinHeight, 180 - interface.PinAngle, lockSizes.bobbypinWidth / 2, 0 )
	end

	nut.bar.drawAction()
end

vgui.Register("lockpickingInterface", PANEL, "Panel")

-------------------------------------------
-- [[ Hide game UI during lockpicking ]] --
-------------------------------------------
hook.Add("OnSpawnMenuOpen", "lockpickingRestrictSpawnMenu", function()
    if ( IsValid(LockpickingPlugin.Panel) ) then
        return false
	end
end)

hook.Add("CanDrawDoorInfo", "lockpickingHideDoorInfo", function()
    if ( IsValid(LockpickingPlugin.Panel) ) then
        return false
	end
end)

hook.Add("CanDrawEntInt", "lockpickingHideDoorInfo", function()
    if ( IsValid(LockpickingPlugin.Panel) ) then
        return false
	end
end)