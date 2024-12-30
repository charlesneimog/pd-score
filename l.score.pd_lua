-- Include required libraries
local slaxml = require("slaxml")
local score = pd.Class:new():register("l.score")

-- Initialize the score object
function score:initialize(_, argv)
	self.inlets = 1
	self:set_size(127, 64)
	self:readFont()
	return true
end

-- Read the SVG font file
function score:readFont()
	self.glyphs = {}
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

	local glyphs = {}
	local currentName = ""
	local currentD = ""
	local currentHorizAdvX = ""
	local parser = slaxml:parser({
		attribute = function(name, value, _, _)
			if name == "glyph-name" then
				currentName = value
			elseif name == "d" then
				currentD = value
			elseif name == "horiz-adv-x" then
				currentHorizAdvX = value
			else
				pd.post("[l.score] Unknown attribute: " .. name)
			end
		end,
		closeElement = function(name, _)
			if name == "glyph" then
				glyphs[currentName] = { d = currentD, horizAdvX = currentHorizAdvX }
			else
				pd.post("[l.score] Unknown element: " .. name)
			end
		end,
	})

	parser:parse(xml, { stripWhitespace = true })
	self.glyphs = glyphs
end

-- Reload the score object
function score:in_1_reload()
	self:dofilex(self._scriptname)
	self:repaint()
end

-- Parse the SVG path data
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
function score:draw_glyph(g, glyph)
	local command = self:parse_svg_path(glyph.d)
	local p
	local x, y
	local last_control_x, last_control_y = nil, nil -- For the previous cubic bezier control point
	local stroke_path = 1

	-- Iterate through the command list and handle each drawing command
	for _, v in pairs(command) do
		local cmd = v[1]
		local params = v[2]
		if cmd == "M" then
			p = Path(params[1], params[2])
			x, y = params[1], params[2]
			last_control_x, last_control_y = nil, nil -- Reset control point for new path
		elseif cmd == "h" then
			x = x + params[1]
			p:line_to(x, y)
		elseif cmd == "l" then
			-- Relative line command
			x = x + params[1]
			y = y + params[2]
			p:line_to(x, y)
		elseif cmd == "v" then
			-- The vertical displacement (relative)
			local dy = params[1]
			y = y + dy
			p:line_to(x, y)
		elseif cmd == "c" then
			-- Relative cubic Bezier curve
			local cx1 = params[1]
			local cy1 = params[2]
			local cx2 = params[3]
			local cy2 = params[4]
			local x3 = params[5]
			local y3 = params[6]

			-- Convert relative coordinates to absolute coordinates
			local control_x1 = x + cx1
			local control_y1 = y + cy1
			local control_x2 = x + cx2
			local control_y2 = y + cy2
			local end_x = x + x3
			local end_y = y + y3

			-- Call the cubic_to function with the absolute coordinates
			p:cubic_to(control_x1, control_y1, control_x2, control_y2, end_x, end_y)
			x, y = end_x, end_y
			last_control_x, last_control_y = control_x2, control_y2
		elseif cmd == "s" then
			-- Smooth cubic Bezier curve (relative)
			local dx2 = params[1]
			local dy2 = params[2]
			local dx = params[3]
			local dy = params[4]
			local control_x1, control_y1
			if last_control_x and last_control_y then
				control_x1 = x + (x - last_control_x)
				control_y1 = y + (y - last_control_y)
			else
				control_x1 = x
				control_y1 = y
			end
			local control_x2 = x + dx2
			local control_y2 = y + dy2
			local end_x = x + dx
			local end_y = y + dy
			p:cubic_to(control_x1, control_y1, control_x2, control_y2, end_x, end_y)
			x, y = end_x, end_y
			last_control_x, last_control_y = control_x2, control_y2
		elseif cmd == "z" then
			g:set_color(0)
			p:close()
			g:fill_path(p)
		else
			self.error(cmd .. " " .. table.concat(params, " "))
		end
	end
end

--╭─────────────────────────────────────╮
--│        Draw the SVG commands        │
--╰─────────────────────────────────────╯
function score:paint(g)
	g:set_color(0)
	g:fill_all()
	-- size_x, size_y = g:get_size()

	local value = {
		"E050",
	}
	local glyph = self.glyphs["uni" .. value[1]]
	local canvas_size = 127
	local bbox_left, bbox_bottom, bbox_right, bbox_top = -434, -1992, 2319, 1951
	local bbox_width = bbox_right - bbox_left
	local bbox_height = bbox_top - bbox_bottom
	local scale_x = canvas_size / bbox_width
	local scale_y = canvas_size / bbox_height
	local scale = math.min(scale_x, scale_y)
	local offset_x = (canvas_size - bbox_width * scale) / 2 - bbox_left * scale
	local canvas_center_y = canvas_size / 2
	local bbox_center_y = (bbox_top + bbox_bottom) / 2
	local offset_y = canvas_center_y - bbox_center_y * scale
	g:scale(scale, -scale) -- Scale the glyph

	local pos_y = -2319 / 2
	local pos_x = 0 --1992 / 2
	g:translate(offset_x + pos_x, offset_y + pos_y) -- Translate with (pos_x, pos_y)
	self:draw_glyph(g, glyph)

	-- pos_x = 350
	-- pos_y = -65
	-- for i = 1, 8 do
	-- 	g:translate(offset_x + pos_x, offset_y + pos_y) -- Translate with (pos_x, pos_y)
	-- 	self:draw_glyph(g, glyph, pos_x, pos_y)
	-- end
end
