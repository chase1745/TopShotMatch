import TopShotMatch from 0xaa3d8fb4584f9b91

transaction(newTradingBlock: [{String: String}]) {
    prepare(acct: AuthAccount) {
        var momentIds: [TopShotMatch.MomentIds] = []
        for i, block in newTradingBlock {
            momentIds.append(TopShotMatch.MomentIds(
                UInt64.fromString(block["globalId"]!)!,
                UInt32.fromString(block["playId"]!)!,
                block["user"]!
            ))
        }
        TopShotMatch.updateUserTradingBlock(user: acct.address, newTradingBlock: momentIds)
    }
}