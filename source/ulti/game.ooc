
// third-party
use deadlogger
import deadlogger/[Log, Logger]

// ours
import ulti/[base, board, servernet]

// sdk
import structs/[ArrayList, HashMap]
import os/[Time]

ServerGame: class {

    board: Board
    players := HashMap<String, ServerPlayer> new()

    state := ServerGameState ACCEPTING_PLAYERS
    net: ServerNet

    logger := static Log getLogger(This name)

    // params
    MINIMUM_PLAYERS := 1

    init: func {
        net = ServerNet new(this, "tcp://0.0.0.0:5555")
        logger info("Socket open.")

        board = Board new()
        board classicSetup()
        logger info("Board set up!")
    }

    addPlayer: func (name: String) {
        player := Player new(name)
        players put(player name, ServerPlayer new(player))

        for (i in 0..1) {
            board createUnit(player)
        }
        logger info("Player %s joined", name)
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

