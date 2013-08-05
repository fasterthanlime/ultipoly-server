
// third-party
use czmq
import czmq

use deadlogger
import deadlogger/[Log, Logger]

// ours
use ultipoly-server
import ulti/[game, zbag, options, servernet, server]

// sdk
import structs/[List, ArrayList, HashMap]

Lobby: class {

    server: Server

    context: Context
    rep: Socket

    seed := 0

    logger := static Log getLogger(This name)

    init: func (=server) {
        // create zmq context
        context = Context new()

        rep = context createSocket(ZMQ REP)
        rep bind("tcp://0.0.0.0:%d" format(server options port))
        logger warn("Reply socket bound on port %d", server options port)
    }

    update: func {
        pumpRep()
    }

    pumpRep: func {
        while (rep poll(10)) {
            str := rep recvStringNoWait()
            if (str == null) return

            bag := ZBag extract(str)

            message := bag pull()
            logger warn("|<< %s", message)

            match (message) {
                case "create" =>
                    reply(onCreateGame(bag))
                case "join" =>
                    reply(onJoinGame(bag))
            }
        }
    }

    // util

    reply: func (bag: ZBag) {
        logger warn("|>> %s", bag first())
        rep sendString(bag pack())
    }

    // business

    generateName: func -> String {
        name := "game%d" format(seed)
        seed += 1
        name
    }

    onCreateGame: func (bag: ZBag) -> ZBag {
        name := generateName()
        if (server games contains?(name)) {
            return ZBag make("nah", "name generation failed")
        }
        
        game := ServerGame new(server, name)
        server games put(name, game)
        ZBag make("welcome", game net repPort)
    }

    onJoinGame: func (bag: ZBag) -> ZBag {
        name := bag pull()
        if (!server games contains?(name)) {
            return ZBag make("nah", "game does not exist")
        }
        game := server games get(name)
        ZBag make("welcome", game net repPort)
    }


}
