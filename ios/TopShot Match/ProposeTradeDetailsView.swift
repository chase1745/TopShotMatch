//
//  TradeDetailsView.swift
//  TopShot Match
//
//  Created by Chase McDermott on 2/20/23.
//

import SwiftUI

struct ProposeTradeDetailsView: View {
    var leftMoment: Moment
    var rightMoment: Moment
    var tradeProposalSubmitted: () -> Void
    
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        PendingTradeDetailsView(
            trade: nil,
            userMoment: leftMoment,
            tradeForMoment: rightMoment,
            tradeProposalAccepted: tradeProposalSubmitted,
            tradeProposalDeclined: {
                self.presentationMode.wrappedValue.dismiss()
            })
    }
}

struct TradeDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        ProposeTradeDetailsView(leftMoment: testMoments[0], rightMoment: testMoments[1]) { }
    }
}
