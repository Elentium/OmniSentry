--!strict
--!optimize 2
--[[
	CFrameF24
	36 bytes
	matrix cframe with float24 components
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
const WRITE_CF: (cursor, CFrame) -> () = writer.CF24
const READ_CF: (cursor) -> (number, CFrame?) = reader.CF24
const FAIL_FN: (<T...>(T...) -> ()) | (<T>(T, number?) -> never) = config.failFn


-----------------------------------------------------
-- READ/WRITE                                      --
-----------------------------------------------------
@native
const function cframef24_write(cursor: cursor, value: CFrame): number
	const vType: string = TYPE(value)
	if vType ~= VAL_TYPE then
		FAIL_FN(`[OmniSentry]: Failed to serialize CFrameF24 type – "CFrame" expected, got "{vType}"`, 0)
		return FAIL
	end
	ALLOC(cursor, 36)
	WRITE_CF(cursor, value)

	return SUCCESS
end

return table.freeze({
	write = cframef24_write,
	read = READ_CF,
	exType = "CFrame"
})
