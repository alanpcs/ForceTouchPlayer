import Foundation

struct SongsRepository {
    private var songs: [Song] = [
        twinkleTwinkleLittleStar
    ]
    
    func listSongs() -> [Song] {
        return songs
    }
}