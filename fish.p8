pico-8 cartridge // http://www.pico-8.com
version 43
__lua__
function _init()
	scenes:set(game)
end

function _update()
	scenes:update()
end

function _draw()
	scenes:draw()
end

-- utils
function tileat(x, y, flag)
	return fget(mget(x \ 8, y \ 8), flag)
end

function randr(min, max)
	return flr(rnd(max-min)) + min
end

function f2(n)
  local s,n=n<0 and "-" or "",abs(n)
  n=flr(n*100+.5)/100
  local i,d=flr(n),flr((n-flr(n))*100)
  return s..i.."."..(d<10 and "0"..d or d)
end

function crect(
	x1, y1, w1, h1,
	x2, y2, w2, h2
)
	return 
		x1 < x2 + w2 and
		x1 + w1 > x2 and
		y1 < y2 + h2 and
		y1 + h1 > y2 
end

-- scene manager
scenes = {
	scene = nil
}

function scenes:set(scene)
	self.scene = scene
	self.scene:init()
end

function scenes:update()
	self.scene:update()
end

function scenes:draw()
	self.scene:draw()
end
-->8
-- player

player = {}

function player:tobobbler()
	line(
		self.x, self.y, 
		self.bobbler.x + 3, 
		self.bobbler.y - self.bobbler.z + 3, 
		7
	)
end

__debug_force_fish = false
__debug_fish = {
	name = "tuna",
	area = "forest",
	size = "small",
}

function player:getbite()
	if __debug_force_fish then
		local fs = nil
		for _, f in ipairs(fish[__debug_fish.area][__debug_fish.size]) do
			if f.name == __debug_fish.name then
				fs = f
				break
			end
		end

		return fs, __debug_fish.size
	end

	local roll = randr(1, 100)
	local chances = self.rod.chances
	local size = "small"
	
	if roll > (chances[1] + chances[2]) then
		size = "large"
	elseif roll > chances[1] then
		size = "medium"
	end

	-- testing
	size = "small"
	
	local pool = fish[game.area.name][size]
	local hook = pool[flr(rnd(#pool)) + 1]

	return hook, size
end

function player:init()
	self.x = 60
	self.y = 60
	
	self.spd = 2
	
	self.state = "walk"
	
	self.reverse = false
	self.power = 0
	self.tick = 0.05
	self.throw = 0
	
	self.xp = 0
	self.lvl = 1
	
	self.money = 0
	
	self.omax = 0.92
	self.omin = 0.1
	
	self.facing = "up"
	
	self.wait = 0
	
	self.strike_base = 20
	self.strike = 0
	
	-- mult is base fish 
	-- strike increase
	
	-- todo
	-- increase size based on
	-- rod or player level
	-- also, global table 
	-- for these :sob:
	self.rod = rods["bomboo"]

	self.inventory = {
		-- todo
		-- accesories
		-- headwear, body, etc etc
		-- increases strike chance
		-- maybe fish drag
		-- make fish slower??
		-- something else maybe????
		accesories = {},
	
		-- todo
		-- bait
		-- increases strike chance?
		bait = {},
		
		fish = {},
	}
	
	self.prate = 0.25
	self.lrate = 0.5
	
	self.bobbler = nil
	self.hooked = nil
	self.hooked_size = nil
	
	-- data for minigame
	self.fish = nil
	self.bar = nil
end

function player:update()
	if self.state == "walk" then
		if btnp(🅾️) then
			self.state = "charge"
			return
		end
		
		-- basic walk
		-- no normalisation & no vel
		if btn(⬅️) then
			self.x -= self.spd
			self.facing = "left"
		elseif btn(➡️) then
			self.x += self.spd
			self.facing = "right"
		end
		
		if btn(⬆️) then
			self.y -= self.spd
			self.facing = "up"
		elseif btn(⬇️) then
			self.y += self.spd
			self.facing = "down"
		end
	elseif self.state == "charge" then
		if btn(🅾️) then
			if self.reverse then
				self.power -= self.tick
				if self.power <= 0 then
					self.reverse = false
				end
			else
				self.power += self.tick
				if self.power >= 1 then
					self.reverse = true
				end
			end 
		else			
			if self.power >= self.omax then
				self.power = 1
			elseif self.power <= self.omin then
				self.power = 0.1
			end
			
			-- todo
			-- max power jingle!
			
			local throw = self.power * self.rod.power
				
			self.power = 0
			self.reverse = false
			
			self.bobbler = bobbler.new(self.x, self.y, self.facing, throw)
		
			self.state = "throwing"
		end
	elseif self.state == "throwing" then
		self.bobbler:update()
		
		if not self.bobbler.active then
			if tileat(self.bobbler.x + 4, self.bobbler.y + 4, 0) then
				self.state = "fishing"
				
				-- todo
				-- decrease based on
				-- accesories
				-- also decrease
				-- based on dist
				-- from shore
				self.wait = 
					randr(
						60, 
						60 + (90 * self.rod.mult)
					)

			else
				self.state = "walk"
				self.bobbler = nil
			end
		end
	elseif self.state == "fishing" then
		self.wait -= 1
		if self.wait <= 0 then
			self.state = "bite"
			
			-- todo: increase 
			-- based on accesories
			self.strike = self.strike_base
		
			self.hooked, self.hooked_size = self:getbite()
		
			-- todo:
			-- feedback for bite
			sfx(1)
		end
		
		if btnp(❎) then
			self.state = "walk"
			self.bobbler = nil
			self.wait = 0
		end
	elseif self.state == "bite" then
		self.strike -= 1
		
		if btnp(❎) then
			self.state = "minigame"
			self.strike = 0
			
			self.fish = {
				x = 64,
				target = 64,
			
				-- 20 frame grace period
				timer = 20,
				dashing = false,
				
				progress = 50,
				flipped = false,
				
				reeling = true,
				sp = 7
			}
			
			-- todo
			-- increase width based
			-- on level
			local w = self.rod.width
			self.bar = {
				x = self.fish.x - w / 2,
				w = w,
				h = 7,
				
				spd = 1.5
			}
			
			return
		end
		
		if self.strike <= 0 then
			-- maybe
			-- could just go back to
			-- the fishing state?
		
			self.state = "walk"
			self.bobbler = nil
			self.hooked = nil
			self.hooked_size = nil
			self.strike = 0
			
			-- todo
			-- feedback for miss
			sfx(0)
		end
	elseif self.state == "minigame" then
		-- bar goes first
		local bar = self.bar
		
		if btn(⬅️) then
			bar.x -= bar.spd
			if bar.x <= minigame.minx then
				bar.x = minigame.minx
			end
		elseif btn(➡️) then
			bar.x += bar.spd
			
			if bar.x >= minigame.maxx - 5 then
				bar.x = minigame.maxx - 5
			end
		end
		
		local fish = self.fish
		
		fish.timer -= 1
		if fish.timer <= 0 then
			fish.target = 
				randr(
					minigame.minx, 
					minigame.maxx
				)
		
			fish.timer = 
				randr(
					30, 
					90 - (self.hooked.aggr * 50)
				)

			fish.dashing = 
				rnd() < self.hooked.aggr
				
			fish.flipped = fish.x < fish.target
		end
		
		local spd = self.hooked.spd
		if fish.dashing then
			spd = self.hooked.dspd
		end
		
		if fish.x < fish.target then
			fish.x += spd
			if (fish.x > fish.target) fish.x = fish.target
		else
			fish.x -= spd
			if (fish.x < fish.target) fish.x = fish.target
		end
		
		if crect(
			bar.x, minigame.y, bar.w, bar.h,
			fish.x, minigame.y, 8, 8
		) then
			fish.reeling = true
		
			fish.sp = 7
			fish.progress += self.prate
			if fish.progress >= 100 then
				fish.progress = 100
			end
		else
			fish.reeling = false
		
			fish.sp = 8
			fish.progress -= self.lrate
			if fish.progress <= 0 then
				fish.progress = 0
			end
		end
		
		if fish.progress >= 100 then
			if btn(❎) then
				self.state = "caught"
			end
		elseif fish.progress <= 0 then
			-- todo
			-- maybe an intermediary
			-- state??
			
			self.state = "walk"
			
			self.hooked = nil
			self.hooked_size = nil
			self.fish = nil
			self.bar = nil
		end
		
	elseif self.state == "caught" then
		if btnp(🅾️) then
			self.state = "walk"
			
			-- todo
			-- add to inventory
			
			self.hooked = nil
			self.hooked_size = nil
			self.fish = nil
			self.bar = nil
		end
	end
end

function player:draw()	
	spr(1, self.x, self.y)
	
	if self.state == "charge" then
		print(
			f2(self.power), 
			self.x, self.y - 6, 
			7
		)
	elseif self.state == "throwing" then
		self:tobobbler()
		self.bobbler:draw()
	elseif self.state == "fishing" then
		self:tobobbler()
		self.bobbler:draw()
	elseif self.state == "bite" then	
		self:tobobbler()
		self.bobbler:draw()
		
		spr(6, self.x, self.y - 10)
	elseif self.state == "minigame" then
		self:tobobbler()
		self.bobbler:draw()
	end
end
-->8
-- bobbler

bobbler = {}
bobbler.__index = bobbler

function bobbler.new(x, y, facing, pwr)
	local b = {
		x = x, y = y, z = 2,
		vx = 0, vy = 0, vz = 2.5,
		
		g = 0.25,
		active = true,
		
		sp = 4
	}
	
	local spd = pwr * 0.5
	if facing == "left" then b.vx = -spd
	elseif facing == "right" then b.vx = spd
	elseif facing == "up" then b.vy = -spd
	elseif facing == "down" then b.vy = spd
	end
	
	return setmetatable(b, bobbler)
end

function bobbler:update()
	if (not self.active) return
	
	self.x += self.vx
	self.y += self.vy
	
	self.z += self.vz
	self.vz -= self.g
	
	if self.z <= 0 then
		self.z = 0
		
		self.vz = 0
		self.vy = 0
		self.vx = 0
		
		self.active = false
		
		self.sp = 5
	end
end

function bobbler:draw()
	if self.active then
		circfill(self.x + 4, self.y + 4, 2, 5)
	end
	
	spr(self.sp, self.x, self.y - self.z)
end
-->8
-- data

-- todo
-- money payout
-- xp payout
-- weighted random
-- some specific fish are
-- rarer than others

-- todo
-- description
function mkfish(name, desc, xp, mon, spd, aggr, dspd)
	return {
		name = name,
		desc = desc,
		spd = spd,
		aggr = aggr,
		dspd = dspd,
		xp = xp,
		sell = mon,
	}
end

-- todo
-- more fish
fish = {
	forest = {
		small = { 
			mkfish("minnow", nil, nil, nil, 0.8, 0.2, 1.0),
			mkfish("tuna", nil, nil, nil, 1.0, 0.4, 1.5),
		}
	}
}

rods = {
	["bomboo"] = {
		name = "bamboo",
		power = 1.4,
		
		mult = 1,
		width = 12,
		
		chances = {
			75, 20, 5
		},
	},
}

minigame = {
	minx = 10,
	maxx = 108,
	
	y = 80
}

-- todo
-- more areas
areas = {
	forest = {
		name = "forest",
		clr = 3,
		
		minx = 0,
		miny = 0,
	}
}
-->8
-- game

game = {}

function game:init()
	self.area = areas.forest

	self.padding = 20

	player:init()
end

function game:update()
	player:update()
end

function game:draw()
	cls(self.area.clr)

	-- camera(player.x - 60, player.y - 60)
	map(self.area.minx, self.area.miny)
	player:draw()
	
	camera(0, 0)
	
	?player.state,5,5,7
	?"facing " .. player.facing
	?"x " .. player.x .. " y " .. player.y
	
	if player.state == "minigame" then
		-- background
		local offset = 5
		local bh = 35
		rrectfill(
			minigame.minx - offset, minigame.y - offset,
			minigame.maxx + offset * 2, bh, 3, 4 
		)

		rrect(
			minigame.minx - offset, minigame.y - offset,
			minigame.maxx + offset * 2, bh, 3, 7 
		)

		local fish = player.fish
		
		rrect(
			minigame.minx - 1, minigame.y - 1,
			minigame.maxx + 2, 10, 2, 
			7
		)
		
		rrectfill(
			minigame.minx, minigame.y, 
			minigame.maxx, 8, 1,
			1
		)
		
		-- player bar
		local bar = player.bar
		rrectfill(
			bar.x, minigame.y,
			bar.w, bar.h + 1, 2, 3
		)
		
		rrect(
			bar.x, minigame.y,
			bar.w, bar.h + 1, 2, 11
		)
		
		-- fish
		spr(fish.sp, 
			fish.x, minigame.y, 
			1, 1, 
			fish.flipped
		)
		
		-- progress
		-- todo
		-- make this a rect
		print(flr(fish.progress) .. "%", minigame.minx, minigame.y + 10, 7)
	
		-- funny pixel worlds-like
		-- text
		if fish.reeling then
			local txt = "fish on!"
			if fish.progress >= 100 then
				txt = "fish on! ❎ to catch!"
			end
			
			local w = #txt * 4
			print(txt, 128 / 2 - w / 2, minigame.y + 20, 11)
		end
	elseif player.state == "caught" then
		-- body
		rectfill(
			self.padding, self.padding,
			128 - self.padding,
			128 - self.padding,
			1
		)
		
		rect(
			self.padding - 1, self.padding - 1,
			128 - self.padding + 1,
			128 - self.padding + 1,
			6
		)
		
		local offset = 85
		
		-- fish name
		local name = player.hooked.name ..
			" (" .. player.hooked_size .. ")"

		print(name, 
			self.padding + 5, 
			128 - self.padding - offset, 
			7
		)
		
		-- separator
		line(
			self.padding, 
			128 - self.padding - offset + 7,
			128 - self.padding,
			128 - self.padding - offset + 7,
			7
		)
		
		-- placeholder img
		local ix, iy = 
			self.padding + 38,
			128 - self.padding - offset + 20
		
		spr(34, ix, iy)
		rect(ix - 1, iy - 1, ix + 9, iy + 9, 7)
	
		-- description
		-- todo
	end
end
__gfx__
0000000011111111000000000000000000000000000000000009a000000000000000000000000000000000000000000000000000000000000000000000000000
00000000111111110000000000000000000000000000000000999a00000000000000000000000000000000000000000000000000000000000000000000000000
00700700111111110000000000000000000820000008200000999a000bbbbb0b0555550500000000000000000000000000000000000000000000000000000000
00077000111111110000000000000000007776000077760000999a00bbbbbbbb5555555500000000000000000000000000000000000000000000000000000000
0007700011111111000000000000000000888200000000000009a000bbbbbbbb5555555500000000000000000000000000000000000000000000000000000000
007007001111111100000000000000000002200000000000000000000bbbbb0b0555550500000000000000000000000000000000000000000000000000000000
000000001111111100000000000000000000000000000000000a9000000000000000000000000000000000000000000000000000000000000000000000000000
000000001111111100000000000000000000000000000000000a9000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
cccccccc000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
c776cccc000000000666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
cccccccc000000000656ee0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ccccc77c00000000066ee00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
cccccccc0000000000eedd0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
cccccccc0000000000e0ddd000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ccc66ccc0000000000000d6600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
77cccccc000000000000006000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3bb33bbbcccccccc77cccccc00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4333333bccccbbcccccccdcc00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
7444433366cc77bcccc666dc00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
17766446cccccccccccccddc00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
11111661ccccc66cccccc77c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
d1dd1111c777ccbcc66dcccc00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
dccdd1d1cccbbcccccd55ccc00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
cccccccdcccbcccccccc777c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__gff__
0001000000000000000000000000000000000000000000000000000000000000030000000000000000000000000000000303030000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
3030303030303030303030303030303000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2020312032322020323231203220203200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2031200020200000002020200000320000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0020200000310000000020310000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000002020202000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000202020202020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000100001d0701d0701d0701d0701d0701d0701d0701d0701d0701707017070170701707017070170701707017070170701707000000000000000000000000000000000000000000000000000000000000000000
000100002b0702b0702b0702b0702b0702a0702a0702b0702e0703107031070310503305035050360500000000000000000000000000000000000000000000000000000000000000000000000000000000000000
