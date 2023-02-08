-- Name this file `main.lua`. Your game can use multiple source files if you wish
-- (use the `import "myFilename"` command), but the simplest games can be written
-- with just `main.lua`.

-- You'll want to import these in just about every project you'll work on.

import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/timer"

-- Declaring this "gfx" shorthand will make your life easier. Instead of having
-- to preface all graphics calls with "playdate.graphics", just use "gfx."
-- Performance will be slightly enhanced, too.
-- NOTE: Because it's local, you'll have to do it in every .lua source file.

local gfx <const> = playdate.graphics
local file<const> = playdate.file
local sin, cos, pi = math.sin, math.cos, math.pi
deltaTime = nil


playdate.setCrankSoundsDisabled(true)

--[[
--controller input
local pressingLeft = false
local pressingRight = false
local pressingUp = false
local pressingDown = false
--]]

--narrative script
local script = playdate.file.open("script.txt",playdate.file.kFileRead)

--textbox parameters
local rectWidth = 150
local borderSize = 3
local radius = 10
local margin = 10
local fontHeight = 20
local rect = playdate.geometry.rect.new(400-rectWidth,0,rectWidth,240)
local textRect = playdate.geometry.rect.new(400-rectWidth+margin,margin,rectWidth-margin*2,240-margin*2-fontHeight)
local spriteRect = playdate.geometry.rect.new(0,0,400-rectWidth,240)


--auto and skip parameters
local skipTypes = {
    ALL = 1,
    PREVIOUS = 2,
}
local autoTime = 0
local autoCounter = 0
local autoModeRectHeight = 25
local autoModeRectWidth = 70
local autoModeRectMargin = 4
local autoModeRect = playdate.geometry.rect.new(0,240-autoModeRectHeight,autoModeRectWidth,autoModeRectHeight)

--settings! (all changeable by user)
local cps = 30
local darkMode = false
local autoMode = false
local skipMode = false
local autoSpeed = 0.030
local skipType = skipTypes.PREVIOUS
local boldText = false

--text paarameters
local font = gfx.font.new("hahahaha!") --default to asheville
local fontRoobert = gfx.font.new("images/font/roobert/Roobert-11-Bold")
local fontRoobertHalf = gfx.font.new("images/font/roobert/Roobert-11-Medium-Halved")
local charHeight = {gfx.getTextSize("R",font)}
charHeight = charHeight[2]
local currentChar = ""
local currentLine = ""
local trimmedLine = ""
local currentPrintedLine = ""
local currentCharNo = 0
local lineFinished = false
local textSpeed = 1
local triangleCounter = 0
local textHidden = true
local currentLineLength = 0
local waitingForClick = false

--sprite parameters
local currentSprite = gfx.image.new("Images/blank.png")
local spriteFadeCounter = 0
local spriteDefaultFadeTime = 0.25
local spriteFadeTime = 0
local previousSprite = currentSprite

--background parameters
local currentBackground = gfx.image.new( "Images/blank.png" )
local previousBackground = currentBackground
local backgroundFadeTime = 0
local backgroundFadeCounter = 0
local backgroundDefaultFadeTime = 0.5
local backgroundIsBlack = 0

--bgm parameters
local currentMusic = nil
local currentMusicName = nil
local musicFadeDefault = 0.5

--short pause parameters
local pauseTime = 0
local pauseCounter = 0

--text pause parameters
local txtPauseTime = 0
local txtPauseCounter = 0

--screen shake parameters
local shakeTime = 0
local shakeCounter = 0
local shakeTimeDefault = 0.5
local shakeDir = 0
local shakeAmount = 0

--fade parameters
local ditherType = gfx.image.kDitherTypeBayer8x8

--rollback parameters
local rollbackMode = false
local rollbackNum = 0

--check if a string is empty
local function isempty(s)
    return s == nil or s == ''
end

--split a string into an array of tokens split by something or other
function split (inputstr, sep)
    if sep == nil then
            sep = "%s"
    end
    local t={}
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
            table.insert(t, str)
    end
    return t
end

function shakeFunc(counter,time)
    return 4.5*math.sin(counter*(2*math.pi)*13)*(time/counter)
end

--a rollbackentry is basically a fully finished screen of vn
RollbackEntry = {
    sfx = nil,
    bgm = nil,
    bg = nil,
    sprite = nil,
    text = nil,
    char = nil
}
function RollbackEntry:new(o)
    o = o or {}
    setmetatable(o,self)
    self.__index = self
    self.sfx = nil
    self.bgm = o.bgm or nil
    self.bg = o.bg or nil
    self.sprite = o.sprite or nil
    self.text = o.text or nil
    self.char = o.char or nil
    return o
end

--the rollbacktable allows you to go back and forward thru vn time
RollbackTable = {RollbackEntry:new(nil)}
function getCurrentRollback()
    return RollbackTable[#RollbackTable]
end
function advanceRollback()
    local newEntry = RollbackEntry:new{
        sfx = nil,
        bgm = getCurrentRollback().bgm,
        bg = getCurrentRollback().bg,
        sprite = getCurrentRollback().sprite,
        text = getCurrentRollback().text,
        char = getCurrentRollback().char
    }
    table.insert(RollbackTable, RollbackEntry:new(newEntry))
    getCurrentRollback().sfx = nil
end

--inject newlines in the proper places of a string to make it print good
function optimizeLineWrap(initialLine)
    local splitLine = split(initialLine)
    local testLine = ""
    local finalLine = ""
    trimmedLine = ""
    local token = ""
    local trimmedToken = ""
    local heightOffset = margin
    local isTag = false
    for i=1, #splitLine do
        token = splitLine[i]
        --trimmedToken = split(token,"{")[1]

        --trimmedtoken is the token with all tags removed
        trimmedToken = ""
        for i=0,string.len(token) do
            if string.sub(token,i,i) == "{" then
                isTag = true
            end
            if not isTag then trimmedToken = trimmedToken .. string.sub(token,i,i) end
            if string.sub(token,i,i) == "}" then
                isTag = false
            end
        end
        
        testLine = trimmedLine .. " " .. trimmedToken
        local width, height = gfx.getTextSize(testLine,font)

        if height - heightOffset > textRect.height - charHeight - margin then
            heightOffset = height
            for i = string.len(finalLine), 1, -1 do
                if string.sub(finalLine,i,i) == " " or string.sub(finalLine,i,i) == "\n" then
                    finalLine = string.sub(finalLine,1,i-1) .. "{x}" .. string.sub(finalLine,i+1)
                    break
                end
            end
        end
        if width > textRect.width then
            finalLine = finalLine .. "\n" .. token
            trimmedLine = trimmedLine .. "\n" .. trimmedToken
        else 
            finalLine = finalLine .. " " .. token
            trimmedLine = trimmedLine .. " " .. trimmedToken
        end
    end
    trimmedLine = string.sub(trimmedLine,2)
    return string.sub(finalLine,2) --removing space
end

function stopAudio(fileplayer)
    fileplayer:stop()
end

function isNextLineExtend(file) 
    local origOffset = file:tell()
    local line = file:readline()
    file:seek(origOffset)
    return split(line," ")[1] == "extend"
end

--parse the next line of the script
function parseLine()
    line = script:readline()
    if line == nil then return end
    line = string.gsub(line,"\\\"","\t")
    if string.sub(line,1,1) == "#" or isempty(line) then --skip if comment
        parseLine()
        return
    end
    local tokenTable = split(line," ")

    if tokenTable[1] == "show" then --show a sprite
        previousSprite = currentSprite
        currentSprite = gfx.image.new("Images/"..tokenTable[2]..".png")
        spriteFadeCounter = 0
        if isempty(tokenTable[3]) then spriteFadeTime = spriteDefaultFadeTime
        else spriteFadeTime = tonumber(tokenTable[3]) end
        if spriteFadeTime == 0 then spriteFadeTime = 0.000001 end
        getCurrentRollback().sprite = tokenTable[2]
        return

    elseif tokenTable[1] == "bg" then --change background image
        previousBackground = currentBackground
        currentBackground = gfx.image.new("images/"..tokenTable[2]..".png")
        backgroundFadeCounter = 0
        if isempty(tokenTable[3]) then backgroundFadeTime = backgroundDefaultFadeTime
        else backgroundFadeTime = tonumber(tokenTable[3]) end
        if backgroundFadeTime == 0 then backgroundFadeTime = 0.000001 end
        if tokenTable[2] == "black" then backgroundIsBlack = true
        else backgroundIsBlack = false end
        getCurrentRollback().bg = tokenTable[2]
        return
        
    elseif tokenTable[1] == "music" then --play music
        currentMusicName = tokenTable[2]
        currentMusic = playdate.sound.fileplayer.new("sound/"..currentMusicName..".mp3")
        currentMusic:play(0)
        getCurrentRollback().bgm = currentMusicName
        parseLine()
        return

    elseif tokenTable[1] == "sound" then --play sfx
        local sound = playdate.sound.fileplayer.new("sound/"..tokenTable[2]..".mp3")
        sound:play()
        getCurrentRollback().sfx = tokenTable[2]
        parseLine()
        return

    elseif tokenTable[1] == "stopmus" then --stop music
        local fade = 0
        if isempty(tokenTable[2]) then fade = musicFadeDefault
        else fade = tokenTable[2] end
        currentMusic:setVolume(0,0,fade,stopAudio)
        currentMusicName = "nil"
        getCurrentRollback().bgm = "nil"
        parseLine()
        return

    elseif tokenTable[1] == "pause" then --pause for a bit
        pauseCounter = 0
        pauseTime = tonumber(tokenTable[2])
    
    elseif tokenTable[1] == "shake" then --screenshake
        shakeCounter = 0
        shakeTime = shakeTimeDefault
        shakeDir = tokenTable[2]

    elseif tokenTable[1] == "extend" then
        lineFinished = false
        tokenTable = split(line,"\"")
        local endQuote = nil
        if isNextLineExtend(script) or string.lower(currentChar)=="narrator" then endQuote = ""
        else endQuote = "\"" end
        currentLine = currentLine .. string.gsub(string.format("%s%s",tokenTable[2],endQuote),"\t","\"")
        currentLine = optimizeLineWrap(currentLine)
    
    elseif tokenTable[1] == "end" then
        while True do end

    else    --character saying something
        lineFinished = false
        currentCharNo = 0
        currentChar = tokenTable[1]
        tokenTable = split(line,"\"")
        local startQuote = nil
        local endQuote = nil
        if string.lower(currentChar)=="narrator" then startQuote = ""
        else startQuote = "\"" end
        if isNextLineExtend(script) then endQuote = ""
        else endQuote = startQuote end
        currentLine = string.gsub(string.format("%s%s%s",startQuote,tokenTable[2],endQuote),"\t","\"")
        currentLine = optimizeLineWrap(currentLine)
    end
end

function round(n)
    return math.floor(n+0.5)
end

function strChr(str,n)
    return string.sub(str,n,n)
end

--continue text to the next character AND parse inline tags
function updateText()
    if lineFinished then 
        return
    end
    local prevRoundedCharNo = round(currentCharNo)
    currentCharNo += deltaTime * 1000 / cps * textSpeed
    local currentRoundedCharNo = round(currentCharNo)
    for i = prevRoundedCharNo+1, currentRoundedCharNo do
        if strChr(currentLine,i) == "{" then
            local j = 0
            while strChr(currentLine,j) ~= "}" do j += 1 end
            local tag = string.sub(currentLine,i+1,j-1)
            local splitTag = split(tag,"=")

            if tag == "x" then
                lineFinished = true
                waitingForClick = true
                if autoMode then autoTime = i * autoSpeed end

            --text pause tag
            elseif splitTag[1] == "w" then
                txtPauseCounter = 0
                txtPauseTime = tonumber(splitTag[2])

            --nowait
            elseif splitTag[1] == "nw" then
                getCurrentRollback().text = trimmedLine
                getCurrentRollback().char = currentChar
                advanceRollback()
                parseLine()

            --speed
            elseif splitTag[1] == "s" then
                textSpeed = splitTag[2]
            end

            currentLine = string.sub(currentLine,1,i-1) .. string.sub(currentLine,j+1)
            currentCharNo = i-1
        end
    end
    
    if currentCharNo >= string.len(currentLine) then
        lineFinished = true
        if autoMode then autoTime = autoSpeed * currentCharNo end
    end
    currentPrintedLine = string.sub(currentLine,1,round(currentCharNo))
end

--display text on the textbox
function showText(char, words)
    local charStr = nil
    if string.lower(char)=="narrator" then charStr = ""
    else charStr = string.format("*%s*:\n",string.upper(char)) end
    local boldChar = nil
    if boldText then boldChar = "*"
    else boldChar = "" end
    local stringToPrint = string.format("%s%s%s%s",charStr,boldChar,words,boldChar)
    --draw text on screen
    if darkMode then gfx.setImageDrawMode( playdate.graphics.kDrawModeInverted ) end
    gfx.drawTextInRect(stringToPrint,textRect,nil,nil,kTextAlignment.left,font)
    if darkMode then playdate.graphics.setImageDrawMode(playdate.graphics.kDrawModeCopy) end
end



parseLine()

local prevTime = nil
local currentTime = playdate.getCurrentTimeMilliseconds() - 0.033

-- `playdate.update()` is the heart of every Playdate game.
-- This function is called right before every frame is drawn onscreen.
-- Use this function to poll input, run game logic, and move sprites.

function drawBG()
    currentBackground:draw( 0, 0 )
    backgroundFadeTime = 0
    parseLine()
end

function drawSprite()
    currentBackground:draw(spriteRect.x, spriteRect.y, gfx.kImageUnflipped, spriteRect)
    currentSprite:draw((400-rectWidth)/2-200,0)
    spriteFadeTime = 0
    parseLine()
end

function hideAutoModeBox()
    currentBackground:draw(autoModeRect.x, autoModeRect.y, gfx.kImageUnflipped, autoModeRect)
    currentSprite:draw(autoModeRect.x,autoModeRect.y,gfx.kImageUnflipped, playdate.geometry.rect.new(-(((400-rectWidth)/2)-200),autoModeRect.y,autoModeRect.width,autoModeRect.height))
end

function drawBox()
    if darkMode then gfx.setColor(gfx.kColorBlack)
    else gfx.setColor(gfx.kColorWhite) end
    gfx.fillRoundRect(rect,radius)
    gfx.setLineWidth(borderSize)
    if darkMode then gfx.setColor(gfx.kColorWhite)
    else gfx.setColor(gfx.kColorBlack) end
    gfx.drawRoundRect(rect,radius)
end

function displayRollbackState(currentRollbackEntry)
    print("bgm = \""..currentRollbackEntry.bgm.."\"")
    print(currentMusicName)
    gfx.image.new( "Images/"..currentRollbackEntry.bg..".png" ):draw( 0, 0 )
    gfx.image.new( "Images/"..currentRollbackEntry.sprite..".png" ):draw((400-rectWidth)/2-200,0)
    drawBox()
    if string.lower(currentRollbackEntry.char)=="narrator" then showText("narrator",currentRollbackEntry.text)
    else showText(currentRollbackEntry.char,currentRollbackEntry.text) end
    
    if not (currentRollbackEntry.sfx == nil) then 
        local sound = playdate.sound.fileplayer.new("sound/"..currentRollbackEntry.sfx..".mp3")
        sound:play()
    end


    if currentRollbackEntry.bgm ~= currentMusicName then
        stopAudio(currentMusic)
        currentMusicName = currentRollbackEntry.bgm
        if currentRollbackEntry.bgm ~= "nil" then
            currentMusic = playdate.sound.fileplayer.new("sound/"..currentRollbackEntry.bgm..".mp3")
            currentMusic:play(0)
        end
    end
end

local crankPos = 0
local prevCrankPos = 0
local crankUp = false
local crankDown = false

function playdate.update()
    --print(getCurrentRollback().text)

    prevTime = currentTime
    currentTime = playdate.getCurrentTimeMilliseconds()
    deltaTime = (currentTime - prevTime)/1000

    prevCrankPos = crankPos
    crankPos = playdate.getCrankPosition()
    if crankUp then crankUp = false end
    if crankDown then crankDown = false end
    if (prevCrankPos < 360 and prevCrankPos >= 270 and crankPos <270 and crankPos >=180) or (prevCrankPos < 180 and prevCrankPos > 90 and crankPos < 90 and crankPos >= 0) then crankUp = true end
    if (crankPos < 360 and crankPos >= 270 and prevCrankPos <270 and prevCrankPos >=180) or (crankPos < 180 and crankPos > 90 and prevCrankPos < 90 and prevCrankPos >= 0) then crankDown = true end

    if rollbackMode then

        --modify rollbacknum with up/down (will implement crank later)
        if (playdate.buttonJustPressed(playdate.kButtonUp) or crankUp) and rollbackNum > 1 then
            rollbackNum -= 1
            displayRollbackState(RollbackTable[rollbackNum])
        end
        if playdate.buttonJustPressed(playdate.kButtonDown) or crankDown then
            rollbackNum += 1
            displayRollbackState(RollbackTable[rollbackNum])
        end
        if playdate.buttonJustPressed(playdate.kButtonB) then 
            rollbackNum = #RollbackTable
            displayRollbackState(RollbackTable[rollbackNum])
        end
        if rollbackNum == #RollbackTable then
            rollbackMode = false
            --draw screen for normal state
            currentBackground:draw(0,0)
            currentSprite:draw((400-rectWidth)/2-200,0)
            drawBox()
            showText(currentChar,currentPrintedLine)
            return
        end

        

        return
    end

    if not rollbackMode and lineFinished and (playdate.buttonJustPressed(playdate.kButtonUp) or crankUp) and #RollbackTable > 1 then
        rollbackMode = true
        rollbackNum = #RollbackTable - 1
        displayRollbackState(RollbackTable[rollbackNum])
    end

    if playdate.buttonJustPressed(playdate.kButtonRight) then
        skipMode = not skipMode
    end

    if playdate.buttonJustPressed(playdate.kButtonB) then
        skipMode = false
        autoMode = not autoMode
        if autoMode and lineFinished then
            parseLine()
            lineFinished = false
        end
        if not autoMode then 
            hideAutoModeBox()
            autoTime = 0
            autoCounter = 0
        end
    end

    if playdate.buttonJustPressed(playdate.kButtonA) and (autoMode or skipMode) then
        autoMode = false
        skipMode = false
        autoTime = 0
        autoCounter = 0
        hideAutoModeBox()
    end

    --A trigger code
    if playdate.buttonJustPressed(playdate.kButtonA) or skipMode == true then

        
        
        if pauseTime > 0 and pauseCounter < pauseTime then
            pauseTime = 0
            pauseCounter = 0
            parseLine()

        elseif shakeTime > 0 and shakeCounter < shakeTime then
            shakeTime = 0
            shakeCounter = 0
            parseLine()
        
        --elseif (backgroundFadeTime > 0 and backgroundFadeCounter < backgroundFadeTime) or (spriteFadeTime > 0 and spriteFadeCounter < spriteFadeTime) then
        --    backgroundFadeCounter = 0
        --    backgroundFadeTime = 0
        --    spriteFadeCounter = 0
        --    spriteFadeTime = 0
        --    --parseLine()
        elseif (backgroundFadeTime > 0) then
            drawBG()
        elseif (spriteFadeTime > 0) then
            drawSprite()
        elseif txtPauseTime > 0 then
            txtPauseTime = 0
            txtPauseCounter = 0
        elseif not lineFinished then
            --currentCharNo = string.len(currentLine)
            while not lineFinished and txtPauseTime == 0 do
                updateText()
            end
            --lineFinished = true
        elseif waitingForClick then
            waitingForClick = false
            getCurrentRollback().text = trimmedLine
            getCurrentRollback().char = currentChar
            advanceRollback()
            currentLine = string.sub(currentLine,currentCharNo+1)
            currentCharNo = 0
            lineFinished = false
            
        else
            getCurrentRollback().text = trimmedLine
            getCurrentRollback().char = currentChar
            advanceRollback()
            parseLine()
            lineFinished = false
            --currentCharNo = 0
        end
    end

    --draw bg
    if backgroundFadeTime > 0 then
        if backgroundFadeCounter < backgroundFadeTime then
            backgroundFadeCounter += deltaTime
            local fadeAlg = math.min(backgroundFadeCounter/backgroundFadeTime,1)
            --currentBackground:drawFaded(0,0,fadeAlg,ditherType)
            currentBackground:draw( 0, 0 )
            previousBackground:drawFaded(0,0,1-fadeAlg,ditherType)
        else
            drawBG()
        end
        updateFinish()
        return
    end
    
    --draw sprite
    if spriteFadeTime > 0 then
        if not textHidden then 
            currentBackground:draw(0,0)
            textHidden = true
        else
            currentBackground:draw(0, 0, gfx.kImageUnflipped, spriteRect)
        end
        if spriteFadeCounter < spriteFadeTime then
            spriteFadeCounter += deltaTime
            local fadeAlg = math.min(spriteFadeCounter/spriteFadeTime,1)
            currentSprite:drawFaded((400-rectWidth)/2-200,0,fadeAlg,ditherType)
            previousSprite:drawFaded((400-rectWidth)/2-200,0,1-fadeAlg,ditherType)
            --previousSprite = previousSprite:blendWithImage(currentSprite,1-fadeAlg,ditherType)
            --previousSprite:draw((400-rectWidth)/2-200,0)
        else
            drawSprite()
        end
        updateFinish()
        return
    end

    --screenshake
    if shakeTime > 0 then
        if shakeCounter ==0 then
        end
        if  shakeCounter < shakeTime then
            shakeAmount = shakeFunc(shakeCounter,shakeTime)
            if shakeDir == "h" then
                currentBackground:draw( shakeAmount, 0 )
                currentSprite:draw((400-rectWidth)/2-200-shakeAmount,0)
            elseif shakeDir == "v" then
                currentBackground:draw( 0, shakeAmount )
                currentSprite:draw((400-rectWidth)/2-200,-shakeAmount)
            end
            shakeCounter += deltaTime
        else
            shakeTime = 0
            currentBackground:draw( 0, 0 )
            currentSprite:draw((400-rectWidth)/2-200,0)
            parseLine()
        end
        updateFinish()
        return
    end

    --wait if paused
    if pauseTime > 0 then
        if pauseCounter ==0 then
            currentBackground:draw( 0, 0 )
            currentSprite:draw((400-rectWidth)/2-200,0)
        end
        if  pauseCounter < pauseTime then
            pauseCounter += deltaTime
        else
            pauseTime = 0
            parseLine()
        end
        updateFinish()
        return
    end

    textHidden = false
    --draw the box
    if currentCharNo == 0 then
        drawBox()
    end

    --wait if txtpaused
    if txtPauseTime > 0 then
        showText(currentChar,currentPrintedLine)
        if  txtPauseCounter < txtPauseTime then
            txtPauseCounter += deltaTime
        else
            txtPauseTime = 0
        end
        updateFinish()
        return
    end

    --draw text
    updateText()
    if triangleCounter == 0 then showText(currentChar,currentPrintedLine) end

    --draw triangle at the end
    if lineFinished then
        triangleCounter += 1
        if math.floor(triangleCounter/20) % 2 == 0 then
            if darkMode then gfx.setColor(gfx.kColorWhite)
            else gfx.setColor(gfx.kColorBlack) end
        else
            if not darkMode then gfx.setColor(gfx.kColorWhite)
            else gfx.setColor(gfx.kColorBlack) end
        end
        gfx.fillTriangle(373,223,385,223,379,230)
    else triangleCounter = 0 end

    --wait for auto trigger
    if autoTime > 0 then
        if  autoCounter < autoTime then
            autoCounter += deltaTime
        else
            autoTime = 0
            autoCounter = 0
            parseLine()
        end
        updateFinish()
        return
    end

    updateFinish()

end

--do after step function (gui ish)
function updateFinish()
    playdate.drawFPS(0,0)
    if autoMode then 
        if darkMode then gfx.setColor(gfx.kColorBlack)
        else gfx.setColor(gfx.kColorWhite) end
        gfx.fillRect(autoModeRect)
        if darkMode then gfx.setImageDrawMode( playdate.graphics.kDrawModeInverted ) end
        gfx.drawTextInRect("AUTO",autoModeRect.x,autoModeRect.y+autoModeRectMargin,autoModeRect.width,autoModeRect.height,autoModeLeading,nil,kTextAlignment.center,fontRoobert)
        if darkMode then gfx.setImageDrawMode( playdate.graphics.kDrawModeCopy ) end
    end
end