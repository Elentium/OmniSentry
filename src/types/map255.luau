--!strict
--!optimize 2
--[[
	Key-value Map
	1 + nodeSize(n) bytes
	max amount of 255 entries
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

-----------------------------------------------------
-- LOCALIZING                                      --
-----------------------------------------------------
const TYPE: <T>(T) -> string = type
const ALLOC: (cursor, number) -> () = writer.ALLOC
const WRITE_LEN: (cursor, number) -> () = writer.U8
const READ_LEN: (cursor) -> (number, number?) = reader.U8
const FAIL_FN: (<T...>(T...) -> ()) | (<T>(T, number?) -> never) = config.failFn


@native
const function map255NodeBuild<K, V>(keyType: typeNode<K>, valueType: typeNode<V>): typeNode
	const valWrite: (cursor, V) -> number = valueType.write
	const valRead: (cursor, number?) -> (number, V?) = valueType.read
	const keyWrite: (cursor, K) -> number = keyType.write
	const keyRead: (cursor, number?) -> (number, K?) = keyType.read

	-----------------------------------------------------
	-- READ/WRITE                                      --
	-----------------------------------------------------
	@native
	const function map255_write(cursor: cursor, value: { [K]: V }): number
		const vType: string = TYPE(value)
		if vType ~= VAL_TYPE then
			FAIL_FN(`[OmniSentry]: Failed to serialize Map255 type – "table" expected, got "{vType}"`, 0)
			return FAIL
		end

		local len: number = 0
		for _ in value do
			len += 1
		end
		if len > 0xFF then
			FAIL_FN(
				`[OmniSentry]: Failed to serialize Map255 type – Map255 max length is 255, input value length is {len}`,
				0
			)
			return FAIL
		end
		ALLOC(cursor, 1)
		WRITE_LEN(cursor, len)
		for k: K, v: V in value do
			if keyWrite(cursor, k) == FAIL then
				return FAIL
			elseif valWrite(cursor, v) == FAIL then
				return FAIL
			end
		end

		return SUCCESS
	end

	@native
	const function map255_read(cursor: cursor, _lastFlag: number?): (number, { [K]: V }?)
		local flag: number, len: number? = READ_LEN(cursor)
		if flag == FAIL then
			return FAIL, nil
		end
		const tbl: { [K]: V } = {}

		for i = 1, len :: number do
			local key: K?, val: V?
			flag, key = keyRead(cursor)
			flag, val = valRead(cursor)
			if flag == FAIL then
				return FAIL, nil
			end
			tbl[key] = val
		end

		return flag, tbl
	end

	return table.freeze({
		write = map255_write,
		read = map255_read,
		exType = "map"
	}) :: typeNode
end

return map255NodeBuild
