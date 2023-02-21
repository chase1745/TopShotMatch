import TopShotMatch from 0xaa3d8fb4584f9b91

transaction(likedMoments: [{String: String}]) {
    prepare(acct: AuthAccount) {
        var momentIds: [TopShotMatch.MomentIds] = []
        for i, moment in likedMoments {
            momentIds.append(TopShotMatch.MomentIds(
                UInt64.fromString(moment["globalId"]!)!,
                UInt32.fromString(moment["playId"]!)!,
                moment["user"]!
            ))
        }
        TopShotMatch.addLikedMoments(user: acct.address, momentIds: momentIds)
    }
}