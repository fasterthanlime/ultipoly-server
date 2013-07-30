
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

    game: ServerGame

    context: Context
    rep: Socket
    pub: Socket
    pubPort: Int

    logger := static Log getLogger(This name)

    init: func (=game, address: String) {
        // create zmq context
        context = Context new()

        rep = context createSocket(ZMQ REP)
        rep bind(address)
        logger warn("Reply socket bound on %s", address)

        pub = context createSocket(ZMQ PUB)
        pubPort = pub bind("tcp://0.0.0.0:*")
        logger warn("Publish socket bound on port %d", pubPort)
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
            logger warn("<< %s", message)

            match (message) {
                case "join" =>
                    onJoin(bag)
                case "ready" =>
                    onReady(bag)
                case "buy" =>
                    onBuy(bag)
                case "keepalive" =>
                    onKeepalive(bag)
                case =>
                    logger warn("unknown message!")
                    reply(ZBag make("error", "unknown message: %s" format(message)))
            }
        }
    }

    // util

    reply: func (bag: ZBag) {
        logger warn(">> %s", bag first())
        rep sendString(bag pack())
    }

    publish: func (bag: ZBag) {
        logger warn(">* %s", bag first())
        pub sendString(bag pack())
    }

    // events

    onJoin: func (bag: ZBag) {
        name := bag pull()
        logger warn("%s is trying to join", name)
        player := game addPlayer(name)
        welcome(player)
    }

    onReady: func (bag: ZBag) {
        name := bag pull()
        logger warn("%s is ready", name)
        game getPlayer(name) ready()
        reply(ZBag make("ack"))
    }

    onBuy: func (bag: ZBag) {
        name := bag pull()
        index := bag pullInt()
        logger warn("%s is trying to buy tile #%d", name, index)

        reply(game tryBuy(name, index))
    }

    onKeepalive: func (bag: ZBag) {
        name := bag pull()
        player := game players get(name)
        player alive = true
        reply(ZBag make("ack"))
    }

    // business

    keepalive: func {
        publish(ZBag make("are you alive?"))
    }

    unitEvent: func (unit: Unit, bag: ZBag) {
        bag preshove(unit hash)
        bag preshove("unit event")
        publish(bag)
    }

    playerEvent: func (player: Player, bag: ZBag) {
        bag preshove(player name)
        bag preshove("player event")
        publish(bag)
    }

    welcome: func (player: Player) {
        bag := ZBag new()
        bag shove("welcome")
        bag shove("port")
        bag shoveInt(pubPort)
        reply(bag)
    }

    broadcastGameInfo: func {
        bag := ZBag new()
        bag shove("game info")
        game board shove(bag)
        bag shoveInt(game players size)
        for (player in game players) {
            bag shove(player player name)
            bag shove(player player avatar)
        }
        publish(bag)

        bag = ZBag new()
        bag shove("new unit")
        bag shoveInt(game board units size) 
        for (unit in game board units) {
            bag shove(unit player name)
            bag shove(unit hash)
        }
        publish(bag)

        bag = ZBag new()
        bag shove("start")
        publish(bag)
    }

}
