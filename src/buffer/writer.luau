--!strict
--!optimize 2
--[[
	BufferWriter V0.1.3

	Each write session owns a cursor with a private growable buffer.
	START creates a cursor (optional offset reserves leading zero-filled bytes).
	ALLOC grows the buffer when needed; FINISH trims to cursor.offset.

	Type nodes call ALLOC(n) once before writing their fields.
	Primitive write functions advance cursor.offset and do no bounds checking.
]]
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
const config = require("../shared/config")
const exports = require("../shared/exports")

-----------------------------------------------------
-- LOCALIZE			                               --
-----------------------------------------------------
const CREATE: (number) -> buffer = buffer.create
const COPY: (buffer, number, buffer, number?, number?) -> () = buffer.copy

const WRITE_U8: (buffer, number, number) -> () = buffer.writeu8
const WRITE_I8: (buffer, number, number) -> () = buffer.writei8
const WRITE_U16: (buffer, number, number) -> () = buffer.writeu16
const WRITE_I16: (buffer, number, number) -> () = buffer.writei16
const WRITE_U32: (buffer, number, number) -> () = buffer.writeu32
const WRITE_I32: (buffer, number, number) -> () = buffer.writei32
const WRITE_F32: (buffer, number, number) -> () = buffer.writef32
const WRITE_F64: (buffer, number, number) -> () = buffer.writef64
const WRITE_STRING: (buffer, number, string, number?) -> () = buffer.writestring

const ABS: (number) -> number = math.abs
const FREXP: (number) -> (number, number) = math.frexp

const AND: (...number) -> number = bit32.band
const OR: (...number) -> number = bit32.bor
const EXTRACT: (number, number, number?) -> number = bit32.extract
const LSHIFT: (number, number) -> number = bit32.lshift


const HUGE: number = math.huge
const NHUGE: number = -HUGE
const SQRT: (number) -> number = math.sqrt

-----------------------------------------------------
-- TYPES			                               --
-----------------------------------------------------
type cursor = exports.cursor

-----------------------------------------------------
-- API                                             --
-----------------------------------------------------
@native
const function start(offset: number?): cursor
	const reserved: number = offset or 0
	const size: number = config.startingBufferSize + reserved
	return {
		offset = reserved,
		len = size,
		buf = CREATE(size),
	}
end

@native
const function finish(cursor: cursor): buffer
	const writtenBytes: number = cursor.offset
	const len: number = cursor.len
	local buf: buffer = cursor.buf

	if writtenBytes ~= len then
		const newBuf: buffer = CREATE(writtenBytes)
		COPY(newBuf, 0, buf, 0, writtenBytes)
		buf = newBuf
	end

	return buf
end

@native
const function alloc(cursor: cursor, bytes: number): ()
	local writtenBytes: number = cursor.offset
	local len: number = cursor.len
	local reallocate: boolean = false
	while writtenBytes + bytes > len do
		len = len * config.bufferExpandMultiplier // 1
		cursor.len = len
		reallocate = true
	end

	if reallocate then
		local oldBuf: buffer = cursor.buf
		local newBuf: buffer = CREATE(len)
		COPY(newBuf, 0, oldBuf, 0, writtenBytes)
		cursor.buf = newBuf
	end
end

-----------------------------------------------------
-- PRIMITIVE WRITES                                --
-----------------------------------------------------
@native
const function writeu8(cursor: cursor, value: number): ()
	const writtenBytes: number = cursor.offset
	WRITE_U8(cursor.buf, writtenBytes, value)
	cursor.offset = writtenBytes + 1
end

@native
const function writei8(cursor: cursor, value: number): ()
	const writtenBytes: number = cursor.offset
	WRITE_I8(cursor.buf, writtenBytes, value)
	cursor.offset = writtenBytes + 1
end

@native
const function writeu16(cursor: cursor, value: number): ()
	const writtenBytes: number = cursor.offset
	WRITE_U16(cursor.buf, writtenBytes, value)
	cursor.offset = writtenBytes + 2
end

@native
const function writei16(cursor: cursor, value: number): ()
	const writtenBytes: number = cursor.offset
	WRITE_I16(cursor.buf, writtenBytes, value)
	cursor.offset = writtenBytes + 2
end

--[[
	Float16 write operation: 1s | 5e(bias15) | 10m
	Special values: ±Inf stored as exp=0x1F mant=0; NaN as exp=0x1F mant=0x200.
]]
@native
const function writef16(cursor: cursor, value: number): ()
	const writtenBytes: number = cursor.offset
	local packed: number
	if value ~= value then
		packed = 0x7E00
	elseif value == HUGE then
		packed = 0x7C00
	elseif value == NHUGE then
		packed = 0xFC00
	elseif value == 0 then
		packed = 0
	else
		const sign: number = if value < 0 then 1 else 0
		const m: number, e: number = FREXP(ABS(value))
		const biasedExp: number = e + 14
		if biasedExp >= 0x1F then
			packed = OR(LSHIFT(sign, 15), 0x7C00)
		elseif biasedExp <= 0 then
			packed = LSHIFT(sign, 15)
		else
			const mant10: number = ((m * 2 - 1) * 1024 + 0.5) // 1
			packed = OR(LSHIFT(sign, 15), LSHIFT(biasedExp, 10), AND(mant10, 0x3FF))
		end
	end
	WRITE_U16(cursor.buf, writtenBytes, packed)
	cursor.offset = writtenBytes + 2
end

@native
const function writeu24(cursor: cursor, value: number): ()
	const writtenBytes: number = cursor.offset
	const buf: buffer = cursor.buf
	WRITE_U16(buf, writtenBytes, AND(value, 0xFFFF))
	WRITE_U8(buf, writtenBytes + 2, EXTRACT(value, 16, 8))
	cursor.offset = writtenBytes + 3
end

--[[
	Float24 write operation: 1s | 7e(bias63) | 16m
	Layout in buffer: [lo16 of mantissa] [sign(1) | exp(7)]
]]
@native
const function writef24(cursor: cursor, value: number): ()
	const writtenBytes: number = cursor.offset
	const buf: buffer = cursor.buf
	local mant16: number
	local byte2: number
	if value ~= value then
		mant16 = 0x8000
		byte2 = 0x7F
	elseif value == HUGE then
		mant16 = 0
		byte2 = 0x7F
	elseif value == NHUGE then
		mant16 = 0
		byte2 = 0xFF
	elseif value == 0 then
		mant16 = 0
		byte2 = 0
	else
		const sign: number = if value < 0 then 1 else 0
		const m: number, e: number = FREXP(ABS(value))
		const biasedExp: number = e + 62
		if biasedExp >= 0x7F then
			mant16 = 0
			byte2 = OR(LSHIFT(sign, 7), 0x7F)
		elseif biasedExp <= 0 then
			mant16 = 0
			byte2 = LSHIFT(sign, 7)
		else
			const frac: number = m * 2 - 1
			mant16 = AND((frac * 65536 + 0.5) // 1, 0xFFFF)
			byte2 = OR(LSHIFT(sign, 7), biasedExp)
		end
	end
	WRITE_U16(buf, writtenBytes, mant16)
	WRITE_U8(buf, writtenBytes + 2, byte2)
	cursor.offset = writtenBytes + 3
end

@native
const function writeu32(cursor: cursor, value: number): ()
	const writtenBytes: number = cursor.offset
	WRITE_U32(cursor.buf, writtenBytes, value)
	cursor.offset = writtenBytes + 4
end

@native
const function writei32(cursor: cursor, value: number): ()
	const writtenBytes: number = cursor.offset
	WRITE_I32(cursor.buf, writtenBytes, value)
	cursor.offset = writtenBytes + 4
end

@native
const function writef32(cursor: cursor, value: number): ()
	const writtenBytes: number = cursor.offset
	WRITE_F32(cursor.buf, writtenBytes, value)
	cursor.offset = writtenBytes + 4
end

@native
const function writef64(cursor: cursor, value: number): ()
	const writtenBytes: number = cursor.offset
	WRITE_F64(cursor.buf, writtenBytes, value)
	cursor.offset = writtenBytes + 8
end

@native
const function writes255(cursor: cursor, value: string, len: number): ()
	local writtenBytes: number = cursor.offset
	const buf: buffer = cursor.buf
	WRITE_U8(buf, writtenBytes, len)
	writtenBytes += 1
	WRITE_STRING(buf, writtenBytes, value)
	cursor.offset = writtenBytes + len
end

@native
const function writes65(cursor: cursor, value: string, len: number): ()
	local writtenBytes: number = cursor.offset
	const buf: buffer = cursor.buf
	WRITE_U16(buf, writtenBytes, len)
	writtenBytes += 2
	WRITE_STRING(buf, writtenBytes, value)
	cursor.offset = writtenBytes + len
end

@native 
const function writeu40(cursor: cursor, value: number): ()
	local writtenBytes: number = cursor.offset
	const buf: buffer = cursor.buf
	const lower: number = value % 0x100000000
	const upper: number = value // 0x100000000
	WRITE_U32(buf, writtenBytes, lower)
	writtenBytes += 4
	WRITE_U8(buf, writtenBytes, upper)
	cursor.offset = writtenBytes + 1
end

@native
const function writeu48(cursor: cursor, value: number): ()
	local writtenBytes: number = cursor.offset
	const buf: buffer = cursor.buf
	const lower: number = value % 0x100000000
	const upper: number = AND(value // 0x100000000, 0xFFFF)
	WRITE_U32(buf, writtenBytes, lower)
	writtenBytes += 4
	WRITE_U16(buf, writtenBytes, upper)
	cursor.offset = writtenBytes + 2
end

@native
const function writev2f32(cursor: cursor, value: Vector2): ()
	local writtenBytes: number = cursor.offset
	const buf: buffer = cursor.buf
	WRITE_F32(buf, writtenBytes, value.X)
	writtenBytes += 4
	WRITE_F32(buf, writtenBytes, value.Y)
	cursor.offset = writtenBytes + 4
end

@native
const function writev2f24(cursor: cursor, value: Vector2): ()
	writef24(cursor, value.X)
	writef24(cursor, value.Y)
end

@native
const function writev2f16(cursor: cursor, value: Vector2): ()
	writef16(cursor, value.X)
	writef16(cursor, value.Y)
end

@native
const function writevf32(cursor: cursor, value: vector | Vector3): ()
	local writtenBytes: number = cursor.offset
	const buf: buffer = cursor.buf
	WRITE_F32(buf, writtenBytes, value.x)
	writtenBytes += 4
	WRITE_F32(buf, writtenBytes, value.y)
	writtenBytes += 4
	WRITE_F32(buf, writtenBytes, value.z)
	cursor.offset = writtenBytes + 4
end

@native
const function writevf24(cursor: cursor, value: vector | Vector3): ()
	writef24(cursor, value.x)
	writef24(cursor, value.y)
	writef24(cursor, value.z)
end

@native
const function writevf16(cursor: cursor, value: vector | Vector3): ()
	writef16(cursor, value.x)
	writef16(cursor, value.y)
	writef16(cursor, value.z)
end

@native 
const function writecolor3(cursor: cursor, value: Color3): ()
	local writtenBytes: number = cursor.offset
	const buf: buffer = cursor.buf
	WRITE_U8(buf, writtenBytes, value.R * 255 // 1)
	writtenBytes += 1
	WRITE_U8(buf, writtenBytes, value.G * 255 // 1)
	writtenBytes += 1
	WRITE_U8(buf, writtenBytes, value.B * 255 // 1)
	cursor.offset = writtenBytes + 1
end

@native
const function writecf32(cursor: cursor, value: CFrame): ()
	local writtenBytes: number = cursor.offset
	const buf: buffer = cursor.buf
	const x: number, y: number, z: number, R0: number, R01: number, R02: number, R10: number, R11: number, R12: number, R20: number, R21: number, R22: number =
		value:GetComponents()
	
	WRITE_F32(buf, writtenBytes, x)
	writtenBytes += 4
	WRITE_F32(buf, writtenBytes, y)
	writtenBytes += 4
	WRITE_F32(buf, writtenBytes, z)
	writtenBytes += 4
	WRITE_F32(buf, writtenBytes, R0)
	writtenBytes += 4
	WRITE_F32(buf, writtenBytes, R01)
	writtenBytes += 4
	WRITE_F32(buf, writtenBytes, R02)
	writtenBytes += 4
	WRITE_F32(buf, writtenBytes, R10)
	writtenBytes += 4
	WRITE_F32(buf, writtenBytes, R11)
	writtenBytes += 4
	WRITE_F32(buf, writtenBytes, R12)
	writtenBytes += 4
	WRITE_F32(buf, writtenBytes, R20)
	writtenBytes += 4
	WRITE_F32(buf, writtenBytes, R21)
	writtenBytes += 4
	WRITE_F32(buf, writtenBytes, R22)
	cursor.offset = writtenBytes + 4
end

@native
const function writecf24(cursor: cursor, value: CFrame): ()
	const x: number, y: number, z: number, R0: number, R01: number, R02: number, R10: number, R11: number, R12: number, R20: number, R21: number, R22: number =
		value:GetComponents()

	writef24(cursor, x)
	writef24(cursor, y)
	writef24(cursor, z)
	writef24(cursor, R0)
	writef24(cursor, R01)
	writef24(cursor, R02)
	writef24(cursor, R10)
	writef24(cursor, R11)
	writef24(cursor, R12)
	writef24(cursor, R20)
	writef24(cursor, R21)
	writef24(cursor, R22)
end

@native
const function writecf16(cursor: cursor, value: CFrame): ()
	const x: number, y: number, z: number, R0: number, R01: number, R02: number, R10: number, R11: number, R12: number, R20: number, R21: number, R22: number =
		value:GetComponents()

	writef16(cursor, x)
	writef16(cursor, y)
	writef16(cursor, z)
	writef16(cursor, R0)
	writef16(cursor, R01)
	writef16(cursor, R02)
	writef16(cursor, R10)
	writef16(cursor, R11)
	writef16(cursor, R12)
	writef16(cursor, R20)
	writef16(cursor, R21)
	writef16(cursor, R22)
end

@native const function writeqcf32(cursor: cursor, value: CFrame): ()
	local writtenBytes: number = cursor.offset
	const buf: buffer = cursor.buf
	-- inline quaternion extracting
	const x: number, y: number, z: number, R0: number, R01: number, R02: number, R10: number, R11: number, R12: number, R20: number, R21: number, R22: number =
        value:GetComponents()

    const trace: number = R0 + R11 + R22
    local qx: number, qy: number, qz: number, qw: number

    if trace > 0 then
        const root = SQRT(trace + 1)
        qw = 0.5 * root
        const invS = 0.5 / root
        qx = (R21 - R12) * invS
        qy = (R02 - R20) * invS
        qz = (R10 - R01) * invS
    elseif (R0 > R11) and (R0 > R22) then
        const root = SQRT(1 + R0 - R11 - R22)
        qx = 0.5 * root
        const invS = 0.5 / root
        qw = (R21 - R12) * invS
        qy = (R01 + R10) * invS
        qz = (R02 + R20) * invS
    elseif R11 > R22 then
        const root = SQRT(1 + R11 - R0 - R22)
        qy = 0.5 * root
        const invS = 0.5 / root
        qw = (R02 - R20) * invS
        qx = (R01 + R10) * invS
        qz = (R12 + R21) * invS
    else
        const root = SQRT(1 + R22 - R0 - R11)
        qz = 0.5 * root
        const invS = 0.5 / root
        qw = (R10 - R01) * invS
        qx = (R02 + R20) * invS
        qy = (R12 + R21) * invS
    end
	-----------------------------------------------------------

	WRITE_F32(buf, writtenBytes, x)
	writtenBytes += 4
	WRITE_F32(buf, writtenBytes, y)
	writtenBytes += 4
	WRITE_F32(buf, writtenBytes, z)
	writtenBytes += 4
	WRITE_F32(buf, writtenBytes, qx)
	writtenBytes += 4
	WRITE_F32(buf, writtenBytes, qy)
	writtenBytes += 4
	WRITE_F32(buf, writtenBytes, qz)
	writtenBytes += 4
	WRITE_F32(buf, writtenBytes, qw)
	cursor.offset = writtenBytes + 4
end

@native const function writeqcf24(cursor: cursor, value: CFrame): ()
	-- inline quaternion extracting
	const x: number, y: number, z: number, R0: number, R01: number, R02: number, R10: number, R11: number, R12: number, R20: number, R21: number, R22: number =
        value:GetComponents()

    const trace: number = R0 + R11 + R22
    local qx: number, qy: number, qz: number, qw: number

    if trace > 0 then
        const root = SQRT(trace + 1)
        qw = 0.5 * root
        const invS = 0.5 / root
        qx = (R21 - R12) * invS
        qy = (R02 - R20) * invS
        qz = (R10 - R01) * invS
    elseif (R0 > R11) and (R0 > R22) then
        const root = SQRT(1 + R0 - R11 - R22)
        qx = 0.5 * root
        const invS = 0.5 / root
        qw = (R21 - R12) * invS
        qy = (R01 + R10) * invS
        qz = (R02 + R20) * invS
    elseif R11 > R22 then
        const root = SQRT(1 + R11 - R0 - R22)
        qy = 0.5 * root
        const invS = 0.5 / root
        qw = (R02 - R20) * invS
        qx = (R01 + R10) * invS
        qz = (R12 + R21) * invS
    else
        const root = SQRT(1 + R22 - R0 - R11)
        qz = 0.5 * root
        const invS = 0.5 / root
        qw = (R10 - R01) * invS
        qx = (R02 + R20) * invS
        qy = (R12 + R21) * invS
    end
	-----------------------------------------------------------

	writef24(cursor, x)
	writef24(cursor, y)
	writef24(cursor, z)
	writef24(cursor, qx)
	writef24(cursor, qy)
	writef24(cursor, qz)
	writef24(cursor, qw)
end

@native 
const function writeqcf16(cursor: cursor, value: CFrame): ()
	-- inline quaternion extracting
	const x: number, y: number, z: number, R0: number, R01: number, R02: number, R10: number, R11: number, R12: number, R20: number, R21: number, R22: number =
        value:GetComponents()

    const trace: number = R0 + R11 + R22
    local qx: number, qy: number, qz: number, qw: number

    if trace > 0 then
        const root = SQRT(trace + 1)
        qw = 0.5 * root
        const invS = 0.5 / root
        qx = (R21 - R12) * invS
        qy = (R02 - R20) * invS
        qz = (R10 - R01) * invS
    elseif (R0 > R11) and (R0 > R22) then
        const root = SQRT(1 + R0 - R11 - R22)
        qx = 0.5 * root
        const invS = 0.5 / root
        qw = (R21 - R12) * invS
        qy = (R01 + R10) * invS
        qz = (R02 + R20) * invS
    elseif R11 > R22 then
        const root = SQRT(1 + R11 - R0 - R22)
        qy = 0.5 * root
        const invS = 0.5 / root
        qw = (R02 - R20) * invS
        qx = (R01 + R10) * invS
        qz = (R12 + R21) * invS
    else
        const root = SQRT(1 + R22 - R0 - R11)
        qz = 0.5 * root
        const invS = 0.5 / root
        qw = (R10 - R01) * invS
        qx = (R02 + R20) * invS
        qy = (R12 + R21) * invS
    end
	-----------------------------------------------------------

	writef16(cursor, x)
	writef16(cursor, y)
	writef16(cursor, z)
	writef16(cursor, qx)
	writef16(cursor, qy)
	writef16(cursor, qz)
	writef16(cursor, qw)
end

return table.freeze({
	START = start,
	FINISH = finish,
	ALLOC = alloc,

	U8 = writeu8,
	I8 = writei8,
	U16 = writeu16,
	I16 = writei16,
	F16 = writef16,
	F24 = writef24,
	U24 = writeu24,
	I24 = writeu24, -- write process is the same, the read isn't
	U32 = writeu32,
	I32 = writei32,
	U40 = writeu40,
	I40 = writeu40, -- same thing here, the same write process
	U48 = writeu48,
	I48 = writeu48,
	F32 = writef32,
	F64 = writef64,
	STR_S = writes255,
	STR = writes65,

	V2F32 = writev2f32,
	V2F24 = writev2f24,
	V2F16 = writev2f16,
	VF32 = writevf32,
	VF24 = writevf24,
	VF16 = writevf16,
	COLOR3 = writecolor3,
	CF32 = writecf32,
	CF24 = writecf24,
	CF16 = writecf16,
	QCF32 = writeqcf32,
	QCF24 = writeqcf24,
	QCF16 = writeqcf16,
})
