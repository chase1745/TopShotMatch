//
//  PendingTradesView.swift
//  TopShot Match
//
//  Created by Chase McDermott on 2/20/23.
//

import SwiftUI

struct PendingTradesView: View {
    var tradeProposalAccepted: (_ trade: Trade) -> Void
    var tradeProposalDeclined: (_ trade: Trade) -> Void
    
    @Environment(\.presentationMode) var presentationMode
    
    @EnvironmentObject var blockchainViewModel: BlockchainViewModel
    
    var body: some View {
        NavigationStack {
            List(blockchainViewModel.pendingTrades) { trade in
                NavigationLink(value: trade) {
                    Text(trade.leftMoment.name + " - " + trade.rightMoment.name)
                }
            }
            .listStyle(.automatic)
            .navigationDestination(for: Trade.self) { trade in
                PendingTradeDetailsView(
                    trade: trade,
                    userMoment: trade.leftMoment,
                    tradeForMoment: trade.rightMoment,
                    tradeProposalAccepted: {
                        self.presentationMode.wrappedValue.dismiss()
                        tradeProposalAccepted(trade)
                    },
                    tradeProposalDeclined: {
                        self.presentationMode.wrappedValue.dismiss()
                        tradeProposalDeclined(trade)
                    }
                )
            }
            .navigationTitle("Pending Trades")
            .onAppear {
                Task {
                    try await blockchainViewModel.getPendingTrades()
                }
            }
        }
    }
}

struct PendingTradesView_Previews: PreviewProvider {
    static var previews: some View {
        PendingTradesView(tradeProposalAccepted: {trade in }, tradeProposalDeclined: {trade in })
            .environmentObject(BlockchainViewModel())
    }
}
