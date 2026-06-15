--!strict
--!optimize 2
--[[
	Enum
	
    2 bytes
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
type typeNode<T = any> = exports.typeNode<T>
type getItemType<T> = exports.getItemType<T>
type cursor = exports.cursor
-----------------------------------------------------
-- CONSTANTS                                       --
-----------------------------------------------------
const SUCCESS: number = config.success
const FAIL: number = config.fail

const VAL_TYPE: string = "Enum"
const VAL_TYPE2: string = "EnumItem"

-----------------------------------------------------
-- LOCALIZING                                      --
-----------------------------------------------------
const TYPE: <T>(T) -> string = typeof
const FAIL_FN: (<T...>(T...) -> ()) | (<T>(T, number?) -> never) = config.failFn

const ALLOC: (cursor, number) -> () = writer.ALLOC
const WRITE: (cursor, number) -> () = writer.U16
const READ: (cursor) -> (number, number?) = reader.U16
const TOSTRING: <T>(T) -> string = tostring

@native
const function enumNodeBuild<T>(input: T & Enum): typeNode<getItemType<T>>
	const enumType: string = TYPE(input)
	if enumType ~= VAL_TYPE then
		error(`[OmniSentry]: Failed to build Enum node – invalid input argument, Enum expected, got {enumType}`, 0)
	end

	-----------------------------------------------------
	-- READ/WRITE                                      --
	-----------------------------------------------------
	@native
	const function enum_write(cursor: cursor, value: getItemType<T> & EnumItem): number
		const vType: string = TYPE(value)
		if vType ~= VAL_TYPE2 then
			FAIL_FN(`[OmniSentry]: Failed to serialize Enum type – "EnumItem" expected, got "{vType}"`, 0)
			return FAIL
		end

		ALLOC(cursor, 2)
		WRITE(cursor, value.Value)

		return SUCCESS
	end

	@native
	const function enum_read(cursor: cursor, _lastFlag: number?): (number, getItemType<T>?)
		const flag: number, id: number? = READ(cursor)
		const enumItem: getItemType<T>? = flag ~= FAIL and input:FromValue(id :: number) or nil

		return flag, enumItem
	end

	return table.freeze({
		write = enum_write,
		read = enum_read,
		exType = "Enum." .. TOSTRING(input)
	}) :: typeNode<getItemType<T>>
end

return enumNodeBuild
