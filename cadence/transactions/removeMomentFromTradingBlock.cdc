import TopShotMatch from 0xaa3d8fb4584f9b91

transaction(moment: {String: String}) {
    prepare(acct: AuthAccount) {
        var momentId: TopShotMatch.MomentIds = TopShotMatch.MomentIds(
            UInt64.fromString(moment["globalId"]!)!,
            UInt32.fromString(moment["playId"]!)!,
            moment["user"]!
        )
        TopShotMatch.removeMomentFromTradingBlock(owner: acct.address, id: momentId)
    }
}