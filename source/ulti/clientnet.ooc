
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

ClientNet: class {

    player: Player

    context: Context
    req: Socket

    logger := static Log getLogger(This name)

    init: func {
        // create zmq context
        context = Context new()
        req = context createSocket(ZMQ REQ)
    }

    // loop

    update: func {
        pumpReq()
        pumpSub()
    }

    pumpReq: func {
        while (req poll(10)) {
            str := req recvString()
            bag := ZBag extract(str)
    
            message := bag pull()
            logger warn("Received from server: %s", message)

            match message {
                case "joined" =>
                    onBoard(Board pull(bag))
                case =>
                    logger warn("Unknown message :'(")
            }
        }
    }

    pumpSub: func {
        // not yet.
    }

    // business

    join: func (name: String) {
        send("join\n%s" format(name))
    }

    // utility

    connect: func (address: String) {
        logger warn("Connecting to: %s", address)
        req connect(address)
    }

    send: func (str: String) {
        logger warn("Sending: %s", str)
        req sendString(str)
    }

    // override that shiznit

    onBoard: func (board: Board)

}

