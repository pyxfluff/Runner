script.Parent.MouseButton1Click:Connect(function()
	local StartExec = tick()
	
	local Success, Error = pcall(function()
		loadstring(script.Parent.Parent.Code.Text)()
	end)
	
	if not Success then
		warn(Error)
	else
		print(`Successfully executed in {tick() - StartExec}s!`)
	end
end)