
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

    context: Context
    leq, req, sub: Socket

    hostname: String
    leqPort, reqPort, subPort: Int

    name: String

    logger := static Log getLogger(This name)

    init: func (=hostname, =leqPort) {
        // create zmq context
        context = Context new()

        // leq = lobby req
        leq = context createSocket(ZMQ REQ)
        address := "tcp://%s:%d" format(hostname, leqPort)
        logger info("Connecting to lobby at %s", address)
        leq connect(address)

        req = context createSocket(ZMQ REQ)
        sub = context createSocket(ZMQ SUB)
    }

    // loop

    update: func {
        pumpLeq()
        pumpReq()
        pumpSub()
    }

    pumpLeq: func {
        while (leq poll(10)) {
            str := leq recvStringNoWait()
            if (str == null) return

            bag := ZBag extract(str)
    
            message := bag pull()
            logger warn("|<< %s", message)

            match message {
                case "welcome" =>
                    onLobbyWelcome(bag)
                case "nah" =>
                    logger warn("Nah: %s", bag pull())
                case =>
                    logger warn("Unknown message :'(")
            }
        }
    }

    pumpReq: func {
        while (req poll(10)) {
            str := req recvStringNoWait()
            if (str == null) return

            bag := ZBag extract(str)
    
            message := bag pull()
            logger warn("<< %s", message)

            match message {
                case "welcome" =>
                    onWelcome(bag)
                case "ack" =>
                    // all good!
                case "denied" =>
                    logger warn("Denied: %s", bag pull())
                case =>
                    logger warn("Unknown message :'(")
            }
        }
    }

    pumpSub: func {
        while (sub poll(10)) {
            str := sub recvStringNoWait()
            if (str == null) return

            bag := ZBag extract(str)

            message := bag pull()
            logger warn("<* %s", message)

            match message {
                case "game info" =>
                    gameInfo(bag)
                case "new unit" =>
                    newUnit(bag)
                case "start" =>
                    start()
                case "unit event" =>
                    unitEvent(bag)
                case "player event" =>
                    playerEvent(bag)
                case "tile bought" =>
                    name := bag pull()
                    tileIndex := bag pullInt()
                    tileBought(name, tileIndex)
                case "are you alive?" =>
                    keepalive()
                case =>
                    logger warn("Unknown message :'(")
            }
        }
    }

    // lobby stuff

    createGame: func {
        lobbySend(ZBag make("create"))
    }

    joinGame: func (name: String) {
        lobbySend(ZBag make("join", name))
    }

    onWelcome: func (bag: ZBag) {
        bag pullCheck("port")
        connectSub(bag pullInt())
        ready()
    }

    // non-lobby stuff

    gameInfo: func (bag: ZBag) {
        board := Board pull(bag)
        onBoard(board)

        numPlayers := bag pullInt()
        for (i in 0..numPlayers) {
            name := bag pull()
            avatar := bag pull()
            onNewPlayer(name, avatar)
        }
    }

    newUnit: func (bag: ZBag) {
        numUnits := bag pullInt()
        for (i in 0..numUnits) {
            playerName := bag pull()
            hash := bag pull()
            onNewUnit(playerName, hash)
        }
    }

    // override that shiznit

    unitEvent: func (bag: ZBag)

    playerEvent: func (bag: ZBag)

    tileBought: func (name: String, tileIndex: Int)

    onBoard: func (board: Board)

    onNewPlayer: func (name, avatar: String)

    onNewUnit: func (playerName, hash: String)

    start: func

    keepalive: func

    // business

    onLobbyWelcome: func (bag: ZBag) {
        reqPort := bag pullInt()
        connect(reqPort)
    }

    join: func (=name) {
        send(ZBag make("join", name))
    }

    ready: func {
        send(ZBag make("ready", name))
    }

    tryBuy: func (tileIndex: Int) {
        send(ZBag make("buy", name, tileIndex))
    }

    // utility

    connect: func (=reqPort) {
        address := "tcp://%s:%d" format(hostname, reqPort)
        logger warn("Connecting req/rep to: %s", address)
        req connect(address)
    }

    connectSub: func (=subPort) {
        address := "tcp://%s:%d" format(hostname, subPort)
        logger warn("Connecting pub/sub to: %s", address)
        sub connect(address)

        // subscribe to ALLLL the messages.
        sub subscribe("")
    }

    lobbySend: func (bag: ZBag) {
        logger warn("|>> %s", bag first())
        leq sendString(bag pack())
    }

    send: func (bag: ZBag) {
        logger warn(">> %s", bag first())
        req sendString(bag pack())
    }

}

