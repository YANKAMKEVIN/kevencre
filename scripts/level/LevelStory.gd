extends RefCounted
## Textes des chapitres : panneaux (dans l'ordre de gauche à droite) et dialogues.

const SIGNS := {
	1: [
		"← → (ou A / D) pour courir.  Espace pour sauter : garde la touche appuyée pour sauter plus haut.",
		"Des Taches grises ! Elles boivent les couleurs. Saute-leur sur la tête pour les repeindre.",
		"Contre un mur, saute à nouveau : Sépia rebondit. Enchaîne d'un mur à l'autre pour grimper.",
		"X (ou J, ou Maj) + une direction : Trait d'encre !  Ton trait reste dans l'air un instant : tu peux marcher dessus et sauter depuis.  Il se recharge en touchant le vrai sol.",
		"Ce papier est fragile : il se déchire si on reste dessus. Il revient un peu plus tard.",
		"Trop haut ? Saute, puis Trait d'encre vers le haut (↑ + X).  Un trait vertical devient un mur sur lequel rebondir.",
	],
	2: [
		"Les fleurs-ressorts te lancent très haut et rechargent ton Trait d'encre.",
		"La grande cascade. Rebondis entre les murs et attrape les gouttes rouges : elles rechargent ton trait en plein vol.",
	],
	3: [
		"Les Falaises d'Ocre. Tout en haut, l'atelier du Délaveur. Les chevalets te soignent quand tu les touches.",
	],
}

const MUSIC := ["", "music_meadow", "music_forest", "music_cliffs", "music_boss"]

const SHRINE := [
	["Vieux Pinceau", "Oh... une goutte d'encre. Une vraie, toute pleine. Je croyais qu'il n'en restait plus une seule."],
	["Vieux Pinceau", "Je suis le Vieux Pinceau. Mes poils sont secs depuis que le Délaveur a bu les couleurs du monde."],
	["Vieux Pinceau", "Mais toi, petite Sépia, tu peux encore tracer. Prends mon dernier geste : le Trait d'encre."],
	["Vieux Pinceau", "Fends l'air d'un coup de pinceau. Ton trait restera un instant avant de sécher : pose-toi dessus, saute depuis, rebondis contre lui."],
	["Vieux Pinceau", "Le Délaveur se cache dans son atelier, tout en haut des Falaises d'Ocre. Va, et rends au monde ses couleurs."],
]

const BRUSH_TOAST := ["Trait d'encre", "X / J / Maj + direction.  Se recharge au sol, sur les fleurs et les gouttes rouges."]

const BOSS_INTRO := [
	["???", "Encore une couleur ? Je les ai toutes bues, pourtant. Le rouge des fruits, le bleu des rivières, le vert des feuilles..."],
	["Le Délaveur", "Le gris est calme. Le gris ne fait pas mal aux yeux. Le gris ne se fane jamais."],
	["Sépia", "..."],
	["Le Délaveur", "Viens, petite goutte. Je vais te diluer, toi aussi."],
]

const BOSS_DEFEAT := [
	["Le Délaveur", "Oh... c'est donc ça, le rouge ? C'est... chaud."],
	["Le Délaveur", "J'avais oublié. Avant d'être gris, j'étais un simple pot d'eau, à côté du chevalet d'un peintre. On rinçait les pinceaux en moi. Toutes les couleurs passaient par moi..."],
	["Sépia", "!"],
	["Le Délaveur", "Va, petite goutte. Le peintre dort encore. Réveille-le."],
]
