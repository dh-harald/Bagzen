function Bagzen:FrameStartMoving(frame)
    frame.isMoving = 1
    frame:StartMoving()
end

function Bagzen:FrameStopMoving(frame)
    frame:StopMovingOrSizing()
    frame.isMoving = nil
    Bagzen:GetPosition(frame)
end

function Bagzen:GetPosition(frame)
        local point, _, relativePoint, xOfs, yOfs = frame:GetPoint()
        Bagzen.settings.char[frame.SettingSection].point = point
        Bagzen.settings.char[frame.SettingSection].relativePoint = relativePoint
        Bagzen.settings.char[frame.SettingSection].xOfs = xOfs
        Bagzen.settings.char[frame.SettingSection].yOfs = yOfs
end

function Bagzen:RePosition(frame)
    local scale = Bagzen.settings.char[frame.SettingSection].scale or 1
    if scale then
        frame:SetScale(scale)
    end
    if Bagzen.settings.char[frame.SettingSection].point then
        frame:SetPoint(Bagzen.settings.char[frame.SettingSection].point, nil, Bagzen.settings.char[frame.SettingSection].relativePoint, Bagzen.settings.char[frame.SettingSection].xOfs, Bagzen.settings.char[frame.SettingSection].yOfs)
    end
end