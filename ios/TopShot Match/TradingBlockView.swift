//
//  TradingBlockView.swift
//  TopShot Match
//
//  Created by Chase McDermott on 2/20/23.
//

import SwiftUI

struct TradingBlockView: View {
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>

    var moments: [Moment]
    var tradingBlockChanged: (_ newTradingBlock: Set<String>, _ allMoments: [Moment]) -> Void
    var isLoading: Bool
    
    @State var selectedMoments: Set<String>
    
    init(
        userMoments: [Moment] = testMoments,
        isLoading: Bool,
        tradingBlockChanged: @escaping (_ newTradingBlock: Set<String>, _ allMoments: [Moment]) -> Void
    ) {
        self.moments = userMoments
        self.tradingBlockChanged = tradingBlockChanged
        self.isLoading = isLoading
        
        let momentsOnTradingBlock: Set<String> = Set(moments.filter { moment in
            return moment.onTradingBlock
        }.map { String($0.globalId) })
        _selectedMoments = State(initialValue: momentsOnTradingBlock)
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    Text("Loading...")
                }
                HStack {
                    Spacer()
                    Button(action: {
                        tradingBlockChanged(selectedMoments, moments)
                        self.presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("Done")
                        .font(.title2)
                    }.padding(.trailing)
                }
                
                List(moments, selection: $selectedMoments) { moment in
                    MomentListDetailView(moment: moment)
                }.listStyle(.plain)
                Text("\(selectedMoments.count) selections")
            }
            .navigationTitle("Trading Block")
            .environment(\.editMode, Binding.constant(EditMode.active))
        }
    }
}

struct TradingBlockView_Previews: PreviewProvider {
    static var previews: some View {
        TradingBlockView(userMoments: testMoments, isLoading: false) {_,_ in}
    }
}

