local _, addon = ...
if type(addon) ~= "table" then return end

local Controls = {}
addon.VignetteRadarControls = Controls
local ACCENT = { 0.05, 0.82, 0.62 }

-- Keep ordinary buttons consistent with the radar legend and target picker.
function Controls.Button(parent, title, width, height)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width, height)
    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    button.label = button:CreateFontString(nil, "OVERLAY")
    local font = EllesmereUI and (EllesmereUI.EXPRESSWAY or EllesmereUI._font)
        or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    button.label:SetFont(font, width <= 48 and 14 or 10, "")
    button.label:SetSize(width - 10, height - 6)
    button.label:SetJustifyH("CENTER")
    button.label:SetWordWrap(false)
    button:SetFontString(button.label)
    button:SetText(title)

    button.selection = button:CreateTexture(nil, "ARTWORK")
    button.selection:SetSize(math.max(1, width - 12), 1)
    button.selection:SetPoint("BOTTOM", 0, 3)
    button.selection:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.8)
    button._enabled = true

    local function Refresh()
        local enabled = button._enabled
        local selected = button._selected
        local hovered = enabled and button._hovered
        local pressed = enabled and button._pressed
        button:SetAlpha(enabled and 1 or 0.38)
        button.label:ClearAllPoints()
        button.label:SetPoint("CENTER", 0, pressed and -1 or 0)
        button.selection:SetShown(enabled and selected == true)
        if pressed then
            button:SetBackdropColor(0.018, 0.055, 0.05, 1)
            button:SetBackdropBorderColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.85)
            button.label:SetTextColor(0.95, 1, 0.98, 1)
        elseif hovered or selected then
            button:SetBackdropColor(0.035, 0.075, 0.065, 0.98)
            button:SetBackdropBorderColor(ACCENT[1], ACCENT[2], ACCENT[3], hovered and 0.65 or 0.42)
            button.label:SetTextColor(hovered and 0.86 or ACCENT[1], hovered and 1 or ACCENT[2],
                hovered and 0.95 or ACCENT[3], 1)
        else
            button:SetBackdropColor(0.025, 0.03, 0.035, 0.96)
            button:SetBackdropBorderColor(1, 1, 1, 0.14)
            button.label:SetTextColor(0.72, 0.8, 0.79, 1)
        end
    end

    -- Preserve native enabled/selected semantics used by Settings range choices.
    local setEnabled, lockHighlight, unlockHighlight = button.SetEnabled, button.LockHighlight, button.UnlockHighlight
    button.SetEnabled = function(self, enabled)
        enabled = enabled == true or enabled == 1
        if self._enabled == enabled then return end
        setEnabled(self, enabled)
        self._enabled = enabled
        if not enabled then self._hovered, self._pressed = false, false end
        Refresh()
    end
    button.LockHighlight = function(self)
        lockHighlight(self)
        self._selected = true
        Refresh()
    end
    button.UnlockHighlight = function(self)
        unlockHighlight(self)
        self._selected = false
        Refresh()
    end
    button:SetScript("OnEnter", function(self) self._hovered = true; Refresh() end)
    button:SetScript("OnLeave", function(self) self._hovered, self._pressed = false, false; Refresh() end)
    button:SetScript("OnMouseDown", function(self) self._pressed = true; Refresh() end)
    button:SetScript("OnMouseUp", function(self) self._pressed = false; Refresh() end)
    button:SetScript("OnHide", function(self) self._hovered, self._pressed = false, false; Refresh() end)
    Refresh()
    return button
end

function Controls.Checkbox(parent)
    local checkbox = CreateFrame("CheckButton", nil, parent, "BackdropTemplate")
    checkbox:SetSize(26, 26)
    checkbox:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    checkbox.mark = {}
    local segments = {
        { -6, 0, -2, -4 },
        { -2, -4, 7, 6 },
    }
    for index, segment in ipairs(segments) do
        local line = checkbox:CreateLine(nil, "OVERLAY")
        line:SetThickness(2)
        line:SetColorTexture(0.80, 1, 0.94, 1)
        line:SetStartPoint("CENTER", checkbox, "CENTER", segment[1], segment[2])
        line:SetEndPoint("CENTER", checkbox, "CENTER", segment[3], segment[4])
        checkbox.mark[index] = line
    end
    function checkbox:RefreshAppearance()
        local checked = self:GetChecked() == true or self:GetChecked() == 1
        local hovered = self._hovered == true
        local pressed = self._pressed == true
        for _, line in ipairs(self.mark) do line:SetShown(checked) end
        if checked then
            self:SetBackdropColor(pressed and 0.02 or 0.035, 0.10, 0.08, 1)
            self:SetBackdropBorderColor(ACCENT[1], ACCENT[2], ACCENT[3], hovered and 0.90 or 0.65)
        else
            self:SetBackdropColor(hovered and 0.035 or 0.025, hovered and 0.065 or 0.03,
                hovered and 0.055 or 0.035, 0.96)
            self:SetBackdropBorderColor(hovered and ACCENT[1] or 1,
                hovered and ACCENT[2] or 1, hovered and ACCENT[3] or 1, hovered and 0.55 or 0.18)
        end
        if self.label then
            self.label:SetTextColor(hovered and 0.95 or 0.82, hovered and 1 or 0.88,
                hovered and 0.96 or 0.88, 1)
        end
    end
    local nativeSetChecked = checkbox.SetChecked
    checkbox.SetChecked = function(self, checked)
        nativeSetChecked(self, checked == true or checked == 1)
        self:RefreshAppearance()
    end
    checkbox:SetScript("OnEnter", function(self) self._hovered = true; self:RefreshAppearance() end)
    checkbox:SetScript("OnLeave", function(self)
        self._hovered, self._pressed = false, false
        self:RefreshAppearance()
    end)
    checkbox:SetScript("OnMouseDown", function(self) self._pressed = true; self:RefreshAppearance() end)
    checkbox:SetScript("OnMouseUp", function(self) self._pressed = false; self:RefreshAppearance() end)
    checkbox:SetScript("OnHide", function(self)
        self._hovered, self._pressed = false, false
        self:RefreshAppearance()
    end)
    checkbox:RefreshAppearance()
    return checkbox
end
