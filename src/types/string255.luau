--!strict
--!optimize 2
--[[
	string255
	1 + strlen bytes
	max amount of 255 characters
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

const VAL_TYPE: string = "string"

const LEN_LIMIT: number = 0xFF

-----------------------------------------------------
-- LOCALIZING                                      --
-----------------------------------------------------
const TYPE: <T>(T) -> string = type
const ALLOC: (cursor, number) -> () = writer.ALLOC
const WRITE: (cursor, string, number) -> () = writer.STR_S
const READ: (cursor) -> (number, string?) = reader.STR_S
const FAIL_FN: (<T...>(T...) -> ()) | (<T>(T, number?) -> never) = config.failFn


-----------------------------------------------------
-- READ/WRITE                                      --
-----------------------------------------------------
@native
const function string255_write(cursor: cursor, value: string): number
	const vType: string = TYPE(value)
	if vType ~= VAL_TYPE then
		FAIL_FN(`[OmniSentry]: Failed to serialize String255 type – "string" expected, got "{vType}"`, 0)
		return FAIL
	end

	const len: number = #value
	if len > LEN_LIMIT then
		FAIL_FN(
			`[OmniSentry]: Failed to serialize String255 type – String255 max length is 255, input value length is {len}`,
			0
		)
		return FAIL
	end
	ALLOC(cursor, 1 + len)
	WRITE(cursor, value, len)
	return SUCCESS
end

return table.freeze({
	write = string255_write,
	read = READ, -- avoid possible extra function call
	exType = "string"
})
