--!strict
--!optimize 2
--[[
	Unsigned 8-bit integer
	1 byte
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

const NUM_TYPE: string = "number"

-----------------------------------------------------
-- LOCALIZING                                      --
-----------------------------------------------------
const TYPE: <T>(T) -> string = type
const ALLOC: (cursor, number) -> () = writer.ALLOC
const WRITE: (cursor, number) -> () = writer.U8
const READ: (cursor) -> (number, number?) = reader.U8
const FAIL_FN: (<T...>(T...) -> ()) | (<T>(T, number?) -> never) = config.failFn


-----------------------------------------------------
-- READ/WRITE                                      --
-----------------------------------------------------
@native
const function uint8_write(cursor: cursor, value: number): number
	const vType: string = TYPE(value)
	if vType ~= NUM_TYPE then
		FAIL_FN(`[OmniSentry]: Failed to serialize UInt8 type – "number" expected, got "{vType}"`, 0)
		return FAIL
	end
	ALLOC(cursor, 1)
	WRITE(cursor, value)
	return SUCCESS
end

return table.freeze({
	write = uint8_write,
	read = READ, -- avoid possible extra function call
	exType = "int"
})
