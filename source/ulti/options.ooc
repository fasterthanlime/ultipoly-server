
// third-party
use zombieconfig
import zombieconfig

ServerOptions: class {

    minPlayers: Int
    loop: Bool
    port: Int

    init: func (config: ZombieConfig) {
        minPlayers = config["minPlayers"] toInt()
        loop = (config["loop"] == "true")
        port = config["port"] toInt()
    }

}

