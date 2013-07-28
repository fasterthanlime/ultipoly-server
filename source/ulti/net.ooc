
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
    req: Socket
    pub: Socket

    logger := static Log getLogger(This name)

    init: func (=game, address: String) {
        // create zmq context
        context = Context new()

        req = context createSocket(ZMQ REQ)
        req bind(address)
        logger warn("Request socket bound on %s", address)

        //pub = context createSocket(ZMQ PUB)
    }

    update: func {
        logger info("ServerNet update o/")

        while (req poll(10)) {
            str := req recvString()
            if (!str) return

            logger error(str)

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
        req sendString(str)
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
    rep: Socket

    logger := static Log getLogger(This name)

    init: func {
        // create zmq context
        context = Context new()
        rep = context createSocket(ZMQ REP)
    }

    // loop

    update: func {
        while (rep poll(10)) {
            str := rep recvString()
            logger warn("Received message from server: %s", str)
        }
    }

    // business

    join: func (name: String) {
        send("join\n%s" format(name))
    }

    // utility

    connect: func (address: String) {
        rep connect(address)
    }

    send: func (str: String) {
        rep
    }

}

