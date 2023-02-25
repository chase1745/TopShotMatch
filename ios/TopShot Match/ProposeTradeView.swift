//
//  TradeView.swift
//  TopShot Match
//
//  Created by Chase McDermott on 2/20/23.
//

import SwiftUI

struct ProposeTradeView: View {
    var likedMoment: Moment
    var tradePropsalSubmitted: (_ leftMoment: Moment, _ rightMoment: Moment) -> Void
    
    @Environment(\.presentationMode) var presentationMode
    
    @EnvironmentObject var blockchainViewModel: BlockchainViewModel
    
    var body: some View {
        NavigationStack {
            List(blockchainViewModel.userMoments) { moment in
                NavigationLink(value: moment) {
                    MomentListDetailView(moment: moment)
                }
            }
            .listStyle(.automatic)
            .navigationDestination(for: Moment.self) { moment in
                ProposeTradeDetailsView(
                    leftMoment: likedMoment,
                    rightMoment: moment,
                    tradeProposalSubmitted: {
                        self.presentationMode.wrappedValue.dismiss()
                        tradePropsalSubmitted(moment, likedMoment)
                    }
                )
            }
            .navigationTitle("Outgoing Moment")
            .onAppear {
                print(likedMoment)
            }
        }
    }
}

struct TradeView_Previews: PreviewProvider {
    static var previews: some View {
        ProposeTradeView(likedMoment: testMoments[0]) { leftMoment,rightMoment in }
        .environmentObject(BlockchainViewModel())
    }
}
