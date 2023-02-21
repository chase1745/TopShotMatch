//
//  Trade.swift
//  TopShot Match
//
//  Created by Chase McDermott on 2/20/23.
//

import Foundation

let TEST_TRADES = [
    Trade(id: "123", leftMoment: testMoments[0], rightMoment: testMoments[1]),
    Trade(id: "432", leftMoment: testMoments[2], rightMoment: testMoments[3])
]

struct Trade: Identifiable, Hashable {
    var id: String

    var leftMoment: Moment
    var rightMoment: Moment
}
