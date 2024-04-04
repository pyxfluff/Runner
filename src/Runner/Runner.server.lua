--// darkpixlz 2024

--// Runner
--// Do whatever you want with this code. Modify it, use it, go crazy.

--// Variables
local Env = script.Parent
local UI = Env.Interface
local BtnConnections = {}
local ExplorerConnections = {}
local Scripts = {}
local PageIsActive = "Init"
local function GUID(c)
	return game:GetService("HttpService"):GenerateGUID(c)
end

local Toolbar

--// UI
local CodeUI = UI.Code
local ExplorerUI = UI.Explorer
local SavesUI = nil

--// Plugin
if not pcall(function() Toolbar = plugin:CreateToolbar("darkpixlz") end) then
	-- Plugin library does not exist in scripts
	error("[Runner] - Please do not execute Runner as a script!")
end

local Button = Toolbar:CreateButton("Runner", "Run server or client multiline code from a plugin window!", "https://www.roblox.com/asset/?id=16963831128")
Button.ClickableWhenViewportHidden = true

local Widget = plugin:CreateDockWidgetPluginGui(
	"Runner", 
	DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Left, false, false, 0, 0, 300, 200)
)

Widget.Title = "Runner - Mini IDE"

local function Run(Code)
	local StartExec = tick()
	local Success, Result = pcall(function()
		loadstring(Code)()
	end)

	if not Success then
		warn(Result)
		return false, Result
	else
		print(`Successfully executed in {tick() - StartExec}s!`)
		
		return true, nil
	end
end

local function LoadGameScripts()
	Scripts = {}

	for i, Script in game:GetDescendants() do
		if Script:IsA("Script") or Script:IsA("LocalScript") and not Script:FindFirstAncestorWhichIsA("CoreGui") then
			table.insert(Scripts, {
				["Directory"] = Script:GetFullName():gsub("%.", "\\"),
				["Content"] = Script.Source,
				["Type"] = Script.ClassName,
				["Name"] = tostring(Script.Name)
			})
		end
	end
	
	for i, Script in Scripts do
		local ClonedTemplate = UI.Templates.Explorer:Clone()
		
		ClonedTemplate.Visible = true
		ClonedTemplate.Name = Script["Name"]
		ClonedTemplate.ScriptName.Text = `<b>{Script["Type"]} {Script["Name"]}</b> ({Script["Directory"]})`
		ExplorerConnections[GUID(false)] = ClonedTemplate.Run.MouseButton1Click:Connect(function()
			Run(Script["Content"])
		end)
		ExplorerConnections[GUID(false)] = ClonedTemplate.Import.MouseButton1Click:Connect(function()
			CodeUI.Code.Text = Script["Content"]
			CodeUI.Parent = Widget
			for i, f in ExplorerUI.Container.List:GetChildren() do
				if f:IsA("Frame") then f:Destroy() end
			end
			ExplorerUI.Parent = UI
		end)
		
		ClonedTemplate.Parent = ExplorerUI.Container.List
	end
end

Button.Click:Connect(function()
	Widget.Enabled = not Widget.Enabled
	
	if PageIsActive == "Init" then
		--// Test loadstring
		local LSEnabled, Error = pcall(function()
			loadstring("local Enabled = true")()
		end)
		
		if not LSEnabled then
			UI.LoadStringDisabled.Parent = Widget
		else
			CodeUI.Parent = Widget
			PageIsActive = "Code"
		end
	end
	
	if Widget.Enabled then
		--// Prewarm events
		BtnConnections["ExecServer"] = CodeUI.ExecuteServer.MouseButton1Click:Connect(function()
			local Success, Message = Run(CodeUI.Code.Text)
			
			if not Success then
				CodeUI.Error.Visible = true
				CodeUI.Error.Label.Text = Message
				
				task.delay(30, function()
					CodeUI.Error.Visible = false
				end)
			else
				CodeUI.Error.Visible = false
			end
		end)
		
		BtnConnections["ToggleExplorer"] = CodeUI.Controls.Explorer.MouseButton1Click:Connect(function()
			CodeUI.Parent = UI
			ExplorerUI.Parent = Widget
			
			LoadGameScripts()
		end)
	else
		for Event: RBXScriptConnection in BtnConnections do
			Event:Disconnect()
		end
	end
end)