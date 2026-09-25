local _, addon = ...
if type(addon) ~= "table" then return end

local Controls = {}
addon.VignetteRadarControls = Controls
local ACCENT = { 0.05, 0.82, 0.62 }
local controls = {}
local POPUP_FACE = "Interface\\AddOns\\VignetteRadar\\Media\\radar-rounded-square.tga"
local POPUP_EDGE = "Interface\\AddOns\\VignetteRadar\\Media\\radar-rounded-border.tga"

function Controls.TitleCase(value)
    if type(value) ~= "string" then return value end
    local special = { cpu = "CPU", ui = "UI", poi = "POI", pois = "POIs",
        wow = "WoW", zygor = "Zygor", yd = "yd", sec = "sec", px = "px" }
    return (value:gsub("[%a][%a']*", function(word)
        local lower = word:lower()
        return special[lower] or (lower:sub(1, 1):upper() .. lower:sub(2))
    end))
end

function Controls.RefreshPopupSurface(frame)
    if not (frame and frame.popupFace) then return end
    local style = addon.VignetteRadarStyle
    local br, bg, bb = .025, .032, .038
    local ar, ag, ab = ACCENT[1], ACCENT[2], ACCENT[3]
    if style then
        br, bg, bb = style.Color("background")
        ar, ag, ab = style.Color("accent")
    end
    frame.popupFace:SetVertexColor(math.min(.14, br * 2.7), math.min(.14, bg * 2.7),
        math.min(.14, bb * 2.7), .99)
    frame.popupEdge:SetVertexColor(ar, ag, ab, .40)
    if frame.SetBackdropColor then frame:SetBackdropColor(0, 0, 0, 0) end
    if frame.SetBackdropBorderColor then frame:SetBackdropBorderColor(0, 0, 0, 0) end
end

function Controls.PopupSurface(frame)
    if frame.popupFace then return end
    frame.popupFace = frame:CreateTexture(nil, "BACKGROUND")
    frame.popupFace:SetAllPoints(frame)
    frame.popupFace:SetTexture(POPUP_FACE)
    frame.popupEdge = frame:CreateTexture(nil, "BORDER")
    frame.popupEdge:SetAllPoints(frame)
    frame.popupEdge:SetTexture(POPUP_EDGE)
    Controls.RefreshPopupSurface(frame)
end

-- Keep the small corner radius circular when a status block is much wider
-- than it is tall; stretching the full square artwork distorts its corners.
function Controls.RoundedStatusSurface(frame)
    if frame.statusSurface then return end
    frame.statusSurface = { face = {}, edge = {} }
    local cut = 8 / 256
    local uv = { 0, cut, 1 - cut, 1 }
    for kind, path in pairs({ face = POPUP_FACE, edge = POPUP_EDGE }) do
        for row = 1, 3 do
            for column = 1, 3 do
                local texture = frame:CreateTexture(nil, kind == "face" and "BACKGROUND" or "BORDER")
                texture:SetTexture(path)
                texture:SetTexCoord(uv[column], uv[column + 1], uv[row], uv[row + 1])
                if column == 1 then
                    texture:SetPoint("LEFT", frame, "LEFT", 0, 0)
                    texture:SetWidth(8)
                elseif column == 2 then
                    texture:SetPoint("LEFT", frame, "LEFT", 8, 0)
                    texture:SetPoint("RIGHT", frame, "RIGHT", -8, 0)
                else
                    texture:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
                    texture:SetWidth(8)
                end
                if row == 1 then
                    texture:SetPoint("TOP", frame, "TOP", 0, 0)
                    texture:SetHeight(8)
                elseif row == 2 then
                    texture:SetPoint("TOP", frame, "TOP", 0, -8)
                    texture:SetPoint("BOTTOM", frame, "BOTTOM", 0, 8)
                else
                    texture:SetPoint("BOTTOM", frame, "BOTTOM", 0, 0)
                    texture:SetHeight(8)
                end
                frame.statusSurface[kind][#frame.statusSurface[kind] + 1] = texture
            end
        end
    end
    Controls.RefreshRoundedStatusSurface(frame)
end

function Controls.RefreshRoundedStatusSurface(frame)
    if not (frame and frame.statusSurface) then return end
    local style = addon.VignetteRadarStyle
    local br, bg, bb, ar, ag, ab = .025, .032, .038, ACCENT[1], ACCENT[2], ACCENT[3]
    if style then
        br, bg, bb = style.Color("background")
        ar, ag, ab = style.Color("accent")
    end
    for _, texture in ipairs(frame.statusSurface.face) do
        texture:SetVertexColor(math.min(.14, br * 2.7), math.min(.14, bg * 2.7),
            math.min(.14, bb * 2.7), .97)
    end
    for _, texture in ipairs(frame.statusSurface.edge) do
        texture:SetVertexColor(ar, ag, ab, .64)
    end
end

function Controls.RefreshTheme()
    if addon.VignetteRadarStyle then
        ACCENT[1], ACCENT[2], ACCENT[3] = addon.VignetteRadarStyle.Color("accent")
    end
    for _, control in ipairs(controls) do
        if control.RefreshAppearance then control:RefreshAppearance() end
    end
end

-- Quiet, flat controls match the unboxed glyphs on the radar. A one-pixel
-- underline carries selection; wide buttons never stretch a rounded sprite.
function Controls.Button(parent, title, width, height)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width, height)
    button.face = button:CreateTexture(nil, "BACKGROUND")
    button.face:SetAllPoints(button)
    button.face:SetTexture("Interface\\Buttons\\WHITE8X8")
    button.edge = button:CreateTexture(nil, "ARTWORK")
    button.edge:SetHeight(1)
    button.edge:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 2, 2)
    button.edge:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
    button.edge:SetTexture("Interface\\Buttons\\WHITE8X8")
    button.label = button:CreateFontString(nil, "OVERLAY")
    local font = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    button.label:SetFont(font, width <= 48 and 14 or 10, "")
    button.label:SetSize(width - 10, height - 6)
    button.label:SetJustifyH("CENTER")
    button.label:SetWordWrap(false)
    button:SetFontString(button.label)
    button:SetText(title)

    button.selection = button:CreateTexture(nil, "ARTWORK")
    button.selection:SetSize(math.max(1, width - 12), 2)
    button.selection:SetPoint("BOTTOM", 0, 1)
    button.selection:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.8)
    button._enabled = true

    local function Refresh()
        local enabled = button._enabled
        local selected = button._selected
        local hovered = enabled and button._hovered
        local pressed = enabled and button._pressed
        button:SetAlpha(enabled and 1 or 0.38)
        button.label:ClearAllPoints()
        button.label:SetPoint("CENTER", 0, 0)
        button.selection:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], .8)
        button.selection:SetShown(enabled and selected == true)
        if pressed then
            button.face:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3], .24)
            button.edge:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3], .75)
            button.label:SetTextColor(0.95, 1, 0.98, 1)
        elseif hovered or selected then
            button.face:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3], hovered and .14 or .08)
            button.edge:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3], hovered and .50 or .32)
            button.label:SetTextColor(hovered and 0.86 or ACCENT[1], hovered and 1 or ACCENT[2],
                hovered and 0.95 or ACCENT[3], 1)
        else
            button.face:SetVertexColor(.13, .17, .19, .24)
            button.edge:SetVertexColor(.60, .70, .70, .10)
            button.label:SetTextColor(.76, .83, .82, 1)
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
    local checkbox = CreateFrame("CheckButton", nil, parent)
    checkbox:SetSize(26, 26)
    checkbox.visual = CreateFrame("Frame", nil, checkbox, "BackdropTemplate")
    checkbox.visual:SetSize(17, 17)
    checkbox.visual:SetPoint("CENTER")
    checkbox.visual:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    checkbox.mark = {}
    local segments = {
        { -5, 0, -1, -4 },
        { -1, -4, 6, 4 },
    }
    for index, segment in ipairs(segments) do
        local line = checkbox.visual:CreateLine(nil, "OVERLAY")
        line:SetThickness(2)
        line:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 1)
        line:SetStartPoint("CENTER", checkbox.visual, segment[1], segment[2])
        line:SetEndPoint("CENTER", checkbox.visual, segment[3], segment[4])
        checkbox.mark[index] = line
    end
    function checkbox:RefreshAppearance()
        local checked = self:GetChecked() == true or self:GetChecked() == 1
        local hovered = self._hovered == true
        local pressed = self._pressed == true
        for _, line in ipairs(self.mark) do line:SetShown(checked and not self.glyph) end
        if self.glyph then
            local r, g, b = checked and ACCENT[1] or 0.69,
                checked and ACCENT[2] or 0.77, checked and ACCENT[3] or 0.78
            for _, line in ipairs(self.glyph.lines or {}) do line:SetColorTexture(r, g, b, 1) end
            if self.glyph.label then self.glyph.label:SetTextColor(r, g, b, 1) end
            if self.glyph.pupil then self.glyph.pupil:SetVertexColor(r, g, b, 1) end
        end
        if checked then
            self.visual:SetBackdropColor(ACCENT[1] * .18,
                ACCENT[2] * .18, ACCENT[3] * .18, .94)
            self.visual:SetBackdropBorderColor(ACCENT[1], ACCENT[2], ACCENT[3],
                pressed and 1 or hovered and .98 or .82)
        else
            self.visual:SetBackdropColor(.025, .033, .039, .88)
            self.visual:SetBackdropBorderColor(hovered and ACCENT[1] or .48,
                hovered and ACCENT[2] or .55, hovered and ACCENT[3] or .57,
                hovered and .78 or .48)
        end
        for _, line in ipairs(self.mark) do
            line:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 1)
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
            local label = self.visual:CreateFontString(nil, "OVERLAY")
            label:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 14, "")
            label:SetAllPoints(self.visual)
            label:SetJustifyH("CENTER")
            label:SetText("N")
            self.glyph.label = label
        elseif symbol == "eye" then
            for _, points in ipairs({
                { -7, 0, 0, 4 }, { 0, 4, 7, 0 }, { -7, 0, 0, -4 }, { 0, -4, 7, 0 },
            }) do
                local line = self.visual:CreateLine(nil, "OVERLAY")
                line:SetThickness(1.7)
                line:SetStartPoint("CENTER", self.visual, points[1], points[2])
                line:SetEndPoint("CENTER", self.visual, points[3], points[4])
                self.glyph.lines[#self.glyph.lines + 1] = line
            end
            local pupil = self.visual:CreateTexture(nil, "OVERLAY")
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
