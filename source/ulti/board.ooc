
// third-party
use deadlogger
import deadlogger/[Log, Logger]

// sdk
import structs/[ArrayList, Stack]
import math/[Random], math

Player: class {

    name: String
    units := ArrayList<Unit> new()
    logger: Logger

    balance := 1500.0

    init: func (=name) {
        logger = Log getLogger(toString())
    }

    toString: func -> String {
        "player %s" format(name)
    }

    spend: func (amount: Float) {
        balance -= amount
        logger warn("Spent %.0f, %.0f remaining", amount, balance)
    }

    gain: func (amount: Float) {
        balance += amount
        logger warn("Gained %.0f, balance = %.0f", amount, balance)
    }

}

// Something that roves on the board and can buy properties,
// pay rent, etc.
Unit: class {

    board: Board
    player: Player
    messages := Stack<String> new()

    // state
    action: Action
    tileIndex: Int

    logger: Logger

    init: func (=board, =player) {
        player units add(this)
        logger = Log getLogger("%s #%d" format(player name, player units size))

        wait := Action new(ActionType WAIT)
        wait timeout = Dice roll(100, 800)
        begin(wait)
    }

    begin: func (newAction: Action) {
        if (action) {
            _apply(action)
        }

        while (!messages empty?()) {
            message := messages pop()
            match (message) {
                case "go-to-prison" =>
                    prisonIndex := board tileIndex(TileType PRISON)
                    if (prisonIndex != -1) {
                        newAction = Action new(ActionType PRISON)
                        moveTo(prisonIndex)
                    }
            }
        }

        logger info("%s => %s (%.0f)",
         action ? action toString() : "(nil)", newAction toString(), newAction timeout)

        action = newAction
    }

    _apply: func (action: Action) {
        match (action type) {
            case ActionType MOVE =>
                if (action number < tileIndex) {
                    // fuck yeah go = $200
                    player gain(200)
                }
                moveTo(action number)
        }
    }

    moveTo: func (index: Int) {
        tileIndex = index
        tile := board getTile(tileIndex)
        logger info("arrived on %s", tile toString())

        match (tile type) {
            case TileType GO =>
                player gain(200)
            case TileType INCOME_TAX =>
                player spend(200)
            case TileType LUXURY_TAX =>
                player spend(75)
            case TileType POLICE =>
                queue("go-to-prison")
        }
    }

    queue: func (message: String) {
        messages push(message)
    }

    step: func (delta: Float) {
        if (action) {
            action step(delta)
        }

        if (action due?()) {
            match (action type) {
                case ActionType MOVE =>
                    begin(Action new(ActionType WAIT))
                case =>
                    move := Action new(ActionType MOVE)
                    roll := Dice roll()
                    move number = board nextTile(tileIndex, roll)
                    logger info("rolled a %d", roll)
                    begin(move)
            }
        }
    }
}

Dice: class {

    roll: static func ~two -> Int {
        roll(2, 12)
    }

    roll: static func (low, high: Int) -> Int {
        Random randInt(low, high)
    }

}

Action: class {
    timeout: Float

    // an int you can store anything in
    number := 0

    type: ActionType

    init: func (=type) {
        timeout = match type {
            case ActionType WAIT => 2000.0
            case ActionType MOVE => 4000.0
            case ActionType PRISON => 5000.0
            case => 1000.0
        }
    }

    step: func (delta: Float) {
        timeout -= delta
    }

    due?: func -> Bool {
        timeout < 0
    }

    toString: func -> String {
        type toString()
    }
}

ActionType: enum {
    WAIT   // just waiting for orders
    MOVE   // going somewhere
    PRISON // the jailhouse won

    toString: func -> String {
        match this {
            case This WAIT   => "wait"
            case This MOVE   => "move"
            case This PRISON => "prison"
        }
    }
}

RGB: class {
    // 0-255
    r, g, b: Int

    init: func (=r, =g, =b) {
    }
}

Board: class {

    tiles := ArrayList<Tile> new()    
    logger := static Log getLogger(This name)

    init: func {
        classicSetup()
    }

    createUnit: func (player: Player) {
        unit := Unit new(this, player)
        unit tileIndex = 0
        logger info("Unit spawned on tile %s", getTile(unit tileIndex) toString())
    }

    getTile: func (index: Int) -> Tile {
        tiles[index]
    }

    nextTile: func (base, offset: Int) -> Int {
        (base + offset) % tiles size
    }

    tileIndex: func (tileType: TileType) -> Int {
        i := 0
        for (tile in tiles) {
            if (tile type == tileType) {
                return i
            }
            i += 1
        }

         -1
    }

    classicSetup: func {
        // for now, hardcode the structure...
        i := 0

        brown  := StreetGroup new("brown", RGB new(153, 102, 51))
        cyan   := StreetGroup new("cyan", RGB new(0, 255, 255))
        pink   := StreetGroup new("pink", RGB new(255, 128, 128))
        orange := StreetGroup new("orange", RGB new(255, 128, 0))
        red    := StreetGroup new("red", RGB new(255, 0, 0))
        yellow := StreetGroup new("yellow", RGB new(255, 255, 0))
        green  := StreetGroup new("green", RGB new(0, 255, 0))
        blue   := StreetGroup new("blue", RGB new(0, 0, 255))

        add(SpecialTile new(TileType GO))
        add(Street new(i += 1, brown))
        add(SpecialTile new(TileType COMMUNITY))
        add(Street new(i += 1, brown))
        add(SpecialTile new(TileType INCOME_TAX))
        add(SpecialTile new(TileType TRAIN))
        add(Street new(i += 1, cyan))
        add(SpecialTile new(TileType CHANCE))
        add(Street new(i += 1, cyan))
        add(Street new(i += 1, cyan))

        add(SpecialTile new(TileType PRISON))
        add(Street new(i += 1, pink))
        add(SpecialTile new(TileType ENERGY))
        add(Street new(i += 1, pink))
        add(Street new(i += 1, pink))
        add(SpecialTile new(TileType TRAIN))
        add(Street new(i += 1, orange))
        add(SpecialTile new(TileType COMMUNITY))
        add(Street new(i += 1, orange))
        add(Street new(i += 1, orange))

        add(SpecialTile new(TileType PARK))
        add(Street new(i += 1, red))
        add(SpecialTile new(TileType CHANCE))
        add(Street new(i += 1, red))
        add(Street new(i += 1, red))
        add(SpecialTile new(TileType TRAIN))
        add(Street new(i += 1, yellow))
        add(Street new(i += 1, yellow))
        add(SpecialTile new(TileType ENERGY))
        add(Street new(i += 1, yellow))

        add(SpecialTile new(TileType POLICE))
        add(Street new(i += 1, green))
        add(Street new(i += 1, green))
        add(SpecialTile new(TileType COMMUNITY))
        add(Street new(i += 1, green))
        add(SpecialTile new(TileType TRAIN))
        add(SpecialTile new(TileType CHANCE))
        add(Street new(i += 1, blue))
        add(SpecialTile new(TileType LUXURY_TAX))
        add(Street new(i += 1, blue))

        logger info("Added %d streets", i)
    }

    add: func (tile: Tile) {
        tiles add(tile)
    }

    print: func {
        logger warn("Tiles")
        for (tile in tiles) {
            logger info(tile toString())
        }
    }

}

Tile: abstract class {

    type: TileType
    owner: Player = null

    init: func (=type)

    toString: func -> String {
        "%s:%p" format(class name, this)
    }

    rent: abstract func -> Float

}

SpecialTile: class extends Tile {

    init: func (.type) {
        super(type)
    }

    rent: func -> Float {
        match type {
            case TileType LUXURY_TAX =>
                75.0
            case TileType INCOME_TAX =>
                200.0
            case =>
                0.0
        }
    }

    toString: func -> String {
        "%s tile" format(type toString())
    }

}

TileType: enum {
    STREET     // street tile!
    GO         // collect $200
    CHANCE     // chance card
    COMMUNITY  // community card
    PRISON     // prison (visit or wait)
    POLICE     // go to prison
    TRAIN      // train station
    ENERGY     // water or electricity
    LUXURY_TAX // $75
    INCOME_TAX // 10% or $200 
    PARK       // nothing!

    toString: func -> String {
        match this {
            case This GO => "go"
            case This CHANCE => "chance"
            case This COMMUNITY => "community"
            case This PRISON => "prison"
            case This POLICE => "police"
            case This TRAIN => "train"
            case This ENERGY => "energy"
            case This LUXURY_TAX => "luxury tax"
            case This INCOME_TAX => "income tax"
            case This PARK => "park"
        }
    }
}

StreetGroup: class {
    name: String
    streets := ArrayList<Street> new()
    rgb: RGB

    init: func (=name, =rgb)

    add: func (street: Street) {
        streets add(street)
    }
}

Street: class extends Tile {
    index: Float

    baseRent: Float
    price: Float
    housePrice: Float
    mortgage: Float

    group: StreetGroup

    // 0 = raw, 1-4 = houses, 5 = hotel
    houseCount := 0

    init: func (=index, =group) {
        super(TileType STREET)

        baseRent = 2 + index * 2.25
        price = 50 + index * 16.67
        housePrice = 50 + index * 7.15
        mortgage = 30 + index * 8.10

        group add(this)
    }

    rent: func -> Float {
        match houseCount {
            case 0 => baseRent
            case 1 => baseRent * 5
            case 2 => powerRent(13, 2)
            case 3 => powerRent(28, 17)
            case 4 => powerRent(34, 46)
            case 5 => powerRent(35, 90)
            case => baseRent // I don't know, that's weird.
        }
    }

    powerRent: func (a, b: Float) -> Float {
        a + b * pow((-1 + (index as Float / 21.0 * 0.3)), 8)
    }

    toString: func -> String {
        "%s street, base = %.0f, price = %.0f, house = %.0f, mort %.0f" \
        format(group name, baseRent, price, housePrice, mortgage)
    }

}

