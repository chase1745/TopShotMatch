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
    
    init(id: String, leftMoment: Moment, rightMoment: Moment) {
        self.id = id
        self.leftMoment = leftMoment
        self.rightMoment = rightMoment
    }
    
    init(proposal: MomentProposal) {
        self.id = proposal.id
        self.leftMoment = Moment(globalId: Int(proposal.leftMoment["globalId"]!)!, metadata: proposal.leftMoment)
        self.rightMoment = Moment(globalId: Int(proposal.rightMoment["globalId"]!)!, metadata: proposal.rightMoment)
    }
}
