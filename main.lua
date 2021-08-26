-- prefs
screenSize = {400, 240}
twoX = true
startPosition = {}
maxSpeed = 100
acceleration = 100
decay = 50
spin = 100
sizeMod = 50
respawnTime = 2
roidSize = 30
roidVariance = 10
roidSpeed = 100
laserSpeed = 200
laserDecay = 2
laserSize = 2
laserClearTime = 1
laserNextClear = 0
debug = true

-- Initialising stuff
function love.load()
	love.window.setTitle("Belt Blaster")
	
	-- adjust parameters for 2x screen size
	if twoX then
		screenSize = {screenSize[1]*2, screenSize[2]*2}
		maxSpeed = maxSpeed * 2
		acceleration = acceleration * 2
		decay = decay * 2
	end
	
	-- set screen size
	love.window.setMode(screenSize[1], screenSize[2], {resizable=false})
	
	-- set background to our 'off' black colour
	red = 28/255
	green = 37/255
	blue = 32/255
	love.graphics.setBackgroundColor(red, green, blue)
	
	-- set drawing colour to our 'on' white colour
	red = 242/255
	green = 239/255
	blue = 233/255
	love.graphics.setColor(red, green, blue)

	startPosition = {
		x = screenSize[1] / 2, 
		y = screenSize[2] / 2
	}
	
	-- initialise player
	player = {
		position = {x = startPosition.x, y = startPosition.y},
		respawnPosition = {x = startPosition.x, y = startPosition.y},
		ship = {
			top = {x = 0, y = 0},
			right = {x = 0, y = 0},
			left = {x = 0, y = 0}
		},
		bearing = 270,
		heading = {x = 0, x = 0},
		lasers = {},
		size = screenSize[1]/sizeMod, -- set player size based on screen size
		speed = 0,
		alive = true,
		firing = false,
		invincible = false,
		respawn = 0
	}
	
	math.randomseed(os.time())
	sx = screenSize[1]/4
	sy = screenSize[2]/4
	asteroids = {
		{
			points = generateAsteroid({x = sx, y = sy}),
			bearing = math.random(0, 360),
			speed = roidSpeed,
			tier = 2,
			active = true
		},
		{
			points = generateAsteroid({x = 3*sx, y = sy}),
			bearing = math.random(0, 360),
			speed = roidSpeed,
			tier = 2,
			active = true
		},
		{
			points = generateAsteroid({x = sx, y = 3*sy}),
			bearing = math.random(0, 360),
			speed = roidSpeed,
			tier = 2,
			active = true
		},
		{
			points = generateAsteroid({x = 3*sx, y = 3*sy}),
			bearing = math.random(0, 360),
			speed = roidSpeed,
			tier = 2,
			active = true
		}
	}
end


-- Main update step
function love.update(dt)
	
	-- kill player if colliding with asteroid
	if player.alive and isPlayerColliding(asteroids) then
		player.alive = false
		player.respawn = love.timer.getTime() + respawnTime
	end

	-- update player's position (if alive)
	if player.alive then
		if love.keyboard.isDown("space") and not player.firing then
			fireLaser()
			player.firing = true
		elseif player.firing and not love.keyboard.isDown("space") then
			player.firing = false
		end
		updatePlayer(dt)
	elseif love.timer.getTime() > player.respawn then
		player.position = {x = player.respawnPosition.x, y = player.respawnPosition.y}
		player.speed = 0
		player.bearing = 270
		player.alive = true
	end
	
	-- update asteroid positions
	updateAsteroids(dt)
	
	-- remove inactive lasers
	activeLasers = {}
	for i=1, #player.lasers, 1 do
		if player.lasers[i].active then table.insert(activeLasers, player.lasers[i]) end
	end
	player.lasers = activeLasers
	
	-- update laser positions
	updateLasers(dt)
	
	-- check lasers against asteroids
	for i=1, #player.lasers, 1 do
		if player.lasers[i].active then 
			isLaserColliding(asteroids, player.lasers[i])
		end
	end
end


-- Main drawing step
function love.draw()
	
	-- draw player
	if player.alive then drawPlayer() end
	
	-- draw asteroids
	drawAsteroids(asteroids)
	
	-- draw lasers
	drawLasers(player.lasers)
	
	-- Debug text
	if debug then
		printDebug()
	end
end


-- Check if player is colliding with an obstacle (asteroid)
function isPlayerColliding(obstacles)

	for i=1, #obstacles, 1 do
		if obstacles[i].active then
			oPoints = {}
			table.insert(oPoints, obstacles[i].points)
			-- check against each obstacle
			for j = 1, #oPoints, 1 do
				if checkCollision(oPoints[j], {player.ship.top, player.ship.right, player.ship.left}) then 
					return true
				end
			end
		end
	end
	
	return false
end


-- Check if laser is colliding with an asteroid
function isLaserColliding(obstacles, laser)
	
	for i=1, #obstacles, 1 do
		if obstacles[i].active then
			oPoints = {}
			table.insert(oPoints, obstacles[i].points)
			for j = 1, #oPoints, 1 do
				if checkCollision(oPoints[j], {{x = laser.x, y = laser.y}}) then 
					obstacles[i].active = false
					laser.active = false
					return true
				end
			end
		end
	end
	
	return false
end

-- Check for collision between point (player, laser) & polygon (asteroid)
function checkCollision(polygon, points)
	-- check polygon with each point supplied	
	for i = 1, #points, 1 do
		-- check point against polygon's bounding box
		polygonBbox = getBbox(polygon)
		if checkBbox(polygonBbox, points[i]) then
			if pointInPolygon(polygon, points[i].x, points[i].y) then return true end
		end
	end
	
	return false
end


-- Is given point within a given polygon?
function pointInPolygon(polygon, tx, ty)
	local i, yflag0, yflag1, inside_flag
	local vtx0, vtx1
	
	local numverts = #polygon

	vtx0 = polygon[numverts]
	vtx1 = polygon[1]

	-- get test bit for above/below X axis
	yflag0 = ( vtx0.y >= ty )
	inside_flag = false
	
	for i=2,numverts+1 do
		yflag1 = ( vtx1.y >= ty )
	
		--[[ Check if endpoints straddle (are on opposite sides) of X axis
		 * (i.e. the Y's differ); if so, +X ray could intersect this edge.
		 * The old test also checked whether the endpoints are both to the
		 * right or to the left of the test point.  However, given the faster
		 * intersection point computation used below, this test was found to
		 * be a break-even proposition for most polygons and a loser for
		 * triangles (where 50% or more of the edges which survive this test
		 * will cross quadrants and so have to have the X intersection computed
		 * anyway).  I credit Joseph Samosky with inspiring me to try dropping
		 * the "both left or both right" part of my code.
		 --]]
		if ( yflag0 ~= yflag1 ) then
			--[[ Check intersection of pgon segment with +X ray.
			 * Note if >= point's X; if so, the ray hits it.
			 * The division operation is avoided for the ">=" test by checking
			 * the sign of the first vertex wrto the test point; idea inspired
			 * by Joseph Samosky's and Mark Haigh-Hutchinson's different
			 * polygon inclusion tests.
			 --]]
			if ( ((vtx1.y - ty) * (vtx0.x - vtx1.x) >= (vtx1.x - tx) * (vtx0.y - vtx1.y)) == yflag1 ) then
				inside_flag = not inside_flag
			end
		end

		-- Move to the next pair of vertices, retaining info as possible.
		yflag0  = yflag1
		vtx0    = vtx1
		vtx1    = polygon[i]
	end

	return  inside_flag
end


-- Get bounding box of polygon
function getBbox(points)
	xMin = points[1].x
	xMax = points[1].x
	yMin = points[1].y
	yMax = points[1].y
	
	for k, v in ipairs(points) do
		-- x coord
		if v.x < xMin then
			xMin = v.x
		elseif v.x > xMax then
			xMax = v.x
		end
		if v.y < yMin then
			yMin = v.y
		elseif v.y > yMax then
			yMax = v.y
		end
	end
	
	return {
		xMin = xMin,
		yMin = yMin,
		xMax = xMax,
		yMax = yMax
	}
end


-- Simple bounding box check
function checkBbox(bbox, point)
	if point.x >= bbox.xMin and point.x <= bbox.xMax and point.y >= bbox.yMin and point.y <= bbox.yMax then return true
	else return false end
end


-- Printing debug info to the screen
function printDebug()
	positionText = "Position: " .. tostring(math.floor(player.position.x)) .. ", " .. tostring(math.floor(player.position.y))
	love.graphics.print(positionText, 4, 5)
	
	speedText = "Speed: " .. tostring(math.floor(player.speed))
	love.graphics.print(speedText, 4, 17)
	
	bearingText = "Bearing: " .. tostring(math.floor(player.bearing))
	love.graphics.print(bearingText, 4, 29)
	
	bboxText =  "Laser Count: " .. tostring(#player.lasers)
	love.graphics.print(bboxText, 4, 41)
end


-- Update the player's position
function updatePlayer(dt)
	-- Bearing changes
	if love.keyboard.isDown("left") then
		player.bearing = player.bearing - (dt * spin)
		if player.bearing < 0 then player.bearing = 360 end
	elseif love.keyboard.isDown("right") then
		player.bearing = player.bearing + (dt * spin)
		if player.bearing > 360 then player.bearing = 0 end
	end
	
	-- Update heading
	bearingRadians = math.rad(player.bearing)
	player.heading = {
		x = math.cos(bearingRadians),
		y = math.sin(bearingRadians)
	}
	
	-- Speed changes
	if love.keyboard.isDown("up") then
		if player.speed < maxSpeed then
			player.speed = player.speed + (dt * acceleration)
		end
	else
		if player.speed > 0 then 
			player.speed = player.speed - (dt * decay)
		end
		if player.speed < 0 then -- make sure speed doesn't become negative
			player.speed = 0
		end
	end
	
	-- Calculate movement based on speed & heading
	playerMove = {
		x = player.heading.x * dt * player.speed, 
		y = player.heading.y * dt * player.speed
	}
	
	-- Move horizontally, check position & wrap screen if required
	player.position.x = player.position.x + playerMove.x
	if player.position.x > screenSize[1] then player.position.x = 0
	elseif player.position.x < 0 then player.position.x = screenSize[1] end
	
	-- Move horizontally, check position & wrap screen if required
	player.position.y = player.position.y + playerMove.y
	if player.position.y > screenSize[2] then player.position.y = 0
	elseif player.position.y < 0 then player.position.y = screenSize[2] end
end


-- Update the position of all asteroids
function updateAsteroids(dt)
	-- for each asteroid
	for i=1, #asteroids, 1 do
		if asteroids[i].active then
			-- Update heading
			local bearingRadians = math.rad(asteroids[i].bearing)
			local heading = {
				x = math.cos(bearingRadians),
				y = math.sin(bearingRadians)
			}
			
			roidMove = {
				x = heading.x * dt * asteroids[i].speed, 
				y = heading.y * dt * asteroids[i].speed
			}
			
			for j=1, #asteroids[i].points, 1 do
				asteroids[i].points[j].x = asteroids[i].points[j].x + roidMove.x
				asteroids[i].points[j].y = asteroids[i].points[j].y + roidMove.y
				
				if asteroidOffScreen(asteroids[i], "full") then
					wrapAsteroid(asteroids[i])
				end
			end
		end
	end
	
end


-- Fire a laser from the player's ship
function fireLaser()
	bolt = {
		x = player.ship.top.x,
		y = player.ship.top.y,
		heading = player.heading,
		speed = laserSpeed,
		fizzle = love.timer.getTime() + laserDecay,
		active = true
	}
	
	table.insert(player.lasers, bolt)
end

-- Update the position of all lasers
function updateLasers(dt)
	-- for each bolt
	for i=1, #player.lasers, 1 do
		
		if love.timer.getTime() > player.lasers[i].fizzle then
			player.lasers[i].active = false
		end
		
		if player.lasers[i].active then
			boltMove = {
				x = player.lasers[i].heading.x * dt * player.lasers[i].speed, 
				y = player.lasers[i].heading.y * dt * player.lasers[i].speed
			}
			
			player.lasers[i].x = player.lasers[i].x + boltMove.x
			if player.lasers[i].x > screenSize[1] then player.lasers[i].x = 0
			elseif player.lasers[i].x < 0 then player.lasers[i].x = screenSize[1] end
			
			player.lasers[i].y = player.lasers[i].y + boltMove.y
			if player.lasers[i].y > screenSize[2] then player.lasers[i].y = 0
			elseif player.lasers[i].y < 0 then player.lasers[i].y = screenSize[2] end
		end
	end
end


-- From player's current position, get the vertices of the ship
function updateShipVertices()
	-- top
	player.ship.top = {
		x = player.position.x+(player.heading.x*player.size), 
		y = player.position.y+(player.heading.y*player.size)
	}
	
	-- right
	if player.bearing < 270 then rightBearing = player.bearing+90
	else rightBearing = player.bearing - 270 end
	rightRadians = math.rad(rightBearing)
	rightHeading = {
		x = math.cos(rightRadians),
		y = math.sin(rightRadians)
	}	
	
	player.ship.right = {
		x = player.position.x+(rightHeading.x*(player.size/2)), 
		y = player.position.y+(rightHeading.y*(player.size/2))
	}
	
	-- left
	if player.bearing > 90 then leftBearing = player.bearing-90
	else leftBearing = player.bearing + 270 end
	leftRadians = math.rad(leftBearing)
	leftHeading = {
		x = math.cos(leftRadians),
		y = math.sin(leftRadians)
	}
	
	player.ship.left = {
		x = player.position.x+(leftHeading.x*(player.size/2)), 
		y = player.position.y+(leftHeading.y*(player.size/2))
	}
end


-- Calculate distance between two points
function distance (a, b)
	local dx = a.x - b.x
	local dy = a.y - b.y
	return math.sqrt ( dx * dx + dy * dy )
end


-- Generate a random asteroid
function generateAsteroid(centre)

	roidMin = roidSize-roidVariance
	roidMax = roidSize+roidVariance
	
	-- generate 11 random points
	points = {}
	for i=0, 330, 30 do
		r = math.rad(i)
		xMod = math.random(roidMin, roidMax)
		yMod = math.random(roidMin, roidMax)
		p = {
			x = centre.x + (math.cos(r)*xMod),
			y = centre.y + (math.sin(r)*yMod)
		}
		table.insert(points, p)
	end
	
	-- compute the angle from each point to the centre
	for i=1, #points, 1 do
		angle = math.atan2(points[i].x-centre.x,points[i].y-centre.y)
		points[i].angle = angle
	end
	
	-- sort by angle
	table.sort(points, function(a,b)
		local aNum = a.angle
		local bNum = b.angle
		return aNum < bNum
	end)
	
	return points
end


-- maybe an optimisation step where we compute & store a bbox for each asteroid, to use in asteroidOnScreen?


-- Check if all points of an asteroid are out of bounds
function asteroidOffScreen(asteroid, mode)
	
	-- full: is asteroid fully off screen (all vertices out of bounds)
	-- partial: is asteroid at least partially off screen (at least one vertex out of bounds)
	
	for i=1, #asteroid.points, 1 do
		p = asteroid.points[i]
		if mode == "full" and p.x >= 0 and p.x <= screenSize[1] and p.y >= 0 and p.y <= screenSize[2] then
			-- if a single point is still on screen, return false
			return false
		-- elseif mode == "partial" and (p.x < 0 or p.x > screenSize[1] or p.y < 0 or p.y > screenSize[2]) then
		-- 	-- if a single point is off screen, return true
		-- 	return true
		end
	end
	
	return true
end


-- Wrap the points of the asteroid around the screen
function wrapAsteroid(asteroid)
	mp = {x = asteroid.points[1].x, y = asteroid.points[1].y}
	for i=1, #asteroid.points, 1 do
		if mp.x > screenSize[1] then
			asteroid.points[i].x = asteroid.points[i].x - screenSize[1]
		elseif mp.x < 0 then
			asteroid.points[i].x = asteroid.points[i].x + screenSize[1]
		elseif mp.y > screenSize[2] then
			asteroid.points[i].y = asteroid.points[i].y - screenSize[2]
		elseif mp.y < 0 then
			asteroid.points[i].y = asteroid.points[i].y + screenSize[2]
		else
			error(mp.x .. ", " .. mp.y)
		end
	end
end


-- Drawing the player's ship
function drawPlayer()
	
	updateShipVertices()
	
	drawType = "fill"
	if player.invincible then drawType = "line" end
	
	-- draw triangle
	love.graphics.polygon(drawType, player.ship.top.x, player.ship.top.y, player.ship.right.x, player.ship.right.y, player.ship.left.x, player.ship.left.y)
	
	-- draw again if player is partially off the screen (vertical)
	if player.ship.top.y < 0 then
		player.ship.top.y = screenSize[2] + player.ship.top.y
		player.ship.left.y = screenSize[2] + player.ship.left.y
		player.ship.right.y = screenSize[2] + player.ship.right.y
		love.graphics.polygon(drawType, player.ship.top.x, player.ship.top.y, player.ship.right.x, player.ship.right.y, player.ship.left.x, player.ship.left.y)
	elseif player.ship.top.y > screenSize[2] then
		player.ship.top.y = player.ship.top.y - screenSize[2]
		player.ship.left.y = player.ship.left.y - screenSize[2]
		player.ship.right.y = player.ship.right.y - screenSize[2]
		love.graphics.polygon(drawType, player.ship.top.x, player.ship.top.y, player.ship.right.x, player.ship.right.y, player.ship.left.x, player.ship.left.y)
	end
	
	-- draw again if player is partially off the screen (horizontal)
	if player.ship.top.x < 0 then
		player.ship.top.x = screenSize[1] + player.ship.top.x
		player.ship.left.x = screenSize[1] + player.ship.left.x
		player.ship.right.x = screenSize[1] + player.ship.right.x
		love.graphics.polygon(drawType, player.ship.top.x, player.ship.top.y, player.ship.right.x, player.ship.right.y, player.ship.left.x, player.ship.left.y)
	elseif player.ship.top.x > screenSize[1] then
		player.ship.top.x = player.ship.top.x - screenSize[1]
		player.ship.left.x = player.ship.left.x - screenSize[1]
		player.ship.right.x = player.ship.right.x - screenSize[1]
		love.graphics.polygon(drawType, player.ship.top.x, player.ship.top.y, player.ship.right.x, player.ship.right.y, player.ship.left.x, player.ship.left.y)
	end
end


-- Drawing all of the asteroids
function drawAsteroids(list)
	oPoints = {}
	
	for i=1, #list, 1 do
		if list[i].active then
			table.insert(oPoints, list[i].points)
		end
	end
	
	for key,polygon in ipairs(oPoints) do
		vertices = {}
		for key, coordinate in ipairs(polygon) do
			table.insert(vertices, coordinate.x)
			table.insert(vertices, coordinate.y)
		end
		love.graphics.polygon("line", vertices)
	end
end


-- Drawing all the laser bolts
function drawLasers(list)
	for i=1, #list, 1 do
		if list[i].active then
			love.graphics.circle("fill", list[i].x, list[i].y, laserSize)
		end
	end
end