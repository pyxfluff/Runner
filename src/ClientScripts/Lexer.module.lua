--// Runner

--// Made by @metatablecatmaid
--// Fixed by @darkpixlz

local Buffer = require(script.Buffer)

local kReserved = {
	["and"] = "KeywordAnd",
	["break"] = "KeywordBreak",
	["do"] = "KeywordDo",
	["else"] = "KeywordElse",
	["elseif"] = "KeywordElseif",
	["end"] = "KeywordEnd",
	["false"] = "KeywordFalse",
	["function"] = "KeywordFunction",
	["if"] = "KeywordIf",
	["in"] = "KeywordIn",
	["local"] = "KeywordLocal",
	["nil"] = "KeywordNil",
	["not"] = "KeywordNot",
	["or"] = "KeywordOr",
	["repeat"] = "KeywordRepeat",
	["return"] = "KeywordReturn",
	["then"] = "KeywordThen",
	["true"] = "KeywordTrue",
	["until"] = "KeywordUntil",
	["while"] = "KeywordWhile"
}

-- Tokeniser code
local line = 1
local line_offset = 0

type LexemeType = "<unknown>"
| "Eof"
| "Character"
| "Equal"
| "LessEqual"
| "GreaterEqual"
| "NotEqual"
| "Dot2"
| "Dot3"
| "SkinnyArrow"
| "DoubleColon"
| "FloorDiv"
| "InterpStringBegin"
| "InterpStringMid"
| "InterpStringSimple"
| "AddAssign"
| "SubAssign"
| "MulAssign"
| "ModAssign"
| "PowAssign"
| "ConcatAssign"
| "RawString"
| "QuotedString"
| "Number"
| "Name"
| "Comment"
| "BlockComment"
| "BrokenString"
| "BrokenComment"
| "Unicode"
| "BrokenInterpDoubleBrace"
| "Error"
| "KeywordAnd"
| "KeywordBreak"
| "KeywordDo"
| "KeywordElse"
| "KeywordElseif"
| "KeywordEnd"
| "KeywordFalse"
| "KeywordFor"
| "KeywordFunction"
| "KeywordIf"
| "KeywondIn"
| "KeywordLocal"
| "KeywordNil"
| "KeywordNot"
| "KeywordOr"
| "KeywordRepeat"
| "KeywordReturn"
| "KeywordThen"
| "KeywordTrue"
| "KeywordUntil"
| "KeywordWhile"

export type Token = {
	Start: number,
	End: number,
	Type: LexemeType,
	Data: string?,
	IsKeyword: boolean,
	Position: {
		start: {line: number, character: number},
		["end"]: {line: number, character: number}
	}
}
local function token(pos, posEnd, type: LexemeType, data)
	if not data then
		print("NO DATA!!!!!!!!!!")
		error("give me data", 3)
	end
	return {
		Start = pos,
		End = posEnd,
		Type = type,
		Data = data,
		IsKeyword = (kReserved[type] ~= nil)
	}
end

local function attachLineInfo(token, src)
	-- adds a position
	--[[
		Position = {
			start = {
				line: number,
				column: number
			},
			["end"] = {
				line: number,
				column: number
			}
		}
	]]
	
	local position = {
		start = {
			line = line,
			character = token.Start - line_offset
		}
	}
	
	local data = string.sub(src, token.Start + 1, token.End)
	for i, c in string.split(data, "") do
		if c == "\n" then
			line += 1
			line_offset = token.Start + i
		end
	end
	
	position["end"] = {
		line = line,
		character = token.End - line_offset
	}
	
	table.freeze(position)
	table.freeze(position.start)
	table.freeze(position["end"])
	token.Position = position
end

local function isSpace(ch)
	return ch == " "
		or ch == "\t"
		or ch == "\r"
		or ch == "\n"
		or ch == "\v"
		or ch == "\f"
end

local function isDigit(ch)
	if not ch then return false end
	local n = string.byte(ch) or 0
	return n >= 48 and n <= 57
end

local function isAlpha(ch)
	if not ch then return false end
	local n = string.byte(ch) or 0
	return n >= 65 and n <= 90 or n >= 97 and n <= 122
end

local function tokenise(src: string): {Token}
	local stream = Buffer(src)
	local tokens = {}
	local braceStack = {}
	
	line = 1
	line_offset = 0
	
	local function peekch(lookahead)
		lookahead = lookahead or 0
		return stream:readAhead(lookahead, 1)
	end

	-- Parsers
	local function skipLongSeperator()
		local start = peekch()
		stream:seek()
		
		local count = 0
		while peekch() == "=" do
			stream:seek()
			count += 1
		end
		
		return if start == peekch() then count else (-count) - 1
	end
	
	local function readLongString(start, sep, ok, broken)
		stream:seek()
		local offset = stream.Offset
		
		local strStack = {}
		while true do
			local ch = peekch()
			if ch == "" then break end
			
			if ch == "]" then
				if skipLongSeperator() == sep then
					stream:seek()
					return token(start, stream.Offset, ok, table.concat(strStack))
				end
			else
				table.insert(strStack, stream:read())
				continue
			end
			
			return token(start, stream.Offset, broken, table.concat(strStack))
		end
	end
	
	local function readCommentBody()
		local start = stream.Offset
		local offset = start + 2
		stream:seek(2)

		if peekch() == "[" then
			local sep = skipLongSeperator()
			
			if sep >= 0 then
				return readLongString(start, sep, "BlockComment", "BrokenComment")
			end
		end
		
		local stack = {}
		while true do
			local ch = peekch()
			if ch == "" or ch == "\r" or ch == "\n" then
				break
			end
			
			table.insert(stack, stream:read())
		end
		
		return token(start, stream.Offset, "Comment", table.concat(stack))
	end
	
	local function readBackslashInString(stack)
		table.insert(stack, "\\")
		stream:seek()
		
		local ch = peekch()
		if ch == "\r" then
			table.insert(stack, stream:read())
			if peekch() == "\n" then
				table.insert(stack, stream:read())
			end
			
		elseif ch == "" then return
		elseif ch == "z" then
			table.insert(stack, stream:read())
			while isSpace(peekch()) do
				table.insert(stack, stream:read())
			end
		else
			table.insert(stack, stream:read())
		end
	end
	
	local function readNumber(start, startOffset)
		local stack = {}
		
		repeat
			local ch = stream:seek()
			local isvalidch = isDigit(ch) or ch == "." or ch == "_" or table.find({"1", "2", "3", "4", "5", "6", "7", "8", "9", "0"}, ch)
			print(isvalidch)
			if isvalidch then
				table.insert(stack, stream:read())
			else
				table.insert(stack, stream:read())
			end
		until not isvalidch
		
		if string.lower(peekch()) == "e" then
			local ch = stream:read()
			table.concat(stack, ch)
			
			if ch == "+" or ch == "-" then
				table.concat(stack, ch)
			end
		end
		
		while true do
			local ch = peekch()
			if not (isAlpha(ch) or isDigit(ch) or ch == "_") then
				break
			end
			
			table.insert(stack, stream:read())
		end
		
		--return token(start, stream.Offset, "Number", table.concat(stack))
		
		--// combine number
		local FinalNum = ""
		
		for i, number in ipairs(stack) do
			print(number)
			FinalNum = `{FinalNum}{number}`
		end
		
		return token(start, stream.Offset, "Number", FinalNum)
	end
	
	local function readQuotedString()
		local start = stream.Offset
		local delimiter = peekch()
		stream:seek()
		local offset = start + 1
		
		local stack = {}
		while true do
			local ch = peekch()
			if ch == delimiter then break end
			
			if ch == "" or ch == "\r" or ch == "\n" then
				return token(start, stream.Offset, "BrokenString", table.concat(stack))
				--return token(start, stream.Offset, "BrokenString", "\"")
			elseif ch == "\\" then
				readBackslashInString(stack)
			else
				table.insert(stack, stream:read())
			end
		end
		
		stream:seek()
		return token(start, stream.Offset, "QuotedString", table.concat(stack))
		--return token(start, stream.Offset, "QuotedString", "\"")
	end

	local function readInterpolatedString(start, fType, eType)
		local offset = stream.Offset
		
		local stack = {}
		while true do
			-- i hate interpolated strings
			local ch = peekch()
			if ch == "`" then break end
			
			if ch == "" or ch == "\r" or ch == "\n" then
				return token(start, stream.Offset, "BrokenString", table.concat(stack))
				
			elseif ch == "\\"	then
				if peekch(1) == "u" and peekch(2) == "{" then
					stream:seek(3)
					table.insert(stack, "\\u{")
					continue
				end
				
				readBackslashInString(stack)
				
			elseif ch == "{" then
				table.insert(braceStack, "InterpolatedString")
				if peekch(1) == "{" then
					local doubleBrace = token(start, stream.Offset, "BrokenString", table.concat(stack))
					stream:seek(2)
					return doubleBrace
				end
				
				stream:seek()
				return token(start, stream.Offset, fType, table.concat(stack))
			else
				table.insert(stack, stream:read())
			end
		end
		
		stream:seek(1)
		return token(start, stream.Offset, eType, table.concat(stack))
	end
	
	local function readInterpolatedStringStart()
		local start = stream.Offset
		stream:seek()

		return readInterpolatedString(start, "InterpStringBegin", "InterpStringSimple")
	end
	
	local function readName()
		local offset = stream.Offset
		
		local stack = {}
		repeat
			local ch = peekch()
			local isvalidch = isAlpha(ch) or isDigit(ch) or ch == "_"
			if isvalidch then
				table.insert(stack, stream:read())
			end
		until not isvalidch
		
		-- i hate AstNames so much
		local k = table.concat(stack)
		return k, kReserved[k] or "Name" 
	end
	
	local function getUtf8Size(ch)
		local size = 0
		local mask = 0x80
		
		local ch_byte = string.byte(ch)
		
		while bit32.band(ch_byte, mask) == mask do
			size = size + 1
			mask = bit32.rshift(mask, 1)
		end
		
		return size
	end

	local function readUtf8Error()
		-- this parses a stream of bytes >= 0x80 which has already been
		-- tested, into a single utf8 char
		local start = stream.Offset
		local size = getUtf8Size(peekch())
		print(size)
		return token(start, start + size, "Unicode", stream:read(size))
	end
	
	-- the function of all time
	local function readNext()
		local start = stream.Offset
		local ch = peekch()
		
		if ch == "" then
			return token(start, start, "Eof", "")
			
		elseif ch == "-" then
			local nextch = peekch(1)
			
			if nextch == ">" then
				stream:seek(2)
				return token(start, start + 2, "SkinnyArrow")
			elseif nextch == "=" then
				stream:seek(2)
				return token(start, start + 2, "SubAssign")
			elseif nextch == "-" then
				return readCommentBody()
			else
				stream:seek()
				return token(start, start + 1, "Character", "-")
			end
			
		elseif ch == "[" then
			local sep = skipLongSeperator()
			
			if sep >= 0 then
				return readLongString(start, sep, "RawString", "BrokenString")
			elseif sep == -1 then
				return token(start, start + 1, "Character", "[")
			else
				return token(start, stream.Offset, "BrokenString")
			end
			
		elseif ch == "{" then
			stream:seek()
			if braceStack[1] then
				table.insert(braceStack, "Normal")
			end
			
			return token(start, start + 1, "Character", "{")
			
		elseif ch == "}" then
			stream:seek()
			if not braceStack[1] then
				return token(start, start + 1, "Character", "}")
			end
			
			local braceTop = table.remove(braceStack, #braceStack)
			if braceTop ~= "InterpolatedString" then
				return token(start, start + 1, "Character", "}")
			end
			
			return readInterpolatedString(stream.Offset, "InterpStringMid", "InterpStringEnd")
		
		elseif ch == "=" then
			stream:seek()
			if peekch() == "=" then
				stream:seek()
				return token(start, start + 2, "Equal", "==")
			end
			
			return token(start, start + 1, "Character", "=")
			
		elseif ch == "<" then
			stream:seek()
			if peekch() == "=" then
				stream:seek()
				return token(start, start + 2, "LessEqual", "<=")
			end

			return token(start, start + 1, "Character", "<")
			
		elseif ch == ">" then
			stream:seek()
			if peekch() == "=" then
				stream:seek()
				return token(start, start + 2, "GreaterEqual", ">=")
			end

			return token(start, start + 1, "Character", ">")
			
		elseif ch == "~" then
			stream:seek()
			if peekch() == "=" then
				stream:seek()
				return token(start, start + 2, "NotEqual", "~=")
			end

			return token(start, start + 1, "Character", "~")
		
		elseif ch == '"' or ch == "'" then
			return readQuotedString()
			
		elseif ch == "`" then
			return readInterpolatedStringStart()
		
		elseif ch == "." then
			stream:seek()
			local ch1 = peekch()
			
			if ch1  == "." then
				stream:seek()
				local ch2 = peekch()
				if ch2 == "." then
					stream:seek()
					return token(start, start + 3, "Dot3", "...")
				elseif ch2 == "=" then
					stream:seek()
					return token(start, start + 3, "ConcatAssign", ".=")
				else
					return token(start, start + 2, "Dot2", "..")
				end
			else
				if isDigit(ch1) then
					stream.Offset -= 1
					return readNumber(start, stream.Offset - 1)
				else
					return token(start, start + 1, "Character", ".")
				end
			end
		
		elseif ch == "+" then
			stream:seek()
			if peekch() == "=" then
				stream:seek()
				return token(start, start + 2, "AddAssign", "+=")
			end

			return token(start, start + 1, "Character", "+")		
			
		elseif ch == "/" then
		
		elseif ch == "*" then
			stream:seek()
			if peekch() == "=" then
				stream:seek()
				return token(start, start + 2, "MulAssign", "*=")
			end

			return token(start, start + 1, "Character", "*")
			
		elseif ch == "%" then
			stream:seek()
			if peekch() == "=" then
				stream:seek()
				return token(start, start + 2, "ModAssign", "%=")
			end

			return token(start, start + 1, "Character", "%")
		
		elseif ch == "^" then
			stream:seek()
			if peekch() == "=" then
				stream:seek()
				return token(start, start + 2, "PowAssign", "^=")
			end

			return token(start, start + 1, "Character", "^")
		
		elseif ch == ":" then
			stream:seek()
			if peekch() == ":" then
				stream:seek()
				return token(start, start + 2, "DoubleColon", "::")
			end

			return token(start, start + 1, "Character", ":")
		
		elseif ch == "("
			or ch == ")"
			or ch == "]" 
			or ch == ";"
			or ch == ","
			or ch == "#"
			or ch == "?"
			or ch == "&"
			or ch == "|"
		then
			return token(start, start + 1, "Character", stream:read())
			
		else
			if isDigit(ch) then
				--// this is annoying me
				--return readNumber(start, stream.Offset)
				return token(start, start + 1, "Number", stream:read())
			elseif isAlpha(ch) or ch == "_" then
				local name, type = readName()
				return token(start, stream.Offset, type, name)
			elseif bit32.btest(string.byte(ch), 0x80) then
				print("meow")
				return readUtf8Error()
			else
				return token(start, start + 1, "Character", stream:read())
			end
		end
	end
	
	repeat
		local lastToken = readNext()
		if not lastToken then return {} end -- empty script
		
		attachLineInfo(lastToken, src)
		table.freeze(lastToken)
		table.insert(tokens, lastToken)
	until lastToken.Type == "Eof"
	return tokens
end 

return tokenise