extends RefCounted
## THE TOWN'S PEOPLE AND PLACES, as plain data: who lives here, how they look, what
## they say, and the words on the boards and shelves. Edit freely: change a line,
## a colour or a name here and the game picks it up. (Where each person stands is
## decided by the buildings, in world/facilities.gd.)
## Characters are everyday folk: no secrets or story, so nothing here can spoil it.

## look: the build options from world/people.gd _make_person (legs, torso, dress,
## apron, belly, sash, beard, hair, scarf_colour). item: what they carry (see
## _item_mesh in world/people.gd). habit: their little idle movement.
## lines: what they say when you talk to them, one per press of E, round and round.
## after: extra lines once Mira's rain-catcher is fixed (said first, then the rest).
const CAST := {
	"sabeth": {
		"name": "Sabeth", "role": "guild clerk", "where": "guild",
		"shirt": Color(0.20, 0.27, 0.45), "bottom": Color(0.20, 0.27, 0.45), "hair": Color(0.62, 0.60, 0.58),
		"skin": Color(0.78, 0.58, 0.42),
		"look": {"torso": 4, "dress": true, "hair": "bun", "sash": Color(0.84, 0.66, 0.24)},
		"item": "ledger", "habit": "write",
		"personality": "Precise, dry, secretly delighted by anyone who fills in a form properly.",
		"lines": [
			"Welcome to the Guild. Requests are on the board, behind you. Please don't pin anything to it yourself.",
			"New members start at the bottom of the list. Everyone starts at the bottom of the list.",
			"I've kept these ledgers for nineteen years. The ink smells better than most people.",
			"If you take a request, come back alive. The paperwork for the other thing is dreadful.",
			"Quiet tonight. I prefer quiet. Quiet doesn't argue about rewards.",
		],
		"after": ["I hear you fixed Mira's rain-catcher. Unpaid, unrequested, unrecorded. Very irregular. Well done."],
	},
	"dorran": {
		"name": "Dorran", "role": "barkeep", "where": "tavern",
		"shirt": Color(0.88, 0.55, 0.30), "bottom": Color(0.30, 0.24, 0.20), "hair": Color(0.45, 0.30, 0.15),
		"skin": Color(0.92, 0.75, 0.62),
		"look": {"belly": true, "apron": true, "beard": true, "hair": "bald"},
		"item": "mug", "habit": "polish",
		"personality": "Big, warm, never forgets an order, always has a story about somebody's cousin.",
		"lines": [
			"Welcome to the Kneeling Strider! Pull up a stool, the good one's by the fire.",
			"Cactus cider's fresh. The stew is... a stew. You'll live.",
			"Every time the city kneels for the night, this place fills up in ten minutes flat.",
			"Rule of the house: no sand in the drinks, no knives on the tables, no singing before the third round.",
			"See old Wendel up on the outer wall? Takes him a cup of tea every dusk. Never says thank you. Always drinks it.",
		],
		"after": ["Water pressure's up in the kitchen! Somebody fixed the rain-catcher, I hear. First round's on me."],
	},
	"bram": {
		"name": "Bram", "role": "mechanic", "where": "workshop",
		"shirt": Color(0.80, 0.42, 0.20), "bottom": Color(0.34, 0.26, 0.20), "hair": Color(0.42, 0.36, 0.32),
		"skin": Color(0.80, 0.60, 0.45),
		"look": {"beard": true, "hair": "short", "sash": Color(0.30, 0.24, 0.20)},
		"item": "goggles", "habit": "hammer",
		"personality": "Gruff, kind underneath, talks to machines more gently than to people.",
		"lines": [
			"Mind the bench. Everything on it is either hot, sharp or important.",
			"The spare valve? Should be right there on the bench. Take it, Mira's been on at me all week.",
			"You hear that groan when the city takes a step? That's the old girl telling us she's fine.",
			"I've fixed every pump on this deck twice. The third time's when they start fixing themselves.",
		],
		"after": [
			"Mira says the catcher's running sweet. Good hands. Come by if you ever want to learn the trade.",
		],
	},
	"pell": {
		"name": "Pell", "role": "shopkeeper", "where": "store",
		"shirt": Color(0.36, 0.56, 0.42), "bottom": Color(0.55, 0.48, 0.38), "hair": Color(0.20, 0.13, 0.08),
		"skin": Color(0.55, 0.38, 0.26),
		"look": {"apron": true, "hair": "scarf", "scarf_colour": Color(0.95, 0.80, 0.35)},
		"item": "feather_hat", "habit": "pace",
		"personality": "Quick-talking, cheerful, believes there's a right tool for every problem and that she sells it.",
		"lines": [
			"Pell's Provisions! Rope, oil, lamps, figs, buckets, boots: if you need it, I've got it, or I know who has.",
			"Going down to the sand tonight? Take a lantern. Then take a spare lantern.",
			"That compass on the top shelf isn't for sale. It's lucky. I'm not saying how I know.",
			"Prices are fair, the figs are fresh, and the boots only squeak for the first week.",
		],
		"after": ["You're the one who fixed the rain-catcher? Here, have a fig. No, take two. Word gets around."],
	},
	"tamsin": {
		"name": "Tamsin", "role": "bath attendant", "where": "bath",
		"shirt": Color(0.92, 0.90, 0.84), "bottom": Color(0.92, 0.90, 0.84), "hair": Color(0.10, 0.09, 0.08),
		"skin": Color(0.92, 0.75, 0.62),
		"look": {"dress": true, "hair": "long", "sash": Color(0.30, 0.55, 0.70)},
		"item": "towels", "habit": "stroll",
		"personality": "Calm, unhurried, speaks softly so everyone else does too.",
		"lines": [
			"Welcome. Sand stays outside. Worries too, if you can manage it.",
			"The water's warmed by the boiler under the deck. The city keeps us cosy whether it means to or not.",
			"Find a spot along the ledge and sit as long as you like. No one's counting.",
			"Some nights you can feel each step through the water, slow as a heartbeat.",
		],
		"after": ["The pool filled faster today. Mira's rain-catcher, I think. Tell her the water says thank you."],
	},
	"mira": {
		"name": "Mira", "role": "your neighbour", "where": "plaza",
		"shirt": Color(0.82, 0.30, 0.26), "bottom": Color(0.24, 0.28, 0.38), "hair": Color(0.10, 0.09, 0.08),
		"skin": Color(0.78, 0.58, 0.42),
		"look": {"hair": "long"},
		"item": "watering_can", "habit": "none",
		"personality": "Practical, upbeat, keeps half the neighbourhood's plants alive.",
		"lines": [
			"The valve's at Bram's workshop, one terrace down on the east side. The rain-catcher's out on the far west of the ring.",
			"Without that catcher my tomatoes are drinking dust. And so am I, nearly.",
			"Bram grumbles, but he'll have left it out for you. He always does.",
		],
		"after": [
			"Listen! Water in the pipes again. You're officially my favourite neighbour.",
			"If you're bored, the new guild hall's at the bottom of the stairs on the homes side. Or the bathhouse, if you've earned a soak. You have.",
			"Don't tell Bram I said so, but he worried about that catcher more than I did.",
		],
	},
	"wendel": {
		"name": "Old Wendel", "role": "lookout", "where": "lookout",
		"shirt": Color(0.40, 0.30, 0.22), "bottom": Color(0.30, 0.24, 0.20), "hair": Color(0.92, 0.90, 0.86),
		"skin": Color(0.80, 0.60, 0.45),
		"look": {"legs": 2, "beard": true, "hair": "short"},
		"item": "spyglass", "habit": "scan",
		"personality": "Weathered, few words, notices everything, likes the desert more than people (mostly).",
		"lines": [
			"Hm. Dust on the eastern ridge. Wind's turning. Tell Dorran to shut his shutters by dusk.",
			"Forty years on this wall. Seen sandstorms eat the sun whole. Seen the sky go green, once. Pretty, that.",
			"The city walks, I watch. Somebody's got to know what's coming before it's here.",
			"You want to be useful? Bring me tea at dusk. Dorran does. Don't tell him I like it.",
		],
		"after": ["Saw the water running down the west side from up here. Good work. Hm."],
	},
	"pip": {
		"name": "Pip", "role": "errand runner", "where": "south_street",
		"shirt": Color(0.94, 0.80, 0.40), "bottom": Color(0.24, 0.28, 0.38), "hair": Color(0.62, 0.28, 0.14),
		"skin": Color(0.92, 0.75, 0.62),
		"look": {"hair": "short"}, "kid": true,
		"item": "satchel", "habit": "run",
		"personality": "Fast, curious, knows every shortcut and every rumour (most of them wrong).",
		"lines": [
			"Can't stop! Got a parcel for the guild, a note for the tavern and a fig for me.",
			"Did you know the bathhouse water is warmed by the boiler under our feet? I've seen it. Well, I've heard it.",
			"When I'm big I'm going down to the sand at night like the guild folk. Sabeth says I have to learn to spell first.",
			"Race you to the stairs! ...Okay, you win, I wasn't ready.",
		],
		"after": ["Everyone's talking about you fixing the rain-catcher! Well, Mira is. Loudly."],
	},
}

## The words on boards and shelves, by spot id (see world/facilities.gd).
const PLACES := {
	"guild_board": {"title": "REQUESTS", "lines": [
		"Wanted: steady hands to escort the water cart to the east pumps. Pays in coin and gratitude.  (Sabeth)",
		"Lost near the cargo lift: one brass compass, sentimental value. Reward: a hot meal at the Kneeling Strider.",
		"Night work: sand-crawlers nesting in the lower hull again. Bring a lantern, a broom and courage.",
	]},
	"guild_ranks": {"title": "MEMBERS THIS SEASON", "lines": [
		"Captain Arvo: 212 requests",
		"Ilse the Quick: 140 requests",
		"The Tanner twins: 96 requests (each)",
		"...",
		"New member: you. 0 requests. Everyone starts somewhere.",
	]},
	"guild_trophy": {"text": "A dune beetle's horn, as long as you are tall, mounted over two crossed spears. The plaque says: \"Season of the Long Drought. Nobody was hurt (much).\""},
	"tavern_hearth": {"text": "You hold your hands to the fire. The stones are warm, the embers tick and settle. Somebody behind you laughs at a joke you missed."},
	"workshop_bench": {"text": "Half a pump lies open on the bench. You tighten three bolts and find a fourth that was never there before. Bram grunts, which is approval."},
	"store_shelves": {"text": "Rope in coils, lamp oil in tins, dried figs, spare boot laces, buckets, a whole shelf of lanterns, and one brass compass with a little sign: NOT FOR SALE."},
	"bath_steam": {"text": "Warm steam rolls off the water. Under it all, slow and steady, you can feel the city taking its next step."},
}
