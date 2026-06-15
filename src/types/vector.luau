--!strict
--!optimize 2
--[[
	vector
	roblox vector type
	12 bytes
	each axis is serialized as float32
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
const WRITE_VEC: (cursor, vector | Vector3) -> () = writer.VF32
const READ_VEC: (cursor) -> (number, vector?) = reader.VF32
const FAIL_FN: (<T...>(T...) -> ()) | (<T>(T, number?) -> never) = config.failFn


-----------------------------------------------------
-- READ/WRITE                                      --
-----------------------------------------------------
@native
const function vector_write(cursor: cursor, value: vector): number
	const vType: string = TYPE(value)
	if vType ~= VAL_TYPE then
		FAIL_FN(`[OmniSentry]: Failed to serialize Vector type – "vector" expected, got "{vType}"`, 0)
		return FAIL
	end
	ALLOC(cursor, 12)
	WRITE_VEC(cursor, value)
	return SUCCESS
end

return table.freeze({
	write = vector_write,
	read = READ_VEC,
	exType = "Vector3"
})
