local slaxml = require("slaxml")
local json = require("json")
local score = pd.Class:new():register("l.score")

local bravura_glyphs = nil
local bravura_glyphnames = nil
local bravura_font = nil
local bravura_metadata = nil

-- ─────────────────────────────────────
function score:initialize(_, args)
	self.inlets = 1
	self.g_width = 127
	self.g_height = 127
	if not bravura_glyphnames then
		self:readGlyphNames()
	end
	if not bravura_glyphs or not bravura_font then
		self:readFont()
	end

	-- parse args
	for i, arg in ipairs(args) do
		if arg == "-width" then
			self.g_width = math.max(math.floor(args[i + 1] or 152), 96)
		elseif arg == "-height" then
			self.g_height = math.max(math.floor(args[i + 1] or 0), 140)
		end
	end
	self:set_size(self.g_width, self.g_height)

	-- parse args
	self.scale = 0
	self.last_note = 0

	return true
end

-- ─────────────────────────────────────
function score:in_1_reload()
	self:dofilex(self._scriptname)
end

-- ─────────────────────────────────────
function score:in_1_width(x)
	self:set_size(x[1], x[2])
	self:set_args({ "-width", x[1], "-height", x[2] })
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
	if bravura_glyphnames and bravura_metadata then
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
	bravura_glyphnames = json.decode(glyphJson)

	glyphName = score._loadpath .. "/bravura_metadata.json"
	f = io.open(glyphName, "r")
	if f == nil then
		self:error("[l.score] Failed to open file!")
		return
	end
	glyphJson = f:read("*all")
	ok = f:close()
	if not ok then
		self:error("[readsvg] Error to read glyphnames!")
		return
	end
	bravura_metadata = json.decode(glyphJson)
end

-- ─────────────────────────────────────
function score:readFont()
	if bravura_glyphs and bravura_font then
		return
	end
	bravura_glyphs = {}
	bravura_font = {}
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
		"units-per-em",
		"panose",
		"ascent",
		"descent",
		"bbox",
		"underline-thickness",
		"underline-position",
		"stemh",
		"stemv",
		"unicode-range",
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
	bravura_glyphs = loaded_glyphs
	bravura_font = loaded_font
end

-- ──────────────────────────────────────────
function score:getGlyph(name)
	local codepoint = bravura_glyphnames[name].codepoint
	codepoint = codepoint:gsub("U%+", "uni")
	return bravura_glyphs[codepoint]
end

-- ──────────────────────────────────────────
function score:paint(g)
	local w, h = self:get_size() -- Get canvas size
	self.width = w
	self.height = h
	g:set_color(250, 250, 250)
	g:fill_all()

	-- Check if necessary font data is available
	if not bravura_glyphnames then
		self:readGlyphNames()
	end
	if not bravura_glyphs or not bravura_font then
		self:readFont()
	end

	-- Extract font and glyph properties
	local bbox_left, bbox_bottom, bbox_right, bbox_top = table.unpack(bravura_font.bbox)
	local bbox_width = bbox_right - bbox_left
	local bbox_height = bbox_top - bbox_bottom
	local scale_x = self.width / bbox_width
	local scale_y = self.height / bbox_height
	self.scaling = math.min(scale_x, scale_y)

	self:draw(g, self:getGlyph("gClef"), 0, 50)
	-- self:draw(g, self:getGlyph("staff5LinesWide"), 0, 50)
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

-- ─────────────────────────────────────
-- @ x: x position
-- @
function score:draw(g, glyph, x, y)
	g:translate(x, y)
	g:scale(self.scaling, -self.scaling)
	score:draw_glyph(g, glyph, 1)
	g:reset_transform()
end

-- ─────────────────────────────────────
function score:draw_glyph(g, glyph, scaling)
	local max_x = 0
	local max_y = 0
	local command = self:parse_svg_path(glyph.d)
	local x, y = 0, 0
	local last_control_x, last_control_y = nil, nil -- For the previous cubic bezier control point

	local p
	for _, v in pairs(command) do
		local cmd = v[1]
		local params = v[2]
		if cmd == "M" then
			if p then
				x, y = params[1] * scaling, params[2] * scaling
				p:line_to(x, y) -- NOTE: Should be move_to
			else
				x, y = params[1] * scaling, params[2] * scaling
				p = Path(x, y)
			end
		elseif cmd == "H" or cmd == "h" then
			local h_x = params[1] * scaling
			if cmd == "h" then
				h_x = x + h_x
			end
			x = h_x
			p:line_to(x, y)
		elseif cmd == "V" or cmd == "v" then
			local v_y = params[1] * scaling
			if cmd == "v" then
				v_y = y + params[1] * scaling
			end
			y = v_y
			p:line_to(x, y)
		elseif cmd == "L" or cmd == "l" then
			local l_x = params[1] * scaling
			local l_y = params[2] * scaling
			if cmd == "l" then
				l_x = x + params[1] * scaling
				l_y = y + params[2] * scaling
			end
			x = l_x
			y = l_y
			p:line_to(x, y)
		elseif cmd == "C" or cmd == "c" then
			local cx1 = params[1] * scaling
			local cy1 = params[2] * scaling
			local cx2 = params[3] * scaling
			local cy2 = params[4] * scaling
			local x3 = params[5] * scaling
			local y3 = params[6] * scaling
			if cmd == "c" then
				cx1 = x + cx1
				cy1 = y + cy1
				cx2 = x + cx2
				cy2 = y + cy2
				x3 = x + x3
				y3 = y + y3
			end
			x, y = x3, y3
			last_control_x, last_control_y = cx2, cy2
			p:cubic_to(cx1, cy1, cx2, cy2, x3, y3)
		elseif cmd == "s" then
			-- TODO: need to implement S
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
		elseif cmd == "Q" or cmd == "q" then
			local cx, cy, x3, y3
			cx = params[1] * scaling
			cy = params[2] * scaling
			x3 = params[3] * scaling
			y3 = params[4] * scaling
			if cmd == "q" then
				cx = x + params[1] * scaling
				cy = y + params[2] * scaling
				x3 = x + params[3] * scaling
				y3 = y + params[4] * scaling
			end
			p:quad_to(cx, cy, x3, y3)
			x, y = x3, y3
			last_control_x, last_control_y = cx, cy
		elseif cmd == "T" or cmd == "t" then
			local cx, cy, x3, y3
			if last_control_x and last_control_y then
				cx = x + (x - last_control_x)
				cy = y + (y - last_control_y)
			else
				cx, cy = x, y
			end

			if cmd == "t" then
				x3 = x + params[1] * scaling
				y3 = y + params[2] * scaling
			else
				x3 = params[1] * scaling
				y3 = params[2] * scaling
			end

			p:quad_to(cx, cy, x3, y3)
			x, y = x3, y3
			last_control_x, last_control_y = cx, cy
		elseif cmd == "A" or cmd == "a" then
			self:error("A/a not implemented, need the arc_to function on Path")
            return
			-- local rx, ry, x_axis_rotation, large_arc_flag, sweep_flag, x3, y3
			-- rx = params[1] * scaling
			-- ry = params[2] * scaling
			-- x_axis_rotation = params[3]
			-- large_arc_flag = params[4]
			-- sweep_flag = params[5]
			-- x3 = params[6] * scaling
			-- y3 = params[7] * scaling
			-- if cmd == "a" then
			-- 	x3 = x + params[6] * scaling
			-- 	y3 = y + params[7] * scaling
			-- end
			-- p:arc_to(rx, ry, x_axis_rotation, large_arc_flag, sweep_flag, x3, y3)
			-- x, y = x3, y3
		elseif cmd == "z" or cmd == "Z" then
			p:close()
		else
			self:error(cmd .. " " .. table.concat(params, " "))
		end

		if x > max_x then
			max_x = x
		end
		if y > max_y then
			max_y = y
		end
	end

	g:set_color(1)
	g:fill_path(p)
end
