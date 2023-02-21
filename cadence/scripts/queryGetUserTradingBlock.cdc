import TopShotMatch from 0xaa3d8fb4584f9b91

pub fun main(user: Address): [TopShotMatch.MomentIds] {
    return TopShotMatch.getTradingBlockForUser(user: user)
}