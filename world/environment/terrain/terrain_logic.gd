class_name TerrainLogic
extends TileMapLayer
## Lưới logic địa hình (tile 32×32, giữ nguyên tile size của dự án): phân loại thô từng ô
## (custom data `terrain`: grass / dirt / water / cliff / high / void, `elevation`: tầng).
## Tách khỏi hình ảnh: mặt đất hiển thị là texture/overlay vẽ tay lớn hơn tile; lớp này ẩn khi chơi
## (bật bằng debug overlay). Dùng cho MapBounds (kích thước map) và truy vấn loại địa hình
## (hiệu ứng bước chân, luật spawn... về sau). Collision và tầng chính xác lấy từ hình học ElevationMap / Stream.

const TERRAIN_DATA: String = "terrain"
const ELEVATION_DATA: String = "elevation"


func get_terrain_at(world_point: Vector2) -> StringName:
	var data: TileData = get_cell_tile_data(local_to_map(to_local(world_point)))
	return StringName(data.get_custom_data(TERRAIN_DATA)) if data != null else &""


func get_elevation_at(world_point: Vector2) -> int:
	var data: TileData = get_cell_tile_data(local_to_map(to_local(world_point)))
	return int(data.get_custom_data(ELEVATION_DATA)) if data != null else 0
