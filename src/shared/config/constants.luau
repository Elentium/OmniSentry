--!strict
--!optimize 2
--[[
	OmniSentry Constants
	Static configuration values with no dependencies.
]]
return {
	startingBufferSize = 64,
	bufferExpandMultiplier = 1.5,
	
	-- If true: overflows (and other writer failures) throw.
	-- If false: failures warn and return FAIL/nil style instead.
	strictMode = true,

	-- Which type will be inferred when the input value is a vector
	dynamicVectorType = "vector" :: "Vector3" | "vector",
	-- Which value will be inferred when the input value is an instance
	dynamicInstanceType = "instance" :: "serInstance" | "instance",

	-- Instance unique id attribute name
	instanceIdAttribute = "_VSID",

	unknownType = 0,
	success = 0,
	fail = 1,
	eor = 2,
	unsupportedUnionExTypes = {
		union = true,
		any = true,
		void = true,
		optional = true,
	},
}
