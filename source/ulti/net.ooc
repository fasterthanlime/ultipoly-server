
// third-party
use czmq
import czmq

use deadlogger
import deadlogger/[Log, Logger]

// ours
use ultipoly-server
import ulti/[board, game]

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
        while (rep poll(10)) {
            str := rep recvString()
            logger warn("Received message: %s", str)

            tokens := str split('\n')
            if (tokens empty?()) {
                reply("error\nmalformed message")
            }

            match (tokens[0]) {
                case "join" =>
                    onJoin(tokens)
            }
        }
    }

    reply: func (str: String) {
        rep sendString(str)
    }

    onJoin: func (tokens: List<String>) {
        name := tokens[1]
        logger warn("%s is trying to join", name)
        game addPlayer(name)
        reply("joined")
    }

}

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
        while (req poll(10)) {
            str := req recvString()
            logger warn("Received message from server: %s", str)
        }
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

}

