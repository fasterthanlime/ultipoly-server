
// third-party
use deadlogger
import deadlogger/[Log, Logger]

// ours
import ulti/[base, board, servernet]

// sdk
import structs/[ArrayList]
import os/[Time]

Game: class {

    board: Board
    players := ArrayList<Player> new()

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
        players add(player)

        for (i in 0..1) {
            board createUnit(player)
        }
        logger info("Player %s joined", name)
    }

    step: func (delta: Float) {
        net update()

        match state {
            case GameState ACCEPTING_PLAYERS =>
                if (players size > 1) {
                    state = GameState RUNNING
                    logger info("Game started!")
                }
            case GameState RUNNING =>
                stepPlayers(delta)
        }
    }

    stepPlayers: func (delta: Float) {
        for (player in players) {
            for (unit in player units) {
                unit step(delta)
            }
        }
    }

}

GameState: enum {
    ACCEPTING_PLAYERS
    RUNNING
}
