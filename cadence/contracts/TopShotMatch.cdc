import TopShot from 0xaa3d8fb4584f9b91

// Note that this contract is very insecsure and should not be used on mainnet,
// it is only for a hackathon demo on testnet
pub contract TopShotMatch {

    pub struct MomentIds {
        pub let globalId: UInt64
        pub let playId: UInt32
        pub let address: String

        init(globalId: UInt64, playId: UInt32, address: String) {
            self.globalId = globalId
            self.playId = playId
            self.address = address
        }
    }

    pub struct MomentProposal {
        pub let id: String
        pub let leftMoment: {String: String}
        pub let rightMoment: {String: String}

        init(id: String, leftMoment: {String: String}, rightMoment: {String: String}) {
            self.id = id
            self.leftMoment = leftMoment
            self.rightMoment = rightMoment
        }
    }

    // {address: [nft global ids that the user has added to their trading block]}
    pub var tradingBlock: {String: [MomentIds]}

    // {nft global id: [address of users that have liked the moment]}
    // pub var likedMoments: {UInt32: [Address]} = {}

    // A very naive way of storing which users have liked >= 1 of the other users moments
    pub var likedMomentsRelationship: {String: [String]}

    pub fun updateUserTradingBlock(user: Address, newTradingBlock: [MomentIds]) {
        self.tradingBlock[user.toString()] = newTradingBlock
    }

    pub fun removeMomentFromTradingBlock(owner: Address, id: MomentIds) {
        var indexOf: Int? = nil
        for i, m in self.tradingBlock[owner.toString()] ?? [] {
            if m.globalId == id.globalId && m.playId == id.playId {
                indexOf = i
                break
            }
        }

        if indexOf != nil {
            var moments = self.tradingBlock[owner.toString()]!
            var newMoments = moments.slice(from: 0, upTo: indexOf!).concat(moments.slice(from: indexOf!+1, upTo: moments.length))
            self.tradingBlock[owner.toString()] = newMoments
        }
    }

    pub fun addLikedMoments(user: Address, momentIds: [MomentIds]) {
        // for id in momentIds {
            // if self.likedMoments[id] == nil {
            //     self.likedMoments[id] = [user]
            // } else if !self.likedMoments[id]?.contains(user) {
            //     self.likedMoments[id]?.append(user)
            // }
        // }

        if self.likedMomentsRelationship[user.toString()] == nil {
            self.likedMomentsRelationship[user.toString()] = []
        }

        for momentIdStruct in momentIds {
            let address = momentIdStruct.address
            if !self.likedMomentsRelationship[user.toString()]!.contains(address) {
                self.likedMomentsRelationship[user.toString()]!.append(address)
            }
        }
    }

    pub fun getTradingBlockForUser(user: Address): [MomentIds] {
        return self.tradingBlock[user.toString()] ?? []
    }

    pub fun getGlobalTradingBlockExcludingUser(user: Address): {UInt64: {String: String}} {
        var moments: {UInt64: {String: String}} = {}
        for address in self.tradingBlock.keys {
            if address != user.toString() {
                for momentId in self.tradingBlock[address]! {
                    var metadata = TopShot.getPlayMetaData(playID: momentId.playId)
                    metadata?.insert(key: "playId", momentId.playId.toString())
                    metadata?.insert(key: "owner", address)

                    // If the owner of this moment
                    if self.likedMomentsRelationship[address]?.contains(user.toString()) ?? false {
                        metadata?.insert(key: "userHasLiked", "true")
                    }
                    moments.insert(key: momentId.globalId, metadata!)
                }
            }
        }
        return moments
    }

    pub fun reset() {
        self.likedMomentsRelationship = {}
        self.tradingBlock = {}
    }

    init() {
        self.tradingBlock = {}
        self.likedMomentsRelationship = {}
    }
}