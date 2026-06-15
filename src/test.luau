--!strict
--[[
	OmniSentry Test Suite

	One round-trip + performance test per type.
	Collection types: 1, 10, and 100 element variants.
	Multi-cursor section exercises writeStart / readStart with interleaved multi-session writes.
]]
--------------------------------------------------------------------------------
-- CONFIG
--------------------------------------------------------------------------------
const CONFIG = {
	PERF_ITERATIONS = 2_000,
	PERF_BUDGET_SCALE = 1.0,
	SEPARATOR_WIDTH = 80,
}

const BUDGET = {
	integer = 5,
	float = 8,
	string = 10,
	roblox = 15,
	complex = 25,
	instance = 20,
	collection = {
		[1] = 10,
		[10] = 25,
		[100] = 80,
	} :: { [number]: number },
	multiCursor = nil,
}

--------------------------------------------------------------------------------
-- DEPENDENCIES
--------------------------------------------------------------------------------
const OmniSentry = require("./")
const config = require("./shared/config")
const types = OmniSentry.types
const static = OmniSentry.static
const SUCCESS = config.success

const function ser(sd: OmniSentry.typeNode, v: any): buffer?
	return static.serialize(sd, v, nil, nil)
end
const function des(sd: OmniSentry.typeNode, b: buffer): any
	return static.deserialize(sd, b, nil, nil)
end

--------------------------------------------------------------------------------
-- FRAMEWORK
--------------------------------------------------------------------------------
const colors = {
	bg = Color3.fromHex("0b0d14"),
	panel = Color3.fromHex("13151f"),
	card = Color3.fromHex("1c2030"),
	border = Color3.fromHex("282d45"),
	accent = Color3.fromHex("6c63ff"),
	accentDim = Color3.fromHex("3b3880"),
	textPri = Color3.fromHex("e8eaf6"),
	textSec = Color3.fromHex("8b8fc4"),
	textDim = Color3.fromHex("454870"),
	pass = Color3.fromHex("3fb87a"),
	fail = Color3.fromHex("e05555"),
	slow = Color3.fromHex("e0a040"),
	crash = Color3.fromHex("c03030"),
}

type TestResult = {
	name: string,
	section: string,
	validityPass: boolean,
	perfPass: boolean,
	perfSkipped: boolean,
	avgUs: number,
	budgetUs: number?,
	crashed: boolean,
	crashMsg: string,
}

type SectionInfo = {
	name: string,
	tests: { TestResult },
}

type SuiteStats = {
	totalTests: number,
	validityPct: number,
	perfPct: number,
	overallPct: number,
}

const allSections: { SectionInfo } = {}
local currentSection: SectionInfo = { name = "", tests = {} }
const SEP = string.rep("─", CONFIG.SEPARATOR_WIDTH)

@native
const function computeSuiteStats(): SuiteStats
	local total = 0
	local vOk = 0
	local perfTotal = 0
	local pOk = 0
	local full = 0
	for _, sec in allSections do
		for _, r in sec.tests do
			total += 1
			if r.validityPass then
				vOk += 1
			end
			if not r.perfSkipped then
				perfTotal += 1
				if r.perfPass then
					pOk += 1
				end
			end
			local perfOk = r.perfSkipped or r.perfPass
			if r.validityPass and perfOk and not r.crashed then
				full += 1
			end
		end
	end
	if total == 0 then
		return { totalTests = 0, validityPct = 100, perfPct = 100, overallPct = 100 }
	end
	return {
		totalTests = total,
		validityPct = (vOk / total) * 100,
		perfPct = if perfTotal > 0 then (pOk / perfTotal) * 100 else 100,
		overallPct = (full / total) * 100,
	}
end

@native
const function bench(iters: number, fn: () -> ()): number
	fn()
	local t0 = os.clock()
	for _ = 1, iters do
		fn()
	end
	return ((os.clock() - t0) / iters) * 1_000_000
end

@native
const function section(name: string)
	currentSection = { name = name, tests = {} }
	table.insert(allSections, currentSection)
end

@native
const function test(name: string, budgetUs: number?, validityFn: () -> boolean, perfFn: () -> ())
	local perfSkipped = budgetUs == nil
	local scaledBudget: number? = if budgetUs then budgetUs * CONFIG.PERF_BUDGET_SCALE else nil

	local validityPass = false
	local crashed = false
	local crashMsg = ""
	local vOk, vErr = pcall(function()
		validityPass = validityFn()
	end)
	if not vOk then
		crashed = true
		crashMsg = tostring(vErr):sub(1, 120)
	end

	local avgUs = 0.0
	local perfPass = true
	if not perfSkipped then
		local pOk, pErr = pcall(function()
			avgUs = bench(CONFIG.PERF_ITERATIONS, perfFn)
		end)
		if not pOk then
			crashed = true
			crashMsg = crashMsg ~= "" and crashMsg or tostring(pErr):sub(1, 120)
		end
		perfPass = avgUs <= scaledBudget :: number
	end

	table.insert(currentSection.tests, {
		name = name,
		section = currentSection.name,
		validityPass = validityPass,
		perfPass = perfPass,
		perfSkipped = perfSkipped,
		avgUs = avgUs,
		budgetUs = scaledBudget,
		crashed = crashed,
		crashMsg = crashMsg,
	})
end

--------------------------------------------------------------------------------
-- HELPERS
--------------------------------------------------------------------------------
@native
const function approxEq(a: number, b: number, tol: number): boolean
	return math.abs(a - b) <= tol
end

@native
const function cframeFuzzyEq(a: CFrame, b: CFrame, epsilon: number): boolean
	return (a :: any):FuzzyEq(b, epsilon)
end

@native
const function roundTrip(serdes: any, check: (any) -> boolean, value: any): boolean
	local b = ser(serdes, value)
	if b == nil then
		return false
	end
	local d = des(serdes, b)
	if d == nil and value ~= nil then
		return false
	end
	return check(d)
end

@native
const function staticRoundTripPerf(serdes: OmniSentry.typeNode, value: any): ()
	local b = static.serialize(serdes, value, nil, nil)
	if b ~= nil then
		static.deserialize(serdes, b, nil, nil)
	end
end

@native
const function valuesEqual(a: any, b: any, tol: number?): boolean
	local ta = typeof(a)
	local tb = typeof(b)
	if ta ~= tb then
		return false
	end
	if a == b then
		return true
	end
	if ta == "number" then
		return if tol then approxEq(a, b, tol) else a == b
	elseif ta == "string" or ta == "boolean" then
		return a == b
	elseif ta == "Vector2" then
		local t = tol or 1e-4
		return approxEq(a.X, b.X, t) and approxEq(a.Y, b.Y, t)
	elseif ta == "Vector3" then
		local t = tol or 1e-4
		return approxEq(a.X, b.X, t) and approxEq(a.Y, b.Y, t) and approxEq(a.Z, b.Z, t)
	elseif ta == "vector" then
		local t = tol or 1e-4
		return approxEq(a.x, b.x, t) and approxEq(a.y, b.y, t) and approxEq(a.z, b.z, t)
	elseif ta == "Color3" then
		return math.floor(a.R * 255 + 0.5) == math.floor(b.R * 255 + 0.5)
			and math.floor(a.G * 255 + 0.5) == math.floor(b.G * 255 + 0.5)
			and math.floor(a.B * 255 + 0.5) == math.floor(b.B * 255 + 0.5)
	elseif ta == "CFrame" then
		return cframeFuzzyEq(a, b, tol or 1e-2)
	elseif ta == "EnumItem" then
		return a == b
	elseif ta == "Instance" then
		return a == b
	elseif ta == "table" then
		if #a > 0 or #b > 0 then
			if #a ~= #b then
				return false
			end
			for i = 1, #a do
				if not valuesEqual(a[i], b[i], tol) then
					return false
				end
			end
			return true
		end
		for k, va in a do
			if not valuesEqual(va, b[k], tol) then
				return false
			end
		end
		for k in b do
			if a[k] == nil then
				return false
			end
		end
		return true
	end
	return false
end

type TypeCase = {
	name: string,
	serdes: OmniSentry.typeNode,
	value: any,
	budget: number?,
	tol: number?,
	check: ((any) -> boolean)?,
}

@native
const function registerTypeCase(case: TypeCase)
	local check = case.check
	if not check then
		check = function(v: any): boolean
			return valuesEqual(v, case.value, case.tol)
		end
	end
	test(case.name, case.budget, function()
		return roundTrip(case.serdes, check :: any, case.value)
	end, function()
		staticRoundTripPerf(case.serdes, case.value)
	end)
end

@native
const function registerCollectionTests(
	prefix: string,
	serdes: OmniSentry.typeNode,
	makeValue: (number) -> any
)
	for _, n in { 1, 10, 100 } do
		local value = makeValue(n)
		local budget = BUDGET.collection[n] or 80
		test(`{prefix} ({n} elements)`, budget, function()
			return roundTrip(serdes, function(v)
				return valuesEqual(v, value)
			end, value)
		end, function()
			staticRoundTripPerf(serdes, value)
		end)
	end
end

@native
const function makeIntArray(n: number): { number }
	local t = table.create<<number>>(n)
	for i = 1, n do
		t[i] = i * 7 - 3
	end
	return t
end

@native
const function makeStringMap(n: number): { [string]: number }
	local t: { [string]: number } = {}
	for i = 1, n do
		t[`key{i}`] = i * 11
	end
	return t
end

@native
const function makeMap255(n: number): { [number]: boolean }
	local t: { [number]: boolean } = {}
	for i = 1, n do
		t[i] = i % 2 == 0
	end
	return t
end

type McWrite = {
	serdes: OmniSentry.typeNode,
	value: any,
	check: (any) -> boolean,
}

type McStep = {
	open: boolean?,
	cursor: number,
	write: McWrite,
}

@native
const function mcWrite(serdes: OmniSentry.typeNode, value: any, check: ((any) -> boolean)?, tol: number?): McWrite
	return {
		serdes = serdes,
		value = value,
		check = check or function(v: any): boolean
			return valuesEqual(v, value, tol)
		end,
	}
end

-- open=true calls writeStart() before writing to step.cursor (1-based index among open cursors).
@native
const function runInterleavedWrites(steps: { McStep }): ({ buffer }?, { { McWrite } }?)
	local writeCursors: { OmniSentry.cursor } = {}
	local ledger: { { McWrite } } = {}

	for _, step in steps do
		if step.open then
			table.insert(writeCursors, OmniSentry.writeStart())
			table.insert(ledger, {} :: { McWrite })
		end
		local wc = writeCursors[step.cursor]
		if wc == nil then
			return nil, nil
		end
		if step.write.serdes.write(wc, step.write.value) ~= SUCCESS then
			return nil, nil
		end
		table.insert(ledger[step.cursor], step.write)
	end

	local buffers: { buffer } = {}
	for i, wc in writeCursors do
		buffers[i] = OmniSentry.writeFinish(wc)
	end
	return buffers, ledger
end

@native
const function validateCursorLedger(buffers: { buffer }, ledger: { { McWrite } }, readOrder: { number }?): boolean
	local order: { number }
	if readOrder then
		order = readOrder
	else
		order = table.create(#buffers) :: { number }
		for i = 1, #buffers do
			order[i] = i
		end
	end

	for _, cursorIdx in order do
		local entries = ledger[cursorIdx]
		local buf = buffers[cursorIdx]
		if entries == nil or buf == nil then
			return false
		end
		local rc = OmniSentry.readStart(buf)
		for _, entry in entries do
			local _, out = entry.serdes.read(rc)
			if not entry.check(out) then
				return false
			end
		end
	end
	return true
end

@native
const function serPartMatches(out: Instance, src: Part): boolean
	if not out:IsA("Part") then
		return false
	end
	local p = out :: Part
	return p.Name == src.Name
		and approxEq(p.Transparency, src.Transparency, 1e-4)
		and approxEq(p.Reflectance, src.Reflectance, 1e-4)
		and cframeFuzzyEq(p.CFrame, src.CFrame, 1e-2)
		and p.Anchored == src.Anchored
		and math.floor(p.Color.R * 255 + 0.5) == math.floor(src.Color.R * 255 + 0.5)
		and math.floor(p.Color.G * 255 + 0.5) == math.floor(src.Color.G * 255 + 0.5)
		and math.floor(p.Color.B * 255 + 0.5) == math.floor(src.Color.B * 255 + 0.5)
end

--------------------------------------------------------------------------------
-- CONSOLE + UI
--------------------------------------------------------------------------------
const function printResults()
	local st = computeSuiteStats()
	print(SEP)
	print(
		string.format(
			"  OmniSentry Test Results   %d iterations/test   scale ×%.1f     |     Validity %.1f%%   Perf %.1f%%   Overall %.1f%%   (n=%d)",
			CONFIG.PERF_ITERATIONS,
			CONFIG.PERF_BUDGET_SCALE,
			st.validityPct,
			st.perfPct,
			st.overallPct,
			st.totalTests
		)
	)
	print(SEP)

	for _, sec in allSections do
		print("")
		print(SEP)
		print(string.format("  %s", sec.name))

		local secValidPass = true
		local secPerfCount = 0
		local secPerfOk = 0
		for _, r in sec.tests do
			if r.crashed or not r.validityPass then
				secValidPass = false
			end
			if not r.perfSkipped then
				secPerfCount += 1
				if not r.crashed and r.perfPass then
					secPerfOk += 1
				end
			end
		end
		local secPerfPass = secPerfCount == 0 or secPerfOk == secPerfCount
		local secPerfLabel = if secPerfCount == 0 then "SKIP" else tostring(secPerfPass)
		print(
			string.format("  ValidityPass: %-5s   PerformancePass: %s", tostring(secValidPass), secPerfLabel)
		)
		print(SEP)

		for _, r in sec.tests do
			if r.crashed then
				print(string.format("  [CRASH] %-50s  %s", r.name, r.crashMsg))
			else
				local vTag = if r.validityPass then "PASS" else "FAIL"
				if r.perfSkipped then
					print(string.format("  [%s] %-50s | SKIP", vTag, r.name))
				else
					local pTag = if r.perfPass then "PASS" else "SLOW"
					print(
						string.format(
							"  [%s] %-50s | %s | avg %7.2f µs (budget %7.2f µs)",
							vTag,
							r.name,
							pTag,
							r.avgUs,
							r.budgetUs :: number
						)
					)
				end
			end
		end
	end

	print("")
	print(SEP)
	print("  End of report")
	print(SEP)
end

const function frame(props: { [string]: any }): Frame
	local f = Instance.new("Frame")
	for k, v in props do
		(f :: any)[k] = v
	end
	return f
end

const function label(props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamMedium
	l.TextSize = 13
	l.TextColor3 = colors.textPri
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextTruncate = Enum.TextTruncate.AtEnd
	for k, v in props do
		(l :: any)[k] = v
	end
	return l
end

const function uiPadding(parent: Instance, h: number, v: number)
	local p = Instance.new("UIPadding")
	p.PaddingLeft = UDim.new(0, h)
	p.PaddingRight = UDim.new(0, h)
	p.PaddingTop = UDim.new(0, v)
	p.PaddingBottom = UDim.new(0, v)
	p.Parent = parent
end

const function uiList(parent: Instance, spacing: number, dir: Enum.FillDirection?)
	local l = Instance.new("UIListLayout")
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.FillDirection = dir or Enum.FillDirection.Vertical
	l.Padding = UDim.new(0, spacing)
	l.Parent = parent
end

const function uiCorner(parent: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = parent
end

const function uiStroke(parent: Instance, clr: Color3, thick: number)
	local s = Instance.new("UIStroke")
	s.Color = clr
	s.Thickness = thick
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
end

const function buildUI()
	local sg = Instance.new("ScreenGui")
	sg.Name = "OmniSentryTestResults"
	sg.ResetOnSpawn = false
	sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	sg.DisplayOrder = 100

	local bg = frame({
		Name = "Background",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = colors.bg,
		Parent = sg,
	})

	local win = frame({
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 860, 0.94, 0),
		BackgroundColor3 = colors.panel,
		Parent = bg,
	})
	uiCorner(win, 14)
	uiStroke(win, colors.border, 1)

	local titleBar = frame({
		Name = "TitleBar",
		Size = UDim2.new(1, 0, 0, 54),
		BackgroundColor3 = colors.card,
		Parent = win,
	})
	uiCorner(titleBar, 14)
	frame({
		Name = "BottomFill",
		Size = UDim2.new(1, 0, 0, 14),
		Position = UDim2.new(0, 0, 1, -14),
		BackgroundColor3 = colors.card,
		BorderSizePixel = 0,
		Parent = titleBar,
	})
	label({
		Name = "Title",
		Size = UDim2.new(1, -24, 1, 0),
		Position = UDim2.new(0, 0, 0, 0),
		Text = "  OmniSentry  ·  Test Results",
		TextSize = 16,
		Font = Enum.Font.GothamBold,
		TextColor3 = colors.textPri,
		Parent = titleBar,
	})

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Body"
	scroll.Position = UDim2.new(0, 0, 0, 54)
	scroll.Size = UDim2.new(1, 0, 1, -54)
	scroll.BackgroundTransparency = 1
	scroll.ScrollBarThickness = 5
	scroll.ScrollBarImageColor3 = colors.accentDim
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.ElasticBehavior = Enum.ElasticBehavior.Never
	scroll.BorderSizePixel = 0
	scroll.Parent = win
	uiPadding(scroll, 14, 10)
	uiList(scroll, 10)

	local statsBar = frame({
		Name = "StatsBar",
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundColor3 = colors.card,
		LayoutOrder = 0,
		Parent = scroll,
	})
	uiCorner(statsBar, 6)
	uiPadding(statsBar, 12, 0)
	local suiteStats = computeSuiteStats()
	label({
		Name = "StatsTextLeft",
		Size = UDim2.new(0.48, 0, 1, 0),
		Position = UDim2.new(0, 0, 0, 0),
		Text = string.format(
			"Iterations per test: %d    Budget scale: ×%.1f",
			CONFIG.PERF_ITERATIONS,
			CONFIG.PERF_BUDGET_SCALE
		),
		TextSize = 12,
		Font = Enum.Font.Gotham,
		TextColor3 = colors.textSec,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = statsBar,
	})
	label({
		Name = "StatsTextRight",
		Size = UDim2.new(0.52, 0, 1, 0),
		Position = UDim2.new(0.48, 0, 0, 0),
		Text = string.format(
			"Validity %.1f%%  ·  Perf %.1f%%  ·  Overall %.1f%%  ·  n=%d",
			suiteStats.validityPct,
			suiteStats.perfPct,
			suiteStats.overallPct,
			suiteStats.totalTests
		),
		TextSize = 12,
		Font = Enum.Font.Gotham,
		TextColor3 = colors.textSec,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = statsBar,
	})

	for sIdx, sec in allSections do
		local card = frame({
			Name = "Section_" .. sIdx,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = colors.card,
			LayoutOrder = sIdx,
			Parent = scroll,
		})
		uiCorner(card, 8)
		uiStroke(card, colors.border, 1)
		uiPadding(card, 12, 10)
		uiList(card, 0)

		local hdrRow = frame({
			Name = "Header",
			Size = UDim2.new(1, 0, 0, 30),
			BackgroundTransparency = 1,
			LayoutOrder = 0,
			Parent = card,
		})

		label({
			Name = "SectionName",
			Size = UDim2.new(0.5, 0, 1, 0),
			Text = sec.name,
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			TextColor3 = colors.textPri,
			Parent = hdrRow,
		})

		local secValidPass = true
		local secPerfCount = 0
		local secPerfOk = 0
		for _, r in sec.tests do
			if r.crashed or not r.validityPass then
				secValidPass = false
			end
			if not r.perfSkipped then
				secPerfCount += 1
				if not r.crashed and r.perfPass then
					secPerfOk += 1
				end
			end
		end
		local secPerfPass = secPerfCount == 0 or secPerfOk == secPerfCount

		local badgeRow = frame({
			Name = "Badges",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.new(0, 220, 0, 22),
			BackgroundTransparency = 1,
			Parent = hdrRow,
		})
		uiList(badgeRow, 6, Enum.FillDirection.Horizontal)

		const function badge(text: string, bg: Color3, fg: Color3, lo: number)
			local b = frame({
				Name = "Badge",
				Size = UDim2.new(0, 0, 1, 0),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundColor3 = bg,
				LayoutOrder = lo,
				Parent = badgeRow,
			})
			uiCorner(b, 5)
			uiPadding(b, 7, 0)
			label({
				Name = "Lbl",
				Size = UDim2.new(0, 0, 1, 0),
				AutomaticSize = Enum.AutomaticSize.X,
				Text = text,
				TextSize = 11,
				Font = Enum.Font.GothamBold,
				TextColor3 = fg,
				Parent = b,
			})
		end

		local vBg = if secValidPass then colors.pass else colors.fail
		local pBg = if secPerfCount == 0 then colors.textDim elseif secPerfPass then colors.pass else colors.slow
		badge("Validity: " .. (if secValidPass then "PASS" else "FAIL"), vBg, colors.bg, 1)
		badge(
			"Perf: " .. (if secPerfCount == 0 then "SKIP" elseif secPerfPass then "PASS" else "FAIL"),
			pBg,
			colors.bg,
			2
		)

		frame({
			Name = "Divider",
			Size = UDim2.new(1, 0, 0, 1),
			BackgroundColor3 = colors.border,
			LayoutOrder = 1,
			Parent = card,
		})

		local colHdr = frame({
			Name = "ColHeaders",
			Size = UDim2.new(1, 0, 0, 20),
			BackgroundTransparency = 1,
			LayoutOrder = 2,
			Parent = card,
		})
		const function colLabel(txt: string, xAnchor: number, xPos: number, xSize: number)
			label({
				Name = txt,
				AnchorPoint = Vector2.new(xAnchor, 0.5),
				Position = UDim2.new(xPos, 0, 0.5, 0),
				Size = UDim2.new(xSize, 0, 0.8, 0),
				Text = txt,
				TextSize = 10,
				Font = Enum.Font.Gotham,
				TextColor3 = colors.textDim,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = colHdr,
			})
		end
		colLabel("Test", 0, 0, 0.50)
		colLabel("Valid", 0, 0.51, 0.07)
		colLabel("Perf", 0, 0.60, 0.07)
		colLabel("Avg µs", 0, 0.68, 0.15)
		colLabel("Budget", 0, 0.84, 0.16)

		for rIdx, r in sec.tests do
			local rowBg = if rIdx % 2 == 0 then colors.bg else colors.card
			local row = frame({
				Name = "Row_" .. rIdx,
				Size = UDim2.new(1, 0, 0, 24),
				BackgroundColor3 = rowBg,
				BackgroundTransparency = if rIdx % 2 == 0 then 0.6 else 0,
				LayoutOrder = rIdx + 10,
				Parent = card,
			})
			uiCorner(row, 4)

			if r.crashed then
				label({
					Name = "Crash",
					Size = UDim2.fromScale(1, 1),
					Text = "  ⚠  " .. r.name .. "  —  " .. r.crashMsg,
					TextSize = 11,
					TextColor3 = colors.crash,
					Parent = row,
				})
			else
				label({
					Name = "Name",
					Position = UDim2.new(0, 4, 0.5, 0),
					AnchorPoint = Vector2.new(0, 0.5),
					Size = UDim2.new(0.49, 0, 0.85, 0),
					Text = r.name,
					TextSize = 11,
					Font = Enum.Font.Gotham,
					TextColor3 = colors.textPri,
					Parent = row,
				})

				local vColor = if r.validityPass then colors.pass else colors.fail
				local vDot = frame({
					Name = "VDot",
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0.51, 0, 0.5, 0),
					Size = UDim2.new(0, 10, 0, 10),
					BackgroundColor3 = vColor,
					Parent = row,
				})
				uiCorner(vDot, 5)

				if r.perfSkipped then
					local pDot = frame({
						Name = "PDot",
						AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.new(0.60, 0, 0.5, 0),
						Size = UDim2.new(0, 10, 0, 10),
						BackgroundColor3 = colors.textDim,
						Parent = row,
					})
					uiCorner(pDot, 5)

					label({
						Name = "Avg",
						AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.new(0.68, 0, 0.5, 0),
						Size = UDim2.new(0.15, 0, 0.85, 0),
						Text = "—",
						TextSize = 11,
						Font = Enum.Font.GothamMedium,
						TextColor3 = colors.textDim,
						Parent = row,
					})

					label({
						Name = "Budget",
						AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.new(0.84, 0, 0.5, 0),
						Size = UDim2.new(0.16, 0, 0.85, 0),
						Text = "—",
						TextSize = 11,
						Font = Enum.Font.Gotham,
						TextColor3 = colors.textDim,
						Parent = row,
					})
				else
					local pColor = if r.perfPass then colors.pass else colors.slow
					local pDot = frame({
						Name = "PDot",
						AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.new(0.60, 0, 0.5, 0),
						Size = UDim2.new(0, 10, 0, 10),
						BackgroundColor3 = pColor,
						Parent = row,
					})
					uiCorner(pDot, 5)

					label({
						Name = "Avg",
						AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.new(0.68, 0, 0.5, 0),
						Size = UDim2.new(0.15, 0, 0.85, 0),
						Text = string.format("%.2f", r.avgUs),
						TextSize = 11,
						Font = Enum.Font.GothamMedium,
						TextColor3 = if r.perfPass then colors.textPri else colors.slow,
						Parent = row,
					})

					label({
						Name = "Budget",
						AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.new(0.84, 0, 0.5, 0),
						Size = UDim2.new(0.16, 0, 0.85, 0),
						Text = string.format("%.2f", r.budgetUs :: number),
						TextSize = 11,
						Font = Enum.Font.Gotham,
						TextColor3 = colors.textSec,
						Parent = row,
					})
				end
			end
		end
	end

	local footerCard = frame({
		Name = "Footer",
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = colors.accentDim,
		LayoutOrder = 9999,
		Parent = scroll,
	})
	uiCorner(footerCard, 8)
	uiPadding(footerCard, 18, 0)

	label({
		Name = "FooterNote",
		Size = UDim2.fromScale(1, 1),
		Text = "Per row: validity · performance · avg µs · budget µs",
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextColor3 = colors.textPri,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = footerCard,
	})

	sg.Parent = game:GetService("StarterGui")
	local lp = game:GetService("Players").LocalPlayer
	if lp then
		local pg = lp:FindFirstChildOfClass("PlayerGui")
		if pg then
			sg:Clone().Parent = pg
		end
	end
end

--------------------------------------------------------------------------------
-- TEST RUNNER
--------------------------------------------------------------------------------
@native
const function OmniSentry_Test(createUI: boolean?, outputResults: boolean?): number
	table.clear(allSections)
	currentSection = { name = "", tests = {} }

	OmniSentry.registerInstanceSchema("Part", {
		Name = types.string255,
		Material = (types.enum :: any)(Enum.Material),
		Transparency = types.float32,
		CFrame = types.qcframe,
		Size = types.vector3,
		CanCollide = types.boolean,
		CanTouch = types.boolean,
		Color = types.color3,
		Reflectance = types.float32,
		Anchored = types.boolean,
	})

	local instanceMap = require("./static/instanceMap")
	local registeredPart = Instance.new("Part")
	registeredPart:SetAttribute("_VSID", 8001)
	instanceMap[8001] = registeredPart

	local serPart = Instance.new("Part")
	serPart.Name = "SerPart"
	serPart.Material = Enum.Material.Neon
	serPart.Transparency = 0.25
	serPart.CFrame = CFrame.new(3, 4, 5) * CFrame.Angles(0.2, -0.1, 0.4)
	serPart.Size = Vector3.new(2, 4, 1)
	serPart.CanCollide = false
	serPart.CanTouch = true
	serPart.Color = Color3.fromRGB(80, 120, 200)
	serPart.Reflectance = 0.1
	serPart.Anchored = true

	local sampleCFrame = CFrame.new(1, 2, 3) * CFrame.Angles(0.1, 0.2, 0.3)
	local structType = types.struct({
		id = types.uint32,
		name = types.string255,
		active = types.boolean,
		score = types.float32,
	})
	local structValue = { id = 42, name = "player", active = true, score = 99.5 }
	local unionType = types.union(types.int32, types.string255, types.boolean)
	local enumMaterial = (types.enum :: any)(Enum.Material)

	--------------------------------------------------------------------------------
	-- Static · Types (one test per type)
	--------------------------------------------------------------------------------
	section("Static · Types")

	local typeCases: { TypeCase } = {
		{ name = "int8", serdes = types.int8, value = -42, budget = BUDGET.integer },
		{ name = "uint8", serdes = types.uint8, value = 200, budget = BUDGET.integer },
		{ name = "int16", serdes = types.int16, value = -10_000, budget = BUDGET.integer },
		{ name = "uint16", serdes = types.uint16, value = 50_000, budget = BUDGET.integer },
		{ name = "int24", serdes = types.int24, value = -500_000, budget = BUDGET.integer },
		{ name = "uint24", serdes = types.uint24, value = 10_000_000, budget = BUDGET.integer },
		{ name = "int32", serdes = types.int32, value = -123_456_789, budget = BUDGET.integer },
		{ name = "uint32", serdes = types.uint32, value = 4_000_000_000, budget = BUDGET.integer },
		{ name = "int40", serdes = types.int40, value = -123_456_789_012, budget = BUDGET.integer },
		{ name = "uint40", serdes = types.uint40, value = 1_099_511_627_775, budget = BUDGET.integer },
		{ name = "int48", serdes = types.int48, value = -9_876_543_210_987, budget = BUDGET.integer },
		{ name = "uint48", serdes = types.uint48, value = 281_474_976_710_655, budget = BUDGET.integer },
		{ name = "float16", serdes = types.float16, value = 1.5, budget = BUDGET.float, tol = 0.05 },
		{ name = "float24", serdes = types.float24, value = math.pi, budget = BUDGET.float, tol = 0.02 },
		{ name = "float32", serdes = types.float32, value = 2.71828, budget = BUDGET.float, tol = 1e-5 },
		{ name = "float64", serdes = types.float64, value = 1.23456789, budget = BUDGET.float },
		{ name = "boolean", serdes = types.boolean, value = true, budget = BUDGET.integer },
		{ name = "string", serdes = types.string, value = "OmniSentry round-trip", budget = BUDGET.string },
		{ name = "string255", serdes = types.string255, value = string.rep("x", 64), budget = BUDGET.string },
		{ name = "vector", serdes = types.vector, value = vector.create(1, 2, 3), budget = BUDGET.roblox },
		{ name = "void", serdes = types.void, value = {}, budget = BUDGET.integer, check = function(v)
			return typeof(v) == "table" and next(v) == nil
		end },
		{ name = "nothing", serdes = types.nothing, value = nil, budget = BUDGET.integer, check = function(v)
			return v == nil
		end },
		{
			name = "boolPacked",
			serdes = types.boolPacked,
			value = { true, false, true, false, true, false, true, false },
			budget = BUDGET.integer,
		},
		{ name = "vector3", serdes = types.vector3, value = Vector3.new(1, 2, 3), budget = BUDGET.roblox },
		{ name = "vector2", serdes = types.vector2, value = Vector2.new(4, 5), budget = BUDGET.roblox },
		{ name = "vector2f24", serdes = types.vector2f24, value = Vector2.new(-2, 7), budget = BUDGET.roblox, tol = 0.02 },
		{ name = "vector2f16", serdes = types.vector2f16, value = Vector2.new(3, -1), budget = BUDGET.roblox, tol = 0.05 },
		{ name = "vector3f24", serdes = types.vector3f24, value = Vector3.new(1, -2, 3), budget = BUDGET.roblox, tol = 0.02 },
		{ name = "vector3f16", serdes = types.vector3f16, value = Vector3.new(2, 3, 4), budget = BUDGET.roblox, tol = 0.08 },
		{ name = "color3", serdes = types.color3, value = Color3.fromRGB(10, 20, 30), budget = BUDGET.roblox },
		{ name = "cframe", serdes = types.cframe, value = sampleCFrame, budget = BUDGET.roblox },
		{ name = "cframef24", serdes = types.cframef24, value = sampleCFrame, budget = BUDGET.roblox },
		{ name = "cframef16", serdes = types.cframef16, value = sampleCFrame, budget = BUDGET.roblox },
		{ name = "qcframe", serdes = types.qcframe, value = sampleCFrame, budget = BUDGET.roblox },
		{ name = "qcframef24", serdes = types.qcframef24, value = sampleCFrame, budget = BUDGET.roblox },
		{ name = "qcframef16", serdes = types.qcframef16, value = sampleCFrame, budget = BUDGET.roblox },
		{ name = "enum", serdes = enumMaterial, value = Enum.Material.Wood, budget = BUDGET.roblox },
		{ name = "struct", serdes = structType, value = structValue, budget = BUDGET.complex },
		{ name = "optional", serdes = types.optional(types.int32), value = 777, budget = BUDGET.complex },
		{ name = "union", serdes = unionType, value = "union-branch", budget = BUDGET.complex },
		{ name = "any", serdes = types.any, value = { tag = "payload", n = 99 }, budget = BUDGET.complex },
		{ name = "instance", serdes = types.instance, value = registeredPart, budget = BUDGET.instance },
		{
			name = "serInstance",
			serdes = types.serInstance("Part"),
			value = serPart,
			budget = BUDGET.instance,
			check = function(v: any): boolean
				return typeof(v) == "Instance" and v ~= serPart and serPartMatches(v, serPart)
			end,
		},
	}

	for _, case in typeCases do
		registerTypeCase(case)
	end

	--------------------------------------------------------------------------------
	-- Static · Collections
	--------------------------------------------------------------------------------
	section("Static · Collections")

	registerCollectionTests("array(int32)", types.array(types.int32), makeIntArray)
	registerCollectionTests("array255(float32)", types.array255(types.float32), function(n: number)
		local t = table.create(n)
		for i = 1, n do
			t[i] = i * 0.25
		end
		return t
	end)
	registerCollectionTests("map(string255,int32)", types.map(types.string255, types.int32), makeStringMap)
	registerCollectionTests("map255(uint8,boolean)", types.map255(types.uint8, types.boolean), makeMap255)

	--------------------------------------------------------------------------------
	-- Multi-Cursor
	-- Several write cursors stay open at once; writes hop between them before finish.
	--------------------------------------------------------------------------------
	section("Multi-Cursor")

	local mapType = types.map(types.string255, types.uint8)
	local arrayInt16 = types.array(types.int16)
	local arrayInt32 = types.array(types.int32)

	local interleaveSteps: { McStep } = {
		-- cursor A opens, write to A
		{ open = true, cursor = 1, write = mcWrite(types.uint32, 0xDEADBEEF) },
		-- cursor B opens, write to A then B
		{ open = true, cursor = 1, write = mcWrite(types.uint16, 65_000) },
		{ cursor = 2, write = mcWrite(types.int32, -424_242) },
		-- cursor C opens, write to B
		{ open = true, cursor = 2, write = mcWrite(types.boolean, true) },
		-- cursor D opens, write to C
		{ open = true, cursor = 3, write = mcWrite(types.float32, 6.022, nil, 1e-5) },
		-- more writes while all four cursors are live
		{ cursor = 1, write = mcWrite(types.string255, "cursor-alpha") },
		{ cursor = 2, write = mcWrite(types.vector3, Vector3.new(9, 8, 7)) },
		{ cursor = 3, write = mcWrite(types.color3, Color3.fromRGB(255, 128, 0)) },
		{ cursor = 1, write = mcWrite(types.uint8, 200) },
		-- cursor E opens, scatter writes across A/B/C/E
		{ open = true, cursor = 4, write = mcWrite(arrayInt16, { 1, -2, 3, -4, 5 }) },
		{ cursor = 1, write = mcWrite(structType, structValue) },
		{ cursor = 2, write = mcWrite(unionType, true) },
		{ cursor = 3, write = mcWrite(mapType, { a = 1, bb = 255 }) },
		-- cursor F opens (empty), then back-fill D and E
		{ open = true, cursor = 5, write = mcWrite(types.qcframe, sampleCFrame) },
		{ cursor = 4, write = mcWrite(types.int24, -500_000) },
		{ cursor = 1, write = mcWrite(types.float64, 1.23456789) },
		{ cursor = 2, write = mcWrite(types.string255, "tail-b") },
		-- cursor G opens with a large payload to stress alloc while others are open
		{ open = true, cursor = 6, write = mcWrite(arrayInt32, makeIntArray(50)) },
		{ cursor = 3, write = mcWrite(types.uint24, 16_777_215) },
		{ cursor = 6, write = mcWrite(types.int16, -12_345) },
		{ cursor = 1, write = mcWrite(types.boolean, false) },
		{ cursor = 5, write = mcWrite(types.float16, 1.5, nil, 0.05) },
	}

	test("multi-cursor – interleaved open/write across seven sessions", BUDGET.multiCursor, function()
		local buffers, ledger = runInterleavedWrites(interleaveSteps)
		if buffers == nil or ledger == nil then
			return false
		end
		-- cursor F (index 6) was opened with one write then received another; cursor G is index 7
		if #buffers ~= 7 then
			return false
		end
		return validateCursorLedger(buffers, ledger)
	end, function()
		for _ = 1, 20 do
			local buffers, ledger = runInterleavedWrites(interleaveSteps)
			if buffers == nil or ledger == nil then
				return
			end
			validateCursorLedger(buffers, ledger)
		end
	end)

	test("multi-cursor – interleaved writes, read in shuffled cursor order", BUDGET.multiCursor, function()
		local buffers, ledger = runInterleavedWrites(interleaveSteps)
		if buffers == nil or ledger == nil then
			return false
		end
		return validateCursorLedger(buffers, ledger, { 7, 1, 5, 3, 6, 2, 4 })
	end, function()
		for _ = 1, 20 do
			local buffers, ledger = runInterleavedWrites(interleaveSteps)
			if buffers ~= nil and ledger ~= nil then
				validateCursorLedger(buffers, ledger, { 4, 7, 2, 6, 1, 5, 3 })
			end
		end
	end)

	test("multi-cursor – rapid ping-pong between two live cursors", BUDGET.multiCursor, function()
		local steps: { McStep } = {
			{ open = true, cursor = 1, write = mcWrite(types.uint16, 1) },
			{ open = true, cursor = 2, write = mcWrite(types.uint16, 101) },
		}
		for i = 2, 40 do
			table.insert(steps, { cursor = 1, write = mcWrite(types.uint16, i) })
			table.insert(steps, { cursor = 2, write = mcWrite(types.uint16, i + 100) })
		end

		local buffers, ledger = runInterleavedWrites(steps)
		if buffers == nil or ledger == nil then
			return false
		end

		local rcA = OmniSentry.readStart(buffers[1])
		local rcB = OmniSentry.readStart(buffers[2])
		for i = 1, 40 do
			local _, a = types.uint16.read(rcA)
			local _, b = types.uint16.read(rcB)
			if a ~= i or b ~= i + 100 then
				return false
			end
		end
		return #ledger[1] == 40 and #ledger[2] == 40
	end, function()
		for _ = 1, 10 do
			local wcA = OmniSentry.writeStart()
			local wcB = OmniSentry.writeStart()
			for i = 1, 20 do
				types.uint16.write(wcA, i)
				types.uint16.write(wcB, i + 50)
			end
			local bufA = OmniSentry.writeFinish(wcA)
			local bufB = OmniSentry.writeFinish(wcB)
			local rcA = OmniSentry.readStart(bufA)
			local rcB = OmniSentry.readStart(bufB)
			for i = 1, 20 do
				types.uint16.read(rcA)
				types.uint16.read(rcB)
			end
		end
	end)

	test("multi-cursor – reserved offset with manual raw bytes", BUDGET.multiCursor, function()
		const HEADER = 8
		local wc = OmniSentry.writeStart(HEADER)
		if types.uint32.write(wc, 1234) ~= SUCCESS or types.float32.write(wc, 9.81) ~= SUCCESS then
			return false
		end
		local buf = OmniSentry.writeFinish(wc)

		buffer.writeu32(buf, 0, 0x0B10C0DE)
		buffer.writeu32(buf, 4, HEADER)

		local rc = OmniSentry.readStart(buf, HEADER)
		local _, n = types.uint32.read(rc)
		local _, f = types.float32.read(rc)
		return buffer.readu32(buf, 0) == 0x0B10C0DE and n == 1234 and approxEq(f, 9.81, 1e-5)
	end, function()
		const HEADER = 8
		for _ = 1, 50 do
			local wc = OmniSentry.writeStart(HEADER)
			types.uint32.write(wc, 99)
			types.float32.write(wc, 1.5)
			local buf = OmniSentry.writeFinish(wc)
			buffer.writeu32(buf, 0, 1)
			local rc = OmniSentry.readStart(buf, HEADER)
			types.uint32.read(rc)
			types.float32.read(rc)
		end
	end)

	test("multi-cursor – mixed manual cursor + static API on same buffer", BUDGET.multiCursor, function()
		local wc = OmniSentry.writeStart()
		if types.uint8.write(wc, 7) ~= SUCCESS then
			return false
		end
		local partial = OmniSentry.writeFinish(wc)

		local tail = static.serialize(types.string255, "tail", nil, nil)
		if tail == nil then
			return false
		end

		local combined = buffer.create(buffer.len(partial) + buffer.len(tail))
		buffer.copy(combined, 0, partial, 0, buffer.len(partial))
		buffer.copy(combined, buffer.len(partial), tail, 0, buffer.len(tail))

		local rc = OmniSentry.readStart(combined)
		local _, a = types.uint8.read(rc)
		local _, s = types.string255.read(rc)
		return a == 7 and s == "tail"
	end, function()
		for _ = 1, 100 do
			local wc = OmniSentry.writeStart()
			types.uint8.write(wc, 42)
			local partial = OmniSentry.writeFinish(wc)
			local tail = static.serialize(types.int16, -1, nil, nil)
			if tail then
				local combined = buffer.create(buffer.len(partial) + buffer.len(tail :: buffer))
				buffer.copy(combined, 0, partial, 0, buffer.len(partial))
				buffer.copy(combined, buffer.len(partial), tail :: buffer, 0, buffer.len(tail :: buffer))
				local rc = OmniSentry.readStart(combined)
				types.uint8.read(rc)
				types.int16.read(rc)
			end
		end
	end)

	--------------------------------------------------------------------------------
	-- OUTPUT
	--------------------------------------------------------------------------------
	if outputResults ~= false then
		printResults()
	end
	if createUI then
		buildUI()
	end

	return 0
end

return OmniSentry_Test
