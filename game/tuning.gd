## TUNING: numbers you can safely change. Save the file, then restart the game to try them.

# --- You ---
const WALK_SPEED := 2.2          # metres per second
const RUN_SPEED := 4.5           # while holding Shift

# --- Camera ---
const CAMERA_ZOOM_START := 0.4   # 0 = close behind you, 1 = the whole-town diorama view
const CAMERA_NEAR_DISTANCE := 4.5   # metres, fully zoomed in
const CAMERA_FAR_DISTANCE := 140.0  # metres, fully zoomed out
const CAMERA_TURN_SPEED := 1.6   # Z and X keys, how fast the camera turns
const MOUSE_LOOK := true         # click in the window, then move the mouse to look around
const MOUSE_SENSITIVITY := 0.0035   # how far the camera turns per bit of mouse movement
const MOUSE_INVERT_Y := false    # true = push the mouse up to look down
const FIRST_PERSON_FOV := 75.0   # how wide you see through your own eyes (degrees)
const EYE_HEIGHT := 1.55         # metres; you're 1.8 m tall
const STOMP_SHAKE := 0.06        # how much the camera shakes when a giant foot lands

# --- The walking city ---
const CITY_SPEED := 4.0          # metres per second
const SWAY := 1.0                # 0 = no swaying, 2 = twice as much

# --- Neighbours ---
const NOTICE_DISTANCE := 2.5     # neighbours stop and look at you when you're this close (metres)

# --- The market street ---
const MARKET_WALKERS := 150      # people strolling and shopping along the market street
const MARKET_GROUPS := 10        # little groups standing and chatting
const MARKET_KIDS := 0.12        # share of walkers who are kids running about
const MARKET_CARRY := 0.2        # share of walkers carrying a crate or basket

# --- The errand ---
const USE_DISTANCE := 1.8        # how close you need to be to use something (metres)
const FIX_TIME := 1.5            # seconds to hold E to fit the valve

# --- Graphics ---
const QUALITY := "high"          # "high" for the home PC, "low" for a weaker laptop (F6 switches in the game)
# Low quality only:
const LOW_RENDER_SCALE := 0.7    # share of the screen's resolution the 3D is drawn at
const LOW_VIEW_DISTANCE := 450.0 # metres the camera can see (high: 1000)
const LOW_HAZE := 0.004          # the least haze, so the shorter view doesn't end in a visible edge
const LOW_SHADOW_DISTANCE := 80.0   # metres around you that get sun shadows
const LOW_PEOPLE_VIEW := 45.0    # metres: people further from the camera are hidden

# --- Sound ---
# Volumes, variety and which recording to use are set in the game with the sound board
# (press F4), and saved in audio/sound_settings.json. The built-in values are in sfx.gd.
const CREAK_CHANCE := 0.5        # chance the city creaks when a giant foot lands (0 = never, 1 = every time)
const CREAK_GAP := 4.0           # at least this many seconds between creaks
