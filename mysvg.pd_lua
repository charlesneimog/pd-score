local mysvg = pd.Class:new():register("mysvg")

-- ─────────────────────────────────────
function mysvg:initialize(name, args)
	self.inlets = 1
	self:set_size(128, 82)
	self.g = nil
	self.notes = {}
	return true
end

-- ─────────────────────────────────────
function mysvg:in_1_reload()
	self:dofilex(self._scriptname)
	self:initialize()
end

-- ─────────────────────────────────────
function mysvg:in_1_note(args)
	self.notes = args
	self:repaint(2)
end

-- ─────────────────────────────────────
-- Group notes by their vertical position (natural + sharp share the same space)
local note_steps = {
	[0] = 0, -- C and C#
	[1] = 0, -- C#
	[2] = 1, -- D and D#
	[3] = 1, -- D#
	[4] = 2, -- E
	[5] = 3, -- F and F#
	[6] = 3, -- F#
	[7] = 4, -- G and G#
	[8] = 4, -- G#
	[9] = 5, -- A and A#
	[10] = 5, -- A#
	[11] = 6, -- B
}

-- Function to get the multiplier, grouping sharps with natural notes
local function get_value_increment(midi_note)
	-- Reference to C4
	local base_note = 60
	local interval = (midi_note - base_note) % 12
	-- Get the step based on the grouped natural/sharp note
	return note_steps[interval] or 0
end

function mysvg:paint_layer_2(g)
	local d = [[
	M216 125c93 0 206 -52 206 -123c0 -70 -52 -127 -216 -127c-149 0 -206 60 -206 127c0 68 83 123 216 123zM111 63c-2 -8 -3 -16 -3 -24c0 -32 15 -66 35 -89c21 -28 58 -52 94 -52c10 0 21 1 31 4c33 8 46 36 46 67c0 60 -55 134 -124 134c-31 0 -68 -5 -79 -40z
	]]

	if #self.notes == 0 then
		return
	end

	local xMin, yMin, xMax, yMax = -434, -1992, 2319, 1951
	local scale_x = 128 / (xMax - xMin)
	local scale_y = -scale_x

	local translate_x = -xMin * scale_x
	local translate_y = -yMax * scale_y

	-- Construct the SVG string
	local svg = '<svg width="128" height="128" xmlns="http://www.w3.org/2000/svg"><path d="'
		.. d
		.. '" fill="#000000" transform="translate('
		.. translate_x
		.. ","
		.. translate_y
		.. ") scale("
		.. scale_x
		.. ","
		.. scale_y
		.. ')"/></svg>'

	local note = self.notes[1]
	local multiplier = get_value_increment(note) -- Get the multiplier based on the note group
	local value = 5.8 * -multiplier -- Adjust the value accordingly

	g:draw_svg(svg, 110, 37 + value)
end

-- ─────────────────────────────────────
function mysvg:paint(g)
	g:set_color(248, 248, 248)
	g:fill_all()

	local size_x, size_y = self:get_size()

	self.g = g

	local d = [[
        M500 1016v-32h-500v32h500zM500 766v-32h-500v32h500zM500 516v-32h-500v32h500zM500 266v-32h-500v32h500zM500 16v-32h-500v32h500z
    ]]

	-- Scale factor
	local xMin, yMin, xMax, yMax = -434, -1992, 2319, 1951

	-- Scale factor
	local scale_x = 128 / (xMax - xMin)
	local scale_y = -scale_x

	local translate_x = -xMin * scale_x
	local translate_y = -yMax * scale_y

	-- Construct the SVG string
	local svg = '<svg width="128" height="128" xmlns="http://www.w3.org/2000/svg"><path d="'
		.. d
		.. '" fill="#000000" transform="translate('
		.. translate_x
		.. ","
		.. translate_y
		.. ") scale("
		.. scale_x
		.. ","
		.. scale_y
		.. ')"/></svg>'

	-- Draw the SVG
	local y = 37
	g:draw_svg(svg, 44, y)
	local x = 44
	for i = 0, 4 do
		x = x + 23
		if x < 128 then
			g:draw_svg(svg, x, y)
		else
			g:draw_svg(svg, x - 10, y)
		end
	end

	self:gClef(g)
end

-- ─────────────────────────────────────
function mysvg:gClef(g)
	local d = [[
M376 415l25 -145c3 -18 3 -18 29 -18c147 0 241 -113 241 -241c0 -113 -67 -198 -168 -238c-14 -6 -15 -5 -13 -17c11 -62 29 -157 29 -214c0 -170 -130 -200 -197 -200c-151 0 -190 98 -190 163c0 62 40 115 107 115c61 0 96 -47 96 -102c0 -58 -36 -85 -67 -94
c-23 -7 -32 -10 -32 -17c0 -13 26 -29 80 -29c59 0 159 18 159 166c0 47 -15 134 -27 201c-2 12 -4 11 -15 9c-20 -4 -46 -6 -69 -6c-245 0 -364 165 -364 339c0 202 153 345 297 464c12 10 11 12 9 24c-7 41 -14 106 -14 164c0 104 24 229 98 311c20 22 51 48 65 48
c11 0 37 -28 52 -50c41 -60 65 -146 65 -233c0 -153 -82 -280 -190 -381c-6 -6 -8 -7 -6 -19zM470 943c-61 0 -133 -96 -133 -252c0 -32 2 -66 6 -92c2 -13 6 -14 13 -8c79 69 174 159 174 270c0 55 -27 82 -60 82zM361 262l-21 128c-2 11 -4 12 -14 4
c-47 -38 -93 -75 -153 -142c-83 -94 -93 -173 -93 -232c0 -139 113 -236 288 -236c20 0 40 2 56 5c15 3 16 3 14 14l-50 298c-2 11 -4 12 -20 8c-61 -17 -100 -60 -100 -117c0 -46 30 -89 72 -107c7 -3 15 -6 15 -13c0 -6 -4 -11 -12 -11c-7 0 -19 3 -27 6
c-68 23 -115 87 -115 177c0 85 57 164 145 194c18 6 18 5 15 24zM430 103l49 -285c2 -12 4 -12 16 -6c56 28 94 79 94 142c0 88 -67 156 -148 163c-12 1 -13 -2 -11 -14z
    ]]

	-- Scale factor
	local xMin, yMin, xMax, yMax = -434, -1992, 2319, 1951

	-- Scale factor
	local scale_x = 128 / (xMax - xMin)
	local scale_y = -scale_x

	local translate_x = -xMin * scale_x
	local translate_y = -yMax * scale_y

	-- Construct the SVG string
	local svg = '<svg width="128" height="128" xmlns="http://www.w3.org/2000/svg"><path d="'
		.. d
		.. '" fill="#000000" transform="translate('
		.. translate_x
		.. ","
		.. translate_y
		.. ") scale("
		.. scale_x
		.. ","
		.. scale_y
		.. ')"/></svg>'

	-- Draw the SVG
	g:draw_svg(svg, 44, 25)
end
