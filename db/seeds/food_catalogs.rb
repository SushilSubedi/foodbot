# Nepali and South Asian food catalog with multilingual support
# Run with: rails db:seed or rails runner "load 'db/seeds/food_catalogs.rb'"

NEPALI_FOODS = [
  # Dal (Lentils)
  {
    name: "Dal Bhat",
    name_nepali: "दाल भात",
    name_romanized: "daal bhaat",
    aliases: ["dal bhat", "daal bhaat", "dal rice", "lentil rice"],
    description: "Traditional Nepali staple meal of steamed rice with lentil soup",
    cuisine_tags: ["nepali", "staple", "vegetarian", "protein-rich"],
    calories_per_serving: 450,
    protein_g: 15,
    carbs_g: 75,
    fat_g: 8,
    default_serving: "1 plate",
    is_nepali: true
  },
  {
    name: "Masoor Dal",
    name_nepali: "मसुरको दाल",
    name_romanized: "masoor ko daal",
    aliases: ["red lentil dal", "masur dal", "pink lentils"],
    description: "Red lentil soup, commonly served with rice",
    cuisine_tags: ["nepali", "indian", "vegetarian", "protein-rich"],
    calories_per_serving: 180,
    protein_g: 12,
    carbs_g: 28,
    fat_g: 4,
    default_serving: "1 bowl",
    is_nepali: true
  },
  {
    name: "Kalo Dal",
    name_nepali: "कालो दाल",
    name_romanized: "kalo daal",
    aliases: ["black dal", "mash dal", "urad dal"],
    description: "Black lentil dal, creamy and protein-rich",
    cuisine_tags: ["nepali", "vegetarian", "protein-rich"],
    calories_per_serving: 200,
    protein_g: 14,
    carbs_g: 30,
    fat_g: 5,
    default_serving: "1 bowl",
    is_nepali: true
  },

  # Rice dishes
  {
    name: "Jeera Rice",
    name_nepali: "जीरा भात",
    name_romanized: "jeera bhaat",
    aliases: ["cumin rice", "jira rice", "jeera bhaat"],
    description: "Fragrant basmati rice tempered with cumin seeds",
    cuisine_tags: ["nepali", "indian", "vegetarian", "side"],
    calories_per_serving: 220,
    protein_g: 4,
    carbs_g: 45,
    fat_g: 3,
    default_serving: "1 cup",
    is_nepali: true
  },
  {
    name: "Pulao",
    name_nepali: "पुलाउ",
    name_romanized: "pulau",
    aliases: ["pulav", "pilaf", "pilau", "vegetable pulao"],
    description: "Aromatic spiced rice with vegetables and ghee",
    cuisine_tags: ["nepali", "indian", "vegetarian", "festive"],
    calories_per_serving: 320,
    protein_g: 6,
    carbs_g: 52,
    fat_g: 10,
    default_serving: "1 plate",
    is_nepali: true
  },
  {
    name: "Chiura",
    name_nepali: "चिउरा",
    name_romanized: "chiura",
    aliases: ["beaten rice", "flattened rice", "poha", "chura"],
    description: "Flattened rice, a traditional Nepali snack often eaten with curd",
    cuisine_tags: ["nepali", "newari", "snack", "quick"],
    calories_per_serving: 180,
    protein_g: 3,
    carbs_g: 40,
    fat_g: 1,
    default_serving: "1 cup",
    is_nepali: true
  },

  # Momos and dumplings
  {
    name: "Chicken Momo",
    name_nepali: "चिकन मोमो",
    name_romanized: "chicken momo",
    aliases: ["kukhura ko momo", "चिकेन मोमो", "steamed momo"],
    description: "Steamed dumplings filled with spiced chicken, served with tomato chutney",
    cuisine_tags: ["nepali", "tibetan", "street-food", "protein-rich"],
    calories_per_serving: 350,
    protein_g: 18,
    carbs_g: 35,
    fat_g: 14,
    default_serving: "10 pieces",
    is_nepali: true
  },
  {
    name: "Buff Momo",
    name_nepali: "बफ मोमो",
    name_romanized: "buff momo",
    aliases: ["buffalo momo", "rangako momo", "बफ मम"],
    description: "Steamed dumplings filled with spiced buffalo meat",
    cuisine_tags: ["nepali", "tibetan", "street-food", "protein-rich"],
    calories_per_serving: 380,
    protein_g: 20,
    carbs_g: 35,
    fat_g: 16,
    default_serving: "10 pieces",
    is_nepali: true
  },
  {
    name: "Veg Momo",
    name_nepali: "तरकारी मोमो",
    name_romanized: "tarkari momo",
    aliases: ["vegetable momo", "veg momo", "sabji momo"],
    description: "Steamed dumplings filled with mixed vegetables",
    cuisine_tags: ["nepali", "tibetan", "vegetarian", "street-food"],
    calories_per_serving: 280,
    protein_g: 8,
    carbs_g: 40,
    fat_g: 10,
    default_serving: "10 pieces",
    is_nepali: true
  },
  {
    name: "Fried Momo",
    name_nepali: "फ्राइड मोमो",
    name_romanized: "fried momo",
    aliases: ["kothey momo", "pan-fried momo", "crispy momo"],
    description: "Pan-fried dumplings with crispy bottom, can be chicken or veg",
    cuisine_tags: ["nepali", "tibetan", "street-food", "fried"],
    calories_per_serving: 450,
    protein_g: 16,
    carbs_g: 38,
    fat_g: 24,
    default_serving: "10 pieces",
    is_nepali: true
  },
  {
    name: "Jhol Momo",
    name_nepali: "झोल मोमो",
    name_romanized: "jhol momo",
    aliases: ["soup momo", "momo soup", "gravy momo"],
    description: "Steamed momos served in spicy sesame-based soup",
    cuisine_tags: ["nepali", "street-food", "soup", "spicy"],
    calories_per_serving: 420,
    protein_g: 18,
    carbs_g: 42,
    fat_g: 18,
    default_serving: "1 bowl",
    is_nepali: true
  },

  # Curries and main dishes
  {
    name: "Chicken Curry",
    name_nepali: "कुखुरा को मासु",
    name_romanized: "kukhura ko masu",
    aliases: ["chicken tarkari", "kukhra ko masu", "nepali chicken curry"],
    description: "Nepali-style chicken curry with onion-tomato gravy",
    cuisine_tags: ["nepali", "curry", "protein-rich", "main"],
    calories_per_serving: 320,
    protein_g: 28,
    carbs_g: 12,
    fat_g: 18,
    default_serving: "1 bowl",
    is_nepali: true
  },
  {
    name: "Mutton Curry",
    name_nepali: "खसी को मासु",
    name_romanized: "khasi ko masu",
    aliases: ["goat curry", "boka ko masu", "mutton tarkari"],
    description: "Slow-cooked goat meat curry with traditional spices",
    cuisine_tags: ["nepali", "curry", "protein-rich", "festive"],
    calories_per_serving: 380,
    protein_g: 30,
    carbs_g: 10,
    fat_g: 24,
    default_serving: "1 bowl",
    is_nepali: true
  },
  {
    name: "Pork Curry",
    name_nepali: "बंगुर को मासु",
    name_romanized: "bangur ko masu",
    aliases: ["sungur ko masu", "pork tarkari"],
    description: "Spiced pork curry, popular in Rai and Limbu communities",
    cuisine_tags: ["nepali", "curry", "protein-rich"],
    calories_per_serving: 350,
    protein_g: 25,
    carbs_g: 8,
    fat_g: 26,
    default_serving: "1 bowl",
    is_nepali: true
  },
  {
    name: "Fish Curry",
    name_nepali: "माछा को तरकारी",
    name_romanized: "macha ko tarkari",
    aliases: ["fish tarkari", "machha curry", "nepali fish curry"],
    description: "Nepali-style fish curry with mustard oil and spices",
    cuisine_tags: ["nepali", "curry", "protein-rich", "omega-3"],
    calories_per_serving: 280,
    protein_g: 26,
    carbs_g: 10,
    fat_g: 14,
    default_serving: "1 bowl",
    is_nepali: true
  },

  # Vegetable dishes
  {
    name: "Aloo Tama",
    name_nepali: "आलु तामा",
    name_romanized: "aalu tama",
    aliases: ["potato bamboo shoot", "alu tama", "tama curry"],
    description: "Curry made with potatoes and fermented bamboo shoots",
    cuisine_tags: ["nepali", "vegetarian", "traditional", "fermented"],
    calories_per_serving: 180,
    protein_g: 5,
    carbs_g: 28,
    fat_g: 6,
    default_serving: "1 bowl",
    is_nepali: true
  },
  {
    name: "Saag",
    name_nepali: "साग",
    name_romanized: "saag",
    aliases: ["greens", "spinach", "mustard greens", "rayo ko saag"],
    description: "Sautéed leafy greens with garlic and spices",
    cuisine_tags: ["nepali", "vegetarian", "healthy", "iron-rich"],
    calories_per_serving: 80,
    protein_g: 4,
    carbs_g: 8,
    fat_g: 4,
    default_serving: "1 cup",
    is_nepali: true
  },
  {
    name: "Gundruk",
    name_nepali: "गुन्द्रुक",
    name_romanized: "gundruk",
    aliases: ["fermented greens", "dried gundruk", "gundruk ko jhol"],
    description: "Fermented leafy green vegetable, traditional Nepali superfood",
    cuisine_tags: ["nepali", "vegetarian", "fermented", "probiotic"],
    calories_per_serving: 60,
    protein_g: 3,
    carbs_g: 10,
    fat_g: 1,
    default_serving: "1 cup",
    is_nepali: true
  },
  {
    name: "Aloo Gobi",
    name_nepali: "आलु गोभी",
    name_romanized: "aalu gobi",
    aliases: ["potato cauliflower", "alu gobi", "cauliflower potato"],
    description: "Dry curry of potatoes and cauliflower with turmeric",
    cuisine_tags: ["nepali", "indian", "vegetarian", "side"],
    calories_per_serving: 160,
    protein_g: 4,
    carbs_g: 24,
    fat_g: 6,
    default_serving: "1 cup",
    is_nepali: true
  },
  {
    name: "Mixed Vegetable Curry",
    name_nepali: "मिश्रित तरकारी",
    name_romanized: "mishrit tarkari",
    aliases: ["mix veg", "sabji", "tarkari"],
    description: "Mixed vegetable curry with seasonal vegetables",
    cuisine_tags: ["nepali", "vegetarian", "healthy", "fiber-rich"],
    calories_per_serving: 140,
    protein_g: 5,
    carbs_g: 20,
    fat_g: 5,
    default_serving: "1 cup",
    is_nepali: true
  },

  # Snacks and street food
  {
    name: "Samosa",
    name_nepali: "समोसा",
    name_romanized: "samosa",
    aliases: ["singara", "samusa"],
    description: "Deep-fried pastry with spiced potato filling",
    cuisine_tags: ["nepali", "indian", "snack", "street-food", "fried"],
    calories_per_serving: 250,
    protein_g: 4,
    carbs_g: 30,
    fat_g: 14,
    default_serving: "2 pieces",
    is_nepali: true
  },
  {
    name: "Pakoda",
    name_nepali: "पकौडा",
    name_romanized: "pakoda",
    aliases: ["pakora", "bhajiya", "bhaji"],
    description: "Deep-fried vegetable fritters in gram flour batter",
    cuisine_tags: ["nepali", "indian", "snack", "street-food", "fried"],
    calories_per_serving: 200,
    protein_g: 5,
    carbs_g: 22,
    fat_g: 12,
    default_serving: "6 pieces",
    is_nepali: true
  },
  {
    name: "Sel Roti",
    name_nepali: "सेल रोटी",
    name_romanized: "sel roti",
    aliases: ["ring bread", "nepali donut", "sel"],
    description: "Traditional ring-shaped fried rice bread, sweet and crispy",
    cuisine_tags: ["nepali", "festive", "breakfast", "sweet"],
    calories_per_serving: 180,
    protein_g: 3,
    carbs_g: 32,
    fat_g: 5,
    default_serving: "2 pieces",
    is_nepali: true
  },
  {
    name: "Chatpate",
    name_nepali: "चटपटे",
    name_romanized: "chatpate",
    aliases: ["chatpat", "spicy puffed rice", "bhel"],
    description: "Spicy and tangy snack mix with puffed rice and vegetables",
    cuisine_tags: ["nepali", "street-food", "snack", "spicy"],
    calories_per_serving: 220,
    protein_g: 5,
    carbs_g: 38,
    fat_g: 6,
    default_serving: "1 plate",
    is_nepali: true
  },
  {
    name: "Panipuri",
    name_nepali: "पानीपुरी",
    name_romanized: "panipuri",
    aliases: ["golgappa", "puchka", "pani puri"],
    description: "Crispy hollow puris filled with spiced water and chickpeas",
    cuisine_tags: ["nepali", "indian", "street-food", "snack"],
    calories_per_serving: 180,
    protein_g: 4,
    carbs_g: 32,
    fat_g: 4,
    default_serving: "6 pieces",
    is_nepali: true
  },

  # Breads
  {
    name: "Roti",
    name_nepali: "रोटी",
    name_romanized: "roti",
    aliases: ["chapati", "fulka", "phulka"],
    description: "Unleavened whole wheat flatbread",
    cuisine_tags: ["nepali", "indian", "vegetarian", "staple"],
    calories_per_serving: 120,
    protein_g: 4,
    carbs_g: 25,
    fat_g: 1,
    default_serving: "2 pieces",
    is_nepali: true
  },
  {
    name: "Paratha",
    name_nepali: "पराठा",
    name_romanized: "paratha",
    aliases: ["parantha", "lachha paratha"],
    description: "Layered flatbread cooked with ghee or oil",
    cuisine_tags: ["nepali", "indian", "breakfast", "staple"],
    calories_per_serving: 200,
    protein_g: 5,
    carbs_g: 28,
    fat_g: 8,
    default_serving: "1 piece",
    is_nepali: true
  },
  {
    name: "Aloo Paratha",
    name_nepali: "आलु पराठा",
    name_romanized: "aalu paratha",
    aliases: ["potato paratha", "alu parantha", "stuffed paratha"],
    description: "Whole wheat flatbread stuffed with spiced potato filling",
    cuisine_tags: ["nepali", "indian", "breakfast", "vegetarian"],
    calories_per_serving: 280,
    protein_g: 6,
    carbs_g: 38,
    fat_g: 12,
    default_serving: "1 piece",
    is_nepali: true
  },
  {
    name: "Puri",
    name_nepali: "पुरी",
    name_romanized: "puri",
    aliases: ["poori", "luchi"],
    description: "Deep-fried puffed bread made from wheat flour",
    cuisine_tags: ["nepali", "indian", "festive", "fried"],
    calories_per_serving: 180,
    protein_g: 4,
    carbs_g: 22,
    fat_g: 10,
    default_serving: "3 pieces",
    is_nepali: true
  },
  {
    name: "Naan",
    name_nepali: "नान",
    name_romanized: "naan",
    aliases: ["nan", "tandoori naan", "butter naan"],
    description: "Leavened flatbread baked in tandoor oven",
    cuisine_tags: ["indian", "bread", "restaurant"],
    calories_per_serving: 260,
    protein_g: 8,
    carbs_g: 45,
    fat_g: 5,
    default_serving: "1 piece",
    is_nepali: false
  },

  # Newari cuisine
  {
    name: "Choila",
    name_nepali: "छोइला",
    name_romanized: "choila",
    aliases: ["chhoyela", "choela", "spiced meat"],
    description: "Spiced grilled meat (usually buffalo) with mustard oil",
    cuisine_tags: ["newari", "nepali", "spicy", "protein-rich"],
    calories_per_serving: 280,
    protein_g: 28,
    carbs_g: 5,
    fat_g: 16,
    default_serving: "1 plate",
    is_nepali: true
  },
  {
    name: "Bara",
    name_nepali: "बरा",
    name_romanized: "bara",
    aliases: ["wo", "woh", "black lentil pancake"],
    description: "Savory lentil pancake, a Newari specialty",
    cuisine_tags: ["newari", "nepali", "vegetarian", "protein-rich"],
    calories_per_serving: 180,
    protein_g: 10,
    carbs_g: 22,
    fat_g: 6,
    default_serving: "2 pieces",
    is_nepali: true
  },
  {
    name: "Yomari",
    name_nepali: "योमरी",
    name_romanized: "yomari",
    aliases: ["yamari", "sweet dumpling"],
    description: "Sweet steamed dumpling filled with chaku (molasses) or khuwa",
    cuisine_tags: ["newari", "nepali", "festive", "sweet", "dessert"],
    calories_per_serving: 160,
    protein_g: 3,
    carbs_g: 32,
    fat_g: 2,
    default_serving: "2 pieces",
    is_nepali: true
  },
  {
    name: "Kwati",
    name_nepali: "क्वाँटी",
    name_romanized: "kwati",
    aliases: ["nine bean soup", "mixed bean soup", "janai purnima soup"],
    description: "Soup made from nine types of sprouted beans, eaten on Janai Purnima",
    cuisine_tags: ["newari", "nepali", "vegetarian", "protein-rich", "festive"],
    calories_per_serving: 220,
    protein_g: 14,
    carbs_g: 35,
    fat_g: 3,
    default_serving: "1 bowl",
    is_nepali: true
  },

  # Thakali cuisine
  {
    name: "Thakali Set",
    name_nepali: "थकाली थाली",
    name_romanized: "thakali thali",
    aliases: ["thakali khana", "thakali set", "thakali meal"],
    description: "Complete Thakali meal with rice, dal, meat, pickles, and vegetables",
    cuisine_tags: ["thakali", "nepali", "complete-meal", "traditional"],
    calories_per_serving: 800,
    protein_g: 35,
    carbs_g: 100,
    fat_g: 28,
    default_serving: "1 thali",
    is_nepali: true
  },

  # Drinks
  {
    name: "Chiya",
    name_nepali: "चिया",
    name_romanized: "chiya",
    aliases: ["nepali tea", "masala chai", "milk tea", "chai"],
    description: "Sweet milk tea with spices like cardamom and ginger",
    cuisine_tags: ["nepali", "beverage", "tea"],
    calories_per_serving: 80,
    protein_g: 2,
    carbs_g: 12,
    fat_g: 3,
    default_serving: "1 cup",
    is_nepali: true
  },
  {
    name: "Lassi",
    name_nepali: "लस्सी",
    name_romanized: "lassi",
    aliases: ["yogurt drink", "sweet lassi", "mahi"],
    description: "Creamy yogurt-based drink, sweet or salty",
    cuisine_tags: ["nepali", "indian", "beverage", "probiotic"],
    calories_per_serving: 150,
    protein_g: 6,
    carbs_g: 20,
    fat_g: 5,
    default_serving: "1 glass",
    is_nepali: true
  },

  # Desserts
  {
    name: "Kheer",
    name_nepali: "खीर",
    name_romanized: "kheer",
    aliases: ["rice pudding", "payasam", "khir"],
    description: "Sweet rice pudding made with milk, sugar, and cardamom",
    cuisine_tags: ["nepali", "indian", "dessert", "festive"],
    calories_per_serving: 250,
    protein_g: 6,
    carbs_g: 40,
    fat_g: 8,
    default_serving: "1 bowl",
    is_nepali: true
  },
  {
    name: "Jalebi",
    name_nepali: "जलेबी",
    name_romanized: "jalebi",
    aliases: ["jilebi", "sweet pretzel"],
    description: "Deep-fried sweet spirals soaked in sugar syrup",
    cuisine_tags: ["nepali", "indian", "dessert", "sweet", "fried"],
    calories_per_serving: 300,
    protein_g: 3,
    carbs_g: 55,
    fat_g: 10,
    default_serving: "3 pieces",
    is_nepali: true
  },
  {
    name: "Rasbari",
    name_nepali: "रसबरी",
    name_romanized: "rasbari",
    aliases: ["rasgulla", "ras malai", "chena sweet"],
    description: "Soft cheese balls soaked in sweet syrup",
    cuisine_tags: ["nepali", "indian", "dessert", "sweet"],
    calories_per_serving: 200,
    protein_g: 5,
    carbs_g: 38,
    fat_g: 4,
    default_serving: "2 pieces",
    is_nepali: true
  },
  {
    name: "Sikarni",
    name_nepali: "सिकार्नी",
    name_romanized: "sikarni",
    aliases: ["shrikhand", "sweet yogurt"],
    description: "Sweetened strained yogurt with cardamom and saffron",
    cuisine_tags: ["newari", "nepali", "dessert", "festive"],
    calories_per_serving: 180,
    protein_g: 5,
    carbs_g: 28,
    fat_g: 6,
    default_serving: "1 cup",
    is_nepali: true
  },

  # Pickles and sides
  {
    name: "Achar",
    name_nepali: "अचार",
    name_romanized: "achar",
    aliases: ["pickle", "chutney", "tomato achar"],
    description: "Spicy pickle/chutney, essential accompaniment to meals",
    cuisine_tags: ["nepali", "condiment", "spicy"],
    calories_per_serving: 40,
    protein_g: 1,
    carbs_g: 8,
    fat_g: 1,
    default_serving: "2 tbsp",
    is_nepali: true
  },
  {
    name: "Mula ko Achar",
    name_nepali: "मुला को अचार",
    name_romanized: "mula ko achar",
    aliases: ["radish pickle", "daikon pickle"],
    description: "Spicy pickled radish with sesame and chili",
    cuisine_tags: ["nepali", "condiment", "spicy", "fermented"],
    calories_per_serving: 30,
    protein_g: 1,
    carbs_g: 5,
    fat_g: 1,
    default_serving: "2 tbsp",
    is_nepali: true
  },
  {
    name: "Dahi",
    name_nepali: "दही",
    name_romanized: "dahi",
    aliases: ["yogurt", "curd", "juju dhau"],
    description: "Fresh yogurt, often served as side dish",
    cuisine_tags: ["nepali", "dairy", "probiotic", "side"],
    calories_per_serving: 100,
    protein_g: 5,
    carbs_g: 8,
    fat_g: 5,
    default_serving: "1 cup",
    is_nepali: true
  },

  # Breakfast items
  {
    name: "Egg Bhurji",
    name_nepali: "अण्डा भुर्जी",
    name_romanized: "anda bhurji",
    aliases: ["scrambled eggs", "egg bhujia", "indian scrambled eggs"],
    description: "Spiced scrambled eggs with onions, tomatoes, and green chilies",
    cuisine_tags: ["nepali", "indian", "breakfast", "protein-rich"],
    calories_per_serving: 220,
    protein_g: 14,
    carbs_g: 4,
    fat_g: 16,
    default_serving: "2 eggs",
    is_nepali: true
  },
  {
    name: "Omelette",
    name_nepali: "आमलेट",
    name_romanized: "omelette",
    aliases: ["omlet", "egg omelette", "anda omelette"],
    description: "Nepali-style omelette with onions and green chilies",
    cuisine_tags: ["nepali", "breakfast", "protein-rich", "quick"],
    calories_per_serving: 200,
    protein_g: 12,
    carbs_g: 2,
    fat_g: 16,
    default_serving: "2 eggs",
    is_nepali: true
  },

  # Common international foods with Nepali names
  {
    name: "Fried Rice",
    name_nepali: "फ्राइड राइस",
    name_romanized: "fried rice",
    aliases: ["bhuteko bhaat", "chinese fried rice"],
    description: "Stir-fried rice with vegetables and choice of protein",
    cuisine_tags: ["indo-chinese", "quick", "main"],
    calories_per_serving: 380,
    protein_g: 10,
    carbs_g: 55,
    fat_g: 12,
    default_serving: "1 plate",
    is_nepali: false
  },
  {
    name: "Chowmein",
    name_nepali: "चाउमिन",
    name_romanized: "chowmein",
    aliases: ["chow mein", "noodles", "fried noodles"],
    description: "Stir-fried noodles with vegetables, very popular street food",
    cuisine_tags: ["indo-chinese", "street-food", "quick"],
    calories_per_serving: 400,
    protein_g: 12,
    carbs_g: 52,
    fat_g: 16,
    default_serving: "1 plate",
    is_nepali: false
  },
  {
    name: "Thukpa",
    name_nepali: "थुक्पा",
    name_romanized: "thukpa",
    aliases: ["tibetan noodle soup", "noodle soup"],
    description: "Hearty Tibetan noodle soup with vegetables or meat",
    cuisine_tags: ["tibetan", "nepali", "soup", "warming"],
    calories_per_serving: 350,
    protein_g: 15,
    carbs_g: 45,
    fat_g: 12,
    default_serving: "1 bowl",
    is_nepali: true
  }
].freeze

puts "Seeding FoodCatalog with #{NEPALI_FOODS.length} foods..."

created = 0
updated = 0

NEPALI_FOODS.each do |food_data|
  food = FoodCatalog.find_or_initialize_by(name: food_data[:name])
  
  was_new = food.new_record?
  food.assign_attributes(food_data)
  
  if food.save
    if was_new
      created += 1
      puts "  Created: #{food.name}"
    else
      updated += 1
      puts "  Updated: #{food.name}"
    end
  else
    puts "  ERROR: #{food.name} - #{food.errors.full_messages.join(', ')}"
  end
end

puts "\nDone! Created: #{created}, Updated: #{updated}, Total: #{FoodCatalog.count}"
