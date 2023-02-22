//
//  BlockchainViewModel.swift
//  TopShot Match
//
//  Created by Chase McDermott on 2/20/23.
//

import SwiftUI
import FCL_SDK
import Cadence
import Combine
import FlowSDK

class BlockchainViewModel: ObservableObject {
    // User's logged in address
    @Published var userAddress: Address?
    @Published var userMoments: [Moment] = []
    @Published var globalTradingBlock: [Moment]? = nil
    @Published var likedMoments: [Moment] = []
    @Published var tradableMoments: [Moment] = []

    @Published var accountSetUp: Bool = false

    @Published var accountSetupLoadingText: String = "Adding a Topshot collection capability to your account..."
    @Published var accountSetupLoading: Bool = false
    @Published var userMomentsLoading: Bool = false
    @Published var feedLoading: Bool = false
    @Published var transactionPending: Bool = false
    @Published var askToSubmitMoments: Bool = false
    @Published var showTradeView: Bool = false
    @Published var askToProposeTrade: Bool = false
    @Published var showProposalSubmitted: Bool = false

    init() {
        let bloctoWalletProvider = try! BloctoWalletProvider(
            bloctoAppIdentifier: "c2c51091-a729-4bc3-8f3d-b3b5771d134b",
            window: nil,
            network: .testnet,
            logging: true
        )

        try! fcl.config
            .put(.network(.testnet))
            .put(.supportedWalletProviders(
                [
                    bloctoWalletProvider,
                ]
            ))
    }

    func userLikedMoment(_ i: Int) {
        likedMoments.append(globalTradingBlock![i])
        let removedMoment = globalTradingBlock?.remove(at: i)

        if likedMoments.count >= 3 && !(removedMoment?.userHasLiked ?? false) {
            askToSubmitMoments = true
        }
        
        if removedMoment?.userHasLiked ?? false {
            askToProposeTrade = true
        }
    }

    func userDislikedMoment(_ i: Int) {
        globalTradingBlock?.remove(at: i)
    }

    // Login with FCL using async/await
    @MainActor
    func login() async throws {
        // add loading
        let user = try await fcl.login()
        withAnimation {
            self.userAddress = user
        }
        self.accountSetUp = try await isAccountSetup()
        
        try await setupAccount()
        
        // check if account is setup, if not, run this
        if !accountSetUp {
            self.accountSetupLoading = true
            try await setupAccount()
            self.accountSetUp = try await isAccountSetup()
            self.accountSetupLoadingText = "Account capability setup! Now minting a few random testnet moments to your account..."

            // mint a few random moments
            let knownPlayIds: Array<Int> = Array(1...15).shuffled()
            try await self.mintMomentToUser(playIds: Array(knownPlayIds[0...3]))
            self.accountSetupLoading = false
        }

        try await getGlobalTradingBlock()
        try await getUserNfts()
    }

    // Logout with FCL using async/await
    @MainActor
    func logout() {
        fcl.logout()
        self.userAddress = nil
        self.userMoments = []
        self.likedMoments = []
        self.globalTradingBlock = nil
    }

    @MainActor
    func isAccountSetup() async throws -> Bool {
        let script = """
        import TopShot from 0xaa3d8fb4584f9b91
        import MetadataViews from 0x631e88ae7f1d7c20
        import NonFungibleToken from 0x631e88ae7f1d7c20

        pub fun main(address: Address): Bool {
            let account = getAccount(address)
            return account
            .getCapability<&{
                NonFungibleToken.CollectionPublic,
                TopShot.MomentCollectionPublic,
                MetadataViews.ResolverCollection
            }>(/public/MomentCollection)
                .check()
        }
        """

        guard let address = userAddress else {
             return false
        }

        let response = try! await sendScript(
            script: script,
            arguments: [Cadence.Argument(.address(address))]
        )

        return try! response.value.toSwiftValue()
    }
    
    @MainActor
    func getOtherUserMoments(user: String) async throws -> Void {
        let script = """
        import NonFungibleToken from 0x631e88ae7f1d7c20
        import TopShot from 0xaa3d8fb4584f9b91
        import MetadataViews from 0x631e88ae7f1d7c20
        
        // return {globalId: metadata}
        pub fun main(account: Address): {UInt64: {String: String}?} {
        
            let acct = getAccount(account)
        
            let collectionRef = acct.getCapability(/public/MomentCollection)
                                .borrow<&{
                                    NonFungibleToken.CollectionPublic,
                                    TopShot.MomentCollectionPublic,
                                    MetadataViews.ResolverCollection
                                }>()!
        
            var moments = collectionRef.borrowMoments()
            var metadatas: {UInt64: {String: String}?} = {}
            for moment in moments {
                var metadata = TopShot.getPlayMetaData(playID: UInt32(moment.data.playID))
                metadata?.insert(key: "playId", moment.data.playID.toString())
                metadata?.insert(key: "owner", account.toString())
                metadatas.insert(key: moment.id, metadata)
            }
            return metadatas
        }
        """
        
        let response = try! await sendScript(
            script: script,
            arguments: [Cadence.Argument(.address(Cadence.Address(hexString: user)))]
        )
        
        let metadatas: [UInt64: [String: String]] = try! response.value.toSwiftValue()

        // filter out bad moments and map to our internal moment model
        let moments = metadatas
            .map { Moment(
                globalId: Int($0),
                metadata: $1
            )}
        
        self.tradableMoments = moments
    }

    @MainActor
    func setupAccount() async throws -> Void {
        let script = """
        import NonFungibleToken from 0x631e88ae7f1d7c20
        import TopShot from 0xaa3d8fb4584f9b91
        import MetadataViews from 0x631e88ae7f1d7c20
        import EMSwap from 0x2a9011074c827145

        transaction {
        
            prepare(acct: AuthAccount) {
                acct.unlink(/public/MomentCollection)
        
                acct.link<&{NonFungibleToken.CollectionPublic, TopShot.MomentCollectionPublic, MetadataViews.ResolverCollection, NonFungibleToken.Receiver, NonFungibleToken.Provider}>(/public/MomentCollection, target: /storage/MomentCollection)
                
                // First, check to see if a moment collection already exists
                if acct.borrow<&TopShot.Collection>(from: /storage/MomentCollection) == nil {
                
                    // create a new TopShot Collection
                    let collection <- TopShot.createEmptyCollection() as! @TopShot.Collection
                
                    // Put the new Collection in storage
                    acct.save(<-collection, to: /storage/MomentCollection)
                
                    // create a public capability for the collection
                    acct.link<&{NonFungibleToken.CollectionPublic, TopShot.MomentCollectionPublic, MetadataViews.ResolverCollection, NonFungibleToken.Receiver, NonFungibleToken.Provider}>(/public/MomentCollection, target: /storage/MomentCollection)
                }
                
                if acct.borrow<&TopShot.Admin>(from: /storage/AdminMintPublic3) == nil {
                    // create a new admin Collection
                    let admin <- TopShot.createAdminCollection() as! @TopShot.Admin
                
                    // Put the new Collection in storage
                    acct.save(<-admin, to: /storage/AdminMintPublic3)
                
                    // create a public capability for the admin
                    acct.link<&{TopShot.AdminMintPublic}>(/public/AdminMintPublic3, target: /storage/AdminMintPublic3)
                }
                
                if acct.borrow<&EMSwap.SwapCollection>(from: EMSwap.SwapCollectionStoragePath) == nil {
                    // create a new Collection
                    let collection <- EMSwap.createEmptySwapCollection() as! @EMSwap.SwapCollection
                
                    // Put the new Collection in storage
                    acct.save(<-collection, to: EMSwap.SwapCollectionStoragePath)
                
                    // create a public capability
                    acct.link<&{EMSwap.SwapCollectionManager, EMSwap.SwapCollectionPublic}>(EMSwap.SwapCollectionPublicPath, target: EMSwap.SwapCollectionStoragePath)
                }
        
                acct.unlink(EMSwap.SwapCollectionPublicPath)
                acct.link<&{EMSwap.SwapCollectionManager, EMSwap.SwapCollectionPublic}>(EMSwap.SwapCollectionPublicPath, target: EMSwap.SwapCollectionStoragePath)
            
            }
        }
        """

        let txHash = try! await sendTx(script: script)
        var status: TransactionStatus = .unknown
        withAnimation {
            transactionPending = true
        }
        while status != .sealed && status != .expired {
            try await Task.sleep(until: .now + .seconds(2), clock: .continuous)

            let tx = try await fcl.getTransactionStatus(transactionId: txHash.description)
            print(tx)
            print(tx.status ?? "UNKNOWN")
            status = tx.status ?? .unknown
        }
        withAnimation {
            transactionPending = false
        }
    }

    @MainActor
    func getUserNfts() async throws -> Void {
        let script = """
        import NonFungibleToken from 0x631e88ae7f1d7c20
        import TopShot from 0xaa3d8fb4584f9b91
        import MetadataViews from 0x631e88ae7f1d7c20

        // return {globalId: metadata}
        pub fun main(account: Address): {UInt64: {String: String}?} {

            let acct = getAccount(account)

            let collectionRef = acct.getCapability(/public/MomentCollection)
                                .borrow<&{
                                    NonFungibleToken.CollectionPublic,
                                    TopShot.MomentCollectionPublic,
                                    MetadataViews.ResolverCollection
                                }>()!

            var moments = collectionRef.borrowMoments()
            var metadatas: {UInt64: {String: String}?} = {}
            for moment in moments {
                var metadata = TopShot.getPlayMetaData(playID: UInt32(moment.data.playID))
                metadata?.insert(key: "playId", moment.data.playID.toString())
                metadatas.insert(key: moment.id, metadata)
            }
            return metadatas
        }
        """

        guard let user = userAddress else {
            return
        }

        self.userMomentsLoading = true
        let response = try! await sendScript(
            script: script,
            arguments: [Cadence.Argument(.address(user))]
        )

        let metadatas: [UInt64: [String: String]] = try! response.value.toSwiftValue()
        let tradingBlockMomentIds = try await getUserTradingBlock()
        // filter out bad moments and map to our internal moment model
        let moments = metadatas
            .map { Moment(
                globalId: Int($0),
                metadata: $1,
                user: user.description,
                onTradingBlock: tradingBlockMomentIds.contains(Int($0)))
            }

        self.userMomentsLoading = false
        self.userMoments = moments
    }

    @MainActor
    func getUserTradingBlock() async throws -> [Int] {
        let script = """
        import TopShotMatch from 0xaa3d8fb4584f9b91

        pub fun main(user: Address): [TopShotMatch.MomentIds] {
            return TopShotMatch.getTradingBlockForUser(user: user)
        }
        """

        guard let address = userAddress else {
            return []
        }

        let response = try! await sendScript(
            script: script,
            arguments: [Cadence.Argument(.address(address))]
        )

        let momentIds: [MomentId] = try! response.value.toSwiftValue()
        return momentIds.map { Int($0.globalId) }
    }

    @MainActor
    func mintMomentToUser(playIds: Array<Int>) async throws -> Void {
        let script = """
        import TopShot from 0xaa3d8fb4584f9b91
        import MetadataViews from 0x631e88ae7f1d7c20
        import NonFungibleToken from 0x631e88ae7f1d7c20

        transaction(setID: UInt32, playIDs: [UInt32], quantity: UInt64, recipientAddr: Address) {

            // Local variable for the topshot Admin object
            let adminRef: &TopShot.Admin

            prepare(acct: AuthAccount) {
                // borrow a reference to the Admin resource in storage
                self.adminRef = acct.borrow<&TopShot.Admin>(from: /storage/AdminMintPublic3)!
            }

            execute {
                let setRef = self.adminRef.borrowSet(setID: setID)

                // Get the account object for the recipient of the minted tokens
                let recipient = getAccount(recipientAddr)

                // get the Collection reference for the receiver
                let receiverRef = recipient.getCapability(/public/MomentCollection).borrow<&{NonFungibleToken.CollectionPublic, TopShot.MomentCollectionPublic, MetadataViews.ResolverCollection}>()
                    ?? panic("Cannot borrow a reference to the recipient's collection")

                // Mint all the new NFTs
                for id in playIDs {
                    let collection <- setRef.batchMintMoment(playID: id, quantity: quantity)

                    // deposit the NFT in the receivers collection
                    receiverRef.batchDeposit(tokens: <-collection)
                }
            }
        }
        """

        guard let user = userAddress else {
            return
        }

        let setId: UInt32 = 1
        let quantity: UInt64 = 1

        let txHash = try! await sendTx(
            script: script,
            arguments: [.uint32(setId), .array(playIds.map { .uint32(UInt32($0)) }), .uint64(quantity), .address(user)]
        )

        var status: TransactionStatus = .unknown
        withAnimation {
            transactionPending = true
        }
        while status != .sealed && status != .expired {
            try await Task.sleep(until: .now + .seconds(2), clock: .continuous)

            let tx = try await fcl.getTransactionStatus(transactionId: txHash.description)
            print(tx)
            status = tx.status ?? .unknown
        }
        withAnimation {
            transactionPending = false
        }
    }

    @MainActor
    func updateTradingBlock(newTradingBlock: [Moment]) async throws -> Void {
        let script = """
        import TopShotMatch from 0xaa3d8fb4584f9b91
        
        transaction(newTradingBlock: [{String: String}]) {
            prepare(acct: AuthAccount) {
                var momentIds: [TopShotMatch.MomentIds] = []
                for i, block in newTradingBlock {
                    momentIds.append(TopShotMatch.MomentIds(
                        UInt64.fromString(block["globalId"]!)!,
                        UInt32.fromString(block["playId"]!)!,
                        block["user"]!
                    ))
                }
                TopShotMatch.updateUserTradingBlock(user: acct.address, newTradingBlock: momentIds)
            }
        }
        """
        let args: [Cadence.Argument] = [
            .array(newTradingBlock.map { return .dictionary(
                Dictionary(key: .string("globalId"), value: .string(String($0.globalId))),
                Dictionary(key: .string("playId"), value: .string(String($0.playId))),
                Dictionary(key: .string("user"), value: .string(String($0.user)))
            ) } )
        ]

        let txHash = try! await sendTx(script: script, arguments: args)
        var status: TransactionStatus = .unknown
        withAnimation {
            transactionPending = true
        }
        while status != .sealed && status != .expired {
            try await Task.sleep(until: .now + .seconds(2), clock: .continuous)

            let tx = try await fcl.getTransactionStatus(transactionId: txHash.description)
            print(tx)
            print(tx.status ?? "UNKNOWN")
            status = tx.status ?? .unknown
        }
        withAnimation {
            transactionPending = false
        }

        // re-fetch moments
        try await getUserNfts()
    }

    @MainActor
    func getGlobalTradingBlock() async throws -> Void {
        let script = """
        import TopShotMatch from 0xaa3d8fb4584f9b91

        pub fun main(user: Address): {UInt64: {String: String}} {
            return TopShotMatch.getGlobalTradingBlockExcludingUser(user: user)
        }
        """

        guard let address = userAddress else {
            return
        }

        withAnimation {
            feedLoading = true
        }
        let response = try! await sendScript(
            script: script,
            arguments: [Cadence.Argument(.address(address))]
        )

        let metadatas: [UInt64: [String: String]] = try! response.value.toSwiftValue()
        print("got reponse")
        print(metadatas)

        withAnimation {
            self.globalTradingBlock = metadatas
                .map { Moment(
                    globalId: Int($0),
                    metadata: $1
                )}

            feedLoading = false
        }
    }

    @MainActor
    func submitLikedMoments() async throws -> Void {
        let script = """
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
        """
        let args: [Cadence.Argument] = [
            .array(likedMoments.map { return .dictionary(
                Dictionary(key: .string("globalId"), value: .string(String($0.globalId))),
                Dictionary(key: .string("playId"), value: .string(String($0.playId))),
                Dictionary(key: .string("user"), value: .string($0.user))
            ) } )
        ]

        let txHash = try! await sendTx(script: script, arguments: args)
        var status: TransactionStatus = .unknown
        withAnimation {
            transactionPending = true
        }
        while status != .sealed && status != .expired {
            try await Task.sleep(until: .now + .seconds(2), clock: .continuous)

            let tx = try await fcl.getTransactionStatus(transactionId: txHash.description)
            print(tx)
            print(tx.status ?? "UNKNOWN")
            status = tx.status ?? .unknown
        }
        withAnimation {
            transactionPending = false
        }

        likedMoments.removeAll()
    }
    
    @MainActor
    func getPendingTrades() async throws -> Void {
        let script = """
        
        """
        
        guard let address = userAddress else {
            return
        }
        
//        let response = try! await sendScript(
//            script: script,
//            arguments: [Cadence.Argument(.address(address))]
//        )
        
//        let metadatas: [UInt64: [String: String]] = try! response.value.toSwiftValue()
    }
    
    @MainActor
    func submitTradeAcceptance(tradeId: String) async throws -> Void {
        let script = """
        
        """
        // TODO: remove
        return
        
        guard let address = userAddress else {
            return
        }
        
//        let args: [Cadence.Argument] = [
//            Cadence.Argument(.uint64(UInt64(userMoment.globalId))),
//            Cadence.Argument(.uint64(UInt64(otherUserMoment.globalId))),
//            Cadence.Argument(.address(Cadence.Address(hexString: otherUserMoment.user))),
//        ]
//        
//        let txHash = try! await sendTx(script: script, arguments: args)
//        var status: TransactionStatus = .unknown
//        withAnimation {
//            transactionPending = true
//        }
//        while status != .sealed && status != .expired {
//            try await Task.sleep(until: .now + .seconds(2), clock: .continuous)
//            
//            let tx = try await fcl.getTransactionStatus(transactionId: txHash.description)
//            print(tx)
//            print(tx.status ?? "UNKNOWN")
//            status = tx.status ?? .unknown
//        }
//        withAnimation {
//            transactionPending = false
//            showProposalSubmitted = true
//        }
//        
//        // re-fetch moments
//        try await getUserNfts()
    }
    
    @MainActor
    func submitTradeProposal(userMoment: Moment, otherUserMoment: Moment) async throws -> Void {
        let script = """
        
        """
        // TODO: remove
        return
        
        guard let address = userAddress else {
            return
        }
        
        let args: [Cadence.Argument] = [
            Cadence.Argument(.uint64(UInt64(userMoment.globalId))),
            Cadence.Argument(.uint64(UInt64(otherUserMoment.globalId))),
            Cadence.Argument(.address(Cadence.Address(hexString: otherUserMoment.user))),
        ]
        
        let txHash = try! await sendTx(script: script, arguments: args)
        var status: TransactionStatus = .unknown
        withAnimation {
            transactionPending = true
        }
        while status != .sealed && status != .expired {
            try await Task.sleep(until: .now + .seconds(2), clock: .continuous)
            
            let tx = try await fcl.getTransactionStatus(transactionId: txHash.description)
            print(tx)
            print(tx.status ?? "UNKNOWN")
            status = tx.status ?? .unknown
        }
        withAnimation {
            transactionPending = false
            showProposalSubmitted = true
        }
        
        // re-fetch moments
        try await getUserNfts()
    }

    // Send a Cadence script query to the blockchain using async/await
    @MainActor
    private func sendScript(script: String, arguments: [Cadence.Argument] = []) async throws -> Cadence.Argument {
        return try await fcl.query(script: script, arguments: arguments)
    }

    @MainActor
    private func sendTx(script: String, arguments: [Cadence.Argument] = []) async throws -> Identifier {
        return try await fcl.mutate(
            cadence: script,
            arguments: arguments,
            limit: 100,
            authorizers: [userAddress!]
        )
    }
}
