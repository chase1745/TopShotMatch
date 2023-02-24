//
//  Moment.swift
//  TopShot Match
//
//  Created by Chase McDermott on 2/20/23.
//

import Foundation

let testMoments: [Moment] = [
    Moment(id: "12313", name: "Kevin Durant", team: "Phoenix Suns", rarity: "Rare", edition: "Base Set (Series 2)", user: "chase1745", serial: "4304/20000", img: URL(string: "https://assets.nbatopshot.com/media/12/transparent?quality=25&width=600"), userHasLiked: false, onTradingBlock: false),
    Moment(id: "9090", name: "Luka Doncic", team: "Dallas Mavericks", rarity: "Legendary", edition: "Base Set (Series 1)", user: "memoore", serial: "10/1000", img: URL(string: "https://assets.nbatopshot.com/media/1337/transparent?quality=25&width=600"), userHasLiked: false, onTradingBlock: true),
    Moment(id: "123132", name: "Kevin Durant", team: "Phoenix Suns", rarity: "Rare", edition: "Base Set (Series 2)", user: "chase1745", serial: "4304/20000", img: URL(string: "https://assets.nbatopshot.com/media/12/transparent?quality=25&width=600"), userHasLiked: false, onTradingBlock: false),
    Moment(id: "90902", name: "Kyrie Irving", team: "Dallas Mavericks", rarity: "Legendary", edition: "Base Set (Series 1)", user: "memoore", serial: "10/1000", img: URL(string: "https://assets.nbatopshot.com/media/12/transparent?quality=25&width=600"), userHasLiked: false, onTradingBlock: false),
    Moment(id: "412313", name: "Kevin Durant", team: "Phoenix Suns", rarity: "Rare", edition: "Base Set (Series 2)", user: "chase1745", serial: "4304/20000", img: URL(string: "https://assets.nbatopshot.com/media/12/transparent?quality=25&width=600"), userHasLiked: true, onTradingBlock: true),
    Moment(id: "90590", name: "Kyrie Irving", team: "Dallas Mavericks", rarity: "Legendary", edition: "Base Set (Series 1)", user: "memoore", serial: "10/1000", img: URL(string: "https://assets.nbatopshot.com/media/12/transparent?quality=25&width=600"), userHasLiked: false, onTradingBlock: false),
    Moment(id: "123173", name: "Kevin Durant", team: "Phoenix Suns", rarity: "Rare", edition: "Base Set (Series 2)", user: "chase1745", serial: "4304/20000", img: URL(string: "https://assets.nbatopshot.com/media/12/transparent?quality=25&width=600"), userHasLiked: true, onTradingBlock: false),
    Moment(id: "90390", name: "Kyrie Irving", team: "Dallas Mavericks", rarity: "Legendary", edition: "Base Set (Series 1)", user: "memoore", serial: "10/1000", img: URL(string: "https://assets.nbatopshot.com/media/12/transparent?quality=25&width=600"), userHasLiked: true, onTradingBlock: false)
]

let imgUrlStr = "https://assets.nbatopshot.com/media/{ID}/transparent?quality=25&width=600"

struct Moment: Identifiable, Equatable, Hashable {
    var globalId: Int
    var id: String
    var imgId: String
    var playId: String
    var name: String
    var team: String
    var rarity: String
    var edition: String
    var user: String
    var serial: String
    var img: URL?
    var video: URL?
    
    var userHasLiked: Bool = false
    var onTradingBlock: Bool = false
    
    init(globalId: Int, metadata: [String: String], user: String? = nil, userHasLiked: Bool = false, onTradingBlock: Bool = false) {
        self.globalId = globalId
        self.id = String(globalId)
        self.user = user ?? metadata["owner"]!
        self.playId = metadata["playId"]!
        self.imgId = metadata["id"]!
        self.name = metadata["name"]!
        self.team = metadata["team"]!
        self.rarity = metadata["tier"]!
        self.edition = metadata["series"]!
        self.serial = metadata["serial"]!
        self.img = URL(string: imgUrlStr.replacingOccurrences(of: "{ID}", with: self.imgId))
        self.userHasLiked = Bool(metadata["userHasLiked"] ?? "false")!
        self.onTradingBlock = onTradingBlock
    }
    
    init(id: String, name: String, team: String, rarity: String, edition: String, user: String, serial: String, img: URL?, userHasLiked: Bool?, onTradingBlock: Bool?) {
        self.globalId = Int(id)!
        self.imgId = id
        self.id = id
        self.playId = id
        self.name = name
        self.team = team
        self.rarity = rarity
        self.edition = edition
        self.user = user
        self.serial = serial
        self.img = img
        self.userHasLiked = userHasLiked ?? false
        self.onTradingBlock = onTradingBlock ?? false
    }
    
    mutating func setUserHasLiked(_ value: Bool) {
        self.userHasLiked = value
    }
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.globalId == rhs.globalId
    }
}
