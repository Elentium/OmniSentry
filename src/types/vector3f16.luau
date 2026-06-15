--!strict
--!optimize 2
--[[
	vector3f16
	roblox Vector3 type
	6 bytes
	each axis is serialized as float16
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

const VAL_TYPE: string = "vector"

-----------------------------------------------------
-- LOCALIZING                                      --
-----------------------------------------------------
const TYPE: <T>(T) -> string = type
const ALLOC: (cursor, number) -> () = writer.ALLOC
const WRITE_VEC: (cursor, vector | Vector3) -> () = writer.VF16
const READ_VEC: (cursor) -> (number, vector?) = reader.VF16
const FAIL_FN: (<T...>(T...) -> ()) | (<T>(T, number?) -> never) = config.failFn


-----------------------------------------------------
-- READ/WRITE                                      --
-----------------------------------------------------
@native
const function vector3f16_write(cursor: cursor, value: Vector3): number
	const vType: string = TYPE(value)
	if vType ~= VAL_TYPE then
		FAIL_FN(`[OmniSentry]: Failed to serialize Vector3F16 type – "vector" expected, got "{vType}"`, 0)
		return FAIL
	end
	ALLOC(cursor, 6)
	WRITE_VEC(cursor, value)
	return SUCCESS
end

return table.freeze({
	write = vector3f16_write,
	read = READ_VEC,
	exType = "Vector3"
})
