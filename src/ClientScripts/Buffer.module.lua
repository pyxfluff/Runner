export type Buffer = {
	Offset: number,
	Source: string,
	Length: number,
	IsFinished: boolean,
	LastUnreadBytes: number,
	AllowOverflows: boolean,

	read: (Buffer, len: number?, shiftOffset: boolean?) -> string,
	readAhead: (Buffer, offset: number, len: number?) -> string,
	readNumber: (Buffer, packfmt: string?, shift: boolean?) -> number,
	seek: (Buffer, len: number) -> (),
	append: (Buffer, newData: string) -> (),
	toEnd: (Buffer) -> ()
}

local function Buffer(str, allowOverflows): Buffer
	local Stream = {}
	Stream.Offset = 0
	Stream.Source = str
	Stream.Length = string.len(str)
	Stream.IsFinished = false	
	Stream.LastUnreadBytes = 0
	Stream.AllowOverflows = if allowOverflows then allowOverflows else true

	function Stream.read(self: Buffer, len: number?, shift: boolean?): string
		local len = len or 1
		local shift = if shift ~= nil then shift else true
		local dat = string.sub(self.Source, self.Offset + 1, self.Offset + len)

		local dataLength = string.len(dat)
		local unreadBytes = len - dataLength

		if unreadBytes > 0 and not self.AllowOverflows then
			error("Buffer went out of bounds and AllowOverflows is false")
		end

		if shift then
			self:seek(len)
		end

		self.LastUnreadBytes = unreadBytes
		return dat
	end

	function Stream.readAhead(self: Buffer, offset: number, len: number?): string
		--[[ reads from offset + offset distance but does not shift the buffer]]--
		local len = len or 1
		local offsetAhead = self.Offset + offset
		
		return string.sub(self.Source, offsetAhead + 1, offsetAhead + len)
	end

	function Stream.seek(self: Buffer, len: number)
		local len = len or 1

		self.Offset = math.clamp(self.Offset + len, 0, self.Length)
		self.IsFinished = self.Offset >= self.Length
	end

	function Stream.append(self: Buffer, newData: string)
		-- adds new data to the end of a stream
		self.Source ..= newData
		self.Length = string.len(self.Source)
		self:seek(0) --hacky but forces a recalculation of the isFinished flag
	end

	function Stream.toEnd(self: Buffer)
		self:seek(self.Length)
	end

	function Stream.readNumber(self: Buffer, fmt: string?, shift: boolean?): number
		fmt = fmt or "I1"
		local packsize = string.packsize(fmt)

		local chunk = self:read(packsize, shift)
		local n = string.unpack(fmt, chunk)
		return n
	end

	return Stream
end

return Buffer