--!strict
--!optimize 2
--[[
	Array
	2 + vSize(n) bytes

	max 65535 elements
]]
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
const config = require("../shared/config")
const writer = require("../buffer/writer")
const reader = require("../buffer/reader")
const exports = require("../shared/exports")

-----------------------------------------------------
-- TYPES                                           --
-----------------------------------------------------
type typeNode<T = any> = exports.typeNode<T>
type cursor = exports.cursor
-----------------------------------------------------
-- CONSTANTS                                       --
-----------------------------------------------------
const SUCCESS: number = config.success
const FAIL: number = config.fail

const VAL_TYPE: string = "table"

const MAX_LEN: number = 0xFFFF

-----------------------------------------------------
-- LOCALIZING                                      --
-----------------------------------------------------
const TYPE: <T>(T) -> string = type
const ALLOC: (cursor, number) -> () = writer.ALLOC
const WRITE_U16: (cursor, number) -> () = writer.U16
const READ_U16: (cursor) -> (number, number?) = reader.U16
const CREATE: typeof(table.create) = table.create
const FAIL_FN: (<T...>(T...) -> ()) | (<T>(T, number?) -> never) = config.failFn


@native
const function arrayNodeBuild<T>(valueType: typeNode<T>): typeNode<{ T }>
	const valWrite: (cursor, T?) -> number = valueType.write
	const valRead: (cursor, number?) -> (number, T?) = valueType.read

	-----------------------------------------------------
	-- READ/WRITE                                      --
	-----------------------------------------------------
	@native
	const function array_write(cursor: cursor, value: { T }): number
		const vType: string = TYPE(value)
		if vType ~= VAL_TYPE then
			FAIL_FN(`[OmniSentry]: Failed to serialize Array type – "table" expected, got "{vType}"`, 0)
			return FAIL
		end

		const len: number = #value
		if len > MAX_LEN then
			FAIL_FN(
				`[OmniSentry]: Failed to serialize Array type – array length exceeds max limit; length: {len}, limit: {MAX_LEN}`,
				0
			)
			return FAIL
		end
		ALLOC(cursor, 2)
		WRITE_U16(cursor, len)
		for i: number, v: any in value do
			if valWrite(cursor, v) == FAIL then
				return FAIL
			end
		end
		return SUCCESS
	end

	@native
	const function array_read(cursor: cursor, _lastFlag: number?): (number, { T }?)
		const flag: number, len: number? = READ_U16(cursor)
		if flag == FAIL then
			return FAIL, nil
		end
		const array: { T } = CREATE(len :: number)
		local rflag: number = flag

		for i = 1, len :: number do
			rflag, array[i] = valRead(cursor)
			if rflag == FAIL then
				return FAIL, nil
			end
		end

		return rflag, array
	end

	return table.freeze({
		write = array_write,
		read = array_read,
		exType = "array"
	}) :: typeNode<{ T }>
end


return arrayNodeBuild
