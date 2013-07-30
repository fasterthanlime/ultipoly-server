
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
    sub: Socket

    hostname: String
    reqPort, subPort: Int

    name: String

    logger := static Log getLogger(This name)

    init: func {
        // create zmq context
        context = Context new()
        req = context createSocket(ZMQ REQ)

        sub = context createSocket(ZMQ SUB)
    }

    // loop

    update: func {
        pumpReq()
        pumpSub()
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
                case =>
                    logger warn("Unknown message :'(")
            }
        }
    }

    onWelcome: func (bag: ZBag) {
        bag pullCheck("port")
        connectSub(bag pullInt())
        ready()
    }

    gameInfo: func (bag: ZBag) {
        board := Board pull(bag)
        onBoard(board)

        numPlayers := bag pullInt()
        for (i in 0..numPlayers) {
            onNewPlayer(bag pull())
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

    unitEvent: func (bag: ZBag)

    playerEvent: func (bag: ZBag)

    tileBought: func (name: String, tileIndex: Int)

    // override that shiznit

    onBoard: func (board: Board)

    onNewPlayer: func (name: String)

    onNewUnit: func (playerName, hash: String)

    start: func

    // business

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

    connect: func (=hostname, =reqPort) {
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

    send: func (bag: ZBag) {
        logger warn(">> %s", bag first())
        req sendString(bag pack())
    }

}

