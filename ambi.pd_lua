local ambi = pd.Class:new():register("ambi")

-- ─────────────────────────────────────
function ambi:initialize(name, args)
	self.inlets = 1
	self.outles = 1
	self:set_size(128, 128)
	self.g = nil
	self.notes = {}
	self.position = { x = 128 / 2, y = 128 / 2 }
	return true
end

-- ─────────────────────────────────────
function ambi:in_1_reload()
	self:dofilex(self._scriptname)
	self:initialize()
end

-- ─────────────────────────────────────
function ambi:mouse_down(x, y)
	if x > 128 or x < 0 or y > 128 or y < 0 then
		return
	end
	self.position = { x = x, y = y }
	self:repaint(2)
end

-- ─────────────────────────────────────
function ambi:mouse_drag(x, y)
	if x > 128 then
		x = 128
	end
	if y > 128 then
		y = 128
	end
	
	if x < 0 then
		x = 0
	end
	if y < 0 then
		y = 0
	end

	self.position = { x = x, y = y }
	self:repaint(2)
end

-- ─────────────────────────────────────
function ambi:paint_layer_2(g)
	g:set_color(255, 0, 0)
	g:fill_ellipse(self.position.x - 2, self.position.y - 2, 6, 6)
end

-- ─────────────────────────────────────
--
function ambi:paint(g)
	g:set_color(248, 248, 248)
	g:fill_all()

	local svgfile = pd._pathnames["ambi"] .. ".svg"

	local svgfile = io.open(svgfile, "r")
	if svgfile == nil then
		pd.post("ambi.svg not found")
		return
	end
	local svg = svgfile:read("*a")

	g:draw_svg(svg, 128 / 2, 128 / 2)
end
