
// third-party
use deadlogger
import deadlogger/[Log, Logger]

// sdk
import structs/[ArrayList]
import math

Player: class {

    index: Int

    init: func (=index) {
    }

}

Board: class {

    tiles := ArrayList<Tile> new()    
    logger := static Log getLogger(This name)

    init: func {
        classicSetup()
    }

    classicSetup: func {
        // for now, hardcode the structure...
        i := 0

        brown  := StreetGroup new()
        cyan   := StreetGroup new()
        pink   := StreetGroup new()
        orange := StreetGroup new()
        red    := StreetGroup new()
        yellow := StreetGroup new()
        green  := StreetGroup new()
        blue   := StreetGroup new()

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
}

StreetGroup: class {
    streets := ArrayList<Street> new()

    init: func

    add: func (street: Street) {
        streets add(street)
    }
}

Street: class extends Tile {
    index: Float

    name: String
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

}

