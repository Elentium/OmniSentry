--!strict
--!optimize 2
--[[
    Union
    1 + nodeSize bytes

    max of 255 possible unions

    each node.exType must be unique; otherwise cannot determine the node for the input value
]]
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
const config = require("../shared/config")
const extypeof = require("../shared/extypeof")
const exports = require("../shared/exports")
const writer = require("../buffer/writer")
const reader = require("../buffer/reader")

-----------------------------------------------------
-- TYPES                                           --
-----------------------------------------------------
type typeNode<T = any> = exports.typeNode<T>
type unionOfPack<T> = exports.unionOfPack<T>
type cursor = exports.cursor

-----------------------------------------------------
-- CONSTANTS                                       --
-----------------------------------------------------
const FAIL: number = config.fail
const UNSUPPORTED_EXTYPES: { [string]: boolean } = config.unsupportedUnionExTypes :: { [string]: boolean }

-----------------------------------------------------
-- LOCALIZATIONS                                   --
-----------------------------------------------------
const WRITE: (cursor, number) -> () = writer.U8
const READ: (cursor) -> (number, number?) = reader.U8
const FAIL_FN: (<T...>(T...) -> ()) | (<T>(T, number?) -> never) = config.failFn

const ALLOC: (cursor, number) -> () = writer.ALLOC

-----------------------------------------------------
-- API                                             --
-----------------------------------------------------
@native local function unionNodeBuild<T...>(...: T...): typeNode<unionOfPack<(T...) -> ()>>
    const variants: { typeNode } = { ... } :: { typeNode }
    const exTypeMap: { [string]: typeNode } = {}
    const signMap: { [typeNode]: number } = {}

    for i: number, variant: typeNode in variants do
        const exType: string = variant.exType
        if exTypeMap[exType] then
            error(`[OmniSentry]: Union type node build failed – The variants include duplicate ExType while proper type node cannot be inferred for duplicate ExTypes; duplicate exType: {variant.exType}`, 0)
        elseif UNSUPPORTED_EXTYPES[exType] then
            error(`[OmniSentry]: Union type node build failed – Unsupported union type: {exType}`, 0)
		end
        exTypeMap[exType] = variant
        signMap[variant] = i
    end

    @native local function union_write(cursor: cursor, value: unionOfPack<(T...) -> ()>): number
        const exType: string = extypeof(value)
        const node: typeNode = exTypeMap[exType]
        if not node then
            FAIL_FN(`[OmniSentry]: Failed to serialize Union type – Variant for the input value not found, ExType: {exType}`, 0)
            return FAIL
        end

        ALLOC(cursor, 1)
        local sign: number = signMap[node]
        WRITE(cursor, sign)
        return node.write(cursor, value)
    end

    @native local function union_read(cursor: cursor, _lastFlag: number?): (number, unionOfPack<(T...) -> ()>?)
        local flag: number, sign: number? = READ(cursor)
        if flag == FAIL then
            return FAIL, nil
        end

        local node: typeNode = variants[sign :: number]
        if not node then
            FAIL_FN(`[OmniSentry]: Failed to serialize Union type - Invalid sign, Variant Node not found; sign: {sign}`, 0)
            return FAIL, nil
        end

        return node.read(cursor)
    end

    return table.freeze({
        write = union_write,
        read = union_read,
        exType = "union"
    }) :: typeNode<unionOfPack<(T...) -> ()>>
end

return unionNodeBuild
