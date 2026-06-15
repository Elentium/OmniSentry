--!strict
--!optimize 2
--[[
	CFrameF16
	24 bytes
	matrix cframe with float16 components
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

const VAL_TYPE: string = "CFrame"

-----------------------------------------------------
-- LOCALIZING                                      --
-----------------------------------------------------
const TYPE: <T>(T) -> string = typeof
const ALLOC: (cursor, number) -> () = writer.ALLOC
const WRITE_CF: (cursor, CFrame) -> () = writer.CF16
const READ_CF: (cursor) -> (number, CFrame?) = reader.CF16
const FAIL_FN: (<T...>(T...) -> ()) | (<T>(T, number?) -> never) = config.failFn


-----------------------------------------------------
-- READ/WRITE                                      --
-----------------------------------------------------
@native
const function cframef16_write(cursor: cursor, value: CFrame): number
	const vType: string = TYPE(value)
	if vType ~= VAL_TYPE then
		FAIL_FN(`[OmniSentry]: Failed to serialize CFrameF16 type – "CFrame" expected, got "{vType}"`, 0)
		return FAIL
	end
	ALLOC(cursor, 24)
	WRITE_CF(cursor, value)

	return SUCCESS
end

return table.freeze({
	write = cframef16_write,
	read = READ_CF,
	exType = "CFrame"
})
