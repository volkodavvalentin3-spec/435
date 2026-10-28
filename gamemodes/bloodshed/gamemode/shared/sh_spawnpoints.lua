-- Точки спавна, расставленные вручную через mur_spawneditor.
--
-- Общая часть: перечень типов и их вид. Сервер держит сами точки
-- (sv_spawnpoints.lua), клиент рисует их в редакторе (cl_spawneditor.lua), а
-- отсюда оба берут порядок, имена и цвета — иначе они разъедутся, и синий
-- маркер на экране будет означать не то, что синий в списке.

MuR.SpawnKinds = {
	{id = "players", name = "editor_spawn_players", color = Color(64, 132, 223)},
	{id = "team1",   name = "editor_spawn_team1", color = Color(74, 196, 108)},
	{id = "team2",   name = "editor_spawn_team2", color = Color(219, 72, 64)},
	{id = "items",   name = "editor_spawn_items", color = Color(224, 184, 64)},
	{id = "npc",     name = "editor_spawn_npc", color = Color(166, 96, 220)},
}

-- id -> описание. Порядок нужен списку, поиск по id — всему остальному.
MuR.SpawnKindByID = {}
for _, kind in ipairs(MuR.SpawnKinds) do
	MuR.SpawnKindByID[kind.id] = kind
end

function MuR.IsSpawnKind(id)
	return MuR.SpawnKindByID[id] ~= nil
end

-- Шанс по умолчанию у точки вещей: примерно каждая вторая за раунд. Не 100,
-- потому что смысл этих точек именно в том, чтобы карта не была одинаковой.
MuR.SpawnItemChance = 50

-- Радиус, в котором ПКМ ищет точку под удаление, и в котором они вообще рисуются.
MuR.SpawnPickRadius = 96
MuR.SpawnDrawRadius = 3000
