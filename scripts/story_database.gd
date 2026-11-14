extends Node
class_name StoryDatabase

## Story dialogue nodes based on the GENRE TONE outline:
## Setting: Lunar Outpost, 2010.
## Player: Untrained civilian first in NASA Space Apps Habitat Program.
## Characters: NASA Cooperation (Mission Control), Berna (girlfriend on Earth), Pearl (station cat).
## Plot: Framed as habitat test, secretly tracking an Earth-bound deep-space asteroid.
## End-game choices: Divert return rocket into asteroid (costs 20 EU power, redirects asteroid to Moon)
## and whether to tell Berna of impending death or comfort her.

const DIALOGUES := {
	"mission_failure": {
		"speaker": "STATION EMERGENCY",
		"role": "HABITAT RUN ENDED",
		"text": "A crew vital has reached zero. The mission is over. Review your resource decisions, then try again. Emergency food, water, oxygen and power are available in the west-wall lockers.",
		"choices": [{"text": "Review mission debrief", "next": ""}]
	},
	"arrival_intro": {
		"speaker": "NASA MISSION CONTROL",
		"role": "HOUSTON · HABITAT PROGRAM",
		"text": "Welcome to Lunar Outpost Artemis-0, Specialist. Touchdown confirmed, Year 2010 log initialized. As our first civilian volunteer in the NASA Space Apps Habitat Program, your primary duty is maintaining the closed-loop life support—oxygen, water, and electrical power—while logging routine telemetry on the command screen.",
		"choices": [
			{
				"text": "Copy that, Houston. Excited to test the habitat systems.",
				"next": "arrival_berna"
			},
			{
				"text": "Why does a habitat test need a deep-space radar array?",
				"next": "arrival_question"
			}
		]
	},
	"arrival_question": {
		"speaker": "NASA MISSION CONTROL",
		"role": "HOUSTON · HABITAT PROGRAM",
		"text": "Standard calibration equipment, Specialist. Nothing to worry about. Just enter the Station Array coordinates when prompted, keep the fuel cell running when reserves dip, and don't let the command screen drain your battery dry.",
		"choices": [
			{
				"text": "Understood. I'll check the systems now.",
				"next": "arrival_berna"
			}
		]
	},
	"arrival_berna": {
		"speaker": "BERNA (EARTH RELAY)",
		"role": "PERSONAL AUDIO LINK · DELAY 1.3s",
		"text": "Hey... the video feed finally came through. I still can't believe you actually went through with this. You're a civilian, not an astronaut! You shouldn't have left Earth for some corporate NASA experiment... Please tell me you and Pearl are okay up there.",
		"choices": [
			{
				"text": "I miss you too, Berna. Pearl is right here and the station is safe.",
				"next": "arrival_pearl",
				"effect": "berna_reassured"
			},
			{
				"text": "It's only a 20-minute orbital window, Berna. I did this for our future.",
				"next": "arrival_pearl",
				"effect": "berna_distant"
			}
		]
	},
	"arrival_pearl": {
		"speaker": "PEARL THE CAT",
		"role": "HABITAT COMPANION",
		"text": "*Purrs softly against your boots, staring up at the green oxygen pipes and the blinking command terminal across the room.*",
		"choices": [
			{
				"text": "Good girl, Pearl. Let's check the command screen and storage lockers.",
				"next": ""
			}
		]
	},
	"obs_1_reveal": {
		"speaker": "NASA MISSION CONTROL",
		"role": "ENCRYPTED TELEMETRY CHANNEL",
		"text": "Observation 04 received. Range 12,400 km... Wait—disregard that orbital solution, Specialist. Keep life support nominal and prepare Observation 05 immediately. The command array requires 1.0 EU per transmission.",
		"choices": [
			{
				"text": "Wait—'Outbound' is a lie. The range is dropping! What am I tracking?",
				"next": "obs_1_berna"
			},
			{
				"text": "Acknowledged. Routing power to the array.",
				"next": "obs_1_berna"
			}
		]
	},
	"obs_1_berna": {
		"speaker": "BERNA (EARTH RELAY)",
		"role": "PERSONAL AUDIO LINK · STATIC INTERFERENCE",
		"text": "Babe, are you still there? The news on Earth just cut out across three networks. People are talking about an uncatalogued object in cis-lunar space. Why did NASA send an untrained civilian to the far-side array?!",
		"choices": [
			{
				"text": "Don't panic, Berna. I'm pulling the raw radar logs right now.",
				"next": ""
			},
			{
				"text": "They told me this was just a habitat test... Stay inside, okay?",
				"next": ""
			}
		]
	},
	"obs_2_truth": {
		"speaker": "NASA DIRECTORATE",
		"role": "CLASSIFIED DIRECTIVE · EYES ONLY",
		"text": "Observation 05 confirmed. Range 6,850 km. There's no point hiding it now, Specialist. The Habitat Program was a cover. An automated lunar beacon failed, and we needed a human hand to align the Station Array on Object-2010-XK—a city-killer asteroid hurtling directly toward Earth.",
		"choices": [
			{
				"text": "You lied to me! Why didn't you send a military crew?",
				"next": "obs_2_explanation"
			},
			{
				"text": "How much time does Earth have left?",
				"next": "obs_2_explanation"
			}
		]
	},
	"obs_2_explanation": {
		"speaker": "NASA DIRECTORATE",
		"role": "CLASSIFIED DIRECTIVE · EYES ONLY",
		"text": "A full crew needed six months of life-support prep. We had days. We need one final high-resolution lock—Observation 06—to calculate the impact corridor. Keep your oxygen scrubbers and fuel cell online so you can transmit the final packet.",
		"choices": [
			{
				"text": "I'll get you the final lock. Then I'm taking my return ship home.",
				"next": ""
			}
		]
	},
	"obs_3_climax": {
		"speaker": "SYSTEM ALERT / NASA",
		"role": "EMERGENCY PRIORITY OVERRIDE",
		"text": "Observation 06 locked: Range 1,920 km. Earth impact probability: 99.8%. Earth defenses cannot intercept in time... UNLESS your lunar return rocket is launched on a remote kinetic intercept. However, firing the return ship requires 20.0 EU of station battery power—and the deflection vector will divert the asteroid directly into your Lunar Outpost.",
		"choices": [
			{
				"text": "[SACRIFICE - Requires 20 EU] Fire return rocket into the asteroid to save Earth.",
				"next": "choice_tell_berna",
				"effect": "launch_intercept",
				"require_energy": 20.0
			},
			{
				"text": "[EVACUATE] Keep the return ship for myself and escape before impact.",
				"next": "choice_tell_berna_escape",
				"effect": "keep_ship"
			}
		]
	},
	"choice_tell_berna": {
		"speaker": "BERNA (EARTH RELAY)",
		"role": "INCOMING CALL · TEARFUL VOICE",
		"text": "The alarms are sounding in the streets here... Please tell me your return rocket is prepped! Tell me you're coming home to me right now!",
		"choices": [
			{
				"text": "[TELL THE TRUTH] Berna... I launched my return ship at the asteroid. It's heading for the Moon now. I won't be coming back, my love.",
				"next": "ending_truth_sacrifice",
				"effect": "told_truth"
			},
			{
				"text": "[HIDE IMPENDING DEATH] Everything is going to be okay, Berna. Look up at the sky tonight—you're safe. I love you.",
				"next": "ending_lie_sacrifice",
				"effect": "hid_truth"
			}
		]
	},
	"choice_tell_berna_escape": {
		"speaker": "BERNA (EARTH RELAY)",
		"role": "INCOMING CALL · TEARFUL VOICE",
		"text": "The alarms are sounding in the streets here... What's happening up there?! Are you able to stop it, or are you coming back?!",
		"choices": [
			{
				"text": "[TELL THE TRUTH] I couldn't sacrifice the outpost, Berna. The asteroid is still heading toward Earth.",
				"next": "ending_escape_truth",
				"effect": "told_truth"
			},
			{
				"text": "[HIDE THE TRUTH] The station didn't have enough power to deflect it... I'm so sorry, Berna.",
				"next": "ending_escape_lie",
				"effect": "hid_truth"
			}
		]
	},
	"ending_truth_sacrifice": {
		"speaker": "EPILOGUE · LUNAR OUTPOST ARTEMIS-0",
		"role": "FINAL TRANSMISSION LOGGED",
		"text": "Your return rocket streaks into the lunar sky, slamming into Object-2010-XK. On the tracking screen, Earth's trajectory clears—while the new impact marker locks onto your crater. Berna weeps through the comm link, whispering your name until the very last second as you hold Pearl in your arms. Earth is saved.",
		"choices": [
			{
				"text": "End transmission · Mission debrief",
				"next": ""
			}
		]
	},
	"ending_lie_sacrifice": {
		"speaker": "EPILOGUE · LUNAR OUTPOST ARTEMIS-0",
		"role": "FINAL TRANSMISSION LOGGED",
		"text": "Your return rocket intercepts Object-2010-XK, sparing Earth and sealing the fate of Lunar Outpost Artemis-0. On Earth, Berna watches the bright flash near the Moon, believing you are still safely aboard your return capsule. You stroke Pearl's fur in the quiet hum of the life-support pipes as the shadow grows.",
		"choices": [
			{
				"text": "End transmission · Mission debrief",
				"next": ""
			}
		]
	},
	"ending_escape_truth": {
		"speaker": "EPILOGUE · LUNAR OUTPOST ARTEMIS-0",
		"role": "FINAL TRANSMISSION LOGGED",
		"text": "You preserve the return ship and confess the truth to Berna. The comm link falls into devastating silence as Object-2010-XK passes the lunar orbit, bound for Earth. You and Pearl survive inside the quiet grey walls of the outpost, alone with the hum of the machines.",
		"choices": [
			{
				"text": "End transmission · Mission debrief",
				"next": ""
			}
		]
	},
	"ending_escape_lie": {
		"speaker": "EPILOGUE · LUNAR OUTPOST ARTEMIS-0",
		"role": "FINAL TRANSMISSION LOGGED",
		"text": "You tell Berna the station lacked the power to stop the asteroid. As Object-2010-XK hurtles past the Moon toward Earth, the telemetry array flickers in the dim light of the habitat. You and Pearl remain behind in the silence of the lunar surface.",
		"choices": [
			{
				"text": "End transmission · Mission debrief",
				"next": ""
			}
		]
	},
	"pearl_pet": {
		"speaker": "PEARL THE CAT",
		"role": "HABITAT COMPANION",
		"text": "*Pearl chirps happily and rubs her head against your glove. Her calm purring makes the isolated lunar habitat feel a little warmer.*",
		"choices": [
			{
				"text": "Give Pearl a gentle scratch behind the ears.",
				"next": ""
			},
			{
				"text": "Offer Pearl a tiny ration treat.",
				"next": "",
				"effect": "feed_pearl"
			}
		]
	},
	"low_power_warning": {
		"speaker": "STATION AI / TELEMETRY",
		"role": "POWER BUS ALERT",
		"text": "WARNING: Command screen operations and life-support scrubbers have depleted station battery reserves below 10 EU. Start the H₂/O₂ Fuel Cell immediately to restore electrical power.",
		"choices": [
			{
				"text": "Understood — heading to the Fuel Cell.",
				"next": ""
			}
		]
	}
}
