//
//  PendingTradeDetailsView.swift
//  TopShot Match
//
//  Created by Chase McDermott on 2/20/23.
//

import SwiftUI

struct PendingTradeDetailsView: View {
    var trade: Trade?
    var userMoment: Moment
    var tradeForMoment: Moment
    var tradeProposalAccepted: () -> Void
    var tradeProposalDeclined: () -> Void
    
    var body: some View {
        ScrollView {
            VStack {
                CardView(moment: userMoment, position: 0, positionFromEnd: 0, totalCount: 1)
                    .frame(width: 325, height: 325)
                
                Image(systemName: "rectangle.2.swap")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(
                        .linearGradient(colors: [.mint, .black], startPoint: .top, endPoint: .bottomTrailing),
                        .linearGradient(colors: [.mint, .black], startPoint: .top, endPoint: .bottomTrailing),
                        .linearGradient(colors: [.black, .mint], startPoint: .top, endPoint: .bottomTrailing)
                    )
                    .font(.system(size: 45))
                
                CardView(moment: tradeForMoment, position: 0, positionFromEnd: 0, totalCount: 1)
                    .frame(width: 325, height: 325)
                
                HStack {
                    Button("Accept") {
                        tradeProposalAccepted()
                    }
                    
                    Spacer()
                    
                    Button("Decline", role: .destructive) {
                        tradeProposalDeclined()
                    }
                }.padding()
            }
        }
    }
}

struct PendingTradeDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        PendingTradeDetailsView(trade: TEST_TRADES[0], userMoment: testMoments.first!, tradeForMoment: testMoments[1], tradeProposalAccepted: {}, tradeProposalDeclined: {})
    }
}
