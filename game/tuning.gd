## TUNING: numbers you can safely change. Save the file, then restart the game to try them.

# --- You ---
const WALK_SPEED := 2.2          # metres per second
const RUN_SPEED := 4.5           # while holding Shift

# --- Camera ---
const CAMERA_ZOOM_START := 0.4   # 0 = close behind you, 1 = the whole-town diorama view
const CAMERA_NEAR_DISTANCE := 4.5   # metres, fully zoomed in
const CAMERA_FAR_DISTANCE := 95.0   # metres, fully zoomed out
const CAMERA_TURN_SPEED := 1.6   # Z and X keys, how fast the camera turns
const MOUSE_LOOK := true         # click in the window, then move the mouse to look around
const MOUSE_SENSITIVITY := 0.0035   # how far the camera turns per bit of mouse movement
const MOUSE_INVERT_Y := false    # true = push the mouse up to look down
const STOMP_SHAKE := 0.06        # how much the camera shakes when a giant foot lands

# --- The walking city ---
const CITY_SPEED := 4.0          # metres per second
const SWAY := 1.0                # 0 = no swaying, 2 = twice as much

# --- Neighbours ---
const NOTICE_DISTANCE := 2.5     # neighbours stop and look at you when you're this close (metres)

# --- The errand ---
const USE_DISTANCE := 1.8        # how close you need to be to use something (metres)
const FIX_TIME := 1.5            # seconds to hold E to fit the valve

# --- Sound (decibels: 0 = full volume, -6 = about half as loud) ---
const FOOTSTEP_DB := -10.0
const STOMP_DB := -11.0          # the city's footsteps (was -2: too loud, playtest 1)
const WIND_DB := -20.0
const EFFECTS_DB := -4.0
