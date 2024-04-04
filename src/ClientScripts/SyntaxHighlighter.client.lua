local Lex = require(script.Lexer)
local Highlights = {
	["Comment"] = "#3e4153",
	["BlockComment"] = "#3e4153",
	
	["QuotedString"] = "#b5bcc4",
	["RawString"] = "#b5bcc4",
	["Number"] = "#F18F01",
	["Globals"] = "#5BC0EB",
	["Name"] = "#adcbcb",
	["IncompleteString"] = "#d50000",
	
	["KeywordLocal"] = "#ad1616",
	["KeywordFunction"] = "#ad1616",
	["KeywordEnd"] = "#ad1616",
	["KeywordBreak"] = "#ad1616",
	["KeywordContinue"] = "#ad1616",
	["KeywordDo"] = "#ad1616",
	["KeywordWhile"] = "#ad1616",
	["KeywordTrue"] = "#46577d",
	["KeywordFalse"] = "#46577d",
	["KeywordNot"] = "#ad1616",
	["KeywordThen"] = "#ad1616",
	["KeywordIf"] = "#ad1616",
	["KeywordIn"] = "#ad1616",
	["KeywordNil"] = "#ad1616",
	["KeywordFor"] = "#ad1616",
	["KeywordOr"] = "#ad1616",
	["KeywordReturn"] = "#46577d",
	["KeywordRepeat"] = "#ad1616",
	
	["InterpStringBegin"] = "#3f5974",
	["InterpStringEnd"] = "#3f5974",
	
	["Equal"] = "#cecece",
	["NotEqual"] = "#cecece"
}


function Highlight(Code)
	local Final = ""
	local Lexed = Lex(Code)

	for Identifier, Word in pairs(Lexed) do
		if not Word.Data then
			Final..= "[missing]"
			continue
		end
		
		if Word.Type == "LessEqual" then
			Final..= Word.Data
		end
		
		if Highlights[Word.Type] then
			Final ..= `<font color="{Highlights[Word.Type]}">{Word.Data}</font>`
		else
			if not table.find({"Character", "Eof"}, Word.Type) then
				--print(Word.Type)
			elseif Word.Type == "BrokenString" then
				--// Implementation is currently broken, have to deal with invisible quotes for now...
				
				--print(Word.Data)
				--Final..= `"{Word.Data}"`
			end
			Final..= Word.Data
		end
	end

	return Final
end


script.Parent.Code:GetPropertyChangedSignal("Text"):Connect(function()
	script.Parent.CodeRendered.Code.Text = Highlight(script.Parent.Code.Text)
end)