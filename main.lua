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
		size = screenSize[1]/sizeMod, -- set player size based on screen size
		speed = 0,
		alive = true,
		invincible = false,
		respawn = 0
	}
	
	-- initialise asteroids (currently hard-coded)
	asteroids = {
		{
			{x = 100, y = 100},
			{x = 200, y = 100},
			{x = 200, y = 120},
			{x = 180, y = 140},
			{x = 200, y = 160},
			{x = 200, y = 200},
			{x = 100, y = 200}
		},
		{
			{x = 300, y = 300},
			{x = 350, y = 300},
			{x = 400, y = 320},
			{x = 380, y = 340},
			{x = 400, y = 360},
			{x = 350, y = 400},
			{x = 280, y = 400}
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
		updatePlayer(dt)
	elseif love.timer.getTime() > player.respawn then
		player.position = {x = player.respawnPosition.x, y = player.respawnPosition.y}
		player.speed = 0
		player.bearing = 270
		player.alive = true
	end
	
end


-- Main drawing step
function love.draw()
	
	-- draw player
	if player.alive then drawPlayer() end
	
	-- draw asteroids
	drawAsteroids(asteroids)
	 
	-- Debug text
	if debug then
		printDebug()
	end
end


function isPlayerColliding(obstacles)
	-- check against each obstacle
	for i = 1, #obstacles, 1 do
		if checkCollision(obstacles[i], {player.ship.top, player.ship.right, player.ship.left}) then return true end
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


-- Simple bounding box check (TODO: this should check against the ship's bounding box rather than each vertex of the ship)
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
	
	bboxText =  "Colliding: " .. tostring(colliding)
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
	heading = {
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
		x = heading.x * dt * player.speed, 
		y = heading.y * dt * player.speed
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


-- From player's current position, get the vertices of the ship
function updateShipVertices()
	-- top
	player.ship.top = {
		x = player.position.x+(heading.x*player.size), 
		y = player.position.y+(heading.y*player.size)
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


-- Generate a random asteroid
function generateAsteroid()
	--TODO
end

-- Drawing all of the asteroids
function drawAsteroids(list)
	for key,polygon in ipairs(list) do
		vertices = {}
		for key, coordinate in ipairs(polygon) do
			table.insert(vertices, coordinate.x)
			table.insert(vertices, coordinate.y)
		end
		love.graphics.polygon("line", vertices)
	end
end