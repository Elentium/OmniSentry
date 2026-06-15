--!strict
--!optimize 2
--[[
	Boolean
	1 byte
	simple true/false value
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

const VAL_TYPE: string = "boolean"

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
const function boolean_write(cursor: cursor, value: boolean): number
	const vType: string = TYPE(value)
	if vType ~= VAL_TYPE then
		FAIL_FN(`[OmniSentry]: Failed to serialize Boolean type – "boolean" expected, got "{vType}"`, 0)
		return FAIL
	end
	ALLOC(cursor, 1)
	WRITE(cursor, value and 1 or 0)
	return SUCCESS
end

@native
const function boolean_read(cursor: cursor, _lastFlag: number?): (number, boolean?)
	const flag: number, value: number? = READ(cursor)
	if flag == FAIL then
		return flag, nil
	end
	return flag, value == 1
end

return table.freeze({
	write = boolean_write,
	read = boolean_read,
	exType = "boolean"
})
