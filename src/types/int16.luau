--!strict
--!optimize 2
--[[
	Signed 16-bit integer
	2 bytes
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
const WRITE: (cursor, number) -> () = writer.I16
const READ: (cursor) -> (number, number?) = reader.I16
const FAIL_FN: (<T...>(T...) -> ()) | (<T>(T, number?) -> never) = config.failFn


-----------------------------------------------------
-- READ/WRITE                                      --
-----------------------------------------------------
@native
const function int16_write(cursor: cursor, value: number): number
	const vType: string = TYPE(value)
	if vType ~= NUM_TYPE then
		FAIL_FN(`[OmniSentry]: Failed to serialize Int16 type – "number" expected, got "{vType}"`, 0)
		return FAIL
	end
	ALLOC(cursor, 2)
	WRITE(cursor, value)
	return SUCCESS
end

return table.freeze({
	write = int16_write,
	read = READ, -- avoid possible extra function call
	exType = "int"
})
