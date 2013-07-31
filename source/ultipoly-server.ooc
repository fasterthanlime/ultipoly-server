
// third-party
use deadlogger
import deadlogger/[Log, Logger]

use zombieconfig
import zombieconfig

// ours
import ulti/[base, servernet, game, options]

// sdk
import structs/[ArrayList]
import os/[Time]

main: func (args: ArrayList<String>) {
    Server new()
}

Server: class extends Base {

    options: ServerOptions
    games := ArrayList<ServerGame> new()

    init: func {
        super()
        logger info("Starting up ultipoly-server...")

        logger info("Loading config")
        configPath := "config/server.config"
        config := ZombieConfig new(configPath, |base|
            base("minPlayers", "2")
            base("loop", "false")
        )

        options = ServerOptions new(config)
        createGame()

        run()
    }

    createGame: func {
        game := ServerGame new(options)
        games add(game)
    }

    run: func {
        delta := 1000.0 / 60.0 // 60FPS simulation

        while (true) {
            t1 := Time runTime()

            iter := games iterator()
            while (iter hasNext?()) {
                game := iter next()
                game step(delta)
                if (!game running) {
                    games remove(game)
                }
            }

            t2 := Time runTime()
            diff := (t2 - t1) as Float
            if (diff < delta) {
                sleep := (delta - diff) as UInt
                Time sleepMilli(sleep)
            }

            if (games empty?()) {
                if (options loop) {
                    logger info("Creating another game")
                    createGame()
                } else {
                    logger info("Server shutting down...")
                    quit()
                }
            }
        }
    }

    quit: func {
        exit(0)
    }

}

