--!strict
--!optimize 2
--[[
	string
	2 + strlen bytes

	max amount of 65535 characters
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

const LEN_LIMIT: number = 0xFFFF

-----------------------------------------------------
-- LOCALIZING                                      --
-----------------------------------------------------
const TYPE: <T>(T) -> string = type
const ALLOC: (cursor, number) -> () = writer.ALLOC
const WRITE: (cursor, string, number) -> () = writer.STR
const READ: (cursor) -> (number, string?) = reader.STR
const FAIL_FN: (<T...>(T...) -> ()) | (<T>(T, number?) -> never) = config.failFn


-----------------------------------------------------
-- READ/WRITE                                      --
-----------------------------------------------------
@native
const function string_write(cursor: cursor, value: string): number
	const vType: string = TYPE(value)
	if vType ~= VAL_TYPE then
		FAIL_FN(`[OmniSentry]: Failed to serialize String type – "string" expected, got "{vType}"`, 0)
		return FAIL
	end

	const len: number = #value
	if len > LEN_LIMIT then
		FAIL_FN(
			`[OmniSentry]: Failed to serialize String type – String max length is 65535, input value length is {len}`,
			0
		)
		return FAIL
	end
	ALLOC(cursor, 2 + len)
	WRITE(cursor, value, len)
	return SUCCESS
end

return table.freeze({
	write = string_write,
	read = READ, -- avoid possible extra function call
	exType = "string"
})
