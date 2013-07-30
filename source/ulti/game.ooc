
// third-party
use deadlogger
import deadlogger/[Log, Logger]

// ours
import ulti/[base, board, servernet, zbag]

// sdk
import structs/[ArrayList, HashMap]
import os/[Time]

ServerGame: class {

    board: Board
    players := HashMap<String, ServerPlayer> new()

    state := ServerGameState ACCEPTING_PLAYERS
    net: ServerNet

    logger := static Log getLogger(This name)

    remainingAvatars := ArrayList<String> new()

    // params
    MINIMUM_PLAYERS := 2

    init: func {
        net = ServerNet new(this, "tcp://0.0.0.0:5555")
        logger info("Socket open.")

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
                stepPlayers(delta)
        }
    }

    readyToStart?: func -> Bool {
        if (players size < MINIMUM_PLAYERS) {
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

    tryBuy: func (name: String, tileIndex: Int) {
        tile := board getTile(tileIndex)
        if (tile owner) {
            net reply(ZBag make("denied", "buy denied - tile is already owned"))
            return
        }

        player := players get(name)
        if (!player) {
            net reply(ZBag make("denied", "unknown player %s" format(name)))
            return
        }

        onThere := false
        for (unit in player player units) {
            if (unit tileIndex == tileIndex && unit waiting?()) {
                onThere = true
            }
        }
        if (!onThere) {
            net reply(ZBag make("denied", "no waiting unit there"))
            return
        }

        if (!tile buyable?()) {
            net reply(ZBag make("denied", "unbuyable tile"))
            return
        }

        tile owner = player
        net publish(ZBag make("tile bought", name, tileIndex))
    }

}

ServerGameState: enum {
    ACCEPTING_PLAYERS
    RUNNING
}

ServerPlayer: class {
    player: Player
    state := PlayerState JOINING

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

