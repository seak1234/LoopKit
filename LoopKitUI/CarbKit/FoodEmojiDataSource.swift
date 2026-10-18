//
//  FoodEmojiDataSource.swift
//  LoopKit
//
//  Copyright © 2017 LoopKit Authors. All rights reserved.
//

public func CarbAbsorptionInputController() -> EmojiInputController {
    return EmojiInputController.instance(withEmojis: FoodEmojiDataSource())
}


final class FoodEmojiDataSource: EmojiDataSource {
    private static let fast: [String] = {
        var fast = [
            "🍭", // lollipop
            "🧃", // juice box
            "🥤", // cup with straw (soda)
            "🍬", // candy
            "🍯", // honey pot
            "🍇", // grapes
            "🫐", // blueberries
            "🍈", // melon
            "🍉", // watermelon
            "🍊", // tangerine
            "🍋", // lemon
            "🍌", // banana
            "🍍", // pineapple
            "🍎", // red apple
            "🍏", // green apple
            "🍐", // pear
            "🍑", // peach
            "🍒", // cherries
            "🍓", // strawberry
            "🥝", // kiwi fruit
            "🥭", // mango
            "🌽", // ear of corn
            "🍿", // popcorn
            "🍘", // rice cracker
            "🍡", // dango
            "🍦", // soft ice cream
            "🍧", // shaved ice
            "🎂", // birthday cake
            "🥠", // fortune cookie
            "☕️", // coffee
            "🫖" // tea
        ]

        return fast
    }()

    private static let medium: [String] = {
        var medium = [
            "🌮", // taco
            "🍟", // french fries
            "🍳", // cooking
            "🍲", // pot of food
            "🥘", // pan of food
            "🍱", // bento box
            "🍛", // curry rice
            "🍜", // steaming bowl (ramen / noodle soup)
            "🍠", // roasted sweet potato
            "🍤", // fried shrimp
            "🦪", // oyster
            "🍥", // fish cake with swirl
            "🥪", // sandwich
            "🥙", // pita sandwich
            "🧆", // falafel
            "🫔", // tamale
            "🥫", // canned food
            "🥟", // dumpling
            "🥡", // takeout box
            "🍢", // oden
            "🍣", // sushi
            "🍅", // tomato
            "🥔", // potato
            "🥕", // carrot
            "🌶", // hot pepper
            "🫑", // bell pepper
            "🧅", // onion
            "🧄", // garlic
            "🥒", // cucumber
            "🥗", // green salad
            "🥬", // leafy green
            "🍄", // mushroom
            "🥦", // broccoli
            "🍆", // eggplant
            "🫘", // beans
            "🥥", // coconut
            "🍞", // bread
            "🥐", // croissant
            "🥖", // baguette bread
            "🥯", // bagel
            "🫓", // flat bread
            "🥨", // pretzel
            "🥞", // pancakes
            "🧇", // waffle
            "🍙", // rice ball
            "🍚", // cooked rice
            "🍼", // baby bottle
            "🥛", // glass of milk
            "🍮", // custard
            "🥧", // pie
            "🍨", // ice cream
            "🍩", // doughnut
            "🍪", // cookie
            "🧁", // cupcake
            "🥮", // moon cake
            "🍰", // shortcake
            "🍫", // chocolate bar
            "🧋", // bubble tea
       ]

        return medium
    }()

    private static let slow: [String] = {
        var slow = [
            "🍗", // poultry leg
            "🍕", // pizza
            "🥑", // avocado
            "🥚", // egg
            "🥜", // peanuts
            "🌰", // chestnut
            "🧀", // cheese wedge
            "🫕", // fondue
            "🍖", // meat on bone
            "🥓", // bacon
            "🍔", // hamburger
            "🌭", // hot dog
            "🌯", // burrito
            "🍝", // spaghetti
            "🥩", // cut of meat
            "🧈", // butter
            "🦴", // bone
        ]

        return slow
    }()

    private static let other: [String] = {
        var other = [
            "🍶", // sake
            "🍾", // bottle with popping cork
            "🍷", // wine glass
            "🍸", // cocktail glass
            "🍺", // beer mug
            "🍻", // clinking beer mugs
            "🥂", // clinking glasses
            "🥃", // tumbler glass
            "🍹", // tropical drink
            "🧉", // mate
            "🫗", // pouring liquid
            "🥣", // bowl with spoon
            "🥤", // cup with straw
            "🥢", // chopsticks
            "🍵", // teacup without handle
            "🍴", // fork and knife
            "🍽", // fork and knife with plate
            "🥄", // spoon
            "🫙", // jar
            "🧊", // ice cube
            "🧂", // salt
            "1️⃣", "2️⃣", "3️⃣", "4️⃣", "5️⃣",
            "6️⃣", "7️⃣", "8️⃣", "9️⃣", "🔟"
        ]

        return other
    }()

    let sections: [EmojiSection]

    init() {
        sections = [
            EmojiSection(
                title: LocalizedString("Fast", comment: "Section title for fast absorbing food"),
                items: type(of: self).fast,
                indexSymbol: " 🍭 "
            ),
            EmojiSection(
                title: LocalizedString("Medium", comment: "Section title for medium absorbing food"),
                items: type(of: self).medium,
                indexSymbol: "🌮"
            ),
            EmojiSection(
                title: LocalizedString("Slow", comment: "Section title for slow absorbing food"),
                items: type(of: self).slow,
                indexSymbol: "🍗"
            ),
            EmojiSection(
                title: LocalizedString("Other", comment: "Section title for no-carb food"),
                items: type(of: self).other,
                indexSymbol: "⋯ "
            )
        ]
    }
}
