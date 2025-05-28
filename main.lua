-- Missile Command

function love.load()
    love.window.setTitle("Missile Command - Remasterizado")
    
    SCREEN_WIDTH = 800
    SCREEN_HEIGHT = 600
    
    spaceshipImage = nil
    cityImage = nil
    batteryImage = nil
    
    local success, result = pcall(love.graphics.newImage, "spaceship.png")
    if success then
        spaceshipImage = result
        print("Imagen de nave espacial cargada: spaceship.png")
    else
        print("No se encontró spaceship.png - usando gráficos por defecto")
    end
    
    success, result = pcall(love.graphics.newImage, "city.png")
    if success then
        cityImage = result
        print("Imagen de ciudad cargada: city.png")
    else
        print("No se encontró city.png - usando gráficos por defecto")
    end
    
    success, result = pcall(love.graphics.newImage, "battery.png")
    if success then
        batteryImage = result
        print("Imagen de batería cargada: battery.png")
    else
        print("No se encontró battery.png - usando gráficos por defecto")
    end
    
    gameState = "playing" 
    
    score = 0
    level = 1
    cities = 6
    ammo = 10
    
    cityPositions = {}
    local cityStartX = 150 
    local citySpacing = 100  
    for i = 1, 6 do
        cityPositions[i] = {
            x = cityStartX + (i-1) * citySpacing,
            y = SCREEN_HEIGHT - 60,
            alive = true
        }
    end
    
    batteries = {
        {x = 120, y = SCREEN_HEIGHT - 30, alive = true},
        {x = SCREEN_WIDTH/2, y = SCREEN_HEIGHT - 30, alive = true},
        {x = SCREEN_WIDTH - 120, y = SCREEN_HEIGHT - 30, alive = true}
    }
    
    enemySpaceships = {}
    playerMissiles = {}
    explosions = {}
    
    enemySpawnTimer = 0
    enemySpawnRate = 3.0
    
    particles = {}
    
    font = love.graphics.newFont("atari.ttf",16)
    titleFont = love.graphics.newFont("atari.ttf",24)
    bigFont = love.graphics.newFont("atari.ttf", 32)
    love.graphics.setFont(font)
    
    uiPulse = 0
    scoreDisplay = 0
    targetScore = 0
    
    startNewWave()
end

function love.update(dt)
    if gameState == "playing" then
        updateGame(dt)
    end
    
    uiPulse = uiPulse + dt * 3
    
    if scoreDisplay < targetScore then
        scoreDisplay = scoreDisplay + math.max(1, (targetScore - scoreDisplay) * dt * 5)
        if scoreDisplay > targetScore then
            scoreDisplay = targetScore
        end
    end
end

function updateGame(dt)
    enemySpawnTimer = enemySpawnTimer + dt
    if enemySpawnTimer >= enemySpawnRate then
        spawnEnemySpaceship()
        enemySpawnTimer = 0
        if enemySpawnRate > 1.0 then
            enemySpawnRate = enemySpawnRate - 0.05
        end
    end
    
    for i = #enemySpaceships, 1, -1 do
        local spaceship = enemySpaceships[i]
        spaceship.x = spaceship.x + spaceship.vx * dt
        spaceship.y = spaceship.y + spaceship.vy * dt
        spaceship.rotation = spaceship.rotation + spaceship.rotationSpeed * dt
        
        local dist = math.sqrt((spaceship.x - spaceship.targetX)^2 + (spaceship.y - spaceship.targetY)^2)
        if dist < 10 then
            createExplosion(spaceship.x, spaceship.y, 80, "enemy")
            table.remove(enemySpaceships, i)
        elseif spaceship.y > SCREEN_HEIGHT + 50 then
            table.remove(enemySpaceships, i)
        end
    end
    
    for i = #playerMissiles, 1, -1 do
        local missile = playerMissiles[i]
        missile.x = missile.x + missile.vx * dt
        missile.y = missile.y + missile.vy * dt
        
        local dist = math.sqrt((missile.x - missile.targetX)^2 + (missile.y - missile.targetY)^2)
        if dist < 10 or missile.y < 0 or missile.x < 0 or missile.x > SCREEN_WIDTH then
            createExplosion(missile.x, missile.y, 60, "player")
            table.remove(playerMissiles, i)
        end
    end
    
    for i = #explosions, 1, -1 do
        local explosion = explosions[i]
        explosion.time = explosion.time + dt
        explosion.radius = explosion.maxRadius * (explosion.time / explosion.duration)
        
        if explosion.time >= explosion.duration then
            table.remove(explosions, i)
        else
            if explosion.type == "player" then
                checkExplosionCollisions(explosion)
            end
            
            if explosion.type == "enemy" then
                checkCityCollisions(explosion)
            end
        end
    end
    
    for i = #particles, 1, -1 do
        local particle = particles[i]
        particle.x = particle.x + particle.vx * dt
        particle.y = particle.y + particle.vy * dt
        particle.life = particle.life - dt
        
        if particle.life <= 0 then
            table.remove(particles, i)
        end
    end
    
    if cities <= 0 then
        gameState = "gameOver"
    end
    
    if #enemySpaceships == 0 and enemySpawnTimer > 3 then
        if cities > 0 then
            startNewWave()
        end
    end
end

function love.draw()
    drawStars()
    
    drawGround()
    
    drawCities()
    
    drawBatteries()
    
    drawSpaceships()
    
    drawExplosions()
    
    drawParticles()
    
    drawUI()
    
    drawCrosshair()
    
    if gameState == "gameOver" then
        drawGameOver()
    end
end

function love.mousepressed(x, y, button)
    if gameState == "playing" and button == 1 and ammo > 0 then
        fireMissile(x, y)
        ammo = ammo - 1
    elseif gameState == "gameOver" and button == 1 then
        restartGame()
    end
end

function love.keypressed(key)
    if key == "r" and gameState == "gameOver" then
        restartGame()
    elseif key == "escape" then
        love.event.quit()
    end
end

function spawnEnemySpaceship()
    local startX = math.random(0, SCREEN_WIDTH)
    local startY = -30
    local targetX, targetY
    
    if math.random() < 0.7 then
        local aliveCities = {}
        for i, city in ipairs(cityPositions) do
            if city.alive then
                table.insert(aliveCities, city)
            end
        end
        if #aliveCities > 0 then
            local target = aliveCities[math.random(#aliveCities)]
            targetX, targetY = target.x, target.y
        else
            targetX, targetY = math.random(150, SCREEN_WIDTH-150), SCREEN_HEIGHT - 30
        end
    else
        local aliveBatteries = {}
        for i, battery in ipairs(batteries) do
            if battery.alive then
                table.insert(aliveBatteries, battery)
            end
        end
        if #aliveBatteries > 0 then
            local target = aliveBatteries[math.random(#aliveBatteries)]
            targetX, targetY = target.x, target.y
        else
            targetX, targetY = math.random(150, SCREEN_WIDTH-150), SCREEN_HEIGHT - 30
        end
    end
    
    local distance = math.sqrt((targetX - startX)^2 + (targetY - startY)^2)
    local speed = 60 + level * 10
    local vx = (targetX - startX) / distance * speed
    local vy = (targetY - startY) / distance * speed
    
    table.insert(enemySpaceships, {
        x = startX,
        y = startY,
        vx = vx,
        vy = vy,
        targetX = targetX,
        targetY = targetY,
        rotation = 0,
        rotationSpeed = math.random(-3, 3),
        trail = {},
        size = math.random(15, 25)
    })
end

function fireMissile(targetX, targetY)
    local closestBattery = nil
    local closestDistance = math.huge
    
    for i, battery in ipairs(batteries) do
        if battery.alive then
            local distance = math.sqrt((battery.x - targetX)^2 + (battery.y - targetY)^2)
            if distance < closestDistance then
                closestDistance = distance
                closestBattery = battery
            end
        end
    end
    
    if closestBattery then
        local startX = closestBattery.x
        local startY = closestBattery.y
        
        local distance = math.sqrt((targetX - startX)^2 + (targetY - startY)^2)
        local speed = 400
        local vx = (targetX - startX) / distance * speed
        local vy = (targetY - startY) / distance * speed
        
        table.insert(playerMissiles, {
            x = startX,
            y = startY,
            vx = vx,
            vy = vy,
            targetX = targetX,
            targetY = targetY,
            trail = {}
        })
    end
end

function createExplosion(x, y, maxRadius, explosionType)
    table.insert(explosions, {
        x = x,
        y = y,
        radius = 0,
        maxRadius = maxRadius,
        time = 0,
        duration = 1.5,
        type = explosionType
    })
    
    for i = 1, 15 do
        table.insert(particles, {
            x = x,
            y = y,
            vx = math.random(-100, 100),
            vy = math.random(-100, 100),
            life = math.random(0.5, 1.5),
            maxLife = math.random(0.5, 1.5)
        })
    end
end

function checkExplosionCollisions(explosion)
    for i = #enemySpaceships, 1, -1 do
        local spaceship = enemySpaceships[i]
        local dist = math.sqrt((spaceship.x - explosion.x)^2 + (spaceship.y - explosion.y)^2)
        if dist <= explosion.radius then
            targetScore = targetScore + 50
            createExplosion(spaceship.x, spaceship.y, 60, "chain")
            table.remove(enemySpaceships, i)
        end
    end
end

function checkCityCollisions(explosion)
    for i, city in ipairs(cityPositions) do
        if city.alive then
            local dist = math.sqrt((city.x - explosion.x)^2 + (city.y - explosion.y)^2)
            if dist <= explosion.radius then
                city.alive = false
                cities = cities - 1
            end
        end
    end
    
    for i, battery in ipairs(batteries) do
        if battery.alive then
            local dist = math.sqrt((battery.x - explosion.x)^2 + (battery.y - explosion.y)^2)
            if dist <= explosion.radius then
                battery.alive = false
            end
        end
    end
end

function startNewWave()
    level = level + 1
    ammo = 10
    enemySpawnRate = math.max(1.0, 3.0 - level * 0.15)
    
    for i, city in ipairs(cityPositions) do
        if city.alive then
            targetScore = targetScore + 100
        end
    end
end

function restartGame()
    gameState = "playing"
    score = 0
    targetScore = 0
    scoreDisplay = 0
    level = 1
    cities = 6
    ammo = 10
    enemySpawnTimer = 0
    enemySpawnRate = 3.0
    
    for i, city in ipairs(cityPositions) do
        city.alive = true
    end
    
    for i, battery in ipairs(batteries) do
        battery.alive = true
    end
    
    enemySpaceships = {}
    playerMissiles = {}
    explosions = {}
    particles = {}
end

function drawStars()
    love.graphics.setColor(1, 1, 1, 0.8)
    for i = 1, 100 do
        local x = (i * 37) % SCREEN_WIDTH
        local y = (i * 73) % (SCREEN_HEIGHT * 0.7)
        local size = 0.5 + (i % 3) * 0.5
        local brightness = 0.3 + (i % 5) * 0.2
        love.graphics.setColor(1, 1, 1, brightness)
        love.graphics.circle("fill", x, y, size)
    end
end

function drawGround()
    love.graphics.setColor(0.3, 0.5, 0.3)
    love.graphics.rectangle("fill", 0, SCREEN_HEIGHT - 40, SCREEN_WIDTH, 40)
    love.graphics.setColor(0.5, 0.7, 0.5)
    love.graphics.line(0, SCREEN_HEIGHT - 40, SCREEN_WIDTH, SCREEN_HEIGHT - 40)
end

function drawCities()
    for i, city in ipairs(cityPositions) do
        if city.alive then
            if cityImage then
                local targetWidth = 40
                local targetHeight = 40
                local scaleX = targetWidth / cityImage:getWidth()
                local scaleY = targetHeight / cityImage:getHeight()
                
                love.graphics.setColor(1, 1, 1)
                love.graphics.draw(
                    cityImage, 
                    city.x,
                    city.y,
                    0,
                    scaleX,
                    scaleY,
                    cityImage:getWidth()/2,
                    cityImage:getHeight()
                )
            else
                love.graphics.setColor(0.2, 0.7, 1)
                love.graphics.rectangle("fill", city.x - 20, city.y - 25, 40, 25)
                love.graphics.setColor(0.1, 0.5, 0.8)
                love.graphics.rectangle("fill", city.x - 15, city.y - 35, 30, 10)
                love.graphics.rectangle("fill", city.x - 8, city.y - 42, 16, 7)
                
                love.graphics.setColor(1, 1, 0.5)
                for j = 1, 4 do
                    for k = 1, 3 do
                        if math.random() > 0.3 then
                            love.graphics.rectangle("fill", city.x - 18 + j*8, city.y - 23 + k*6, 3, 4)
                        end
                    end
                end
                
                love.graphics.setColor(0.8, 0.8, 0.8)
                love.graphics.line(city.x, city.y - 42, city.x, city.y - 50)
                love.graphics.circle("fill", city.x, city.y - 50, 2)
            end
        else
            love.graphics.setColor(0.4, 0.2, 0.1)
            love.graphics.rectangle("fill", city.x - 20, city.y - 12, 40, 12)
            love.graphics.setColor(0.3, 0.1, 0.05)
            love.graphics.rectangle("fill", city.x - 15, city.y - 18, 30, 6)
            
            for j = 1, 5 do
                local smokeX = city.x - 15 + j*6 + math.sin(love.timer.getTime() + j) * 3
                local smokeY = city.y - 20 - j*4
                love.graphics.setColor(0.2, 0.2, 0.2, 0.4 - j*0.05)
                love.graphics.circle("fill", smokeX, smokeY, 3 + j)
            end
        end
    end
end

function drawBatteries()
    for i, battery in ipairs(batteries) do
        if battery.alive then
            if batteryImage then
                love.graphics.setColor(1, 1, 1)
                love.graphics.draw(batteryImage, battery.x - batteryImage:getWidth()/2, battery.y - batteryImage:getHeight())
            else
                love.graphics.setColor(0.1, 0.3, 0.8)
                love.graphics.rectangle("fill", battery.x - 12, battery.y - 18, 24, 18)
                love.graphics.setColor(0.3, 0.5, 1)
                love.graphics.rectangle("fill", battery.x - 4, battery.y - 24, 8, 10)
                
                love.graphics.setColor(0, 1, 1)
                love.graphics.rectangle("fill", battery.x - 10, battery.y - 15, 6, 4)
                love.graphics.rectangle("fill", battery.x + 4, battery.y - 15, 6, 4)
                
                if math.sin(love.timer.getTime() * 4) > 0 then
                    love.graphics.setColor(0, 1, 0)
                    love.graphics.circle("fill", battery.x, battery.y - 20, 2)
                end
            end
        else
            love.graphics.setColor(0.3, 0.3, 0.3)
            love.graphics.rectangle("fill", battery.x - 12, battery.y - 10, 24, 10)
            love.graphics.setColor(1, 0.3, 0)
            love.graphics.circle("fill", battery.x, battery.y - 5, 3)
        end
    end
end

function drawSpaceships()
    for i, spaceship in ipairs(enemySpaceships) do
        
        table.insert(spaceship.trail, {x = spaceship.x, y = spaceship.y})
        if #spaceship.trail > 12 then
            table.remove(spaceship.trail, 1)
        end
        
        for j, point in ipairs(spaceship.trail) do
            local alpha = j / #spaceship.trail
            love.graphics.setColor(1, 0.3, 0, alpha * 0.8)
            love.graphics.circle("fill", point.x, point.y, 2 + alpha * 2)
        end
        
        if spaceshipImage then
            love.graphics.setColor(1, 1, 1)
            love.graphics.draw(spaceshipImage, spaceship.x, spaceship.y, spaceship.rotation, 
                            spaceship.size/spaceshipImage:getWidth(), spaceship.size/spaceshipImage:getHeight(), 
                            spaceshipImage:getWidth()/2, spaceshipImage:getHeight()/2)
        else
            love.graphics.push()
            love.graphics.translate(spaceship.x, spaceship.y)
            love.graphics.rotate(spaceship.rotation)
            
            love.graphics.setColor(0.7, 0.7, 0.9)
            love.graphics.ellipse("fill", 0, 0, spaceship.size, spaceship.size * 0.6)
            
            love.graphics.setColor(1, 1, 1, 0.8)
            love.graphics.ellipse("fill", 0, -spaceship.size * 0.15, spaceship.size * 0.6, spaceship.size * 0.25)
            
            local pulse = math.sin(love.timer.getTime() * 8 + i) * 0.5 + 0.5
            love.graphics.setColor(1, 0, 0, pulse)
            love.graphics.circle("fill", -spaceship.size * 0.6, 0, 3)
            love.graphics.setColor(0, 1, 0, pulse)
            love.graphics.circle("fill", spaceship.size * 0.6, 0, 3)
            love.graphics.setColor(0, 0, 1, pulse)
            love.graphics.circle("fill", 0, spaceship.size * 0.4, 3)
            
            love.graphics.setColor(0.3, 0.7, 1, 0.9)
            love.graphics.ellipse("fill", 0, spaceship.size * 0.5, spaceship.size * 0.4, spaceship.size * 0.2)
            
            love.graphics.pop()
        end
    end
    
    for i, missile in ipairs(playerMissiles) do
        table.insert(missile.trail, {x = missile.x, y = missile.y})
        if #missile.trail > 10 then
            table.remove(missile.trail, 1)
        end
        
        for j, point in ipairs(missile.trail) do
            local alpha = j / #missile.trail
            love.graphics.setColor(0, 1, 0.5, alpha * 0.9)
            love.graphics.circle("fill", point.x, point.y, 1 + alpha * 2)
        end
        
        love.graphics.setColor(0, 1, 1)
        love.graphics.circle("fill", missile.x, missile.y, 4)
        love.graphics.setColor(1, 1, 1)
        love.graphics.circle("fill", missile.x, missile.y, 2)
    end
end

function drawExplosions()
    for i, explosion in ipairs(explosions) do
        local progress = explosion.time / explosion.duration
        local alpha = 1 - progress
        
        for ring = 1, 3 do
            local ringRadius = explosion.radius * (0.3 + ring * 0.35)
            local ringAlpha = alpha * (1 - ring * 0.2)
            
            if explosion.type == "enemy" then
                love.graphics.setColor(1, 0.2 + ring * 0.2, 0, ringAlpha)
            else
                love.graphics.setColor(1, 1, 0.2 + ring * 0.2, ringAlpha)
            end
            
            love.graphics.circle("line", explosion.x, explosion.y, ringRadius)
        end
        
        love.graphics.setColor(1, 1, 1, alpha * 0.5)
        love.graphics.circle("fill", explosion.x, explosion.y, explosion.radius * 0.3)
    end
end

function drawParticles()
    for i, particle in ipairs(particles) do
        local alpha = particle.life / particle.maxLife
        love.graphics.setColor(1, 0.8, 0, alpha)
        love.graphics.circle("fill", particle.x, particle.y, 1 + alpha * 2)
    end
end

function drawCrosshair()
    if gameState == "playing" then
        local mx, my = love.mouse.getPosition()
        love.graphics.setColor(1, 1, 1, 0.7)
        love.graphics.circle("line", mx, my, 15)
        love.graphics.line(mx - 10, my, mx + 10, my)
        love.graphics.line(mx, my - 10, mx, my + 10)
    end
end

function drawUI()
    
    
    love.graphics.setFont(font)
    love.graphics.setColor(1, 1, 0.5)
    love.graphics.print("PUNTUACION", 10, 10)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(string.format("%.0f", scoreDisplay), 10, 28)
    
    love.graphics.setColor(0.5, 1, 0.5)
    love.graphics.print("NIVEL " .. level, 10, 50)
    
    love.graphics.setColor(0.5, 0.8, 1)
    love.graphics.print("CIUDADES", 10, 72)
    for i = 1, 6 do
        if i <= cities then
            love.graphics.setColor(0, 1, 0)
        else
            love.graphics.setColor(0.3, 0.3, 0.3)
        end
        love.graphics.rectangle("fill", 10 + (i-1) * 15, 100, 12, 8)
    end
    
    love.graphics.setColor(1, 0.8, 0.2)
    love.graphics.print("MISILES: " .. ammo, 10, 115)
    
    local waveProgress = math.max(0, (3 - enemySpawnTimer) / 3)
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", SCREEN_WIDTH - 150, 10, 140, 30)
    love.graphics.setColor(0.2, 0.4, 0.8)
    love.graphics.rectangle("line", SCREEN_WIDTH - 150, 10, 140, 30)
    
    love.graphics.setColor(0.8, 0.4, 0.2)
    love.graphics.rectangle("fill", SCREEN_WIDTH - 145, 15, 130 * waveProgress, 20)
    love.graphics.setColor(1, 1, 1)
    
    if #enemySpaceships > 0 then
        love.graphics.setColor(1, 0.3, 0.3, 0.8 + math.sin(uiPulse) * 0.2)
        love.graphics.printf("¡INVASION EN CURSO!", SCREEN_WIDTH - 200, 50, 200, "center")
    end
end

function drawGameOver()
    love.graphics.setColor(0, 0, 0, 0.9)
    love.graphics.rectangle("fill", 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
    
    love.graphics.setColor(0.8, 0.2, 0.2, 0.8)
    love.graphics.rectangle("line", 50, 150, SCREEN_WIDTH - 100, 300)
    love.graphics.rectangle("line", 55, 155, SCREEN_WIDTH - 110, 290)
    
    love.graphics.setFont(bigFont)
    love.graphics.setColor(1, 0.2, 0.2)
    love.graphics.printf("GAME OVER", 0, SCREEN_HEIGHT/2 - 80, SCREEN_WIDTH, "center")
    
    love.graphics.setFont(titleFont)
    love.graphics.setColor(1, 1, 0.5)
    love.graphics.printf("ESTADISTICAS FINALES", 0, SCREEN_HEIGHT/2 - 40, SCREEN_WIDTH, "center")
    
    love.graphics.setFont(font)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Puntuación Final: " .. math.floor(scoreDisplay), 0, SCREEN_HEIGHT/2 - 10, SCREEN_WIDTH, "center")
    love.graphics.printf("Nivel Alcanzado: " .. level, 0, SCREEN_HEIGHT/2 + 10, SCREEN_WIDTH, "center")
    love.graphics.printf("Ciudades Salvadas: " .. cities .. "/6", 0, SCREEN_HEIGHT/2 + 30, SCREEN_WIDTH, "center")
    
    local pulse = math.sin(love.timer.getTime() * 3) * 0.3 + 0.7
    love.graphics.setColor(0.5, 1, 0.5, pulse)
    love.graphics.printf("Presiona R o Click para reiniciar", 0, SCREEN_HEIGHT/2 + 70, SCREEN_WIDTH, "center")
    love.graphics.setColor(0.8, 0.8, 0.8, pulse)
    love.graphics.printf("ESC para salir", 0, SCREEN_HEIGHT/2 + 90, SCREEN_WIDTH, "center")
    
    love.graphics.setColor(1, 0.3, 0.3, 0.3)
    for i = 1, 10 do
        local x = 100 + (i-1) * 60
        local y = 100 + math.sin(love.timer.getTime() + i) * 20
        love.graphics.circle("fill", x, y, 3)
        
        x = 100 + (i-1) * 60
        y = SCREEN_HEIGHT - 100 + math.sin(love.timer.getTime() + i + 3) * 20
        love.graphics.circle("fill", x, y, 3)
    end
end