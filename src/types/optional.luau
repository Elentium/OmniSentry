--!strict
--!optimize 2
--[[
	Optional mark
	1 + nodeSize? bytes

	1 if value exists 0 if not

	if value does not exist, it takes only 1 byte
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

-----------------------------------------------------
-- LOCALIZING                                      --
-----------------------------------------------------
const ALLOC: (cursor, number) -> () = writer.ALLOC
const WRITE: (cursor, number) -> () = writer.U8
const READ: (cursor) -> (number, number?) = reader.U8

@native
const function optionalNodeBuild<T>(node: typeNode<T>): typeNode<T?>
	const innerWrite: (cursor, T?) -> number = node.write
	const innerRead: (cursor, number?) -> (number, T?) = node.read

	-----------------------------------------------------
	-- READ/WRITE                                      --
	-----------------------------------------------------
	@native
	const function optional_write(cursor: cursor, value: T?): number
		ALLOC(cursor, 1)
		const sign: number = value ~= nil and 1 or 0
		WRITE(cursor, sign)

		if value ~= nil then
			return innerWrite(cursor, value)
		end
		return SUCCESS
	end

	@native
	const function optional_read(cursor: cursor, _lastFlag: number?): (number, T?)
		const flag: number, sign: number? = READ(cursor)
		if flag == FAIL then
			return FAIL, nil
		end

		if sign == 1 then
			return innerRead(cursor)
		end
		return flag, nil
	end

	return table.freeze({
		write = optional_write,
		read = optional_read,
		exType = "optional"
	}) :: typeNode<T?>
end

return optionalNodeBuild
