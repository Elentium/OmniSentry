--!strict
--!optimize 2
--[[
	color3
	3 bytes
	each channel is serialized as uint8
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

const VAL_TYPE: string = "Color3"

-----------------------------------------------------
-- LOCALIZING                                      --
-----------------------------------------------------
const TYPE: <T>(T) -> string = typeof
const ALLOC: (cursor, number) -> () = writer.ALLOC
const WRITE: (cursor, Color3) -> () = writer.COLOR3
const READ: (cursor) -> (number, Color3?) = reader.COLOR3
const FAIL_FN: (<T...>(T...) -> ()) | (<T>(T, number?) -> never) = config.failFn


-----------------------------------------------------
-- READ/WRITE                                      --
-----------------------------------------------------
@native
const function color3_write(cursor: cursor, value: Color3): number
	const vType: string = TYPE(value)
	if vType ~= VAL_TYPE then
		FAIL_FN(`[OmniSentry]: Failed to serialize Color3 type – "Color3" expected, got "{vType}"`, 0)
		return FAIL
	end
	ALLOC(cursor, 3)
	WRITE(cursor, value)
	return SUCCESS
end

return table.freeze({
	write = color3_write,
	read = READ,
	exType = "Color3"
})
