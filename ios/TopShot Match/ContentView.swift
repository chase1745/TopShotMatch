//
//  ContentView.swift
//  TopShot Match
//
//  Created by Chase McDermott on 2/20/23.
//

import SwiftUI
import FCL_SDK

struct ContentView: View {
    @Environment(\.colorScheme) var colorScheme
    
    static let userActivity = "com.topshotmatch.chasemcdermott"
    
    @EnvironmentObject var blockchainViewModel: BlockchainViewModel
    
    @State private var pendingTrades: [Trade] = TEST_TRADES
    @State private var showTradeView: Bool = false
    @State private var showTradingBlockView: Bool = false
    @State private var showPendingTradesView: Bool = false
    
    var accountInfo: some View {
        VStack {
            Label(blockchainViewModel.userAddress?.description ?? "", systemImage: "person.fill")
                .font(.subheadline)
                .padding()
                .foregroundColor(.black)
                .background(Color(
                    red: 6/255,
                    green: 239/255,
                    blue: 139/255).gradient)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.gray.gradient, lineWidth: 2)
                        .shadow(radius: 10)
                )
                .padding(.leading)
                .onTapGesture {
                    withAnimation {
                        blockchainViewModel.logout()
                    }
                }
        }
    }
    
    var loginView: some View {
        Button(action: {
            Task {
                try await blockchainViewModel.login()
            }
        }) {
            Text("Login")
        }
        .font(.title2)
        .padding()
    }
    
    var headers: some View {
        HStack {
            if blockchainViewModel.userAddress != nil {
                accountInfo
            } else {
                loginView
            }
            
            Spacer()
            
            Button(action: {
                showTradingBlockView.toggle()
            }) {
                Image(systemName: "plus.circle")
            }
            .disabled(blockchainViewModel.userAddress == nil)
            .font(.title2)
            .padding()
            
            Button(action: {
                blockchainViewModel.askToSubmitMoments.toggle()
            }) {
                Image(systemName: "heart.circle")
            }
            .disabled(blockchainViewModel.userAddress == nil)
            .font(.title2)
            
            Button(action: {
                showPendingTradesView.toggle()
            }) {
                Image(systemName: pendingTrades.isEmpty ? "bell.fill" : "bell.badge.fill")
            }
            .disabled(blockchainViewModel.userAddress == nil)
            .font(.title2)
            .padding()
        }
    }
    
    var body: some View {
        VStack {
            headers
            
            if blockchainViewModel.globalTradingBlock == nil {
                VStack {
                    Spacer()
                    Text("Login above to load some moments to trade.")
                        .font(.headline)
                        .padding()
                    Text("Don't worry, this is connected to testnet with fake Moments.")
                        .font(.subheadline)
                    Spacer()
                    Spacer()
                    Spacer()
                }
            } else if blockchainViewModel.feedLoading {
                Text("Loading other users trading blocks for you to like/dislike.")
            } else if blockchainViewModel.globalTradingBlock?.isEmpty ?? false {
                VStack {
                    Spacer()
                    Text("You've gone through all the moments on the trading block.")
                        .font(.headline)
                        .padding()
                    Spacer()
                    Spacer()
                    Spacer()
                }
            }
            
            ZStack {
                ForEach(Array(((blockchainViewModel.globalTradingBlock ?? []).enumerated())), id: \.1) { i, moment in
                    CardView(
                        moment: moment,
                        position: i,
                        positionFromEnd: (blockchainViewModel.globalTradingBlock?.count ?? 0)-i-1,
                        totalCount: blockchainViewModel.globalTradingBlock?.count ?? 0,
                        movable: true, removal: { direction in
                            withAnimation {
                                swipeMoment(at: i, direction)
                            }
                        })
                    .transition(.move(edge: .top))
                }
            }.padding(.top)
            
            Spacer()
            
            if blockchainViewModel.transactionPending {
                Text("Waiting on pending transaction...")
                    .padding()
                    .cornerRadius(5)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color(
                                red: 6/255,
                                green: 239/255,
                                blue: 139/255), lineWidth: 3)
                            .shadow(radius: 0.3)
                    )
                    .transition(.push(from: .leading))
            }
            
            HStack {
                Text("Built on")
                Image(colorScheme == .dark ? "flow-dark" : "flow-light").resizable()
                    .scaledToFit()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 100.0)
            }
        }.onChange(of: blockchainViewModel.likedMoments) { newValue in
            onLikedMomentsChange(newValue)
        }.popover(isPresented: $blockchainViewModel.showTradeView) {
            ProposeTradeView(likedMoment: blockchainViewModel.likedMoments.last!, tradePropsalSubmitted: tradePropsalSubmitted)
        }
        .popover(isPresented: $showTradingBlockView) {
            TradingBlockView(userMoments: blockchainViewModel.userMoments,
                             isLoading: blockchainViewModel.userMomentsLoading,
                             tradingBlockChanged: tradingBlockChanged)
                .presentationDetents([.large])
        }
        .popover(isPresented: $showPendingTradesView) {
            PendingTradesView(tradeProposalAccepted: tradePropsalAccepted,
                              tradeProposalDeclined: tradePropsalDeclined)
        }
        .popover(isPresented: $blockchainViewModel.accountSetupLoading) {
            VStack {
                Text("Setting up your account on Testnet. This may take a few seconds.")
                    .font(.title3)
                    .padding()
                Text(self.blockchainViewModel.accountSetupLoadingText)
                    .font(.title3)
                    .padding()
            }
        }
        .alert(
            "Would you like to submit your liked moments to the blockchain?",
            isPresented: $blockchainViewModel.askToSubmitMoments,
            actions: {
                Button("Submit", action: {
                    Task {
                        try await blockchainViewModel.submitLikedMoments()
                    }
                })
                Button("Cancel", role: .cancel, action: {
                    blockchainViewModel.askToSubmitMoments = false
                })
        }, message: {
                Text("You've liked a few moments. Since liked moments are stored on-chain, they needs to be periodically submitted in a trasaction. This is so when these moments owners likes one of your moments, they're prompted to propose a trade.")
        })
        .alert(
            "It's a match!",
            isPresented: $blockchainViewModel.askToProposeTrade,
            actions: {
                Button("Yes!", action: {
                    blockchainViewModel.showTradeView.toggle()
                })
                Button("No thanks", role: .cancel, action: {
                    blockchainViewModel.askToProposeTrade = false
                })
        }, message: {
                Text("Would you like to propose a trade? The owner of this moment also liked one of your moments.")
        })
        .alert(
            "Proposal submitted!",
            isPresented: $blockchainViewModel.showProposalSubmitted,
            actions: {
                Button("Close", role: .cancel, action: {
                    blockchainViewModel.showProposalSubmitted = false
                })
            }, message: {
                Text("Now just wait for the other user to accept or decline.")
            })
    }
    
    func swipeMoment(at index: Int, _ direction: Direction) {
        if (direction == .left) {
            swipeLeft(index: index)
        } else {
            swipeRight(index: index)
        }
    }
    
    func swipeRight(index: Int) {
        withAnimation(.spring(dampingFraction: 0.45)) {
            hapticSwipe()
            blockchainViewModel.userLikedMoment(index)
        }
    }
    
    func swipeLeft(index: Int) {
        hapticSwipe()
        blockchainViewModel.userDislikedMoment(index)
    }
    
    func hapticSwipe() {
        let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
        impactHeavy.impactOccurred()
    }
    
    func onLikedMomentsChange(_ newMoments: [Moment]) {
        if newMoments.last?.userHasLiked ?? false {
            showTradeView.toggle()
        }
    }
    
    func tradingBlockChanged(_ newTradingBlock: Set<String>, _ allMoments: [Moment]) {
        Task {
            try await blockchainViewModel.updateTradingBlock(
                newTradingBlock: allMoments.filter {
                    newTradingBlock.contains(String($0.globalId))
                }
            )
        }
    }
    
    func tradePropsalSubmitted(userMoment: Moment, tradeForMoment: Moment) {
        Task {
            try await blockchainViewModel.submitTradeProposal(
                userMoment: userMoment, otherUserMoment: tradeForMoment
            )
        }
    }
    
    func tradePropsalAccepted(trade: Trade) {
        Task {
            try await blockchainViewModel.submitTradeAcceptance(trade: trade)
        }
    }
    
    func tradePropsalDeclined(trade: Trade) {
        print("Proposal declined")
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(BlockchainViewModel())
    }
}
