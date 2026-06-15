--!strict
--!optimize 2
--[[
	Static V0.1.0

	Schematized serializer for OmniSentry
	Faster compared to Dynamic serializer as it has no type inferring overhead
]]
-----------------------------------------------------
-- SERVICES                                        --
-----------------------------------------------------
const EncodingService = game:GetService("EncodingService")

-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
const exports = require("../shared/exports")
const writer = require("../buffer/writer")
const reader = require("../buffer/reader")
const config = require("../shared/config")

-----------------------------------------------------
-- CONSTANTS                                       --
-----------------------------------------------------
const ALG: Enum.CompressionAlgorithm = Enum.CompressionAlgorithm.Zstd
const FAIL: number = config.fail
-----------------------------------------------------
-- TYPES                                           --
-----------------------------------------------------
type serializer = exports.staticSerializer
type cursor = exports.cursor
type typeNode<T = any> = exports.typeNode<T>
type extractTypeFromTypeNode<T> = exports.extractTypeFromTypeNode<T>
-----------------------------------------------------
-- LOCALIZE                                        --
-----------------------------------------------------
const W_FINISH: (cursor: cursor) -> buffer = writer.FINISH
const W_START: (number?) -> cursor = writer.START
const R_START: (buffer, number?) -> cursor = reader.START
-----------------------------------------------------
-- API                                             --
-----------------------------------------------------
const static = {}

@native
function static.deserialize<T>(serdes: typeNode & T, input: buffer, offset: number?, wasCompressed: boolean?): extractTypeFromTypeNode<T>?
	if wasCompressed then
		input = EncodingService:DecompressBuffer(input, ALG)
	end
	const cursor: cursor = R_START(input, offset)
	const _, result: T? = serdes.read(cursor)

	return result
end

@native
function static.serialize<T>(serdes: typeNode<T>, input: T, offset: number?, compressionLevel: number?): buffer?
	const cursor: cursor = W_START(offset)
	const flag: number = serdes.write(cursor, input)
	if flag == FAIL then
		return nil
	end
	local b: buffer = W_FINISH(cursor)
	if compressionLevel then
		b = EncodingService:CompressBuffer(b, ALG, compressionLevel)
	end
	return b
end

return table.freeze(static)
