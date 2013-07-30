
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
                // bail out! for now!
                quit()
            }
        }
    }

    quit: func {
        exit(0)
    }

}


