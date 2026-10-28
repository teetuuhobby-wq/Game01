extends RefCounted
## THE TOWN'S PEOPLE AND PLACES, as plain data: who lives here, how they look, what
## they say, and the words on the boards and shelves. Edit freely: change a line,
## a colour or a name here and the game picks it up. (Where each person stands is
## decided by the buildings, in world/facilities.gd.)
## Characters are everyday folk: no secrets or story, so nothing here can spoil it.
## Their colours are their own: the random crowd (world/people.gd) doesn't use them,
## so each one stands out.

## look: the build options from world/people.gd _make_person (legs, torso, dress,
## apron, belly, sash, beard, hair, scarf_colour). items: what they carry or wear
## (see _item_mesh in world/cast.gd). habit: their little idle movement.
## lines: what they say when you talk to them, one per press of E, round and round.
## before: lines only until Mira's rain-catcher is fixed (said first).
## after: lines once it's fixed (said first, then the everyday lines).
const CAST := {
	"sabeth": {
		"name": "Sabeth", "role": "guild clerk", "where": "guild",
		"shirt": Color(0.16, 0.20, 0.36), "bottom": Color(0.16, 0.20, 0.36), "hair": Color(0.70, 0.68, 0.66),
		"skin": Color(0.78, 0.58, 0.42),
		"look": {"torso": 4, "dress": true, "hair": "bun", "sash": Color(0.84, 0.66, 0.24)},
		"items": ["ledger", "spectacles", "tall_bun"], "habit": "write",
		"personality": "Precise, dry, secretly delighted by anyone who fills in a form properly.",
		"lines": [
			"Requests are on the board behind you. Please don't pin anything to it yourself.",
			"New members start at the bottom of the ledger. Everyone starts at the bottom of the ledger.",
			"Nineteen years I've kept these books. The ink smells better than most people.",
			"If you take a request, come back in one piece. The paperwork for the other thing is dreadful.",
			"Quiet tonight. I prefer quiet. Quiet doesn't argue.",
		],
		"after": ["I hear you fixed the west catcher. Unrequested, unrecorded, unpaid. Very irregular. Well done."],
	},
	"dorran": {
		"name": "Dorran", "role": "barkeep", "where": "tavern",
		"shirt": Color(0.50, 0.14, 0.18), "bottom": Color(0.26, 0.20, 0.16), "hair": Color(0.45, 0.30, 0.15),
		"skin": Color(0.92, 0.75, 0.62),
		"look": {"belly": true, "apron": true, "beard": true, "hair": "bald"},
		"items": ["mug"], "habit": "polish",
		"personality": "Big, warm, never forgets an order, always has a story about somebody's cousin.",
		"lines": [
			"Welcome to the Kneeling Strider! Pull up a stool, the good one's by the fire.",
			"Cactus cider's fresh. The stew is... a stew. You'll live.",
			"Every time the city kneels for the night, this place fills up in ten minutes flat.",
			"House rules: no sand in the drinks, no knives on the tables, no singing before the third round.",
			"My cousin swears he out-drank a sand-crawler. My cousin has never seen a sand-crawler.",
			"I take Old Wendel a cup of tea every dusk. Never says thanks. Never leaves a drop.",
		],
		"after": ["Water pressure's up in the kitchen! That was you, with the rain-catcher? First round's on me."],
	},
	"bram": {
		"name": "Bram", "role": "mechanic", "where": "workshop",
		"shirt": Color(0.30, 0.40, 0.55), "bottom": Color(0.30, 0.40, 0.55), "hair": Color(0.42, 0.36, 0.32),
		"skin": Color(0.80, 0.60, 0.45),
		"look": {"beard": true, "hair": "short", "sash": Color(0.30, 0.24, 0.20)},
		"items": ["goggles"], "habit": "hammer",
		"personality": "Gruff, kind underneath, talks to machines more gently than to people.",
		"before": ["The spare valve? On the bench. Take it, Mira's been on at me all week."],
		"lines": [
			"Mind the bench. Everything on it is either hot, sharp or important.",
			"Hear that groan when the city takes a step? That's the old girl telling us she's fine.",
			"I've fixed every pump on this deck twice. The third time, I'm retiring.",
		],
		"after": ["Catcher's purring, Mira says. You didn't force the thread. I can tell."],
	},
	"pell": {
		"name": "Pell", "role": "shopkeeper", "where": "store",
		"shirt": Color(0.20, 0.48, 0.30), "bottom": Color(0.55, 0.48, 0.38), "hair": Color(0.20, 0.13, 0.08),
		"skin": Color(0.55, 0.38, 0.26),
		"look": {"apron": true, "hair": "short"},
		"items": ["feather_hat"], "habit": "pace",
		"personality": "Quick-talking, cheerful, believes there's a right tool for every problem and that she sells it.",
		"lines": [
			"Pell's Provisions! Rope, oil, lamps, figs, buckets, boots: if you need it, I've got it, or I know who has.",
			"Going down to the sand tonight? Take a lantern. Then take a spare lantern.",
			"That dented lantern up top was my very first one. Sentimental. Not for sale.",
			"Prices are fair, the figs are fresh, and the boots only squeak for the first week.",
		],
		"after": ["You're the one who fixed the rain-catcher? Here, have a fig. No, take two. Word gets around."],
	},
	"tamsin": {
		"name": "Tamsin", "role": "bath attendant", "where": "bath",
		"shirt": Color(0.25, 0.70, 0.78), "bottom": Color(0.25, 0.70, 0.78), "hair": Color(0.10, 0.09, 0.08),
		"skin": Color(0.92, 0.75, 0.62),
		"look": {"dress": true, "hair": "long", "sash": Color(0.96, 0.95, 0.90)},
		"items": ["towels", "head_towel"], "habit": "stroll",
		"personality": "Calm, unhurried, speaks softly so everyone else does too.",
		"lines": [
			"Sand stays outside. Worries too, if you can manage it.",
			"Breathe slower. The water will wait for you.",
			"Find a spot along the ledge and sit as long as you like. No one's counting.",
			"Some evenings, before the city kneels, you can feel each step through the water. Slow and steady.",
		],
		"after": ["The pool filled faster today. The west catcher, I think. Tell her the water says thank you."],
	},
	"mira": {
		"name": "Mira", "role": "your neighbour", "where": "plaza",
		"shirt": Color(0.86, 0.48, 0.62), "bottom": Color(0.24, 0.28, 0.38), "hair": Color(0.10, 0.09, 0.08),
		"skin": Color(0.78, 0.58, 0.42),
		"look": {"hair": "scarf", "scarf_colour": Color(0.18, 0.62, 0.52)},
		"items": ["watering_can"], "habit": "none",
		"personality": "Practical, upbeat, keeps half the neighbourhood's plants alive.",
		"before": [
			"Valve's at Bram's workshop, one terrace down on the east side. The catcher's out west on the ring.",
			"Without that catcher half the street's gardens drink dust. Mine first.",
			"Bram grumbles, but he'll have left it out for you. He always does.",
		],
		"lines": [
			"These pots won't water themselves. Believe me, I've asked.",
		],
		"after": [
			"Listen! Water in the pipes again. You're officially my favourite neighbour.",
			"Guild hall's at the foot of the homes-side stairs. Or go soak. You've earned it.",
			"Don't tell Bram, but he worried about that catcher more than I did.",
		],
	},
	"wendel": {
		"name": "Old Wendel", "role": "lookout", "where": "lookout",
		"shirt": Color(0.36, 0.26, 0.16), "bottom": Color(0.36, 0.26, 0.16), "hair": Color(0.92, 0.90, 0.86),
		"skin": Color(0.80, 0.60, 0.45),
		"look": {"legs": 2, "dress": true, "beard": true, "hair": "short"},
		"items": ["spyglass", "brim_hat"], "habit": "scan",
		"personality": "Weathered, few words, notices everything, likes the desert more than people (mostly).",
		"lines": [
			"Hm. Dust on the eastern ridge. Wind's turning. Tell Dorran to shut his shutters by dusk.",
			"Forty years on this wall. Seen a dust devil taller than the tavern. Pretty, that.",
			"The city walks, I watch. Somebody's got to spot the storms before they spot us.",
			"You want to be useful? Bring me tea at dusk. Dorran does. Don't tell him I like it.",
		],
		"after": ["Saw the water running down the west side from up here. Good work. Hm."],
	},
	"pip": {
		"name": "Pip", "role": "errand runner", "where": "south_street",
		"shirt": Color(0.55, 0.80, 0.25), "bottom": Color(0.24, 0.28, 0.38), "hair": Color(0.62, 0.28, 0.14),
		"skin": Color(0.92, 0.75, 0.62),
		"look": {"hair": "short"}, "kid": true,
		"items": ["satchel", "cap"], "habit": "run",
		"personality": "Fast, curious, knows every shortcut and every rumour (most of them wrong).",
		"lines": [
			"Can't stop! Got a parcel for the guild, a note for the tavern and a fig for me.",
			"Crawlers in the lower hull are big as dogs! Okay, cats. Okay, I've never seen one.",
			"When I'm big I'm going down to the sand at night like the guild folk. Sabeth says I have to learn to spell first.",
			"Race you to the stairs! ...Okay, you win, I wasn't ready.",
		],
		"after": ["Everyone's talking about you fixing the rain-catcher! Well, Mira is. Loudly."],
	},
}

## The words on boards and shelves, by spot id (see world/facilities.gd).
## Flavour only: there are no real requests, ranks or money in the game yet.
const PLACES := {
	"guild_board": {"title": "REQUESTS", "lines": [
		"Wanted: steady hands to escort the water cart to the east pumps. Pays in gratitude and a good dinner.  (Sabeth)",
		"Lost near the cargo lift: one left boot, well loved. Reward: a hot meal at the Kneeling Strider.",
		"Night work: sand-crawlers nesting in the lower hull again. Bring a lantern, a broom and courage.",
	]},
	"guild_ranks": {"title": "GUILD NOTICES", "lines": [
		"Lost property: ask Sabeth at the counter.",
		"Lanterns must be returned clean.",
		"The cargo lift is not a toy. (This means you, Pip.)",
		"New members this season: you. Sign the ledger, please.",
	]},
	"guild_trophy": {"text": "A dune beetle's horn, as long as you are tall, mounted over two crossed spears. The plaque says: \"Season of the Long Drought. Nobody was hurt (much).\""},
	"tavern_hearth": {"text": "You hold your hands to the fire. The stones are warm, the embers tick and settle. Somebody behind you laughs at a joke you missed."},
	"workshop_bench": {"text": "Half a pump lies open on the bench. You tighten three bolts and chase a fourth that's rolling loose under the bench. Bram grunts, which is approval."},
	"store_shelves": {"text": "Rope in coils, lamp oil in tins, dried figs, spare boot laces, buckets, a whole shelf of lanterns, and one dented old lantern with a little sign: NOT FOR SALE."},
	"bath_steam": {"text": "Warm steam rolls off the water. The noise of the street fades away behind you."},
}


# ---------------------------------------------------------------- the town's day
# Times are on a 24-hour clock, in hours: 8.0 = 8:00, 17.5 = half past five,
# 10.25 = quarter past ten. A day runs from 7:00 to 19:00 (how long that takes in
# real minutes is DAY_MINUTES in tuning.gd).

## Each place's opening hours. busy: its busiest hours, when all its regulars come in
## (the rest of the open hours only about half of them do). Doors are never locked:
## when a place is closed you can still walk in, but nobody sits at its tables, and
## the people working there tell you when it opens.
const OPEN_HOURS := {
	"store": {"open": 8.0, "close": 17.0},
	"guild": {"open": 8.0, "close": 17.0},
	"tavern": {"open": 11.0, "close": 19.0, "busy": [17.0, 19.0]},
	"bath": {"open": 9.0, "close": 19.0, "busy": [16.0, 19.0]},
	"workshop": {"open": 7.0, "close": 18.0},
}

## What people say (and boards show) at a place that's closed. {open} becomes the
## opening time, like "8:00". "before": it opens later today; "after": closed for the day.
const CLOSED_LINES := {
	"default": {"before": "We open at {open}. Come back then!", "after": "We're closed for the day. We open at {open} tomorrow."},
	"guild": {"before": "The guild opens at {open}. The requests will keep till then.", "after": "The guild is closed for the day. We open at {open} tomorrow."},
	"tavern": {"before": "Not open yet! Doors open at {open}. Come back thirsty.", "after": "Closed for the night. We open at {open} tomorrow."},
	"workshop": {"before": "Shop opens at {open}.", "after": "Shop's shut for the day. Back at {open} tomorrow."},
}

## Each resident's day: [time, where they head]. Places: "home" (their front door,
## then they go inside), "guild", "tavern", "store", "bath", "workshop", "lookout",
## "plaza", "south_street" (the street between the guild and the tavern). Their own
## place (their "where" above) means their usual spot; any other, a spot inside it.
## Leave a little before opening time: walking takes a while.
## Mira stays in the plaza all day (her errand needs her there).
const ROUTINES := {
	"sabeth": [[7.0, "home"], [7.5, "guild"], [17.0, "home"]],
	"pell": [[7.0, "home"], [7.4, "store"], [17.0, "tavern"]],
	"dorran": [[7.0, "home"], [10.4, "tavern"]],
	"tamsin": [[7.0, "home"], [8.3, "bath"]],
	"bram": [[7.0, "workshop"]],
	"wendel": [[7.0, "lookout"]],
	"pip": [[7.0, "home"], [7.6, "south_street"], [18.0, "home"]],
	"mira": [[7.0, "plaza"]],
}

## How fast each resident walks between places (metres per second).
const WALK_PACE := {"default": 1.25, "pip": 2.3, "wendel": 0.8, "sabeth": 1.1}

## How full the market street is over the day: [time, share of the crowd] (0 = empty,
## 1 = everyone in MARKET_WALKERS in tuning.gd). In between it changes gradually.
const MARKET_CROWD := [[7.0, 0.0], [8.0, 0.15], [9.0, 0.45], [10.5, 0.85], [11.5, 1.0],
		[16.0, 1.0], [17.5, 0.6], [18.25, 0.25], [18.75, 0.05], [19.0, 0.0]]

## The market's standing people (shopkeepers, shoppers at the stalls, chatting groups):
## [earliest, latest] time they arrive in the morning and leave in the evening, each at
## their own time in between. Shopkeepers come first and go last.
const MARKET_KEEPERS := {"arrive": [7.0, 8.0], "leave": [18.25, 18.75]}
const MARKET_STANDERS := {"arrive": [7.5, 8.5], "leave": [18.0, 18.5]}
