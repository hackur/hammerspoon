local module = {}

--- === hs.alert ===
---
--- Simple on-screen alerts

local drawing = require("hs.drawing")
local timer   = require("hs.timer")
local screen  = require("hs.screen")
local uuid    = require"hs.host".uuid
local stext   = require"hs.styledtext".new

local stextMT = hs.getObjectMetatable("hs.styledtext")

module._visibleAlerts = {}

--- hs.alert.defaultStyle[]
--- Variable
--- A table defining the default visual style for the alerts generated by this module.
---
--- The following may be specified in this table (any other key is ignored):
---  * Keys which affect the alert rectangle:
---    * fillColor   - a table as defined by the `hs.drawing.color` module to specify the background color for the alert, defaults to { white = 0, alpha = 0.75 }.
---    * strokeColor - a table as defined by the `hs.drawing.color` module to specify the outline color for the alert, defaults to { white = 1, alpha = 1 }.
---    * strokeWidth - a number specifying the width of the outline for the alert, defaults to 2
---    * radius      - a number specifying the radius used for the rounded corners of the alert box, defaults to 27
---
---  * Keys which affect the text of the alert when the message is a string (note that these keys will be ignored if the message being displayed is already an `hs.styledtext` object):
---    * textColor   - a table as defined by the `hs.drawing.color` module to specify the message text color for the alert, defaults to { white = 1, alpha = 1 }.
---    * textFont    - a string specifying the font to be used for the alert text, defaults to ".AppleSystemUIFont" which is a symbolic name representing the systems default user interface font.
---    * textSize    - a number specifying the font size to be used for the alert text, defaults to 27.
---    * textStyle   - an optional table, defaults to `nil`, specifying that a string message should be converted to an `hs.styledtext` object using the style elements specified in this table.  This table should conform to the key-value pairs as described in the documentation for the `hs.styledtext` module.  If this table does not contain a `font` key-value pair, one will be constructed from the `textFont` and `textSize` keys (or their defaults); likewise, if this table does not contain a `color` key-value pair, one will be constructed from the `textColor` key (or its default).
---
--- If you modify these values directly, it will affect all future alerts generated by this module.  To adjust one of these properties for a single alert, use the optional `style` argument to the [hs.alert.show](#show) function.
module.defaultStyle = {
    strokeWidth  = 2,
    strokeColor = { white = 1, alpha = 1 },
    fillColor   = { white = 0, alpha = 0.75 },
    textColor = { white = 1, alpha = 1 },
    textFont  = ".AppleSystemUIFont",
    textSize  = 27,
    radius = 27,
}

local purgeAlert = function(UUID, duration)
    duration = math.max(duration, 0.0) or 0.15
    local indexToRemove
    for i,v in ipairs(module._visibleAlerts) do
        if v.UUID == UUID then
            if v.timer then v.timer:stop() end
            for i2,v2 in ipairs(v.drawings) do
                v2:hide(duration)
                if duration > 0.0 then
                    timer.doAfter(duration, function() v2:delete() end)
                end
                v.drawings[i2] = nil
            end
            indexToRemove = i
            break
        end
    end
    if indexToRemove then
        table.remove(module._visibleAlerts, indexToRemove)
    end
end

local showAlert = function(message, style, screenObj, duration)
    local thisAlertStyle = {}
    for k,v in pairs(module.defaultStyle) do thisAlertStyle[k] = v end
    if type(style) == "table" then
        for k,v in pairs(style) do thisAlertStyle[k] = v end
    end

    local textSize  = thisAlertStyle.textSize
    local textFont  = thisAlertStyle.textFont
    local textColor = thisAlertStyle.textColor

    if type(thisAlertStyle.textStyle) == "table" and getmetatable(message) ~= stextMT then
        if not thisAlertStyle.textStyle.font then
            thisAlertStyle.textStyle.font = { name = textFont, size = textSize }
        end
        if not thisAlertStyle.textStyle.color then
            thisAlertStyle.textStyle.color = textColor
        end
        textSize  = thisAlertStyle.textStyle.font.size
        textFont  = thisAlertStyle.textStyle.font.name
        textColor = thisAlertStyle.textStyle.color
        message   = stext(message, thisAlertStyle.textStyle)
--        print(finspect(message:asTable()))
    end

    local screenFrame = screenObj:fullFrame()

    local absoluteTop = screenFrame.y + (screenFrame.h * (1 - 1 / 1.55) + 55) -- mimic module behavior for inverted rect
    if #module._visibleAlerts > 0 then
        -- we're looking for the latest on the same screen
        for i = #module._visibleAlerts, 1, -1 do
            if screenObj == module._visibleAlerts[i].screen then
                absoluteTop = module._visibleAlerts[i].frame.y + module._visibleAlerts[i].frame.h + 3
                break
            end
        end
    end

    if absoluteTop > (screenFrame.y + screenFrame.h) then
        absoluteTop = screenFrame.y
    end

    local alertEntry = {
        drawings = {},
        screen = screenObj,
    }
    local UUID = uuid()
    alertEntry.UUID = UUID

    local textFrame = drawing.getTextDrawingSize(message, { font = textFont, size = textSize })
    textFrame.w = textFrame.w + 8 -- known fudge factor, see hs.drawing.getTextDrawingSize docs
    -- fudge factor seems worse when using `hs.drawing` but completely unnecessary with `hs.canvas`
    -- need to figure out where drawing is inheriting margins from or push to retire hs.drawing completely...
    local drawingFrame = {
-- approximates, but it scales a *little* better than hard coded numbers for differing sizes...
--         x = screenFrame.x + (screenFrame.w - (textFrame.w + 26)) / 2,
        x = screenFrame.x + (screenFrame.w - (textFrame.w + textSize)) / 2,
        y = absoluteTop,
--         h = textFrame.h + 24,
--         w = textFrame.w + 26,
        h = textFrame.h + textSize,
        w = textFrame.w + textSize,
    }
--     textFrame.x = drawingFrame.x + 13
--     textFrame.y = drawingFrame.y + 12
    textFrame.x = drawingFrame.x + textSize / 2
    textFrame.y = drawingFrame.y + textSize / 2

    table.insert(alertEntry.drawings, drawing.rectangle(drawingFrame)
                                            :setStroke(true)
                                            :setStrokeWidth(thisAlertStyle.strokeWidth)
                                            :setStrokeColor(thisAlertStyle.strokeColor)
                                            :setFill(true)
                                            :setFillColor(thisAlertStyle.fillColor)
                                            :setRoundedRectRadii(thisAlertStyle.radius, thisAlertStyle.radius)
                                            :show(0.15)
    )
    table.insert(alertEntry.drawings, drawing.text(textFrame, message)
                                            :setTextFont(textFont)
                                            :setTextSize(textSize)
                                            :setTextColor(textColor)
                                            :orderAbove(alertEntry.drawings[1])
                                            :show(0.15)
    )
    alertEntry.frame = drawingFrame

    table.insert(module._visibleAlerts, alertEntry)
    if type(duration) == "number" then
        alertEntry.timer = timer.doAfter(duration, function()
            purgeAlert(UUID, 0.15)
        end)
    end
    return UUID
end

--- hs.alert.show(str, [style], [screen], [seconds]) -> uuid
--- Function
--- Shows a message in large words briefly in the middle of the screen; does tostring() on its argument for convenience.
---
--- NOTE: For convenience, you can call this function as `hs.alert(...)`
---
--- Parameters:
---  * str     - The string or `hs.styledtext` object to display in the alert
---  * style   - an optional table containing one or more of the keys specified in [hs.alert.defaultStyle](#defaultStyle).  If `str` is already an `hs.styledtext` object, this argument is ignored.
---  * screen  - an optional `hs.screen` userdata object specifying the screen (monitor) to display the alert on.  Defaults to `hs.screen.mainScreen()` which corresponds to the screen with the currently focused window.
---  * seconds - The number of seconds to display the alert. Defaults to 2.  If seconds is specified and is not a number, displays the alert indefinately.
---
--- Returns:
---  * a string identifier for the alert.
---
--- Notes:
---  * The optional parameters are parsed in the order presented as follows:
---    * if the argument is a table and `style` has not previously been set, then the table is assigned to `style`
---    * if the argument is a userdata and `screen` has not previously been set, then the userdata is assigned to `screen`
---    * if `duration` has not been set, then it is assigned the value of the argument
---    * if all of these conditions fail for a given argument, then an error is returned
---  * The reason for this logic is to support the creation of persistent alerts as was previously handled by the module: If you specify a non-number value for `seconds` you will need to store the string identifier returned by this function so that you can close it manually with `hs.alert.closeSpecific` when the alert should be removed.
---  * Any style element which is not specified in the `style` argument table will use the value currently defined in the [hs.alert.defaultStyle](#defaultStyle) table.
module.show = function(message, ...)
    local style, screenObj, duration
    for i,v in ipairs(table.pack(...)) do
        if type(v) == "table" and not style then
            style = v
        elseif type(v) == "userdata" and not screenObj then
            screenObj = v
        elseif type(duration) == "nil" then
            duration = v
        else
            error("unexpected type " .. type(v) .. " found for argument " .. tostring(i + 1), 2)
        end
    end
    if getmetatable(message) ~= stextMT then
        message = tostring(message)
    end
    duration  = duration or 2.0
    screenObj = screenObj or screen.mainScreen()
    return showAlert(message, style, screenObj, duration)
end

--- hs.alert.closeAll([seconds])
--- Function
--- Closes all alerts currently open on the screen
---
--- Parameters:
---  * seconds - Optional number specifying the fade out duration. Defaults to 0.15
---
--- Returns:
---  * None
module.closeAll = function(duration)
    duration = duration and math.max(duration, 0.0) or 0.15
    while (#module._visibleAlerts > 0) do
        purgeAlert(module._visibleAlerts[#module._visibleAlerts].UUID, duration)
    end
end

--- hs.alert.closeSpecific(uuid, [seconds])
--- Function
--- Closes the alert with the specified identifier
---
--- Parameters:
---  * uuid    - the identifier of the alert to close
---  * seconds - Optional number specifying the fade out duration. Defaults to 0.15
---
--- Returns:
---  * None
---
--- Notes:
---  * Use this function to close an alert which is indefinate or close an alert with a long duration early.
module.closeSpecific = function(UUID, duration)
    duration = duration and math.max(duration, 0.0) or 0.15
    purgeAlert(UUID, duration)
end

return setmetatable(module, { __call = function(_, ...) return module.show(...) end })
