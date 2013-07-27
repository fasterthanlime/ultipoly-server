
// third-party
use deadlogger
import deadlogger/[Log, Logger]

// ours
import ulti/[base, board]

// sdk
import structs/[ArrayList]
import os/[Time]

main: func (args: ArrayList<String>) {
    Server new()
}

Server: class extends Base {

    games := ArrayList<Game> new()

    init: func {
        super()
        logger info("Starting up ultipoly-server...")

        game := Game new()
        games add(game)

        run()
    }

    run: func {
        delta := 20

        while (true) {
            for (game in games) {
                game step(delta)
            }

            Time sleepMilli(delta)
        }
    }

}

Game: class {

    board: Board
    players := ArrayList<Player> new()

    init: func {
        board := Board new()
        board print()

        player := Player new("zapa")
        board createUnit(player)
        players add(player)
    }

    step: func (delta: Float) {
        for (player in players) {
            for (unit in player units) {
                unit step(delta)
            }
        }
    }

}

