
// third-party
use deadlogger
import deadlogger/[Log, Logger]

// ours
import ulti/[base, board, servernet]

// sdk
import structs/[ArrayList, HashMap]
import os/[Time]

Game: class {

    board: Board
    players := HashMap<String, ServerPlayer> new()

    state := GameState ACCEPTING_PLAYERS
    net: ServerNet

    logger := static Log getLogger(This name)

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
            case GameState ACCEPTING_PLAYERS =>
                if (readyToStart?()) {
                    state = GameState RUNNING
                    logger info("Game started!")
                    net broadcastGameInfo()
                }
            case GameState RUNNING =>
                stepPlayers(delta)
        }
    }

    readyToStart?: func -> Bool {
        if (players size < 2) {
            logger warn("Not enough players")
            return false
        }

        for (p in players) {
            if (!p ready?()) {
                logger warn("Player %s is not ready", p player name)
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

GameState: enum {
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

