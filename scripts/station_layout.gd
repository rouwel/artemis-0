extends RefCounted
class_name StationLayout

# Shared asset and scale settings for the current single-room station build.
# Scene coordinates use metres; generated GLB bounds are approximate and are verified visually.

const ASSET_POWER_SCREEN := "res://assets/power_screen_slim_tv.glb"
const ASSET_TANK_ASSEMBLY := "res://assets/oxygen_tank_station.glb"
const ASSET_CABINET := "res://assets/cabinet.glb"
const ASSET_BED := "res://assets/small_bed.glb"
const ASSET_STORAGE_CONTAINER := "res://assets/storage_container.glb"
const ASSET_GREEN_PIPE := "res://assets/green_pipe_segment.glb"
const ASSET_BLUE_CABLE := "res://assets/blue_cable_segment.glb"
const ASSET_LIGHT_FIXTURE := "res://assets/light_fixture.glb"

const POWER_SCREEN_SCALE := Vector3(2.0, 2.0, 2.0)
const CABINET_SCALE := Vector3(2.37, 2.37, 2.37)
const STORAGE_SCALE := Vector3(1.0, 1.5, 1.0)
const BED_SCALE := Vector3(2.0, 2.0, 2.0)
const FIXTURE_SCALE := Vector3(0.25, 0.25, 0.25)

const CEILING_HEIGHT := 4.25
const CEILING_UNDERSIDE := 4.25
const CEILING_THICKNESS := 0.3
const FIXTURE_LIGHT_COLOR := Color(1.0, 0.886, 0.69)

# Pipe/cable GLBs run along local +Z; the builder changes their rotation and segment length.
const GREEN_PIPE_BASE_SCALE := Vector3(0.265, 0.68, 1.0)
const GREEN_PIPE_SEGMENT_LENGTH := 0.998
const BLUE_CABLE_BASE_SCALE := Vector3(0.036, 0.032, 1.0)
const BLUE_CABLE_SEGMENT_LENGTH := 0.998
