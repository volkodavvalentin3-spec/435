MuR = MuR or {}

MuR.GORE_EVENT_DEFS = {
    dismember = {priority = "critical", eventCost = 6, recipientCost = 4},
    impact = {priority = "normal", eventCost = 2, recipientCost = 2},
    arterial = {priority = "normal", eventCost = 2, recipientCost = 2},
    pool = {priority = "normal", eventCost = 3, recipientCost = 2},
    organ = {priority = "normal", eventCost = 3, recipientCost = 2},
    gib_collision = {priority = "ambient", eventCost = 1, recipientCost = 1},
    drag = {priority = "ambient", eventCost = 1, recipientCost = 1},
    drip = {priority = "ambient", eventCost = 1, recipientCost = 1}
}

local EVENT_CAPACITY = 36
local EVENT_REFILL_PER_SECOND = 24
local RECIPIENT_CAPACITY = 18
local RECIPIENT_REFILL_PER_SECOND = 12
local BROADCAST_DIST_SQR = 1800 * 1800

local VALID_PRIORITIES = {
    critical = true,
    normal = true,
    ambient = true
}

local debugCvar = GetConVar("mur_gore_budget_debug")
    or CreateConVar("mur_gore_budget_debug", "0", FCVAR_ARCHIVE, "Enable gore budget counters")

local counters = {
    admitted = {},
    rejected = {},
    messages = {},
    clientParticles = 0,
    clientDecals = 0
}
local eventBucket

local function debugEnabled()
    return debugCvar and debugCvar:GetBool()
end

local function incrementCounter(group, kind, amount)
    if not debugEnabled() then return end

    if isstring(group) and istable(counters[group]) then
        counters[group][kind] = (counters[group][kind] or 0) + (amount or 1)
    elseif isstring(group) and isnumber(counters[group]) then
        counters[group] = counters[group] + (amount or 1)
    end
end

local function copyCounts(values)
    local result = {}
    for key, value in pairs(values) do
        result[key] = value
    end
    return result
end

local function isFiniteNumber(value)
    return isnumber(value)
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

local function isValidPosition(pos)
    return isvector(pos)
        and isFiniteNumber(pos.x)
        and isFiniteNumber(pos.y)
        and isFiniteNumber(pos.z)
end

local function resolveDefinition(kind, priority)
    local definition = isstring(kind) and MuR.GORE_EVENT_DEFS[kind]
    if not definition then return nil end

    priority = priority or definition.priority
    if not VALID_PRIORITIES[priority] then return nil end

    return definition, priority
end

local function refill(bucket, capacity, rate, now)
    local elapsed = math.max(now - bucket.updatedAt, 0)
    bucket.tokens = math.min(capacity, bucket.tokens + elapsed * rate)
    bucket.updatedAt = now
end

local function canSpend(tokens, cost, priority)
    if tokens >= cost then return true end
    return priority == "critical" and tokens >= 0
end

function MuR:GetGoreBudgetStats()
    local result = {
        admitted = copyCounts(counters.admitted),
        rejected = copyCounts(counters.rejected),
        messages = copyCounts(counters.messages),
        clientParticles = counters.clientParticles,
        clientDecals = counters.clientDecals
    }

    if SERVER and eventBucket then
        result.eventTokens = eventBucket.tokens
    end

    return result
end

if SERVER then
    eventBucket = {
        tokens = EVENT_CAPACITY,
        updatedAt = CurTime()
    }
    local recipientBuckets = setmetatable({}, {__mode = "k"})
    local sourceAdmissions = setmetatable({}, {__mode = "k"})

    function MuR:TryAdmitGoreEvent(kind, pos, priority, source)
        local definition, resolvedPriority = resolveDefinition(kind, priority)
        if not definition or not isValidPosition(pos) then
            incrementCounter("rejected", isstring(kind) and kind or "invalid")
            return false
        end

        local now = CurTime()
        refill(eventBucket, EVENT_CAPACITY, EVENT_REFILL_PER_SECOND, now)

        if not canSpend(eventBucket.tokens, definition.eventCost, resolvedPriority) then
            incrementCounter("rejected", kind)
            return false
        end

        eventBucket.tokens = math.max(
            eventBucket.tokens - definition.eventCost,
            resolvedPriority == "critical" and -definition.eventCost or 0
        )

        if IsValid(source) or istable(source) then
            sourceAdmissions[source] = {
                kind = kind,
                admittedAt = now
            }
        end

        incrementCounter("admitted", kind)
        return true
    end

    function MuR:CollectGoreRecipients(pos, kind, priority)
        local definition, resolvedPriority = resolveDefinition(kind, priority)
        if not definition or not isValidPosition(pos) then return {} end

        local now = CurTime()
        local recipients = {}

        for _, ply in player.Iterator() do
            if not IsValid(ply) or not ply:IsPlayer() then continue end

            local refEnt = ply
            if ply.GetRD then
                local ragdoll = ply:GetRD()
                if IsValid(ragdoll) then refEnt = ragdoll end
            end

            local refPos = refEnt.WorldSpaceCenter and refEnt:WorldSpaceCenter() or refEnt:GetPos()
            if not isValidPosition(refPos) or refPos:DistToSqr(pos) > BROADCAST_DIST_SQR then continue end

            local bucket = recipientBuckets[ply]
            if not bucket then
                bucket = {
                    tokens = RECIPIENT_CAPACITY,
                    updatedAt = now
                }
                recipientBuckets[ply] = bucket
            else
                refill(bucket, RECIPIENT_CAPACITY, RECIPIENT_REFILL_PER_SECOND, now)
            end

            if not canSpend(bucket.tokens, definition.recipientCost, resolvedPriority) then continue end

            bucket.tokens = math.max(
                bucket.tokens - definition.recipientCost,
                resolvedPriority == "critical" and -definition.recipientCost or 0
            )
            recipients[#recipients + 1] = ply
            incrementCounter("messages", kind)
        end

        return recipients
    end
end

if CLIENT then
    local qualityCvar = GetConVar("cl_mur_gore_quality")
        or CreateClientConVar("cl_mur_gore_quality", "1", true, false, "0=low, 1=medium, 2=high", 0, 2)

    local QUALITY = {
        [0] = {
            name = "low",
            particleScale = 0.45,
            decalScale = 0.50,
            lifetimeScale = 0.55,
            particlesPerSecond = 45,
            decalsPerSecond = 12
        },
        [1] = {
            name = "medium",
            particleScale = 0.75,
            decalScale = 0.75,
            lifetimeScale = 0.80,
            particlesPerSecond = 80,
            decalsPerSecond = 20
        },
        [2] = {
            name = "high",
            particleScale = 1.00,
            decalScale = 1.00,
            lifetimeScale = 1.00,
            particlesPerSecond = 120,
            decalsPerSecond = 30
        }
    }

    local renderBuckets = {
        particles = {tokens = QUALITY[1].particlesPerSecond, updatedAt = CurTime()},
        decals = {tokens = QUALITY[1].decalsPerSecond, updatedAt = CurTime()}
    }
    local decalCells = {}
    local decalCellCount = 0
    local nextDecalCellCleanup = 0
    local decalCellCalls = 0
    local DECAL_CELL_SIZE = 24
    local DECAL_CELL_HARD_CAP = 512
    local RENDER_RESERVE_LIMIT = 1

    local function getQuality(quality)
        if quality == nil then
            quality = qualityCvar and qualityCvar:GetInt() or 1
        end

        quality = tonumber(quality)
        if quality ~= 0 and quality ~= 1 and quality ~= 2 then
            quality = 1
        end

        return QUALITY[quality]
    end

    local function copyQuality(profile)
        return {
            name = profile.name,
            particleScale = profile.particleScale,
            decalScale = profile.decalScale,
            lifetimeScale = profile.lifetimeScale,
            particlesPerSecond = profile.particlesPerSecond,
            decalsPerSecond = profile.decalsPerSecond
        }
    end

    function MuR:GetGoreQualityProfile(quality)
        return copyQuality(getQuality(quality))
    end

    local function normalizeRenderCost(value)
        value = tonumber(value) or 0
        if not isFiniteNumber(value) or value < 0 then return nil end
        return value
    end

    local function canSpendRender(bucket, cost, preserveCore)
        if cost <= 0 or bucket.tokens >= cost then return true end
        return preserveCore
            and bucket.tokens >= 0
            and bucket.tokens - cost >= -RENDER_RESERVE_LIMIT
    end

    function MuR:SpendGoreRenderBudget(kind, particleCost, decalCost, preserveCore)
        local definition, priority = resolveDefinition(kind)
        if not definition then return false end

        particleCost = normalizeRenderCost(particleCost)
        decalCost = normalizeRenderCost(decalCost)
        if not particleCost or not decalCost then return false end

        local profile = getQuality()
        local now = CurTime()
        refill(renderBuckets.particles, profile.particlesPerSecond, profile.particlesPerSecond, now)
        refill(renderBuckets.decals, profile.decalsPerSecond, profile.decalsPerSecond, now)

        local allowReserve = preserveCore == true and priority == "critical"
        if not canSpendRender(renderBuckets.particles, particleCost, allowReserve)
            or not canSpendRender(renderBuckets.decals, decalCost, allowReserve) then

            return false
        end

        renderBuckets.particles.tokens = renderBuckets.particles.tokens - particleCost
        renderBuckets.decals.tokens = renderBuckets.decals.tokens - decalCost
        incrementCounter("clientParticles", nil, particleCost)
        incrementCounter("clientDecals", nil, decalCost)
        return true
    end

    local function cleanupDecalCells(now)
        for key, expiresAt in pairs(decalCells) do
            if expiresAt <= now then
                decalCells[key] = nil
                decalCellCount = decalCellCount - 1
            end
        end

        nextDecalCellCleanup = now + 1
        decalCellCalls = 0
    end

    local function evictOldestDecalCell()
        local oldestKey
        local oldestExpiry

        for key, expiresAt in pairs(decalCells) do
            if not oldestExpiry or expiresAt < oldestExpiry then
                oldestKey = key
                oldestExpiry = expiresAt
            end
        end

        if oldestKey then
            decalCells[oldestKey] = nil
            decalCellCount = decalCellCount - 1
        end
    end

    function MuR:TryGoreDecalCell(pos, cooldown)
        if not isValidPosition(pos) then return false end

        cooldown = tonumber(cooldown) or 0.12
        if not isFiniteNumber(cooldown) then return false end
        cooldown = math.Clamp(cooldown, 0.01, 10)

        local now = CurTime()
        decalCellCalls = decalCellCalls + 1
        if now >= nextDecalCellCleanup or decalCellCalls >= 64 then
            cleanupDecalCells(now)
        end

        local key = math.floor(pos.x / DECAL_CELL_SIZE)
            .. ":" .. math.floor(pos.y / DECAL_CELL_SIZE)
            .. ":" .. math.floor(pos.z / DECAL_CELL_SIZE)
        local expiresAt = decalCells[key]
        if expiresAt and expiresAt > now then return false end

        if not expiresAt then
            if decalCellCount >= DECAL_CELL_HARD_CAP then
                evictOldestDecalCell()
            end
            decalCellCount = decalCellCount + 1
        end

        decalCells[key] = now + cooldown
        return true
    end
end
