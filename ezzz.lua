require( "rocx" )

local PANEL = {}

local math_Clamp                        = math.Clamp

local scrw                              = ScrW()
local scrh                              = ScrH()
local scrwc                             = scrw / 2
local scrhc                             = scrh / 2

PANEL.URL = "http://metastruct.github.io/lua_editor/"
PANEL.COMPILE = "C"

local javascript_escape_replacements =
{
	["\\"] = "\\\\",
	["\0"] = "\\0" ,
	["\b"] = "\\b" ,
	["\t"] = "\\t" ,
	["\n"] = "\\n" ,
	["\v"] = "\\v" ,
	["\f"] = "\\f" ,
	["\r"] = "\\r" ,
	["\""] = "\\\"",
	["\'"] = "\\\'",
}

function PANEL:Init()
	self.Code = ""

	self.ErrorPanel = self:Add("DButton")
	self.ErrorPanel:SetFont('BudgetLabel')
	self.ErrorPanel:SetTextColor(Color(0,0,0))
	self.ErrorPanel:SetText("")
	self.ErrorPanel:SetTall(0)
	self.ErrorPanel.DoClick = function()
		self:GotoErrorLine()
	end
	self.ErrorPanel.DoRightClick = function(self)
		SetClipboardText(self:GetText())
	end
	self.ErrorPanel.Paint = function(self,w,h)
		surface.SetDrawColor(255,50,50)
		surface.DrawRect(0,0,w,h)
	end

	self:StartHTML()
end

function PANEL:Think()
	if self.NextValidate && self.NextValidate < CurTime() then
		self:ValidateCode()
	end
end

function PANEL:StartHTML()
	self.HTML = self:Add("DHTML")

	self:AddJavascriptCallback("OnCode")
	self:AddJavascriptCallback("OnLog")

	self.HTML:OpenURL(self.URL)
	
	self.HTML:RequestFocus()
end

function PANEL:ReloadHTML()
	self.HTML:OpenURL(self.URL)
end

function PANEL:JavascriptSafe(str)
	str = str:gsub(".",javascript_escape_replacements)
	str = str:gsub("\226\128\168","\\\226\128\168")
	str = str:gsub("\226\128\169","\\\226\128\169")
	return str
end

function PANEL:CallJS(JS)
	self.HTML:Call(JS)
end

function PANEL:AddJavascriptCallback(name)
	local func = self[name]

	self.HTML:AddFunction("gmodinterface",name,function(...)
		func(self,HTML,...)
	end)
end

function PANEL:OnCode(_,code)
	self.NextValidate = CurTime() + 0.2
	self.Code = code
end

function PANEL:OnLog(_,...)
	Msg("Editor: ")
	print(...)
end

function PANEL:SetCode(code)
	self.Code = code
	self:CallJS('SetContent("' .. self:JavascriptSafe(code) .. '");')
end

function PANEL:GetCode()
    return self.Code
end

function PANEL:SetGutterError(errline,errstr)
	self:CallJS("SetErr('" .. errline .. "','" .. self:JavascriptSafe(errstr) .. "')")
end

function PANEL:GotoLine(num)
	self:CallJS("GotoLine('" .. num .. "')")
end

function PANEL:ClearGutter()
	self:CallJS("ClearErr()")
end

function PANEL:GotoErrorLine()
	self:GotoLine(self.ErrorLine || 1)
end

function PANEL:SetError(err)
	if !IsValid(self.HTML) then
		self.ErrorPanel:SetText("")
		self:ClearGutter()
		return
	end

	local tall = 0 

	if err then
		local line,err = string.match(err,self.COMPILE .. ":(%d*):(.+)")

		if line && err then
			tall = 20

			self.ErrorPanel:SetText((line && err) && ("Line " .. line .. ": " .. err) || err || "")
			self.ErrorLine = tonumber(string.match(err," at line (%d)%)") || line) || 1
			self:SetGutterError(self.ErrorLine,err)
		end
	else
		self.ErrorPanel:SetText("")
		self:ClearGutter()
	end

	local wide = self:GetWide()
	local tallm = self:GetTall()

	self.ErrorPanel:SetPos(0,tallm - tall)
	self.ErrorPanel:SetSize(wide,tall)
	self.HTML:SetSize(wide,tallm - tall)
end

function PANEL:ValidateCode() 
	local time = SysTime()
	local code = self:GetCode()

	self.NextValidate = nil

	if !code || code == "" then
		self:SetError()
		return
	end

	local errormsg = CompileString(code,self.COMPILE,false)
	time = SysTime() - time

	if type(errormsg) == "string" then
		self:SetError(errormsg)
	elseif time > 0.25 then
		self:SetError("Compiling took too long. (" .. math.Round(time * 1000) .. ")")
	else
		self:SetError()
	end
end

function PANEL:PerformLayout(w,h)
	local tall = self.ErrorPanel:GetTall()

	self.ErrorPanel:SetPos(0,h - tall)
	self.ErrorPanel:SetSize(w,tall)

	self.HTML:SetSize(w,h - tall)
end

vgui.Register( "CodeEditor", PANEL, "EditablePanel" )

// CODE START
local surface = surface 

local surface_SetDrawColor 		= surface.SetDrawColor
local surface_DrawRect 			= surface.DrawRect
local surface_DrawOutlinedRect 	= surface.DrawOutlinedRect


local pal = { { 40, 40, 40 }, { 60, 56, 54 }, { 146, 131, 116 }, { 204, 36, 29 }, { 251, 73, 52 }, { 152, 151, 26 }, { 184, 187, 38 }, { 215, 153, 33 }, { 250, 189, 47 }, { 69, 133, 136 }, { 131, 165, 152 }, { 177, 98, 134 }, { 211, 134, 155 }, { 104, 157, 106 }, { 142, 192, 124 }, { 168, 153, 132 }, { 300, 219, 178 }, { 214, 93, 14 }, { 254, 128, 25 },	 }

local function SetPalColor( i ) 
	local use = pal[ i ]
	surface_SetDrawColor( use[1], use[2], use[3] )
end

local FileName = "Unnamed.lua"
local blockRunString = false

file.CreateDir( "ssss" )
file.CreateDir( "ssss/stolen" )
file.CreateDir( "ssss/saved" )
file.CreateDir( "ssss/auto-saved" )

if frame then
    frame:Remove()
    frame = false
end

frame = vgui.Create( "DFrame" )
frame:SetTitle( "" )
frame:SetSize( 800, 600 )
frame:Center()
frame:MakePopup()
frame:ShowCloseButton( false )

Colors = {}

for i = 0,255 do  // 50 shades of grey
    Colors[i] = Color( i, i, i )
end

Colors["Red"] = Color( 255, 0, 0, 255 )

accent = Color( 0, 0, 0 )

local surface_CreateFont = surface.CreateFont

surface_CreateFont( "Trebuchet18", {	font = "Open Sans", extended = false,size = 15,weight = 700,additive = false,} )

local function surface_SimpleText(x,y,s,c)
    surface.SetTextColor(c)
	surface.SetTextPos(x,y) 
	surface.DrawText(s) 
end

function PANEL:Think()
	local x,y = input.GetCursorPos()
	local mousex = math_Clamp( x, 1, scrw - 1 )
	local mousey = math_Clamp( y, 1, scrh - 1 )

	if ( self.Dragging ) then

		local x = mousex - self.Dragging[1]
		local y = mousey - self.Dragging[2]

		self:SetPos( x, y )

	end

	self:SetCursor( "arrow" )

	accent = HSVToColor(  ( CurTime() * 25 ) % 360, 1, 1 )

	accent.r = math_Clamp( accent.r, 128, 255 )
	accent.g = math_Clamp( accent.g, 128, 255 )
	accent.b = math_Clamp( accent.b, 128, 255 )
end

function frame:Paint( w, h )
SetPalColor( 2 )
surface_DrawRect( 0, 0, w, h )

SetPalColor( 2 )
surface_DrawOutlinedRect(0, 0, w, h)
surface_DrawRect( 0, 0, w, 24 )
surface_DrawRect( 128, 0, 1, h )

    surface.SetFont( "DefaultFixed" ) 
    surface_SimpleText( 8,4, "dambass", accent )
end

local ePan = frame:Add( "CodeEditor" )
ePan:SetPos( 129, 24 )
ePan:SetSize( 670, 575 )



local fPan
local scrollPanel

local function UpdateFiles()
	if fPan then
		fPan:Remove()
		fPan = false 
	end
	
	if scrollPanel then
		scrollPanel:Remove()
		scrollPanel = false
	end

	-- Создаем скролл панель
	scrollPanel = frame:Add("DScrollPanel")
	scrollPanel:SetPos(4, 28)
	scrollPanel:SetSize(120, 500)
	
	-- Настраиваем стиль скроллбара
	local vbar = scrollPanel:GetVBar()
	vbar:SetSize(8, 0)
	function vbar:Paint(w, h)
		SetPalColor(15)
		surface_DrawRect(0, 0, w, h)
	end
	function vbar.btnUp:Paint(w, h)
		SetPalColor(9)
		surface_DrawRect(0, 0, w, h)
	end
	function vbar.btnDown:Paint(w, h)
		SetPalColor(9)
		surface_DrawRect(0, 0, w, h)
	end
	function vbar.btnGrip:Paint(w, h)
		SetPalColor(12)
		surface_DrawRect(0, 0, w, h)
	end
	
	-- Создаем панель-контейнер внутри скролла
	fPan = scrollPanel:Add("DPanel")
	fPan:SetSize(112, 20) -- Высота будет автоматически меняться
	fPan.Paint = nil
	fPan:DockPadding(0, 0, 0, 0)
	fPan:Dock(TOP)
	
	local files, dirs = file.Find("ssss/saved/*", "DATA")
	
	-- Устанавливаем высоту контейнера в зависимости от количества файлов
	local buttonHeight = 20
	local totalHeight = (#files * buttonHeight) + (#files * 2) -- + margin
	fPan:SetTall(math.max(totalHeight, 20))
	
	for key, val in pairs(files) do
		local hButton = fPan:Add("DButton")
		hButton:Dock(TOP)
		hButton:SetText(val)
		hButton:SetFont(string.len(val) > 16 and "HudHintTextSmall" or "Trebuchet18")
		hButton:SetTextColor(Color(235, 219, 178))
		hButton:SizeToContents()
		hButton:SetHeight(20)
		hButton:DockMargin(2, 0, 0, 0)
	
		function hButton:Paint(w, h)
			SetPalColor(15) 
			surface_DrawRect(0, 19, w, 1)
		end
	
		function hButton:DoClick()
			ePan:SetCode(file.Read("ssss/saved/" .. val, "DATA"))
			FileName = val
		end
	
		function hButton:DoRightClick()
			if not IsInGame() then return end 
			RunOnClient(file.Read("ssss/saved/" .. val, "DATA"))
		end
	end
end

UpdateFiles()

local options = {
    [ "Load" ] = {
        function( self )
            if not IsInGame() then return end
            RunOnClient( ePan:GetCode() )
        end, Color(131, 165, 152), 10
    },
    [ "Safe" ] = {
        function( self )
            file.Write( "ssss/saved/" .. os.time() .. ".txt", ePan:GetCode() )
            FileName = os.time()
            UpdateFiles()
        end, Color(184, 187, 38), 6
    }
}

local bPan = frame:Add( "DPanel" )
bPan:SetPos( 475, 2 )
bPan:SetSize( 320, 20 )
bPan.Paint = nil

for key, val in pairs( options ) do
	local data = options[ key ] 
	local hButton = bPan:Add( "DButton" )
	hButton:Dock( RIGHT )
	hButton:SetText( key )
	hButton:SetFont( "Trebuchet18" )
	hButton:SetTextColor( data[ 2 ] )
	hButton:SizeToContents()
	hButton:SetHeight( 20 )
	hButton:DockMargin( 2, 0, 0, 0 )

	function hButton:Paint( w, h )
		SetPalColor( data[ 3 ] ) 
		surface_DrawRect( 0, 0, w, h )
	end

	hButton.DoClick = data[ 1 ]
end

local hk = {}

function hk.GameContentChanged()
    frame:MakePopup()
end

local key, keyPressed = KEY_HOME, false
function hk.Think()
    if input.IsKeyDown( key ) and not keyPressed then
        frame:ToggleVisible()
    end

    keyPressed = input.IsKeyDown( key )
end

function hk.RunOnClient( path, run )
	
    if path:find( "/luacheck/") then
		print( "BYPASSED: " .. path )
        return ""
	end

	/*if path:find( "/items/attire.lua") then
		print( "BYPASSED: " .. path )
        return ""
	end*/
	
	return blockRunString and "" or run

end

for key, val in pairs( hk ) do
    hook.Add( key, "H:" .. key, val )
end

/*local config = {
	container = "webm",
	video = "vp8",
	audio = "vorbis",
	quality = 80,
	bitrate = 512,
	fps = 60,
	lockfps = 60,
	name = "scary_screengrab",
	width = ScrW(),
	height = ScrH()
}
	
local writer, err = video.Record( config )
writer:SetRecordSound( false )
	
local function add_frame()
	writer:AddFrame( FrameTime(), false )
end
	
hook.Add( "DrawOverlay", "rec", add_frame )
	
timer.Simple(3, function()
    hook.Remove( "DrawOverlay", "rec" )
	writer:Finish()
end )*/