class TranslationService
  ANALYZING_MESSAGES_EN = [
    "📸 Ooh, that looks interesting! Let me take a closer look...",
    "📸 Yum! Analyzing your meal now...",
    "📸 Got it! Give me a sec to figure out what's on your plate...",
    "📸 Nice! Let me check the nutrition for you...",
    "📸 Looking good! Analyzing..."
  ].freeze

  ANALYZING_MESSAGES_NE = [
    "📸 राम्रो देखिन्छ! हेर्दैछु...",
    "📸 वाह! विश्लेषण गर्दैछु...",
    "📸 फोटो पाएँ! एक छिन पर्खनुहोस्...",
    "📸 मिठो देखिन्छ! जाँच गर्दैछु..."
  ].freeze

  LOGGED_CONFIRMATIONS_EN = [
    "Got it! Logged.",
    "Done! Added to your log.",
    "Tracked!",
    "All set!",
    "Saved!"
  ].freeze

  LOGGED_CONFIRMATIONS_NE = [
    "भयो! रेकर्ड गरियो।",
    "सेभ भयो!",
    "ट्र्याक गरियो!",
    "राम्रो!"
  ].freeze

  ENCOURAGEMENTS_EN = [
    "Keep it up!",
    "You're doing great!",
    "Nice choice!",
    "Good job tracking!",
    "Stay consistent!"
  ].freeze

  ENCOURAGEMENTS_NE = [
    "राम्रो!",
    "यसरी नै गर्नुहोस्!",
    "बधाई छ!",
    "शाबास!"
  ].freeze

  TRANSLATIONS = {
    'en' => {
      'analyzing' => :dynamic_analyzing,
      'welcome_new' => "Hey %{name}! 👋\n\nI'm KhanaAI, think of me as your food buddy who keeps track of what you eat.\n\nJust snap a photo of your meal and I'll tell you the calories and nutrition. Works great with Nepali food like dal bhat, momo, and more!\n\n📸 Send me a food pic to get started\n\n💡 Pro tip: Add a caption like \"2 plates momo\" for better accuracy",
      'welcome_back_morning' => "Morning, %{name}! ☀️\n\nWhat's for breakfast today?%{yesterday_msg}\n\n📸 Send a pic when you're ready",
      'welcome_back_afternoon' => "Hey %{name}! 👋\n\nHad lunch yet?%{yesterday_msg}\n\n📸 Send me a photo",
      'welcome_back_evening' => "Evening, %{name}! 🌙\n\nReady to log dinner?%{yesterday_msg}\n\n📸 Send a pic",
      'welcome_back_hello' => "Hey %{name}! 👋\n\nGood to see you back.%{yesterday_msg}\n\n📸 Send a food pic anytime",
      'quick_menu' => "Hey %{name}! What can I help with?\n\n📸 Send a food photo\n📊 /today - what you've eaten\n📈 /week - weekly overview\n\nOr just send me a pic!",
      'lang_set_ne' => "ठीक छ! अब म नेपालीमा कुरा गर्छु। 🇳🇵",
      'lang_set_en' => "Alright! Switching to English. 🇬🇧",
      'health_score' => "Health",
      'analysis_failed' => "Hmm, I couldn't figure that one out. Mind sending another photo?",
      'unknown_error' => "Oops, something went wrong on my end. Try again?",
      'logged_as' => :dynamic_logged,
      'confident' => "sure",
      'balance_balanced' => "Nicely balanced!",
      'balance_carb_heavy' => "A bit carb-heavy",
      'balance_protein_low' => "Could use more protein",
      'balance_fat_heavy' => "On the fatty side",
      'meal_breakfast' => "breakfast",
      'meal_lunch' => "lunch",
      'meal_dinner' => "dinner",
      'meal_snack' => "snack",
      'meal_unknown' => "meal",
      'protein' => "P",
      'carbs' => "C",
      'fat' => "F",
      'meal_logged' => :dynamic_logged,
      'items' => "items",
      'total' => "Total",
      'assumptions' => "I'm assuming",
      'low_confidence_guess' => "I'm not 100% sure, but here's my guess",
      'possible_food' => "Could be",
      'estimated_calories' => "Roughly",
      'reply_for_accuracy' => "Tell me what it is for a better estimate",
      'example' => "Like",
      'or' => "or",
      'feature_in_development' => "Still working on this feature! Check back soon.",
      'today_header' => "Here's what you've had today",
      'goal_label' => "Goal",
      'progress_label' => "Progress",
      'remaining' => "left",
      'weekly_header' => "Your week at a glance",
      'weekly_avg' => "Avg",
      'weekly_target' => "Target",
      'kcal_per_day' => "kcal/day",
      'status_perfect' => "⭐",
      'status_good' => "✅",
      'status_warning' => "⚠️",
      'status_bad' => "🔴",
      'no_meals_logged' => "Nothing logged yet today!\n\n📸 Send me a food pic to get started",
      'not_food_header' => "Hmm, I don't think that's food 🤔",
      'not_food_tip' => "Send me a pic of your actual meal and I'll analyze it!",
      'error_oops' => "Oops! That didn't work.",
      'error_tips' => "Try sending:\n• A clearer photo\n• Better lighting\n• Just one meal",
      'error_help' => "Still not working? Type /help",
      'daily_limit_reached' => "You've hit today's limit (%{limit} scans).\n\nBack tomorrow! Or use a promo code for more.",
      'promo_success' => "Nice! You got %{amount} extra scans.\n\nNew limit: %{new_limit}/day 🎉",
      'promo_invalid' => "That code doesn't work. Double-check it?",
      'promo_already_used' => "You've already used this code!",
      'promo_limit_reached' => "This code has expired.",
      'encouragement' => :dynamic_encouragement
    },
    'ne' => {
      'analyzing' => :dynamic_analyzing_ne,
      'welcome_new' => "नमस्ते %{name}! 👋\n\nम KhanaAI हुँ | तपाईंको खाना ट्र्याक गर्ने साथी।\n\nखानाको फोटो पठाउनुहोस्, म क्यालोरी र पोषण बताउँछु। दाल भात, मोमो सबै चिन्छु!\n\n📸 सुरु गर्न फोटो पठाउनुहोस्\n\n💡 टिप: \"२ प्लेट मोमो\" जस्तो क्याप्शन थप्नुहोस्",
      'welcome_back_morning' => "शुभ प्रभात, %{name}! ☀️\n\nबिहानको खाना के हो?%{yesterday_msg}\n\n📸 फोटो पठाउनुहोस्",
      'welcome_back_afternoon' => "नमस्ते %{name}! 👋\n\nखाना खानुभयो?%{yesterday_msg}\n\n📸 फोटो पठाउनुहोस्",
      'welcome_back_evening' => "शुभ सन्ध्या, %{name}! 🌙\n\nबेलुकाको खाना ट्र्याक गर्ने?%{yesterday_msg}\n\n📸 फोटो पठाउनुहोस्",
      'welcome_back_hello' => "नमस्ते %{name}! 👋\n\nफेरि भेट भयो!%{yesterday_msg}\n\n📸 खानाको फोटो पठाउनुहोस्",
      'quick_menu' => "नमस्ते %{name}! के गर्ने?\n\n📸 फोटो पठाउनुहोस्\n📊 /today - आजको खाना\n📈 /week - हप्ताको सारांश\n\nवा सिधै फोटो पठाउनुहोस्!",
      'lang_set_ne' => "ठीक छ! अब नेपालीमा कुरा गर्छु। 🇳🇵",
      'lang_set_en' => "Alright! Switching to English. 🇬🇧",
      'health_score' => "स्वास्थ्य",
      'analysis_failed' => "बुझिन। अर्को फोटो पठाउनुहुन्छ?",
      'unknown_error' => "केही गल्ती भयो। फेरि प्रयास गर्नुहोस्?",
      'logged_as' => :dynamic_logged_ne,
      'confident' => "पक्का",
      'balance_balanced' => "राम्रो सन्तुलित!",
      'balance_carb_heavy' => "कार्ब अलि बढी",
      'balance_protein_low' => "प्रोटिन थप्नुस्",
      'balance_fat_heavy' => "बोसो बढी",
      'meal_breakfast' => "बिहानको",
      'meal_lunch' => "दिउँसोको",
      'meal_dinner' => "बेलुकाको",
      'meal_snack' => "खाजा",
      'meal_unknown' => "खाना",
      'protein' => "प्रो",
      'carbs' => "कार्ब",
      'fat' => "फ्याट",
      'meal_logged' => :dynamic_logged_ne,
      'items' => "परिकार",
      'total' => "जम्मा",
      'assumptions' => "मेरो अनुमान",
      'low_confidence_guess' => "पक्का छैन तर मेरो अनुमान",
      'possible_food' => "सायद",
      'estimated_calories' => "लगभग",
      'reply_for_accuracy' => "के हो भन्नुस् राम्रो अनुमानको लागि",
      'example' => "जस्तै",
      'or' => "वा",
      'feature_in_development' => "यो फिचर बन्दैछ। पर्खनुहोस्!",
      'today_header' => "आज यति खानुभयो",
      'goal_label' => "लक्ष्य",
      'progress_label' => "प्रगति",
      'remaining' => "बाँकी",
      'weekly_header' => "यो हप्ताको सारांश",
      'weekly_avg' => "औसत",
      'weekly_target' => "लक्ष्य",
      'kcal_per_day' => "kcal/दिन",
      'status_perfect' => "⭐",
      'status_good' => "✅",
      'status_warning' => "⚠️",
      'status_bad' => "🔴",
      'no_meals_logged' => "आज अझै केही लग भएको छैन!\n\n📸 खानाको फोटो पठाउनुहोस्",
      'not_food_header' => "यो त खाना जस्तो लागेन 🤔",
      'not_food_tip' => "खानाको फोटो पठाउनुहोस् त!",
      'error_oops' => "ओहो! केही गल्ती भयो।",
      'error_tips' => "यस्तो प्रयास गर्नुहोस्:\n• सफा फोटो\n• राम्रो उज्यालो\n• एउटा मात्र खाना",
      'error_help' => "समस्या छ? /help टाइप गर्नुहोस्",
      'daily_limit_reached' => "आजको सीमा पुग्यो (%{limit} फोटो)।\n\nभोलि आउनुहोस्! वा प्रोमो कोड प्रयोग गर्नुहोस्।",
      'promo_success' => "बधाई! %{amount} थप स्क्यान पाउनुभयो।\n\nनयाँ सीमा: %{new_limit}/दिन 🎉",
      'promo_invalid' => "यो कोड काम गरेन। जाँच गर्नुस्?",
      'promo_already_used' => "यो कोड पहिले प्रयोग भइसक्यो!",
      'promo_limit_reached' => "यो कोडको म्याद सकियो।",
      'encouragement' => :dynamic_encouragement_ne
    }
  }.freeze

  def self.t(key, lang = 'en', params = {})
    value = TRANSLATIONS[lang]&.[](key) || TRANSLATIONS['en'][key] || key

    text = case value
    when :dynamic_analyzing
      ANALYZING_MESSAGES_EN.sample
    when :dynamic_analyzing_ne
      ANALYZING_MESSAGES_NE.sample
    when :dynamic_logged
      LOGGED_CONFIRMATIONS_EN.sample
    when :dynamic_logged_ne
      LOGGED_CONFIRMATIONS_NE.sample
    when :dynamic_encouragement
      ENCOURAGEMENTS_EN.sample
    when :dynamic_encouragement_ne
      ENCOURAGEMENTS_NE.sample
    else
      value.to_s
    end

    params.each { |k, v| text = text.gsub("%{#{k}}", v.to_s) }
    text
  end

  def self.random_encouragement(lang = 'en')
    lang == 'ne' ? ENCOURAGEMENTS_NE.sample : ENCOURAGEMENTS_EN.sample
  end

  def self.random_analyzing(lang = 'en')
    lang == 'ne' ? ANALYZING_MESSAGES_NE.sample : ANALYZING_MESSAGES_EN.sample
  end
end
