local _, addon = ...
if type(addon) ~= "table" then return end

local Controls = {}
addon.VignetteRadarControls = Controls
local ACCENT = { 0.05, 0.82, 0.62 }
local controls = {}

function Controls.RefreshTheme()
    if addon.VignetteRadarStyle then
        ACCENT[1], ACCENT[2], ACCENT[3] = addon.VignetteRadarStyle.Color("accent")
    end
    for _, control in ipairs(controls) do
        if control.RefreshAppearance then control:RefreshAppearance() end
    end
end

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
        button.selection:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], .8)
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
    button.RefreshAppearance = Refresh

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
    controls[#controls + 1] = button
    return button
end

-- The small, unboxed toolbar language used by the radar also fits range
-- steppers in both settings panels. The hit target stays larger than the glyph.
function Controls.IconButton(parent, symbol, width, height)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width, height)
    button:SetText(symbol)
    button.glow = button:CreateTexture(nil, "BACKGROUND")
    button.glow:SetSize(18, 18)
    button.glow:SetPoint("CENTER")
    button.glow:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
    button.strokes = {}
    local horizontal = button:CreateLine(nil, "OVERLAY")
    horizontal:SetThickness(2)
    horizontal:SetStartPoint("CENTER", button, -5, 0)
    horizontal:SetEndPoint("CENTER", button, 5, 0)
    button.strokes[1] = horizontal
    if symbol == "+" then
        local vertical = button:CreateLine(nil, "OVERLAY")
        vertical:SetThickness(2)
        vertical:SetStartPoint("CENTER", button, 0, -5)
        vertical:SetEndPoint("CENTER", button, 0, 5)
        button.strokes[2] = vertical
    end
    button._enabled = true
    function button:RefreshAppearance()
        local selected, hovered = self._selected == true, self._hovered == true
        local r, g, b = .69, .77, .78
        if selected or hovered then r, g, b = ACCENT[1], ACCENT[2], ACCENT[3] end
        local opacity = not self._enabled and .32 or (selected or hovered) and 1 or .78
        self.glow:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3],
            not self._enabled and 0 or hovered and .20 or selected and .12 or 0)
        for _, stroke in ipairs(self.strokes) do stroke:SetColorTexture(r, g, b, opacity) end
    end
    local nativeSetEnabled = button.SetEnabled
    button.SetEnabled = function(self, enabled)
        enabled = enabled == true or enabled == 1
        nativeSetEnabled(self, enabled)
        self._enabled = enabled
        if not enabled then self._hovered = false end
        self:RefreshAppearance()
    end
    button:SetScript("OnEnter", function(self) self._hovered = true; self:RefreshAppearance() end)
    button:SetScript("OnLeave", function(self) self._hovered = false; self:RefreshAppearance() end)
    button:SetScript("OnHide", function(self) self._hovered = false; self:RefreshAppearance() end)
    button:RefreshAppearance()
    controls[#controls + 1] = button
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
        { -7, 0, -2, -5 },
        { -2, -5, 8, 6 },
    }
    for index, segment in ipairs(segments) do
        local line = checkbox:CreateLine(nil, "OVERLAY")
        line:SetThickness(3)
        line:SetColorTexture(0.015, 0.075, 0.06, 1)
        line:SetStartPoint("CENTER", checkbox, segment[1], segment[2])
        line:SetEndPoint("CENTER", checkbox, segment[3], segment[4])
        checkbox.mark[index] = line
    end
    function checkbox:RefreshAppearance()
        local checked = self:GetChecked() == true or self:GetChecked() == 1
        local hovered = self._hovered == true
        local pressed = self._pressed == true
        for _, line in ipairs(self.mark) do line:SetShown(checked and not self.glyph) end
        if self.glyph then
            local r, g, b = checked and 0.015 or 0.69, checked and 0.075 or 0.77,
                checked and 0.06 or 0.78
            for _, line in ipairs(self.glyph.lines or {}) do line:SetColorTexture(r, g, b, 1) end
            if self.glyph.label then self.glyph.label:SetTextColor(r, g, b, 1) end
            if self.glyph.pupil then self.glyph.pupil:SetVertexColor(r, g, b, 1) end
        end
        if checked then
            self:SetBackdropColor(pressed and ACCENT[1] * .55 or ACCENT[1],
                hovered and math.min(1, ACCENT[2] * 1.08) or ACCENT[2] * .95,
                hovered and math.min(1, ACCENT[3] * 1.08) or ACCENT[3] * .95, 1)
            self:SetBackdropBorderColor(math.min(1, ACCENT[1] + .45),
                math.min(1, ACCENT[2] + .2), math.min(1, ACCENT[3] + .25), 1)
        else
            self:SetBackdropColor(hovered and 0.035 or 0.025, hovered and 0.065 or 0.03,
                hovered and 0.055 or 0.035, 0.96)
            self:SetBackdropBorderColor(hovered and ACCENT[1] or 0.55,
                hovered and ACCENT[2] or 0.62, hovered and ACCENT[3] or 0.62, hovered and 0.75 or 0.65)
        end
        if self.label then
            self.label:SetTextColor(checked and 0.90 or (hovered and 0.95 or 0.82),
                checked and 1 or (hovered and 1 or 0.88),
                checked and 0.94 or (hovered and 0.96 or 0.88), 1)
        end
    end
    function checkbox:SetGlyph(symbol)
        if self.glyph then return end
        self.glyph = { lines = {} }
        if symbol == "N" then
            local label = self:CreateFontString(nil, "OVERLAY")
            label:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 14, "")
            label:SetAllPoints()
            label:SetJustifyH("CENTER")
            label:SetText("N")
            self.glyph.label = label
        elseif symbol == "eye" then
            for _, points in ipairs({
                { -7, 0, 0, 4 }, { 0, 4, 7, 0 }, { -7, 0, 0, -4 }, { 0, -4, 7, 0 },
            }) do
                local line = self:CreateLine(nil, "OVERLAY")
                line:SetThickness(1.7)
                line:SetStartPoint("CENTER", self, points[1], points[2])
                line:SetEndPoint("CENTER", self, points[3], points[4])
                self.glyph.lines[#self.glyph.lines + 1] = line
            end
            local pupil = self:CreateTexture(nil, "OVERLAY")
            pupil:SetSize(3, 3)
            pupil:SetPoint("CENTER")
            pupil:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
            self.glyph.pupil = pupil
        end
        self:RefreshAppearance()
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
    controls[#controls + 1] = checkbox
    return checkbox
end
