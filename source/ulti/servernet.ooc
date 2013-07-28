
// third-party
use czmq
import czmq

use deadlogger
import deadlogger/[Log, Logger]

// ours
use ultipoly-server
import ulti/[board, game, zbag]

// sdk
import text/StringTokenizer
import structs/[List, ArrayList]

ServerNet: class {

    game: Game

    context: Context
    rep: Socket
    pub: Socket

    logger := static Log getLogger(This name)

    init: func (=game, address: String) {
        // create zmq context
        context = Context new()

        rep = context createSocket(ZMQ REP)
        rep bind(address)
        logger warn("Reply socket bound on %s", address)

        //pub = context createSocket(ZMQ PUB)
    }

    update: func {
        pumpRep()
    }

    pumpRep: func {
        while (rep poll(10)) {
            str := rep recvString()
            logger warn("Received message: %s", str)

            tokens := str split('\n')
            if (tokens empty?()) {
                reply(ZBag make("error", "malformed message"))
            }

            match (tokens[0]) {
                case "join" =>
                    onJoin(tokens)
            }
        }
    }

    reply: func (bag: ZBag) {
        logger warn("Replying a: %s", bag first())
        rep sendString(bag pack())
    }

    onJoin: func (tokens: List<String>) {
        name := tokens[1]
        logger warn("%s is trying to join", name)
        game addPlayer(name)

        bag := ZBag new()
        bag shove("joined")
        game board shove(bag)
        reply(bag)
    }

}
