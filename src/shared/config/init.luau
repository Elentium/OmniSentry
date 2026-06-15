--!strict
--!optimize 2
--[[
	OmniSentry Configuration Module
]]
const constants = require("@self/constants")
const typeSigns = require("@self/typeSigns")
const createFailFn = require("@self/failFn")

local config = {
	-- constants
	startingBufferSize = constants.startingBufferSize,
	bufferExpandMultiplier = constants.bufferExpandMultiplier,
	strictMode = constants.strictMode,
	dynamicVectorType = constants.dynamicVectorType,
	dynamicInstanceType = constants.dynamicInstanceType,
	unknownType = constants.unknownType,
	success = constants.success,
	fail = constants.fail,
	eor = constants.eor,
	unsupportedUnionExTypes = constants.unsupportedUnionExTypes,
	instanceIdAttribute = constants.instanceIdAttribute,

	editableConstantsMap = {
		startingBufferSize = "number",
		bufferExpandMultiplier = "number",
		strictMode = "boolean",
		dynamicVectorType = "string",
		dynamicInstanceType = "string",
		unsupportedUnionExTypes = "table",
	},

	-- type signs
	typeSigns = typeSigns,
}

config.failFn = createFailFn(config)

return config
