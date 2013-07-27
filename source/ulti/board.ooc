
// third-party
use deadlogger
import deadlogger/[Log, Logger]

// sdk
import structs/[ArrayList]
import math/[Random], math

Player: class {

    name: String
    units := ArrayList<Unit> new()

    balance := 1500.0

    init: func (=name)

    toString: func -> String {
        "player %s" format(name)
    }

}

// Something that roves on the board and can buy properties,
// pay rent, etc.
Unit: class {

    board: Board
    player: Player

    // state
    action: Action
    tileIndex: Int

    logger: Logger

    init: func (=board, =player) {
        player units add(this)
        logger = Log getLogger("%s #%d" format(player name, player units size))

        begin(Action new(ActionType WAIT))
    }

    begin: func (newAction: Action) {
        logger info("%s => %s", player toString(),
        action ? action toString() : "(nil)", newAction toString())

        if (action) {
            _apply(action)
        }
        action = newAction
    }

    _apply: func (action: Action) {
        match (action type) {
            case ActionType MOVE =>
                tileIndex = action number
                logger info("arrived on %s", board getTile(tileIndex) toString())
        }
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
    timeout := 5000.0

    // an int you can store anything in
    number := 0

    type: ActionType

    init: func (=type) {
        timeout = match type {
            case ActionType WAIT => 1500.0
            case ActionType MOVE => 3000.0
            case ActionType MOVE => 5000.0
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

    classicSetup: func {
        // for now, hardcode the structure...
        i := 0

        brown  := StreetGroup new("brown")
        cyan   := StreetGroup new("cyan")
        pink   := StreetGroup new("pink")
        orange := StreetGroup new("orange")
        red    := StreetGroup new("red")
        yellow := StreetGroup new("yellow")
        green  := StreetGroup new("green")
        blue   := StreetGroup new("blue")

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

    owner: Player = null

    init: func

    toString: func -> String {
        "%s:%p" format(class name, this)
    }

    rent: abstract func -> Float

}

SpecialTile: class extends Tile {

    type: TileType

    init: func (=type)

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

    init: func (=name)

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

