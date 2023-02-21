import TopShotMatch from 0xaa3d8fb4584f9b91

pub fun main(user: Address): {UInt64: {String: String}} {
    return TopShotMatch.getGlobalTradingBlockExcludingUser(user: user)
}