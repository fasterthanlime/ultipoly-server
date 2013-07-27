
// third-party
use deadlogger
import deadlogger/[Log, Logger, Handler, Formatter]

// sdk
import io/File

Base: class {

    logger: Logger

    init: func {
        setupLogging()
    }

    setupLogging: func {
        // log to console
        console := StdoutHandler new()
        formatter := NiceFormatter new()
        version (!windows) {
            formatter = ColoredFormatter new(formatter)
        }
        console setFormatter(formatter)
        //console setFilter(LevelFilter new(Level info..Level critical))
        Log root attachHandler(console)

        // log to file
        logFile := File new("ultipoly.log")
        logFile write("")

        file := FileHandler new(logFile path)
        file setFormatter(NiceFormatter new())
        Log root attachHandler(file)

        logger = Log getLogger("Ultipoly")
    }

}
