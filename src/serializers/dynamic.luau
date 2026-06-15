--!strict
--!optimize 2
--[[
	Dynamic V0.1.0

	Schemaless serializer for OmniSentry
	Uses dynanode for dynamic behaviour
]]
-----------------------------------------------------
-- SERVICES                                        --
-----------------------------------------------------
const EncodingService = game:GetService("EncodingService")
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
const dynanode = require("../shared/dynanode")
const config = require("../shared/config")
const exports = require("../shared/exports")
const reader = require("../buffer/reader")
const writer = require("../buffer/writer")

-----------------------------------------------------
-- TYPES                                           --
-----------------------------------------------------
type cursor = exports.cursor
-----------------------------------------------------
-- CONSTANTS                                       --
-----------------------------------------------------
const FAIL: number = config.fail
const EOR: number = config.eor
const ALG: Enum.CompressionAlgorithm = Enum.CompressionAlgorithm.Zstd

-----------------------------------------------------
-- LOCALIZATIONS                                   --
-----------------------------------------------------
const PACK: <V>(...V) -> { [number]: V, n: number } = table.pack
const UNPACK: <V>({ V }, number?, number?) -> ...V = table.unpack
const DYNANODE_WRITE: (cursor, any) -> number = dynanode.write
const W_START: (number?) -> cursor = writer.START
const W_FINISH: (cursor) -> buffer = writer.FINISH
const R_START: (buffer, number?) -> cursor = reader.START
const LEN: (buffer) -> number = buffer.len

-----------------------------------------------------
-- API                                             --
-----------------------------------------------------
const dynamic = {}

@native
function dynamic.serialize(compressionLevel: number?, offset: number?, ...: any): buffer?
	const input: { [number]: any, n: number } = PACK(...)
	const n: number = input.n

	const cursor: cursor = W_START(offset)
	for i = 1, n do
		const value: any = input[i]
		const flag: number = DYNANODE_WRITE(cursor, value)
		if flag == FAIL then
			return nil
		end
	end
	local b: buffer = W_FINISH(cursor)
	if compressionLevel then
		b = EncodingService:CompressBuffer(b, ALG, compressionLevel)
	end

	return b
end

@native
function dynamic.deserialize(wasCompressed: boolean?, offset: number?, input: buffer): ...any
	const output: { any } = {}
	if wasCompressed then
		input = EncodingService:DecompressBuffer(input, ALG)
	end
	if LEN(input) - (offset or 0) == 0 then
		-- empty buffer
		return
	end
	const cursor: cursor = R_START(input, offset)
	local i: number = 0
	while true do
		i += 1
		local flag: number
		flag, output[i] = dynanode.read(cursor)
		if flag == FAIL then
			return
		elseif flag == EOR then
			break
		end
	end
	return UNPACK(output, 1, i)
end

return table.freeze(dynamic)
