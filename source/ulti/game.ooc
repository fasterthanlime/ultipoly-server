
// third-party
use deadlogger
import deadlogger/[Log, Logger]

// ours
import ulti/[base, board, servernet, zbag, options, lobby, server]

// sdk
import structs/[ArrayList, HashMap]
import os/[Time]

ServerGame: class {

    server: Server
    name: String

    running := true

    board: Board
    players := HashMap<String, ServerPlayer> new()

    state := ServerGameState ACCEPTING_PLAYERS
    net: ServerNet

    logger: Logger

    remainingAvatars := ArrayList<String> new()

    keepalive := 0.0

    init: func (=server, =name) {
        logger = Log getLogger("%s %s" format(This name, name))

        net = ServerNet new(server lobby context, this)

        board = Board new()
        board classicSetup()
        logger info("Board set up!")

        // setting up avatars
        remainingAvatars add("alien"). add("astronaut")
    }

    addPlayer: func (name: String) -> Player {
        avatar := remainingAvatars removeAt(0)
        player := Player new(name, avatar)
        players put(player name, ServerPlayer new(player))
        player hose subscribe(|bag|
            logger info("Player event: %s", bag first())
            net playerEvent(player, bag)
        )

        for (i in 0..1) {
            unit := board createUnit(player)
            unit initialWait()
            unit hose subscribe(|bag|
                logger info("Unit event: %s", bag first())
                net unitEvent(unit, bag)
            )
        }
        logger info("Player %s joined", name)
        player
    }

    getPlayer: func (name: String) -> ServerPlayer {
        players get(name)
    }

    step: func (delta: Float) {
        net update()

        match state {
            case ServerGameState ACCEPTING_PLAYERS =>
                if (readyToStart?()) {
                    state = ServerGameState RUNNING
                    logger info("Game started!")
                    net broadcastGameInfo()
                }
            case ServerGameState RUNNING =>
                handleKeepalive(delta)
                stepPlayers(delta)
        }
    }

    handleKeepalive: func (delta: Float) {
        keepalive -= delta
        if (keepalive > 0) return

        // check for dead clients
        for (sPlayer in players) {
            if (!sPlayer alive) {
                // kick player - but for now, just quit
                logger error("Player %s left, bailing out!", sPlayer player name)
                running = false
            }
        }

        // reset everyone
        for (sPlayer in players) {
            sPlayer alive = false
        }

        // ask for ping
        net keepalive()

        // reset timer
        keepalive = 3000.0
    }

    readyToStart?: func -> Bool {
        if (players size < server options minPlayers) {
            return false
        }

        for (p in players) {
            if (!p ready?()) {
                return false
            }
        }

        true
    }

    stepPlayers: func (delta: Float) {
        for (player in players) {
            for (unit in player player units) {
                unit step(delta)
            }
        }
    }

    // stuff

    tryBuy: func (name: String, tileIndex: Int) -> ZBag {
        tile := board getTile(tileIndex)
        if (tile owner) {
            return ZBag make("denied", "buy denied - tile is already owned")
        }

        sPlayer := players get(name)
        if (!sPlayer) {
            return ZBag make("denied", "unknown player %s" format(name))
        }
        player := sPlayer player

        unit: Unit
        for (u in player units) {
            if (u tileIndex == tileIndex && u waiting?()) {
                unit = u
            }
        }
        if (unit == null) {
            return ZBag make("denied", "not there anymore!")
        }

        if (!tile buyable?()) {
            return ZBag make("denied", "unbuyable tile")
        }

        if (player balance < tile getPrice()) {
            return ZBag make("denied", "can't afford it!")
        }

        unit begin(Action new(ActionType BUY))
        ZBag make("ack")
    }

    doBuy: func (unit: Unit) -> ZBag {
        tile := board getTile(unit tileIndex)
        player := unit player

        tile owner = player
        player spend(tile getPrice())
        net publish(ZBag make("tile bought", player name, unit tileIndex))
    }

}

ServerGameState: enum {
    ACCEPTING_PLAYERS
    RUNNING
}

ServerPlayer: class {
    player: Player
    state := PlayerState JOINING
    alive := true

    init: func (=player) {
    }

    ready: func {
        state = PlayerState READY
    }

    ready?: func -> Bool {
        state == PlayerState READY
    }
}

PlayerState: enum {
    JOINING
    READY
}

