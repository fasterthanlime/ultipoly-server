
// third-party
use deadlogger
import deadlogger/[Log, Logger]

use zombieconfig
import zombieconfig

// ours
import ulti/[base, servernet, game, options, lobby]

// sdk
import structs/[ArrayList, HashMap]
import os/[Time]

Server: class extends Base {

    options: ServerOptions
    games := HashMap<String, ServerGame> new()
    lobby: Lobby

    init: func {
        super()
        logger info("Starting up ultipoly-server...")

        logger info("Loading config")
        configPath := "config/server.config"
        config := ZombieConfig new(configPath, |base|
            base("minPlayers", "2")
            base("loop", "false")
            base("port", "5555")
        )

        options = ServerOptions new(config)
        lobby = Lobby new(this)

        run()
    }

    run: func {
        delta := 1000.0 / 60.0 // 60FPS simulation

        while (true) {
            t1 := Time runTime()

            lobby update()

            iter := games iterator()
            while (iter hasNext?()) {
                game := iter next()
                game step(delta)
                if (!game running) {
                    games remove(game name)
                }
            }

            t2 := Time runTime()
            diff := (t2 - t1) as Float
            if (diff < delta) {
                sleep := (delta - diff) as UInt
                Time sleepMilli(sleep)
            }
        }
    }

    quit: func {
        exit(0)
    }

}

