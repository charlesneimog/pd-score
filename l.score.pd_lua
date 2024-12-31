-- Include required libraries
local slaxml = require("slaxml")
local json = require("json")
local score = pd.Class:new():register("l.score")

local glyphs = nil
local glyphnames = nil
local font = nil

-- ─────────────────────────────────────
function score:initialize(_, _)
	self.inlets = 1

	-- graphics
	self:set_size(1024, 512)
	self.scale = 0
	self.x, self.y = self:get_size()
	self:readFont()
	self:readGlyphNames()

	return true
end

-- ─────────────────────────────────────
function score:split(string, delimiter)
	local result = {}
	local pattern = string.format("([^%s]+)", delimiter)
	for match in string:gmatch(pattern) do
		table.insert(result, match)
	end
	return result
end

-- ─────────────────────────────────────
function score:readGlyphNames()
	if glyphnames then
		return
	end

	local glyphName = score._loadpath .. "/glyphnames.json"
	local f = io.open(glyphName, "r")
	if f == nil then
		self:error("[l.score] Failed to open file!")
		return
	end
	local glyphJson = f:read("*all")
	local ok = f:close()
	if not ok then
		self:error("[readsvg] Error to read glyphnames!")
		return
	end
	glyphnames = json.decode(glyphJson)
end

-- ─────────────────────────────────────
function score:readFont()
	if glyphs then
		return
	end
	glyphs = {}
	local svgfile = score._loadpath .. "/Bravura.svg"
	local f = io.open(svgfile, "r")
	if f == nil then
		self:error("[l.score] Failed to open file!")
		return
	end

	local xml = f:read("*all")
	local ok = f:close()
	if not ok then
		self:error("[readsvg] Error closing file!")
		return
	end

	local loaded_glyphs = {}
	local currentName = ""
	local currentD = ""
	local currentHorizAdvX = ""

	local loaded_font = {}
	local font_field = {
		"family",
		"weight",
		"stretch",
		"units_per_em",
		"panose",
		"ascent",
		"descent",
		"bbox",
		"underline_thickness",
		"underline_position",
		"stemh",
		"stemv",
		"unicode_range",
	}

	local parser = slaxml:parser({
		attribute = function(name, value, _, _)
			-- glyph
			if name == "glyph-name" then
				currentName = value
			elseif name == "d" then
				currentD = value
			elseif name == "horiz-adv-x" then
				currentHorizAdvX = value
			end

			for _, field in ipairs(font_field) do
				if name == field then
					loaded_font[field] = score:split(value, " ")
				end
			end
		end,
		closeElement = function(name, _)
			if name == "glyph" then
				loaded_glyphs[currentName] = { d = currentD, horizAdvX = currentHorizAdvX }
			end
		end,
	})

	parser:parse(xml, { stripWhitespace = true })
	glyphs = loaded_glyphs
	font = loaded_font
end

-- ─────────────────────────────────────
function score:in_1_reload()
	self:dofilex(self._scriptname)
	self:initialize()
	self:repaint()
end

-- ─────────────────────────────────────
function score:parse_svg_path(d)
	local commands = {}
	local i = 1
	while i <= #d do
		local cmd = d:sub(i, i)
		i = i + 1
		local params = {}
		while i <= #d and not (d:sub(i, i):match("[a-zA-Z]")) do
			local param = d:match("^-?%d+%.?%d*", i)
			if param then
				table.insert(params, tonumber(param))
				i = i + #param
			else
				i = i + 1
			end
		end
		table.insert(commands, { cmd, params })
	end
	return commands
end

-- ──────────────────────────────────────────
function score:getGlyph(name)
	if not glyphnames then
		self:readGlyphNames()
	end
	if not glyphs then
		self:readFont()
	end

	local codepoint = glyphnames[name].codepoint
	codepoint = codepoint:gsub("U%+", "uni")
	return glyphs[codepoint]
end

-- ──────────────────────────────────────────
function score:paint(g)
	g:set_color(0)
	g:fill_all()
	self.x_size, self.y_size = self:get_size()

	local bbox_left, bbox_bottom, bbox_right, bbox_top = -434, -1992, 2319, 1951
	local bbox_width = bbox_right - bbox_left
	local bbox_height = bbox_top - bbox_bottom
	local scale_x = self.x_size / bbox_width
	local scale_y = self.y_size / bbox_height
	self.scale = math.min(scale_x, scale_y)
	g:scale(1, -1)
	g:translate(50, -self.y_size / 2.5)

	local lG = self:getGlyph("gClef8vbCClef")
	score:draw_glyph(g, lG, self.scale)
	-- self:create_staff(g)
end

-- ─────────────────────────────────────
function score:create_staff(g)
	g:reset_transform()
	g:scale(1, -1)

	g:translate(0, -self.y_size / 2.5)
	local score_g = self:getGlyph("staff5LinesNarrow")
	if not score_g then
		self:error("Glyph not found")
		return
	end

	local adv = score_g["horizAdvX"]
	g:translate(0, 0)
	self:draw_glyph(g, score_g, self.scale)

	local x = adv * self.scale
	local maxIter = self.x_size / x
	maxIter = math.ceil(maxIter) - 1
	local x_trans = x * (maxIter + 1)
	for i = 1, maxIter do
		g:translate(x, 0)
		self:draw_glyph(g, score_g, self.scale)
	end

	g:translate(-x_trans, -30)
	for i = 1, maxIter + 1 do
		g:translate(x, 0)
		self:draw_glyph(g, score_g, self.scale)
	end
end

-- ─────────────────────────────────────
function score:draw_glyph(g, glyph, scaling)
	local command = self:parse_svg_path(glyph.d)
	local x, y = 0, 0
	local last_control_x, last_control_y = nil, nil -- For the previous cubic bezier control point
	g:set_color(1)
	local p = Path(0, 0) -- Start with a new Path

	for _, v in pairs(command) do
		local cmd = v[1]
		local params = v[2]
		if cmd == "M" then
			x, y = params[1] * scaling, params[2] * scaling
			-- should be a move_to
			p:line_to(x, y)
		elseif cmd == "h" then
			x = x + params[1] * scaling
			p:line_to(x, y)
		elseif cmd == "l" then
			x = x + params[1] * scaling
			y = y + params[2] * scaling
			p:line_to(x, y)
		elseif cmd == "v" then
			y = y + params[1] * scaling
			p:line_to(x, y)
		elseif cmd == "c" then
			local cx1 = params[1] * scaling
			local cy1 = params[2] * scaling
			local cx2 = params[3] * scaling
			local cy2 = params[4] * scaling
			local x3 = params[5] * scaling
			local y3 = params[6] * scaling
			p:cubic_to(x + cx1, y + cy1, x + cx2, y + cy2, x + x3, y + y3)
			x, y = x + x3, y + y3
			last_control_x, last_control_y = x + cx2, y + cy2
		elseif cmd == "s" then
			local dx2 = params[1] * scaling
			local dy2 = params[2] * scaling
			local dx = params[3] * scaling
			local dy = params[4] * scaling
			local control_x1, control_y1
			if last_control_x and last_control_y then
				control_x1 = x + (x - last_control_x)
				control_y1 = y + (y - last_control_y)
			else
				control_x1 = x
				control_y1 = y
			end
			p:cubic_to(control_x1, control_y1, x + dx2, y + dy2, x + dx, y + dy)
			x, y = x + dx, y + dy
			last_control_x, last_control_y = x + dx2, y + dy2
		elseif cmd == "z" then
			p:close()
		else
			self:error(cmd .. " " .. table.concat(params, " "))
		end
	end

	g:set_color(1)
	g:fill_path(p)
end
