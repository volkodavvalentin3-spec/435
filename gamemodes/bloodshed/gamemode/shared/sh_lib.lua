MuR = MuR or {}

MuR.UNIDENTIFIED_NAME = "???"

function table.FindValueRecursive(tbl, value, visited)
    visited = visited or {}
    if visited[tbl] then return false end
    visited[tbl] = true

    for k, v in pairs(tbl) do
        if v == value then
            return true
        elseif type(v) == "table" then
            if table.FindValueRecursive(v, value, visited) then
                return true
            end
        end
    end

    return false
end
