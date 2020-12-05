function Quarry(miningTurtle, guiCustomMessages, master)
  -- Local variables of the object / Variáveis locais do objeto
  local self = {}
  local miningT = miningTurtle
  local Data = miningT.getData()
  local commonF = miningT.getCommonF()
  local objects = Data.getObjects()
  local specificData
  local guiMessages = guiCustomMessages or GUIMessages()

  -- Private functions / Funções privadas

  local function specificDataInput()
    local specificLocalData = {}
    specificLocalData.stepX = 0
    specificLocalData.stepY = 0
    specificLocalData.y = 0
    specificLocalData.x = 0
    specificLocalData.f = objects.position.getF()
    if master ~= nil then
      specificLocalData.x = master.task.params[1]
      specificLocalData.y = master.task.params[2]
    else
      while specificLocalData.y <= 0 or specificLocalData.x <= 0 do
        guiMessages.showHeader("Quarry")
        print("Tell me the quarry dimension x:y")
        print("X:")
        specificLocalData.x = tonumber(commonF.limitToWrite(15))
        print("Y:")
        specificLocalData.y = tonumber(commonF.limitToWrite(15))
        if specificLocalData.y <= 0 or specificLocalData.x <= 0 then
          guiMessages.showWarningMsg("Informed value can't be zero or lower than zero")
        end
      end
    end
    specificLocalData.bounds = computeBounds(specificLocalData.x, specificLocalData.y, specificLocalData.f)
    if specificLocalData.bounds == nil then
      guiMessages.showWarningMsg("Unable to compute quarry bounds")
    else
      guiMessages.showInfoMsg("Quarry Bounds Min/Max:")
      guiMessages.showInfoMsg("  X=" .. specificData.bounds.minX .. "/" .. specificData.bounds.maxX)
      guiMessages.showInfoMsg("  Z=" .. specificData.bounds.minZ .. "/" .. specificData.bounds.maxZ)
    end
    specificLocalData.turn = false
    specificLocalData.descend = false
    return specificLocalData
  end

  local function computeBounds(sizeX, sizeY, facing)
    if facing == nil then
      guiMessages.showWarningMsg("No facing for quarry bounds")
      return nil
    end
    local x = objects.position.getX()
    local z = objects.position.getZ()
    local boundsCase =
      commonF.switch {
      [0] = function(x) -- Facing South +Z, -X
        return {
          minX = x - (sizeY - 1),
          minZ = z,
          maxX = x,
          maxZ = z + sizeX
        }
      end,
      [1] = function(x) -- Facing West -X, -Z
        return {
          minX = x - sizeX,
          minZ = z - (sizeY - 1),
          maxX = x,
          maxZ = z 
        }
      end,
      [2] = function(x) -- Facing North -Z, +X
        return {
          minX = x,
          minZ = z - sizeX,
          maxX = x + (sizeY - 1),
          maxZ = z
        }
      end,
      [3] = function(x) -- Facing East +X, +Z
        return {
          minX = x,
          minZ = z,
          maxX = x + sizeX,
          maxZ = z + (sizeY - 1)
        }
      end,
      default = function(x)
        return nil
      end
    }
    return boundsCase:case(facing)
  end

  -- Left = true, Right = false
  local function adjustTurn()
    local turn = (specificData.stepX % 2 == 1)
    -- Even sized y numbered quarries flip turn direction based on level
    -- level math should be changed if quarry level doesn't start at home position
    local level = math.abs(objects.home.getY() - objects.position.getY())
    if specificData.y % 2 == 0 and level % 2 == 0 then
      turn = not turn
    end
    guiMessages.showInfoMsg("Old turn direction: " .. specificData.turn)
    guiMessages.showInfoMsg("New turn direction: " .. turn)
    specificData.turn = turn
  end
    
  local function verifyBounds()
    if specificData.bounds == nil then
      guiMessages.showWarningMsg("Unable to verify quarry boundary")
      return
    end
    local x = objects.position.getX()
    local z = objects.position.getZ()
    local facing = objects.position.getF()
    -- Check facing and "move" forward one
    local function newPos(x, z, facing)
      local new = {}
      if facing == 0 then new.z = z +1 -- South
      elseif facing == 1 then new.x = x -1 -- West
      elseif facing == 2 then new.z = z -1 -- North
      elseif facing == 3 then new.x = x +1 end  -- East
      return new
    end
    local new = newPos(x, z, facing)
    -- If "move" is outside quarry bounds, reverse facing
    local tries = 0
    while specificData.bounds.minX > new.x or specificData.bounds.maxX < new.x
    or specificData.bounds.minZ > new.z or specificData.bounds.maxZ < new.z do
      guiMessages.showWarningMsg("Wrong facing discovered, correcting")
      facing = bit.bxor(facing, 2)
      new = newPos(x, z, facing)
      tries = tries +1
      if tries > 2 then
        guiMessages.showErrorMsg("I'm lost, I think I'm outside the quarry bounds")
        guiMessages.showInfoMsg("Position: { X=" .. objects.position.getX()
          ..", Y=" .. objects.position.getY() .. ", Z=" .. objects.position.getZ() .. "}")
        guiMessages.showInfoMsg("New: { X=" .. new.x .. ", Z=" .. new.z .. "}")
        guiMessages.showInfoMsg("Quarry Bounds Min/Max:")
        guiMessages.showInfoMsg("  X=" .. specificData.bounds.minX .. "/" .. specificData.bounds.maxX)
        guiMessages.showInfoMsg("  Z=" .. specificData.bounds.minZ .. "/" .. specificData.bounds.maxZ)
        while true do
          os.sleep(60)
        end
      end
    end
    -- If we have the wrong facing, we likely need to adjust our turn direciton
    if objects.position.getF() ~= facing then
      adjustTurn()
    end
    while objects.position.getF() ~= facing do
      miningT.left()
    end
  end

  local function addStepX()
    specificData.stepX = specificData.stepX + 1
    miningT.saveAll()
  end

  local function addStepY()
    specificData.stepY = specificData.stepY + 1
    miningT.saveAll()
  end

  local function main()
    if objects.execution.getExecuting() ~= "Quarry" then
      objects.execution.setExecuting("Quarry")
      objects.execution.setStep(0)
      objects.execution.setTerminate(false)
      objects.escape.setTries(0)
      objects.escape.setTryToEscape(true)
      objects.execution.setSpecificData(specificDataInput())
      specificData = objects.execution.getSpecificData()
      miningT.down()
    else
      specificData = objects.execution.getSpecificData()
      objects.escape.setTryToEscape(true)
    end
    miningT.saveAll()
  end
  main()

  local actionsCase =
    commonF.switch {
    [0] = function(x)
      if specificData.stepX == 0 then
        verifyBounds()
      end
      while specificData.stepX < specificData.x - 1 and not objects.execution.getTerminate() do
        miningT.forward()
        addStepX()
      end
      if not objects.execution.getTerminate() then
        specificData.stepX = 0
      end
    end,
    [1] = function(x)
      if (not objects.execution.getTerminate()) then
        if specificData.turn then
          if specificData.stepY < specificData.y - 1 then
            miningT.left()
            miningT.forward()
            miningT.left()
            addStepY()
          else
            miningT.left()
            miningT.left()
            specificData.stepY = 0
            specificData.descend = true
          end
          specificData.turn = false
        else
          if specificData.stepY < specificData.y - 1 then
            miningT.right()
            miningT.forward()
            miningT.right()
            addStepY()
          else
            miningT.right()
            miningT.right()
            specificData.stepY = 0
            specificData.descend = true
          end
          specificData.turn = true
        end
      end
    end,
    [2] = function(x)
      if (not objects.execution.getTerminate()) then
        if specificData.descend then
          miningT.down()
          specificData.descend = false
          specificData.turn = (not specificData.turn)
        end
      end
    end,
    default = function(x)
      return 0
    end
  }

  local function patternAction()
    while objects.execution.getStep() <= 2 and not objects.execution.getTerminate() do
      actionsCase:case(objects.execution.getStep())
      if (not objects.execution.getTerminate()) then
        objects.execution.addStep()
        miningT.saveAll()
      end
    end
    if (not objects.execution.getTerminate()) then
      objects.execution.setStep(0)
      miningT.saveAll()
    end
  end

  local function wasTerminated(terminate)
    if terminate then
      Data.storeCurrentPosition()
      Data.storeCurrentExecution()
      Data.saveData()
      local maintenance = Maintenance(miningT, guiMessages)
      maintenance.start()
    else
      Data.finalizeExecution()
      objects.task.setStatus(true)
      objects.task.complete()
      Data.previousPosIsHome()
      local maintenance = Maintenance(miningT, guiMessages)
      maintenance.start()
    end
  end

  -- Global functions of the object / Funções Globais do objeto

  function self.start()
    while not objects.execution.getTerminate() and objects.position.getY() > 5 do
      miningT.verifyFuelLevelToGoBackHome()
      patternAction()
    end
    wasTerminated(objects.execution.getTerminate())
  end

  return self
end
