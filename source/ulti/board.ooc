
// third-party
use deadlogger
import deadlogger/[Log, Logger]

// sdk
import structs/[ArrayList, Stack, HashMap]
import math/[Random], math

// ours
import ulti/[zbag, events]

Player: class {

    name: String
    avatar: String
    units := ArrayList<Unit> new()

    balance := 1500.0

    logger: Logger
    hose := Firehose new()

    init: func (=name, =avatar) {
        logger = Log getLogger(toString())
    }

    toString: func -> String {
        "player %s" format(name)
    }

    spend: func (amount: Float) {
        balance -= amount
        logger warn("Spent %.0f, %.0f remaining", amount, balance)
        balanceOp(-amount)
    }

    gain: func (amount: Float) {
        balance += amount
        logger warn("Gained %.0f, balance = %.0f", amount, balance)
        balanceOp(amount)
    }

    // broadcast balance
    balanceOp: func (diff: Float) {
        hose publish(ZBag make("balance", diff, balance))
    }

    applyEvent: func (bag: ZBag) {
        message := bag pull()
        match message {
            case "balance" =>
                // do something with diff? visual feedback? hell yeah.
                diff := bag pullFloat()
                balance = bag pullFloat()
        }
    }

}

// Something that roves on the board and can buy properties,
// pay rent, etc.
Unit: class {

    board: Board
    player: Player
    messages := Stack<String> new()

    hash: String

    // state
    action: Action
    tileIndex: Int

    logger: Logger

    hose := Firehose new()

    init: func (=board, =player) {
        player units add(this)
        logger = Log getLogger("%s #%d" format(player name, player units size))
    }

    initialWait: func {
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
        hose publish(ZBag make("action", action type as Int, action timeout, action number))
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

        hose publish(ZBag make("move", tileIndex))
    }

    applyEvent: func (bag: ZBag) {
        message := bag pull()
        match message {
            case "move" =>
                tileIndex = bag pullInt()
                logger info("Unit %s moved to %d", hash, tileIndex)
            case "action" =>
                type := bag pullInt() as ActionType
                action = Action new(type)
                action timeout = bag pullFloat()
                action number = bag pullInt()
                logger info("Unit %s changed action to %s", hash, action toString())
            case =>
                logger warn("Unknown unit event message: %s", message)
        }
    }

    queue: func (message: String) {
        messages push(message)
    }

    step: func (delta: Float) {
        fakeStep(delta)

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

    fakeStep: func (delta: Float) {
        if (action) {
            action step(delta)
        }
    }

    waiting?: func -> Bool {
        (action != null && action type == ActionType WAIT)
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
    type: ActionType
    timeout: Float

    // an int you can store anything in
    number := 0

    init: func (=type) {
        timeout = match type {
            case ActionType WAIT => 4000.0
            case ActionType MOVE => 1500.0
            case ActionType PRISON => 12000.0
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
        "%s(%.0f, number: %d)" format(type toString(), timeout, number)
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
    units := HashMap<String, Unit> new()

    streetGroups := HashMap<String, StreetGroup> new()    
    logger := static Log getLogger(This name)

    // for hash generation
    seed := 0

    init: func {
    }

    createUnit: func (player: Player) -> Unit {
        hash := "%s-%d" format(player name, seed)
        seed += 1
        addUnit(player, hash)
    }

    addUnit: func (player: Player, hash: String) -> Unit {
        unit := Unit new(this, player)
        unit hash = hash
        unit tileIndex = 0
        units put(hash, unit)
        logger info("Unit spawned on tile %s", getTile(unit tileIndex) toString())
        unit
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

        brown  := addGroup(StreetGroup new("brown", RGB new(153, 102, 51)))
        cyan   := addGroup(StreetGroup new("cyan", RGB new(0, 255, 255)))
        pink   := addGroup(StreetGroup new("pink", RGB new(255, 128, 128)))
        orange := addGroup(StreetGroup new("orange", RGB new(255, 128, 0)))
        red    := addGroup(StreetGroup new("red", RGB new(255, 0, 0)))
        yellow := addGroup(StreetGroup new("yellow", RGB new(255, 255, 0)))
        green  := addGroup(StreetGroup new("green", RGB new(0, 255, 0)))
        blue   := addGroup(StreetGroup new("blue", RGB new(0, 0, 255)))

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

    addGroup: func (group: StreetGroup) -> StreetGroup {
        streetGroups put(group name, group)
        group
    }

    getGroup: func (name: String) -> StreetGroup {
        streetGroups get(name)
    }

    add: func (tile: Tile) {
        tiles add(tile)
    }

    print: func {
        logger warn("Board tiles:")
        for (tile in tiles) {
            logger info(tile toString())
        }
    }

    shove: func (bag: ZBag) {
        bag shove("board")

        bag shove("groups")
        bag shoveInt(streetGroups size)

        for (group in streetGroups) {
            group shove(bag)
        }
        bag shove("groups end")

        bag shove("tiles")
        bag shoveInt(tiles size)

        for (tile in tiles) {
            tile shove(bag)
        }
        bag shove("tiles end")

        bag shove("board end")
    }

    pull: static func (bag: ZBag) -> This {
        bag pullCheck("board")
        board := This new()

        bag pullCheck("groups")
        numGroups := bag pullInt()

        for (i in 0..numGroups) {
            board addGroup(StreetGroup pull(bag))
        }
        bag pullCheck("groups end")

        bag pullCheck("tiles")
        numTiles := bag pullInt()

        for (i in 0..numTiles) {
            board add(Tile pull(bag, board))
        }
        bag pullCheck("tiles end")
        bag pullCheck("board end")

        board
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

    shove: func (bag: ZBag) {
        bag shove("tile start")
        bag shoveInt(type as Int)
        match this {
            case street: Street =>
                bag shoveInt(street index)
                bag shove(street group name)
        }
        bag shove("tile end")
    }

    pull: static func (bag: ZBag, board: Board) -> This {
        bag pullCheck("tile start")
        type := bag pullInt() as TileType

        tile: This = match type {
            case TileType STREET =>
                index := bag pullInt()
                groupName := bag pull()
                group := board getGroup(groupName)
                if (!group) {
                    ZBag complain("Can't find group '%s'" format(groupName))
                }
                Street new(index, group)
            case =>
                SpecialTile new(type)
        }
        bag pullCheck("tile end")
        tile
    }

    buyable?: func -> Bool {
        getPrice() >= 0.0
    }

    getPrice: func -> Float {
        return -1.0
    }

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
        "%s" format(type toString())
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
            case This PRISON => "detention"
            case This POLICE => "militia"
            case This TRAIN => "moonrail"
            case This ENERGY => "solar"
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

    shove: func (bag: ZBag) {
        bag shove("streetgroup")
        bag shove(name)
        bag shoveInt(rgb r)
        bag shoveInt(rgb g)
        bag shoveInt(rgb b)
        bag shove("streetgroup end")
    }

    pull: static func (bag: ZBag) -> This {
        bag pullCheck("streetgroup")
        name := bag pull()
        r := bag pullInt()
        g := bag pullInt()
        b := bag pullInt()
        bag pullCheck("streetgroup end")

        This new(name, RGB new(r, g, b))
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

    getPrice: func -> Float {
        return price
    }
}

