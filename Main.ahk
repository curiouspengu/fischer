﻿/*
Made by b0red_man
Project started on 10/11/2024

Alot of this code has been taken from dolphSol Macro
*/

#Requires AutoHotkey v1.1
#NoEnv
#SingleInstance, force

SetWorkingDir, % A_ScriptDir "\lib"
CoordMode, Pixel, Client
CoordMode, Mouse, Client

#Include *i %A_ScriptDir%\lib
#Include *i ocr.ahk
#Include *i Gdip_All.ahk
#Include *i Gdip_ImageSearch.ahk

Gdip_Startup()

global configpath := A_ScriptDir . "\lib\config.ini"

global macroOn := 0
configHeader := "; bmFisch Settings`n;   Do not put spaces between equals`n;   Additions may break this file and the macro overall, please be cautious`n;   If you mess up this file, clear it entirely and restart the macro`n`n[Options]`r`n"

global options := {"WebhookOn":0
    ,"WebhookURL":""
    ,"UserID":""
    ,"AutoFishEnabled":1
    ,"MsgMin":25
    ,"PingMin":100
    ,"AFMiddle":915
    ,"AFLeft":515
    ,"AFRight":1350
    ,"ScreenshotsOn":1
    ,"ScreenshotInterval":60
    ,"SendEvents":1}
loadData()
validateWebhookLink(link){ ; Taken from dolphSol
    return RegexMatch(link, "i)https:\/\/(canary\.|ptb\.)?(discord|discordapp)\.com\/api\/webhooks\/([\d]+)\/([a-z0-9_-]+)") ; filter by natro
}
global guis := Object(), timers := Object()

Highlight(x="", y="", w="", h="", showTime=20000, color="Red", d=2) {
    ; If no coordinates are provided, clear all highlights
    if (x = "" || y = "" || w = "" || h = "") {
        for key, timer in timers {
            SetTimer, % timer, Off
            Gui, %key%Top:Destroy
            Gui, %key%Left:Destroy
            Gui, %key%Bottom:Destroy
            Gui, %key%Right:Destroy
            guis.Delete(key)
        }
        timers := Object()
        return
    }

    x := Floor(x)
    y := Floor(y)
    w := Floor(w)
    h := Floor(h)

    ; Create a new highlight
    key := "Highlight" x y w h
    Gui, %key%Top:New, +AlwaysOnTop -Caption +ToolWindow
    Gui, %key%Top:Color, %color%
    Gui, %key%Top:Show, x%x% y%y% w%w% h%d%

    Gui, %key%Left:New, +AlwaysOnTop -Caption +ToolWindow
    Gui, %key%Left:Color, %color%
    Gui, %key%Left:Show, x%x% y%y% h%h% w%d%

    Gui, %key%Bottom:New, +AlwaysOnTop -Caption +ToolWindow
    Gui, %key%Bottom:Color, %color%
    Gui, %key%Bottom:Show, % "x"x "y"(y+h-d) "w"w "h"d

    Gui, %key%Right:New, +AlwaysOnTop -Caption +ToolWindow
    Gui, %key%Right:Color, %color%
    Gui, %key%Right:Show, % "x"(x+w-d) "y"y "w"d "h"h

    ; Store the gui and set a timer to remove it
    guis[key] := true
    if (showTime > 0) {
        timerKey := Func("RemoveHighlight").Bind(key)
        timers[key] := timerKey
        SetTimer, %timerKey%, -%showTime%
    }
}

RemoveHighlight(key) {
    global guis, timers
    Gui, %key%Top:Destroy
    Gui, %key%Left:Destroy
    Gui, %key%Bottom:Destroy
    Gui, %key%Right:Destroy
    guis.Delete(key)
    timers.Delete(key)
}

getINIData(path) {
    FileRead, retrieved, %path%

    retrievedData := {}
    readingPoint := 0

    ls := StrSplit(retrieved,"`n")
    for i,v in ls {
        ; Remove any carriage return characters
        v := Trim(v, "`r")

            isHeader := RegExMatch(v,"\[(.*)]")
            if (v && readingPoint && !isHeader){
                RegExMatch(v,"(.*)(?==)",index)
                RegExMatch(v,"(?<==)(.*)",value)
                if (index){
                    retrievedData[index] := value
                }
            } else if (isHeader){
                readingPoint := 1
            }
        }
    return retrievedData
}
loadData(){
    global

    savedRetrieve := getINIData(configPath)
    if (!savedRetrieve){
        MsgBox, % "Unable to retrieve config data, your settings have been set to their defaults."
        savedRetrieve := {}
    }

    local newOptions := {}
    for i, v in options { ; Iterating through defined options does not load dynamic settings - currently aura, biomes
        if (savedRetrieve.HasKey(i)) {
            newOptions[i] := savedRetrieve[i]

            ; Temporary code to fix time error
            for _, key in ["LastCraftSession","LastInvScreenshot","LastPotionAutoAdd"] {
                if (i = key && savedRetrieve[i] > getUnixTime()) {
                    ; logMessage("Resetting " i)
                    ; Reset value so it's not too high to trigger
                    newOptions[i] := 0
                }
            }
        } else {
            newOptions[i] := v
        }
    }
    options := newOptions
}

handleWebhookEnableToggle(){ ; Taken from dolphSol
    Gui main:Default
    GuiControlGet, rValue,,WebhookEnabled

    if (rValue){
        GuiControlGet, link,,WebhookURL
        if (!validateWebhookLink(link)){
            GuiControl, , WebhookEnabled,0
            MsgBox,0,Webhook Link Invalid, % "Invalid webhook link, the webhook option has been disabled."
        }
    }
}

writeToINI(path,object,header){ ; Taken from dolphSol
    ; if (!FileExist(path)){
    ;     MsgBox, You are missing the file: %path%, please ensure that it is in the correct location.
    ;     return
    ; }

    formatted := header

    for i,v in object {
        formatted .= i . "=" . v . "`r`n"
    }

    if (FileExist(path)) {
        FileDelete, %path%
    }
    FileAppend, %formatted%, %path%
}

getUnixTime() {
    now := A_NowUTC
    EnvSub, now, 1970, seconds
    return now
}

applyNewUIOptions(){
    global hGui
    Gui main:Default

    VarSetCapacity(wp, 44), NumPut(44, wp)
    DllCall("GetWindowPlacement", "uint", hGUI, "uint", &wp)
	x := NumGet(wp, 28, "int"), y := NumGet(wp, 32, "int")

    options.WindowX := x
    options.WindowY := y

    for i,v in directValues {
        GuiControlGet, rValue,,%i%
        options[v] := rValue
    }

    GuiControlGet, webhookLink,,WebhookInput
    if (webhookLink){
        valid := validateWebhookLink(webhookLink)
        if (valid){
            options.WebhookLink := webhookLink
        } else {
            if (options.WebhookLink){
                MsgBox,0,New Webhook Link Invalid, % "Invalid webhook link, the link has been reverted to your previous valid one."
            } else {
                MsgBox,0,Webhook Link Invalid, % "Invalid webhook link, the webhook option has been disabled."
                options.WebhookEnabled := 0
            }
        }
    }
}

createMainGUI() {
    global
    Gui main: New
    Gui Font, s10 Norm, Segoe UI
    Gui Add, Button, vStartButton gHandleStart x8 y192 w120 h25 -Tabstop, F1 - Start/Stop
    Gui Add, Tab3, vMainTabs x8 y8 w390 h180, Main|Webhook|Credits

    ; Main tab
    Gui Tab, 1
    Gui Font, s10 w600
    Gui Add, GroupBox, x16 y40 w200 h70, Auto Fish
    Gui Font, s9 norm
    Gui Add, Checkbox, x25 y60 vEnableAutoFish, Enable Auto Fish
    Gui Add, Button, gCalibration vCalibrationButton x25 y82 w130 h22, % "Auto Fish Calibration"

    Gui Font, s10 w600
    Gui Add, GroupBox, x232 y40 w150 h140, Fish Detection
    Gui Font, s9 norm
    Gui Add, Text, y65 x250 vMessageMinHeader, % "Send Minimum (kg)"
    Gui Add, Edit, vMessageMin x250 y85 w120 h18
    Gui Add, UpDown, vMessageMin2 Range1-1000 x370 y85
    Gui Add, Text, y112 x250 vPingMinHeader, % "Ping Minimum (kg)"
    Gui Add, Edit, vPingMin x250 y132 w120 h18
    Gui Add, UpDown, vPingMin2 Range1-1000 x370 y132
    Gui Add, Button, gSendPingHelp vSendPingHelpButton w23 h23 y156 x358, % "?"

    Gui Font, s10 w600
    Gui Add, GroupBox, y115 x16 w200 h65, Other
    Gui Font, s7 norm
    Gui Add, CheckBox, vScreenshotsEnabled x25 y135, % "Inv screenshots every"
    Gui Add, Edit, vScreenshotInterval x135 y135 w40 h14
    Gui Add, UpDown, vScreenshotInterval2 Range1-240 x160 y135
    Gui Add, Text, vScreenshotIntervalHeader x180 y135, % "mins"

    Gui Add, CheckBox, vEventsEnabled x25 y158, % "Send All Events"
    ; Webhook Tab
    Gui Tab, 2
    Gui Font, s10 w600
    Gui Add, GroupBox, x16 y40 w370 h140, Webhook Options
    Gui Font, s9 norm
    Gui Add, Checkbox, x25 y65 vWebhookEnabled gEnableWebhookToggle, Webhook Enabled
    Gui Add, Text, vWebhookHeader x25 y92, Discord Webhook URL
    Gui Add, Edit, x25 y107 w280 h20 vWebhookUrl
    Gui Add, Text, vUserIDHeader x25 y135, % "Discord User ID"
    Gui Add, Edit, x25 y152 w280 h20 vUserID



    Gui Show, w400 h225, boredFisch Macro v0.0
    updateUIOptions()
}

calibrationGUI() {
    global
    Gui calibration: new

    Gui Font, s9 norm
    Gui Add, Text, x16 y16 w184 h20, % "Calibration for auto fishing so pro"
    Gui Add, Edit, vAFMiddle x16 y45 w60 h20
    Gui Add, UpDown, vAFMiddle2 Range1-2000 x60 y45
    Gui Add, Text, x90 y45, % "Fishing bar Y coord"

    Gui Add, Edit, vAFLeft x16 y72 w60 h20
    Gui Add, UpDown, vAFleft2 Range1-2000 x60 y72
    Gui Add, Text, x90 y72, % "X coord left"

    Gui Add, Edit, vAFRight x16 y100 w60 h20
    Gui Add, UpDown, vAFRight2 Range1-2000 x60 y100
    Gui Add, Text, x90 y100, % "X coord Right"

    Gui Add, Button, vSaveCalibration gSaveCalButton x40 y135 w120 h25, % "Save Calibration"
    Gui Add, Button, vHighlightCalibration gHighlightCal x40 y165 w120 h25, % "Highlight Calibration"
    Gui Add, Button, vCalHelp gHelpCalButton x65 y196 w70 h25, % "Help!"

    Gui Show, w200 h225, Auto Fish Calibration
    updateUIOptions()
}

CalHighlight() {
    Highlight(options.AFLeft-3, options.AFMiddle-3, 6, 6)
    Highlight(options.AFRight-3, options.AFMiddle-3, 6, 6)
}

saveAFCal() {
    GuiControlGet, middle,, AfMiddle
    GuiControlGet, left,, AFLeft
    GuiCOntrolGet, right,, AFRight
    options.AFMiddle := middle
    options.AFLeft := left
    options.AFRight := right
    saveOptions()
}

getRobloxPos(ByRef x := "", ByRef y := "", ByRef width := "", ByRef height := "", hwnd := ""){
    if !hwnd
        hwnd := GetRobloxHWND()
    VarSetCapacity( buf, 16, 0 )
    DllCall( "GetClientRect" , "UPtr", hwnd, "ptr", &buf)
    DllCall( "ClientToScreen" , "UPtr", hwnd, "ptr", &buf)

    x := NumGet(&buf,0,"Int")
    y := NumGet(&buf,4,"Int")
    width := NumGet(&buf,8,"Int")
    height := NumGet(&buf,12,"Int")
}

; used from natro
GetRobloxHWND(){
	if (hwnd := WinExist("Roblox ahk_exe RobloxPlayerBeta.exe")) {
		return hwnd
	} else if (WinExist("Roblox ahk_exe ApplicationFrameHost.exe")) {
		ControlGet, hwnd, Hwnd, , ApplicationFrameInputSinkWindow1
		return hwnd
	} else {
        Sleep, 5000
		return 0
    }
}

; Check if area contains the specified text
containsText(x, y, width, height, text) {
    ; Potential improvement by ignoring non-alphanumeric characters
    ; Highlight(x-10, y-10, width+20, height+20, 2000)

    try {
        pbm := Gdip_BitmapFromScreen(x "|" y "|" width "|" height)
        pbm := Gdip_ResizeBitmap(pbm,500,500,true)
        ocrText := ocrFromBitmap(pbm)
        Gdip_DisposeBitmap(pbm)

        if (!ocrText) {
            return false
        }
        ocrText := RegExReplace(ocrText,"(\n|\r)+"," ")
        StringLower, ocrText, ocrText
        StringLower, text, text
        textFound := InStr(ocrText, text)

        if (textFound > 0) { ; Reduce logging by only saving when found
        }

        return textFound > 0
    } catch e {
        return -1
    }
}


; V auto fishing 861 594

global ismousedown := 0
global fishloops := 0

mouseDown() {
    Click, Down
    ismousedown := 1
}

mouseUp() {
    Click, Up
    ismousedown := 0
}

searchForShake(startX, startY, endX, endY) {
    segmentSideLength := 150  ; Width of each segment to check

    ; Calculate the number of segments in both x and y directions
    xSegments := (endX - startX) // (segmentSideLength/1.5)-1
    ySegments := (endY - startY) // (segmentSideLength/1.5)-1

    ; Loop through each segment in the x-direction
    Loop, %xSegments% {
        xStart := startX + A_Index * (segmentSideLength/1.5)  ; Calculate the starting X coordinate for each

        ; Loop through each segment in the y-direction
        Loop, %ySegments% {
            yStart := startY + A_Index * (segmentSideLength/1.5)  ; Calculate the starting Y coordinate for each segment

            ; Check if "shake" is found in the current

            if containsText(xStart, yStart, segmentSideLength, segmentSideLength, "s") {
                centerX := xStart + (segmentSideLength // 2)
                centerY := yStart + (segmentSideLength // 2)
                Click, %centerX%, %centerY%
                return true
            }
        }
    }

    ; If "shake" was not found in any segment
    return false
}

ZoomIn() {
    Loop, 15
    {
        SendInput {WheelUp}
		sleep, 150
    }
    Loop, 5
    {
        SendInput {WheelDown}
		sleep, 150
	}
}

cast() {
	ZoomIn()
    SendInput {Click, Down}

    screenCenterX := 960
    screenCenterY := 540
    IfWinExist, %robloxWindowTitle%
    {
        WinGetPos, winX, winY, winWidth, winHeight, %robloxWindowTitle%

        screenCenterX := winX + (winWidth // 2)
        screenCenterY := winY + (winHeight // 2)
    } else {
        screenCenterX := A_ScreenWidth // 2
        screenCenterY := A_ScreenHeight // 2
    }


    Xcoord1 := Floor(screenCenterX + (330/1920)*screenCenterX*2)
    Xcoord2 := Floor(screenCenterX + (340/1920)*screenCenterX*2)
    Xcoord3 := Floor(screenCenterX + (435/1920)*screenCenterX*2)
    Ycoord1 := Floor(screenCenterY + (260/1080)*screenCenterY*2)
    Ycoord2 := Floor(screenCenterY - (185/1080)*screenCenterY*2)
    Ycoord3 := FLoor(screenCenterY - (225/1080)*screenCenterY*2)

    if (CheckPixelLine(0xE0E0E0, Xcoord2, Ycoord2, Xcoord3, Ycoord3, 30, 10000)) {
        SendInput {Click, Up}
        sleep, 50
        return 1
    } else if (WaitPixelColor(0xE0E0E0, Xcoord3, Ycoord3, 10000, 30)) {
        SendInput {Click, Up}
        sleep, 50
        return 1
    } else {
        return 0
    }
}

WaitPixelColor(p_DesiredColor, p_PosX, p_PosY, p_TimeOut=0, p_ColorVariation=0) {
    SplitRGBColor(p_DesiredColor, red1, green1, blue1)
    redvar1 := red1 - p_ColorVariation
    redvar2 := red1 + p_ColorVariation
    greenvar1 := green1 - p_ColorVariation
    greenvar2 := green1 + p_ColorVariation
    bluevar1 := blue1 - p_ColorVariation
    bluevar2 := blue1 + p_ColorVariation

    l_Start := A_TickCount
    Loop {
        PixelGetColor, l_OutputColor, %p_PosX%, %p_PosY%, RGB
        SplitRGBColor(l_OutputColor, red2, green2, blue2)
        If (ErrorLevel)
            Return false
        If (redvar1 <= red2 && red2 <= redvar2)
            If (greenvar1 <= green2 && green2 <= greenvar2)
                If (bluevar1 <= blue2 && blue2 <= bluevar2)
                    return true
        If (p_TimeOut) && (A_TickCount - l_Start >= p_TimeOut)
            Return false
    }
}

CheckPixelColor(p_DesiredColor, p_PosX, p_PosY, p_ColorVariation := 0) {
    SplitRGBColor(p_DesiredColor, red1, green1, blue1)

    redvar1 := red1 - p_ColorVariation
    redvar2 := red1 + p_ColorVariation
    greenvar1 := green1 - p_ColorVariation
    greenvar2 := green1 + p_ColorVariation
    bluevar1 := blue1 - p_ColorVariation
    bluevar2 := blue1 + p_ColorVariation

    PixelGetColor, l_OutputColor, %p_PosX%, %p_PosY%, RGB
    If (ErrorLevel) {
        return false
    }

    SplitRGBColor(l_OutputColor, red2, green2, blue2)

    If (redvar1 <= red2 && red2 <= redvar2)
        If (greenvar1 <= green2 && green2 <= greenvar2)
            If (bluevar1 <= blue2 && blue2 <= bluevar2)
                return true

    return false
}

CheckPixelLine(ColorToCheck, x1, y1, x2, y2, Variation := 0, p_Timeout := 0) {
     ; Calculate the difference between the points
    dx := Abs(x2 - x1)
    dy := Abs(y2 - y1)
    steps := Max(dx, dy)  ; Total number of pixels to check
    ; Calculate the increments for x and y
    xIncrement := (x2 - x1) / steps
    yIncrement := (y2 - y1) / steps

    steps := Ceil(steps / 3)
    l_Start := A_TickCount
    ; Loop through each step to get the color along the diagonal
    Loop {
        Loop, %steps% {
            If (p_TimeOut) && (A_TickCount - l_Start >= p_TimeOut) {
                return 0
            }

            x := Round(x1 + (A_Index*3) * xIncrement)
            y := Round(y1 + (A_Index*3) * yIncrement)
            if (CheckPixelColor(ColorToCheck, x, y, Variation)) {
                return 1
            }
        }
    }
}


SplitRGBColor(RGBColor, ByRef Red, ByRef Green, ByRef Blue)
{
    Red := RGBColor >> 16 & 255
    Green := RGBColor >> 8 & 255
    Blue := RGBColor & 255
}

CreateGrayscaleArray(startX, startY, endX) {
    grayscaleArray := []

    steps := (endX-startX)//5
    Loop, %steps%
    {
        PixelGetColor, color, % (startX + A_Index * 5), startY, RGB

        R := (color >> 16) & 0xFF
        G := (color >> 8) & 0xFF
        B := color & 0xFF

        grayValue := 0.299 * R + 0.587 * G + 0.114 * B

        grayValue := grayValue / 255

        grayscaleArray.push(grayValue)
    }

    return grayscaleArray
}

GrayScaleArrayToClick(array) {

}
;searchForShake(370, 100, 1600, 900)

handleAutoFish() {
    getRobloxPos(x,y,w,h)

    screenCenterX := 960
    screenCenterY := 540
    IfWinExist, %robloxWindowTitle%
    {
        WinGetPos, winX, winY, winWidth, winHeight, %robloxWindowTitle%

        screenCenterX := winX + (winWidth // 2)
        screenCenterY := winY + (winHeight // 2)
    } else {
        screenCenterX := A_ScreenWidth // 2
        screenCenterY := A_ScreenHeight // 2
    }

    minigamestarted := 0
    cast()
    fished := 0
    Loop {
        test := screenCenterX+20

        if (CheckPixelColor(0xFFFFFF, test, options.AFMiddle, 10)) {
            fished := 1
            loop {
                bar = CreateGrayscaleArray(options.AFLeft, options.AFMiddle, options.AFRight)
            }
        } else if (!fished) {

        } else {
            break
        }
        global fishpos
        PixelSearch, fishpos,, options.AFLeft,  options.AFMiddle, options.AFRight, options.AFMiddle, 0x5B4A43,1, Fast

    }
}

handleScreenshot() {
    getRobloxPos(x,y,w,h)
    SendRaw, g
    MouseMove % w*0.5, h*0.8
    Loop, 50 {
        Send {WheelDown}
    }
}

global directValues := {"WebhookEnabled":"WebhookOn"
    ,"WebhookURL":"WebhookURL"
    ,"UserID":"UserID"
    ,"EnableAutoFish":"AutoFishEnabled"
    ,"MessageMin":"MsgMin"
    ,"PingMin":"PingMin"
    ,"AFLeft":"AFLeft"
    ,"AFMiddle":"AFMiddle"
    ,"AFRight":"AFRight"
    ,"ScreenshotsEnabled":"ScreenshotsOn"
    ,"ScreenshotInterval":"ScreenshotInterval"
    ,"EventsEnabled":"SendEvents"}

updateUIOptions(){ ; Taken from dolphSol
    for i,v in directValues {
        GuiControl,,%i%,% options[v]
    }
}
;515, 915 fish bar location left
; fish bar x pos right: 1350
; fish color 434b5b
saveOptions(){ ; Taken from dolphSol
    global configPath,configHeader
    writeToINI(configPath,options,configHeader)
}

createMainGUI()
/*
WaitPixelColor(p_DesiredColor, p_PosX, p_PosY, p_TimeOut=0, p_ColorVariation=0) {
    SplitRGBColor(p_DesiredColor, red1, green1, blue1)
    redvar1 := red1 - p_ColorVariation
    redvar2 := red1 + p_ColorVariation
    greenvar1 := green1 - p_ColorVariation
    greenvar2 := green1 + p_ColorVariation
    bluevar1 := blue1 - p_ColorVariation
    bluevar2 := blue1 + p_ColorVariation

    l_Start := A_TickCount
    Loop {
        PixelGetColor, l_OutputColor, %p_PosX%, %p_PosY%, RGB
        SplitRGBColor(l_OutputColor, red2, green2, blue2)
        If (ErrorLevel)
            Return false
        If (redvar1 <= red2 && red2 <= redvar2)
            If (greenvar1 <= green2 && green2 <= greenvar2)
                If (bluevar1 <= blue2 && blue2 <= bluevar2)
                    return true
        If (p_TimeOut) && (A_TickCount - l_Start >= p_TimeOut)
            Return false
    }
}

CheckPixelColor(p_DesiredColor, p_PosX, p_PosY, p_ColorVariation := 0) {
    SplitRGBColor(p_DesiredColor, red1, green1, blue1)

    redvar1 := red1 - p_ColorVariation
    redvar2 := red1 + p_ColorVariation
    greenvar1 := green1 - p_ColorVariation
    greenvar2 := green1 + p_ColorVariation
    bluevar1 := blue1 - p_ColorVariation
    bluevar2 := blue1 + p_ColorVariation

    PixelGetColor, l_OutputColor, %p_PosX%, %p_PosY%, RGB
    If (ErrorLevel) {
        return false
    }

    SplitRGBColor(l_OutputColor, red2, green2, blue2)

    If (redvar1 <= red2 && red2 <= redvar2)
        If (greenvar1 <= green2 && green2 <= greenvar2)
            If (bluevar1 <= blue2 && blue2 <= bluevar2)
                return true

    return false
}


SplitRGBColor(RGBColor, ByRef Red, ByRef Green, ByRef Blue)
{
    Red := RGBColor >> 16 & 255
    Green := RGBColor >> 8 & 255
    Blue := RGBColor & 255
} thanks e ipi
ZoomIn() {
    Loop, 15
    {
        SendInput {WheelUp}
        sleep, 150
    }
    Loop, 5
    {
        SendInput {WheelDown}
        sleep, 150
    }
}
*/
; Help Buttons

EnableWebhookToggle: ; Taken from dolphSol
    handleWebhookEnableToggle()
    return
SendPingHelp:
    MsgBox, % "Send Minimum `n`n All fish that are over the weight you `n entered will be sent through the webhook`n`nPing Minimum`n`n Same thing but it will ping you aswell"
    return
mainLoop() {
    Loop, {
        handleAutoFish()
    }
}
start() {
    applyNewUIOptions()
    saveOptions()
    return
}

HandleStart:
    start()
    return
Calibration:
    calibrationGUI()
    return
HelpCalButton:
    return
SaveCalButton:
    saveAFCal()
    return
HighlightCal:
    CalHighlight()
    return
F1::
    handleAutoFish()
F2::ExitApp
F3::
    handleScreenshot()