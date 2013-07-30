
// third-party
use deadlogger
import deadlogger/[Log, Logger]

// ours
import ulti/[base, servernet, game]

// sdk
import structs/[ArrayList]
import os/[Time]

main: func (args: ArrayList<String>) {
    Server new()
}

Server: class extends Base {

    games := ArrayList<ServerGame> new()

    init: func {
        super()
        logger info("Starting up ultipoly-server...")

        game := ServerGame new()
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


