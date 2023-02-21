//
//  TopShot_MatchApp.swift
//  TopShot Match
//
//  Created by Chase McDermott on 2/20/23.
//

import SwiftUI
import FCL_SDK

@main
struct TopShot_MatchApp: App {
    @ObservedObject var blockchainViewModel: BlockchainViewModel = BlockchainViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(blockchainViewModel)
                .onOpenURL { url in
                    print("*****", url)
                    fcl.application(open: url)
                }
                .onContinueUserActivity(ContentView.userActivity) { userActivity in
                    fcl.continueForLinks(userActivity)
                }
        }
    }
}
