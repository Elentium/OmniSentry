--!strict
--!optimize 2
--[[
    Quaternion CFrame F16
	14 bytes
    each component is serialized as float16
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
const WRITE_QCF: (cursor, CFrame) -> () = writer.QCF16
const READ_QCF: (cursor) -> (number, CFrame?) = reader.QCF16
const FAIL_FN: (<T...>(T...) -> ()) | (<T>(T, number?) -> never) = config.failFn


-----------------------------------------------------
-- READ/WRITE                                      --
-----------------------------------------------------
@native
const function qcframef16_write(cursor: cursor, value: CFrame): number
	const vType: string = TYPE(value)
	if vType ~= VAL_TYPE then
		FAIL_FN(`[OmniSentry]: Failed to serialize QCFrameF16 type – "CFrame" expected, got "{vType}"`, 0)
		return FAIL
	end
	ALLOC(cursor, 14)
	WRITE_QCF(cursor, value)

	return SUCCESS
end

return table.freeze({
	write = qcframef16_write,
	read = READ_QCF,
	exType = "CFrame"
})
