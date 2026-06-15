--!strict
--!optimize 2
--[[
	vector2f24
	roblox Vector2 type
	6 bytes
	each axis is serialized as float24
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

const VAL_TYPE: string = "Vector2"

-----------------------------------------------------
-- LOCALIZING                                      --
-----------------------------------------------------
const TYPE: <T>(T) -> string = typeof
const ALLOC: (cursor, number) -> () = writer.ALLOC
const WRITE_V2: (cursor, Vector2) -> () = writer.V2F24
const READ_V2: (cursor) -> (number, Vector2?) = reader.V2F24
const FAIL_FN: (<T...>(T...) -> ()) | (<T>(T, number?) -> never) = config.failFn


-----------------------------------------------------
-- READ/WRITE                                      --
-----------------------------------------------------
@native
const function vector2f24_write(cursor: cursor, value: Vector2): number
	const vType: string = TYPE(value)
	if vType ~= VAL_TYPE then
		FAIL_FN(`[OmniSentry]: Failed to serialize Vector2F24 type – "Vector2" expected, got "{vType}"`, 0)
		return FAIL
	end
	ALLOC(cursor, 6)
	WRITE_V2(cursor, value)
	return SUCCESS
end

return table.freeze({
	write = vector2f24_write,
	read = READ_V2,
	exType = "Vector2"
})
