--!strict
--!optimize 2
--[[
	BooleanPacked
	1 byte
	8 packed booleans in 1 byte
]]
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
const config = require("../shared/config")
const exports = require("../shared/exports")
const writer = require("../buffer/writer")
const reader = require("../buffer/reader")

-----------------------------------------------------
-- TYPES                                           --
-----------------------------------------------------
type cursor = exports.cursor
-----------------------------------------------------
-- CONSTANTS                                       --
-----------------------------------------------------
const SUCCESS: number = config.success
const FAIL: number = config.fail

const VAL_TYPE: string = "table"

-----------------------------------------------------
-- LOCALIZING                                      --
-----------------------------------------------------
const TYPE: <T>(T) -> string = type
const ALLOC: (cursor, number) -> () = writer.ALLOC
const WRITE: (cursor, number) -> () = writer.U8
const READ: (cursor) -> (number, number?) = reader.U8
const FAIL_FN: (<T...>(T...) -> ()) | (<T>(T, number?) -> never) = config.failFn

const OR: (...number) -> number = bit32.bor
const LSHIFT: (number, number) -> number = bit32.lshift
const EXTRACT: (number, number, number?) -> number = bit32.extract

-----------------------------------------------------
-- READ/WRITE                                      --
-----------------------------------------------------
@native
const function booleanPacked_write(cursor: cursor, value: { boolean }): number
	const vType: string = TYPE(value)
	if vType ~= VAL_TYPE then
		FAIL_FN(`[OmniSentry]: Failed to serialize BooleanPacked type – "table" expected, got "{vType}"`, 0)
		return FAIL
	end
	ALLOC(cursor, 1)
    local byte: number = 0
    for i: number, bool: boolean in value do
        byte = OR(byte, LSHIFT(bool and 1 or 0, i - 1))
    end
	WRITE(cursor, byte)
	return SUCCESS
end

@native
const function booleanPacked_read(cursor: cursor, _lastFlag: number?): (number, { boolean }?)
	const flag: number, byte: number? = READ(cursor)
	if flag == FAIL then
		return flag, nil
	end
    local boolPack: { boolean } = {}
    for i = 0, 7 do
		boolPack[i + 1] = EXTRACT(byte :: number, i) == 1
    end
	return flag, boolPack
end

return table.freeze({
	write = booleanPacked_write,
	read = booleanPacked_read,
	exType = "array"
})
