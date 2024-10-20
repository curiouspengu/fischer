/*
Made by b0red_man
Project started on 10/11/2024

Alot of this code has been taken from dolphSol Macro
*/

#Requires AutoHotkey v1.1
#NoEnv
#SingleInstance, force

SetWorkingDir, % A_ScriptDir "\lib"
CoordMode, Pixel, Screen
CoordMode, Mouse, Screen

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

webhookPost(data := 0){
    data := data ? data : {}

    url := options.webhookLink

    if (data.pings){
        data.content := data.content ? data.content " <@" options.DiscordUserID ">" : "<@" options.DiscordUserID ">"
    }

    payload_json := "
		(LTrim Join
		{
			""content"": """ data.content """,
			""embeds"": [{
                " (data.embedAuthor ? """author"": {""name"": """ data.embedAuthor """" (data.embedAuthorImage ? ",""icon_url"": """ data.embedAuthorImage """" : "") "}," : "") "
                " (data.embedTitle ? """title"": """ data.embedTitle """," : "") "
				""description"": """ data.embedContent """,
                " (data.embedThumbnail ? """thumbnail"": {""url"": """ data.embedThumbnail """}," : "") "
                " (data.embedImage ? """image"": {""url"": """ data.embedImage """}," : "") "
                " (data.embedFooter ? """footer"": {""text"": """ data.embedFooter """}," : "") "
				""color"": """ (data.embedColor ? data.embedColor : 0) """
			}]
		}
		)"

    if ((!data.embedContent && !data.embedTitle) || data.noEmbed)
        payload_json := RegExReplace(payload_json, ",.*""embeds.*}]", "")


    objParam := {payload_json: payload_json}

    for i,v in (data.files ? data.files : []) {
        objParam["file" i] := [v]
    }

    try {
        CreateFormData(postdata, hdr_ContentType, objParam)

        WebRequest := ComObjCreate("WinHttp.WinHttpRequest.5.1")
        WebRequest.Open("POST", url, true)
        WebRequest.SetRequestHeader("User-Agent", "Mozilla/5.0 (Windows NT 6.1; WOW64; Trident/7.0; rv:11.0) like Gecko")
        WebRequest.SetRequestHeader("Content-Type", hdr_ContentType)
        WebRequest.SetRequestHeader("Pragma", "no-cache")
        WebRequest.SetRequestHeader("Cache-Control", "no-cache, no-store")
        WebRequest.SetRequestHeader("If-Modified-Since", "Sat, 1 Jan 2000 00:00:00 GMT")
        WebRequest.Send(postdata)
        WebRequest.WaitForResponse()
    } catch e {
        ; MsgBox, 0, Webhook Error, % "An error occurred while creating the webhook data: " e
        return
    }
}

CreateFormData(ByRef retData, ByRef retHeader, objParam) {
	New CreateFormData(retData, retHeader, objParam)
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
    Gui Add, UpDown, vAFMiddleUpDown Range1-2000 x60 y45
    Gui Add, Text, x90 y45, % "Fishing bar Y coord"

     /*
    Gui Add, Edit, vAFLeft x16 y72 w60 h20
    Gui Add, UpDown, vAFleftUpDown Range1-2000 x60 y72
    Gui Add, Text, x90 y72, % "X coord left"

    Gui Add, Edit, vAFRight x16 y100 w60 h20
    Gui Add, UpDown, vAFRightUpDown Range1-2000 x60 y100
    Gui Add, Text, x90 y100, % "X coord Right"
    */

    Gui Add, Button, vSaveCalibration gSaveCalButton x15 y85 w175 h25, % "Save Calibration"
    Gui Add, Button, vHighlightCalibration gHighlightCal x15 y115 w175 h25, % "Highlight Calibration"
    Gui Add, Button, vCalHelp gHelpCalButton x15 y146 w75 h25, % "Help!"
    Gui Add, Button, vSelectPos gSelectAutoFishPos x100 y146 w90 h25, % "Select Pos"

    Gui Show, , Auto Fish Calibration
    updateUIOptions()
}

CalculateFishingBounds(ByRef xL := "", ByRef xR := "") {
    getRobloxPos(rX, rY, rW, rH)

    xL := Floor(rX+rW*0.25)
    xR := Floor(rX+rW*0.75)
}
CalHighlight() {
    CalculateFishingBounds(AFLeft, AFRight)
    Highlight(AFLeft-3, options.AFMiddle-3, 6, 6)
    Highlight(AFRight-3, options.AFMiddle-3, 6, 6)
}

SelectAutoFishPos() {

    global options

    ToolTip, Move your mouse to the center of the fishing bar and press Q
    KeyWait, Q, D
    MouseGetPos, , yValue
    ToolTip

    GuiControl,, AFMiddle, %yValue%

    saveAFCal()
}
saveAFCal() {
    GuiControlGet, middle,, AfMiddle
    options.AFMiddle := middle
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

getText(ByRef OutputVar := "",x:="",y:="",w:="",h:="") {
    pbm := Gdip_BitmapFromScreen(x "|" y "|" w "|" h)
    pbm := Gdip_ResizeBitmap(pbm,500,500,true)
    OutputVar := ocrFromBitmap(pbm)
    Gdip_DisposeBitmap(pbm)
}

detectFish() {
    getRobloxPos(x,y,w,h)
    getText(fishtext, w*0.33, h*0.67, (w*0.67)-(w*0.33),(h*0.79)-(h*0.67))
    Highlight(w*0.33, h*0.79, (w*0.67)-(w*0.33),(h*0.79)-(h*0.67))
    fishweight := RegExReplace(fishtext, "\D")
    if (fishweight && fishweight/10 >= options.MsgMin) {

    }
}

getNum(text) {

}

; V auto fishing 861 594

global isMouseDown := 0
global fishloops := 0

mouseDown() {
    SendInput {Click, Down}
    isMouseDown := 1
}

mouseUp() {
    SendInput {Click, Up}
    isMouseDown := 0
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

    getRobloxPos(rX, rY, rW, rH)

    MouseMove, rX + rW*0.75, rY + 44 + rH*0.05
    Sleep, 200
    MouseClick
    Sleep, 200

    MouseClickDrag, R, rX + rW*0.75, rY + 44 + rH*0.05, rX + rW*0.75, rY + 444 + rH*0.05

}

cast() {
	ZoomIn()
    SendInput {Click, Down}

    getRobloxPos(winX, winY, winWidth, winHeight)

    screenCenterX := winX + (winWidth // 2)
    screenCenterY := winY + (winHeight // 2)

    Xcoord1 := Floor(screenCenterX + (200/1920)*screenCenterX*2)
    Xcoord2 := Floor(screenCenterX + (500/1920)*screenCenterX*2)
    Ycoord := Floor(screenCenterY - (185/1080)*screenCenterY*2)

    Sleep, 500

    if (CheckPixelLine(0xE0E0E0, Xcoord1, Ycoord, Xcoord2, Ycoord, 30, 10000)) {
        SendInput {Click, Up}
        sleep, 50
        return 1
    } else {
        SendInput {Click, Up}
        sleep, 50
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

    if (y1 != y2) {
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
    } else {
        l_Start := A_TickCount

        Loop {
            If (p_TimeOut) && (A_TickCount - l_Start >= p_TimeOut) {
                return 0
            }

            PixelSearch, colorCheck,, x1, y1, x2, y1, ColorToCheck, Variation, Fast

            if (colorCheck) {
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

ReAlignCamera() {
    rotateCameraMode()
    Sleep, 1500
    rotateCameraMode()
}

global camFollowMode := 0

rotateCameraMode(){
    ; Initialize retry counter

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

    Xcoord := Floor(screenCenterX + (65/1920)*screenCenterX*2)
    Ycoord := Floor(screenCenterY - (237/1920)*screenCenterX*2)
    Width := Floor((190/1920) * screenCenterX*2)
    Height := Floor((70/1920) * screenCenterY*2)

    YMove := Floor(Ycoord+(Height/2))

    static retryCount := 0
    maxRetries := 5 ; Set the maximum number of retries

    ; Update to the new camera mode
    camFollowMode := !camFollowMode
    mode := camFollowMode ? "Follow" : "Default"

    SendInput {Esc}
    Sleep, 300
    SendInput {Tab}
    Sleep, 500
    MouseMove, Xcoord, YMove
    Sleep, 300
    SendInput {Right}
    Sleep, 150
    SendInput {Right}
    Sleep, 150

    ; If enabled, use OCR to confirm the camera mode change

    while !(containsText(Xcoord, Ycoord, Width, Height, mode)) {

        if (retryCount >= maxRetries) {
            camFollowMode := !camFollowMode ; Reset to previous state
            retryCount := 0 ; Reset retry counter for the next call
            return
        }

        SendInput {Right}
        Sleep, 300

        retryCount++
    }
    MouseMove, 0, screenCenterY
    SendInput {Esc}
    Sleep, 250

    ; Reset retry counter after successful execution
    retryCount := 0
}

Initialize() {
    Sleep, 200
    SendInput {\}
    SendInput {Right}
    SendInput {Right}
    SendInput {Right}
    Sleep, 50
    SendInput {Enter}
    Sleep, 200
    SendInput {Click}
}


handleAutoFish() {
    getRobloxPos(x, y, w, h)
    CalculateFishingBounds(AFLeft, AFRight)
    global minigameStarted := 0, minigameCompletion := 0, failureTick := 0, shaking := 0
    global isMouseDown := 0, timeHeld := 0
    global sliderLengthCalculated := 0, sliderLength := 0, arrowPos := 0 sliderCenterPos := 0

    cast()

    Loop {
        PixelSearch, fishPos,, AFLeft, options.AFMiddle, AFRight, options.AFMiddle, 0x5B4A43, 1, Fast
        if (fishPos) {
            if (shaking) {
                SendInput {\}
                shaking := 0
            }

            if (!sliderLengthCalculated) {
                ; Detect slider length
                PixelSearch, arrowPosLeft,, AFLeft, options.AFMiddle, AFRight, options.AFMiddle, 0x878584, 1, Fast
                SendInput {Click, Down}
                Sleep, 250
                PixelSearch, arrowPosRight,, AFLeft, options.AFMiddle, AFRight, options.AFMiddle, 0x878584, 1, Fast
                SendInput {Click, Up}

                sliderLength := arrowPosRight - arrowPosLeft
                sliderLengthCalculated := 1
            }

            minigameStarted := 1

            PixelSearch, arrowPos,, AFLeft, options.AFMiddle, AFRight, options.AFMiddle, 0x878584, 1, Fast


            if (isMouseDown) {
                sliderCenterPos := Floor(arrowPos - (sliderLength/2.1))
            } else {
                sliderCenterPos := Floor(arrowPos + (sliderLength/2.1))
            }

            if (arrowPos) {
                if (moveStep != 0) {
                    if (!isMouseDown) {
                        mouseDown()
                        if (sliderCenterPos-fishPos < 0) {
                            time := Floor((Log(Abs(sliderCenterPos-fishPos)/A_ScreenWidth*1920))**6)
                            Sleep, time
                        }
                    } else if (isMouseDown) {
                        mouseUp()
                        if (sliderCenterPos-fishPos > 0) {
                            time := Floor((Log(Abs(sliderCenterPos-fishPos)/A_ScreenWidth*1920))**6)
                            Sleep, time
                        }
                    }
                }
            } else {
                Sleep, 15
            }
        } else {
            if (minigameStarted) {
                PixelSearch, fishPos,, AFLeft, options.AFMiddle, AFRight, options.AFMiddle, 0x5B4A43, 3, Fast
                if !(fishPos) {
                    failureTick += 1
                    if (failureTick > 10) {
                        minigameCompletion := 1
                        minigameStarted := 0
                    }
                }
            } else {
                if (!shaking) {
                    SendInput {\}
                    shaking := 1
                } else {
                    SendInput {Down}
                    SendInput {Enter}
                }
            }
        }

        ; Break the loop after 75 seconds or upon minigame completion
        if ((A_TickCount - l_Start >= 75000 && !minigameStarted) || minigameCompletion) {
            Sleep, 1000
            SendInput {Click}
            shaking := 1
            break
        }
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

; Help Buttons

EnableWebhookToggle: ; Taken from dolphSol
    handleWebhookEnableToggle()
    return
SendPingHelp:
    MsgBox, % "Send Minimum `n`n All fish that are over the weight you `n entered will be sent through the webhook`n`nPing Minimum`n`n Same thing but it will ping you aswell"
    return
mainLoop() {
    Initialize()
    Loop, {
        handleAutoFish()
    }
}
start() {
    applyNewUIOptions()
    saveOptions()
    return
}

PrepLeave() {
    Initialize()
    ExitApp
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
F1::mainLoop()
F2::PrepLeave()
F3::handleScreenshot()
F4::detectFish()
