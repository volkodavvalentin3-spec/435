executionCamera = {}
executionCamera.lerpSpeed = 6
executionCamera.returnLerpSpeed = 16
executionCamera.currentPos = Vector(0, 0, 0)
executionCamera.currentAng = Angle(0, 0, 0)
executionCamera.wasExecuting = false
executionCamera.distThreshold = 8
executionCamera.sideOffset = 60
executionCamera.backDistance = 40
executionCamera.minDistance = 5
executionCamera.cameraPhase = 0

function executionCamera:FindExecutionTarget(ply)
    local target = ply:GetNW2Entity("ExecutionTarget")

    if !IsValid(target) then
        local trace = {
            start = ply:EyePos(),
            endpos = ply:EyePos() + ply:GetForward() * 100 + Vector(0,0,32),
            filter = ply,
            mask = MASK_SHOT_HULL
        }

        local tr = util.TraceLine(trace)
        if tr.Hit and tr.Entity and IsValid(tr.Entity) then
            target = tr.Entity
        end
    else
        if target:IsPlayer() and IsValid(target:GetNW2Entity("RD_EntCam")) then
            target = target:GetNW2Entity("RD_EntCam")
        end
    end

    return target
end

hook.Add("CalcView", "!!!GamemodeExecutionCamera", function(ply, pos, angles, fov)
    if MuR.CutsceneActive then return end

    local isExecuting = ply:IsExecuting()
    if isExecuting and MuR:GetClient("blsd_execution_3rd_person") then
        local target = executionCamera:FindExecutionTarget(ply)

        if not executionCamera.wasExecuting then
            executionCamera.currentPos = pos
            executionCamera.currentAng = angles
            executionCamera.wasExecuting = true
            executionCamera.cameraPhase = 0
        end

        executionCamera.cameraPhase = math.min(executionCamera.cameraPhase + FrameTime() * 1.5, 1)

        local headBone = ply:LookupBone("ValveBiped.Bip01_Spine4")
        if headBone then
            local headPos = ply:GetBonePosition(headBone)
            if headPos then
                local targetLookAt = headPos + ply:GetForward() * 100
                if IsValid(target) then
                    local targetHeadBone = target:LookupBone("ValveBiped.Bip01_Spine4")
                    if targetHeadBone then
                        targetLookAt = target:GetBonePosition(targetHeadBone)
                    else
                        targetLookAt = target:WorldSpaceCenter()
                    end
                end

                local direction = (targetLookAt - headPos):GetNormalized()
                local sideVec = direction:Cross(Vector(0, 0, 1)):GetNormalized()

                local startPos = headPos + Vector(0, 0, 30)
                local sideAmount = executionCamera.sideOffset * math.sin(CurTime() * 0.5)
                local ah = Vector(0, 0, -8)
                if string.find(ply:GetSVAnim(), "victim") then
                    ah = Vector(0,0,64)
                end

                local endPos = headPos - direction * executionCamera.backDistance + sideVec * sideAmount + ah
                local phase = executionCamera.cameraPhase
                local desiredPos = LerpVector(phase, startPos, endPos)

                local trace = {
                    start = headPos,
                    endpos = desiredPos,
                    filter = {ply, target},
                    mask = MASK_SOLID
                }

                local tr = util.TraceLine(trace)
                if tr.Hit then
                    desiredPos = tr.HitPos + tr.HitNormal * executionCamera.minDistance
                end

                local lookStart = (headPos - desiredPos):Angle()
                local lookEnd = (targetLookAt - desiredPos):Angle()
                local desiredAng = LerpAngle(phase, lookStart, lookEnd)
                local addyaw = 0

                local shakeFactor = 2 * phase
                desiredAng.pitch = desiredAng.pitch + math.sin(CurTime() * 8) * shakeFactor
                desiredAng.yaw = desiredAng.yaw + math.sin(CurTime() * 12) * shakeFactor

                executionCamera.currentPos = LerpVector(FrameTime() * executionCamera.lerpSpeed, executionCamera.currentPos, desiredPos)
                executionCamera.currentAng = LerpAngle(FrameTime() * executionCamera.lerpSpeed, executionCamera.currentAng, desiredAng)
            end
        end

        local dynamicFOV = fov - 5 * math.sin(CurTime() * 2) * executionCamera.cameraPhase

        return {
            origin = executionCamera.currentPos,
            angles = executionCamera.currentAng,
            fov = dynamicFOV,
            drawviewer = true
        }
    elseif executionCamera.wasExecuting then
        executionCamera.currentPos = LerpVector(FrameTime() * executionCamera.returnLerpSpeed, executionCamera.currentPos, pos)
        executionCamera.currentAng = LerpAngle(FrameTime() * executionCamera.returnLerpSpeed, executionCamera.currentAng, angles)

        if executionCamera.currentPos:Distance(pos) < executionCamera.distThreshold then
            executionCamera.wasExecuting = false
            executionCamera.cameraPhase = 0
            return
        end

        return {
            origin = executionCamera.currentPos,
            angles = executionCamera.currentAng,
            fov = fov
        }
    end
end)
