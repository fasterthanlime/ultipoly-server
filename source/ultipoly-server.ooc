
// third-party
use deadlogger
import deadlogger/[Log, Logger]

// ours
import ulti/[base, board]

// sdk
import structs/[ArrayList]

main: func (args: ArrayList<String>) {
    Server new()
}

Server: class extends Base {

    init: func {
        super()
        logger info("Starting up ultipoly-server...")

        board := Board new()
        board print()
    }

}

