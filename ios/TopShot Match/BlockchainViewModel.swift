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
    @Published var originalGlobalTradingBlock: [Moment]? = nil
    @Published var likedMoments: [Moment] = []
    @Published var pendingTrades: [Trade] = []
    
//    @Published var tradableMoments: [Moment] = []

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
        self.originalGlobalTradingBlock = nil
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

    // TODO: I don't think this function is needed... can probs remove
//    @MainActor
//    func getOtherUserMoments(user: String) async throws -> Void {
//        let script = """
//        import NonFungibleToken from 0x631e88ae7f1d7c20
//        import TopShot from 0xaa3d8fb4584f9b91
//        import MetadataViews from 0x631e88ae7f1d7c20
//
//        // return {globalId: metadata}
//        pub fun main(account: Address): {UInt64: {String: String}?} {
//
//            let acct = getAccount(account)
//
//            let collectionRef = acct.getCapability(/public/MomentCollection)
//                                .borrow<&{
//                                    NonFungibleToken.CollectionPublic,
//                                    TopShot.MomentCollectionPublic,
//                                    MetadataViews.ResolverCollection
//                                }>()!
//
//            var moments = collectionRef.borrowMoments()
//            var metadatas: {UInt64: {String: String}?} = {}
//            for moment in moments {
//                var metadata = TopShot.getPlayMetaData(playID: UInt32(moment.data.playID))
//                metadata?.insert(key: "playId", moment.data.playID.toString())
//                metadata?.insert(key: "owner", account.toString())
//                metadatas.insert(key: moment.id, metadata)
//            }
//            return metadatas
//        }
//        """
//
//        let response = try! await sendScript(
//            script: script,
//            arguments: [Cadence.Argument(.address(Cadence.Address(hexString: user)))]
//        )
//
//        let metadatas: [UInt64: [String: String]] = try! response.value.toSwiftValue()
//
//        // filter out bad moments and map to our internal moment model
//        let moments = metadatas
//            .map { Moment(
//                globalId: Int($0),
//                metadata: $1
//            )}
//
//        self.tradableMoments = moments
//    }

    @MainActor
    func setupAccount() async throws -> Void {
        let script = """
        import NonFungibleToken from 0x631e88ae7f1d7c20
        import TopShot from 0xaa3d8fb4584f9b91
        import MetadataViews from 0x631e88ae7f1d7c20
        import EMSwap from 0xaa3d8fb4584f9b91
        
        // This transaction sets up an account to use Top Shot
        // by storing an empty moment collection and creating
        // a public capability for it
        transaction {
        
            prepare(acct: AuthAccount) {
            
                // First, check to see if a moment collection already exists
                if acct.borrow<&TopShot.Collection>(from: /storage/MomentCollection) == nil {
                    // create a new TopShot Collection
                    let collection <- TopShot.createEmptyCollection() as! @TopShot.Collection
                
                    // Put the new Collection in storage
                    acct.save(<-collection, to: /storage/MomentCollection)
                
                    // create a public capability for the collection
                    acct.link<&{NonFungibleToken.CollectionPublic, TopShot.MomentCollectionPublic, MetadataViews.ResolverCollection}>(/public/MomentCollection, target: /storage/MomentCollection)
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
                    acct.link<&{EMSwap.SwapCollectionPublic, EMSwap.SwapCollectionManager}>(EMSwap.SwapCollectionPublicPath, target: EMSwap.SwapCollectionStoragePath)
                    // create a private capability
                    acct.link<&{EMSwap.SwapCollectionManager}>(EMSwap.SwapCollectionPrivatePath, target: EMSwap.SwapCollectionStoragePath)
                }
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
        
        let userTradingBlock = userMoments.filter { $0.onTradingBlock }
        // block hasn't changed, return early
        if newTradingBlock == userTradingBlock {
            return
        }
        
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

        withAnimation {
            self.globalTradingBlock = metadatas
                .map { Moment(
                    globalId: Int($0),
                    metadata: $1
                )}
            self.originalGlobalTradingBlock = globalTradingBlock

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
        import EMSwap from 0xaa3d8fb4584f9b91
        import TopShotMatch from 0xaa3d8fb4584f9b91
        import NonFungibleToken from 0x631e88ae7f1d7c20
        import TopShot from 0xaa3d8fb4584f9b91
        import MetadataViews from 0x631e88ae7f1d7c20
        
        pub fun main(user: Address, otherUsers: [Address]): [TopShotMatch.MomentProposal] {
            let acct = getAccount(user)
            var relatedProposals: {String: [EMSwap.UserOffer]} = {}
            
            for otherUser in otherUsers {
            let otherUserAcct = getAccount(otherUser)
            let swapCollection = otherUserAcct.getCapability<&{EMSwap.SwapCollectionPublic, EMSwap.SwapCollectionManager}>(EMSwap.SwapCollectionPublicPath).borrow() ?? panic("Cannot get swap collection from other user")
            
            let proposals = swapCollection.getAllProposals()
            for proposalId in proposals.keys {
                let proposal = proposals[proposalId]!
                if proposal.rightUserAddress == user.toString() {
                    let leftOffer = swapCollection.getUserOffer(proposalId: proposal.id, leftOrRight: "left")
                    let rightOffer = swapCollection.getUserOffer(proposalId: proposal.id, leftOrRight: "right")
                    relatedProposals.insert(key: proposal.id, [leftOffer, rightOffer])
                }
            }
            }
            
            
            var momentProposals: [TopShotMatch.MomentProposal] = []
            // This assumes there is exactly one moment in each offer
            for proposalId in relatedProposals.keys {
                let leftOffer = relatedProposals[proposalId]![0]!
                let rightOffer = relatedProposals[proposalId]![1]!
                
                // Get left moment
                let leftAccount = getAccount(leftOffer.userAddress)
                
                let leftCollection = leftAccount.getCapability(/public/MomentCollection)
                                        .borrow<&{
                                            NonFungibleToken.CollectionPublic,
                                            TopShot.MomentCollectionPublic,
                                            MetadataViews.ResolverCollection
                                        }>()!
                
                var leftMoment = leftCollection.borrowMoment(
                    id: leftOffer.proposedNfts[0]!.nftID
                )
                // If we can't find the moment, its probably already executed, just continue
                if leftMoment == nil {
                    continue
                }
                
                var leftMetadata: {String: String} = TopShot.getPlayMetaData(playID: UInt32(leftMoment!.data.playID))!
                leftMetadata.insert(key: "playId", leftMoment!.data.playID.toString())
                leftMetadata.insert(key: "owner", leftOffer.userAddress.toString())
                leftMetadata.insert(key: "globalId", leftOffer.proposedNfts[0]!.nftID.toString())
                
                // Get right moment
                let rightAccount = getAccount(rightOffer.userAddress)
                
                let rightCollection = rightAccount.getCapability(/public/MomentCollection)
                                        .borrow<&{
                                            NonFungibleToken.CollectionPublic,
                                            TopShot.MomentCollectionPublic,
                                            MetadataViews.ResolverCollection
                                        }>()!
                
                var rightMoment = rightCollection.borrowMoment(
                    id: rightOffer.proposedNfts[0]!.nftID
                )
                if rightMoment == nil {
                    continue
                }
                var rightMetadata: {String: String} = TopShot.getPlayMetaData(
                    playID: UInt32(rightMoment!.data.playID)
                )!
                rightMetadata.insert(key: "playId", rightMoment!.data.playID.toString())
                rightMetadata.insert(key: "owner", rightOffer.userAddress.toString())
                rightMetadata.insert(key: "globalId", rightOffer.proposedNfts[0]!.nftID.toString())
                
                momentProposals.append(TopShotMatch.MomentProposal(
                    id: proposalId,
                    leftMoment: leftMetadata,
                    rightMoment: rightMetadata
                ))
            }
            
            return momentProposals
        }
        """

        guard let user = userAddress else {
            return
        }

        let args: [Cadence.Argument] = [
            Cadence.Argument(.address(Cadence.Address(hexString: user.description))),
            Cadence.Argument(.array(
                Array(Set(originalGlobalTradingBlock!))
//                    .filter { $0.userHasLiked == true }
                    .map {
                        return Cadence.Argument(.address(Cadence.Address(hexString: $0.user)))
                    }
            ))
        ]

        let response = try! await sendScript(
            script: script,
            arguments: args
        )

        let proposals: [MomentProposal] = try! response.value.toSwiftValue()
        pendingTrades = proposals.map { Trade(proposal: $0)}
    }

    @MainActor
    func submitTradeAcceptance(trade: Trade) async throws -> Void {
        let script = """
        import EMSwap from 0xaa3d8fb4584f9b91
        import TopShotMatch from 0xaa3d8fb4584f9b91
        import NonFungibleToken from 0x631e88ae7f1d7c20
        import TopShot from 0xaa3d8fb4584f9b91
        import MetadataViews from 0x631e88ae7f1d7c20
        
        transaction(leftUserAddress: Address, proposalId: String, leftUserMoment: {String: String}, rightUserMoment: {String: String}) {
        
            let rightUserReceiverCapabilities: {String: Capability<&{NonFungibleToken.Receiver}>}
            let rightUserProviderCapabilities: {String: Capability<&{NonFungibleToken.Provider}>}
            let leftUserSwapCollection: &AnyResource{EMSwap.SwapCollectionPublic}
            let rightUserAddress: Address
            
            prepare(signer: AuthAccount) {
            
            let missingProviderMessage: String = "Missing or invalid provider capability for "
            let providerLinkFailedMessage: String = "Unable to create private link to collection provider for "
            
            let leftUserAccount: PublicAccount = getAccount(leftUserAddress)
            
            let leftUserSwapCollectionCapability = leftUserAccount.getCapability<&AnyResource{EMSwap.SwapCollectionPublic}>(EMSwap.SwapCollectionPublicPath)
            assert(leftUserSwapCollectionCapability.check(), message: "Invalid SwapCollectionPublic capability")
            self.leftUserSwapCollection = leftUserSwapCollectionCapability.borrow() ?? panic("leftUserSwapCollection is invalid")
            
            self.rightUserReceiverCapabilities = {}
            self.rightUserAddress = signer.address
            
            let leftUserOffer = self.leftUserSwapCollection.getUserOffer(proposalId: proposalId, leftOrRight: "left")
            
            for partnerProposedNft in leftUserOffer.proposedNfts {
            
                if (self.rightUserReceiverCapabilities[partnerProposedNft.type.identifier] == nil) {
            
                    if (signer.type(at: partnerProposedNft.metadata.collectionData.storagePath) != nil) {
            
                        let receiverCapability = signer.getCapability<&AnyResource{NonFungibleToken.Receiver}>(partnerProposedNft.metadata.collectionData.publicPath)
                        if (receiverCapability.check()) {
            
                            self.rightUserReceiverCapabilities[partnerProposedNft.type.identifier] = receiverCapability
                            continue
                        }
                    }
            
                    panic(missingProviderMessage.concat(partnerProposedNft.type.identifier))
                }
            }
            
            self.rightUserProviderCapabilities = {}
            
            let rightUserOffer = self.leftUserSwapCollection.getUserOffer(proposalId: proposalId, leftOrRight: "right")
            
            for proposedNft in rightUserOffer.proposedNfts {
            
                if (self.rightUserProviderCapabilities[proposedNft.type.identifier] == nil) {
            
                    if (signer.getCapability<&{NonFungibleToken.Provider}>(proposedNft.metadata.collectionData.privatePath).borrow() == nil) {
            
                        signer.unlink(proposedNft.metadata.collectionData.privatePath)
                        signer.link<&{NonFungibleToken.Provider}>(proposedNft.metadata.collectionData.privatePath, target: proposedNft.metadata.collectionData.storagePath)
                    }
            
                    let providerCapability = signer.getCapability<&{NonFungibleToken.Provider}>(proposedNft.metadata.collectionData.privatePath)
                    if (providerCapability.check()) {
            
                        self.rightUserProviderCapabilities[proposedNft.type.identifier] = providerCapability
                        continue
            
                    }
            
                        panic(providerLinkFailedMessage.concat(proposedNft.type.identifier))
                    }
                }
            }
        
            execute {
            
                self.leftUserSwapCollection.executeProposal(
                    id: proposalId,
                    rightUserCapabilities: EMSwap.UserCapabilities(
                        collectionReceiverCapabilities: self.rightUserReceiverCapabilities,
                        collectionProviderCapabilities: self.rightUserProviderCapabilities,
                        feeProviderCapabilities: nil
                    )
                )
                
                TopShotMatch.removeMomentFromTradingBlock(owner: leftUserAddress, id: TopShotMatch.MomentIds(
                    UInt64.fromString(leftUserMoment["globalId"]!)!,
                    UInt32.fromString(leftUserMoment["playId"]!)!,
                    leftUserMoment["user"]!
                ))
                TopShotMatch.removeMomentFromTradingBlock(owner: self.rightUserAddress, id: TopShotMatch.MomentIds(
                    UInt64.fromString(rightUserMoment["globalId"]!)!,
                    UInt32.fromString(rightUserMoment["playId"]!)!,
                    rightUserMoment["user"]!
                ))
            }
        }
        """

        if userAddress == nil {
            return
        }

        let args: [Cadence.Argument] = [
            Cadence.Argument(.address(Cadence.Address(hexString: trade.leftMoment.user))),
            Cadence.Argument(.string(trade.id)),
            Cadence.Argument(.dictionary([
                Dictionary(key: .string("globalId"), value: .string(String(trade.leftMoment.globalId))),
                Dictionary(key: .string("playId"), value: .string(String(trade.leftMoment.playId))),
                Dictionary(key: .string("user"), value: .string(trade.leftMoment.user))
            ])),
            Cadence.Argument(.dictionary([
                Dictionary(key: .string("globalId"), value: .string(String(trade.rightMoment.globalId))),
                Dictionary(key: .string("playId"), value: .string(String(trade.rightMoment.playId))),
                Dictionary(key: .string("user"), value: .string(trade.rightMoment.user))
            ]))
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
//            showProposalSubmitted = true
        }

        // re-fetch everything
        try await getUserNfts()
        try await getGlobalTradingBlock()
    }

    @MainActor
    func submitTradeProposal(userMoment: Moment, otherUserMoment: Moment) async throws -> Void {
        let script = """
        import EMSwap from 0xaa3d8fb4584f9b91
        import NonFungibleToken from 0x631e88ae7f1d7c20
        import TopShot from 0xaa3d8fb4584f9b91
        
        transaction(rightUserAddress: Address, leftUserNft: UInt64, rightUserNft: UInt64) {
        
            let leftUserOffer: EMSwap.UserOffer
            let rightUserOffer: EMSwap.UserOffer
            let leftUserReceiverCapabilities: {String: Capability<&{NonFungibleToken.Receiver}>}
            let leftUserProviderCapabilities: {String: Capability<&{NonFungibleToken.Provider}>}
            let leftUserAccount: AuthAccount
            let fees: [EMSwap.Fee]
            
            prepare(signer: AuthAccount) {
            
                let missingProviderMessage: String = "Missing or invalid provider capability for "
                let providerLinkFailedMessage: String = "Unable to create private link to collection provider for "
                let invalidNftFormatMessage: String = "Invalid proposed NFT format"
                
                self.fees = []
                self.leftUserAccount = signer
                
                let mapNfts = fun (_ array: [{ String: UInt64 }]): [EMSwap.ProposedTradeAsset] {
                
                    var nfts: [EMSwap.ProposedTradeAsset] = []
                
                    for item in array {
                
                        if (item.keys.length != 1) {
                
                            panic(invalidNftFormatMessage)
                        }
                
                        let key = item.keys[0];
                
                        nfts.append(EMSwap.ProposedTradeAsset(
                            nftID: item[key]!,
                            type: key!,
                            ownerAddress: nil
                        ))
                    }
                
                    return nfts
                }
                
                let leftProposedNfts: [EMSwap.ProposedTradeAsset] = mapNfts([{
                    "A.aa3d8fb4584f9b91.TopShot.NFT": leftUserNft
                }])
                
                let rightProposedNfts: [EMSwap.ProposedTradeAsset] = mapNfts([{
                    "A.aa3d8fb4584f9b91.TopShot.NFT": rightUserNft
                }])
                
                self.leftUserOffer = EMSwap.UserOffer(userAddress: signer.address, proposedNfts: leftProposedNfts)
                self.rightUserOffer = EMSwap.UserOffer(userAddress: rightUserAddress, proposedNfts: rightProposedNfts)
                
                self.leftUserReceiverCapabilities = {}
                
                let partnerPublicAccount: PublicAccount = getAccount(rightUserAddress)
                
                for partnerProposedNft in self.rightUserOffer.proposedNfts {
                
                    if (self.leftUserReceiverCapabilities[partnerProposedNft.type.identifier] == nil) {
                
                        if (signer.type(at: partnerProposedNft.metadata.collectionData.storagePath) != nil) {
                
                            let receiverCapability = signer.getCapability<&AnyResource{NonFungibleToken.Receiver}>(partnerProposedNft.metadata.collectionData.publicPath)
                            if (receiverCapability.check()) {
                
                                self.leftUserReceiverCapabilities[partnerProposedNft.type.identifier] = receiverCapability
                                continue
                            }
                        }
                
                        panic(missingProviderMessage.concat(partnerProposedNft.type.identifier))
                    }
                }
                
                self.leftUserProviderCapabilities = {}
                
                for proposedNft in self.leftUserOffer.proposedNfts {
                
                    if (self.leftUserProviderCapabilities[proposedNft.type.identifier] == nil) {
                
                        if (signer.getCapability<&{NonFungibleToken.Provider}>(proposedNft.metadata.collectionData.privatePath).borrow() == nil) {
                
                            signer.unlink(proposedNft.metadata.collectionData.privatePath)
                            signer.link<&{NonFungibleToken.Provider}>(proposedNft.metadata.collectionData.privatePath, target: proposedNft.metadata.collectionData.storagePath)
                        }
                
                        let providerCapability = signer.getCapability<&{NonFungibleToken.Provider}>(proposedNft.metadata.collectionData.privatePath)
                        if (providerCapability.check()) {
                
                            self.leftUserProviderCapabilities[proposedNft.type.identifier] = providerCapability
                            continue
                        }
                
                        panic(providerLinkFailedMessage.concat(proposedNft.type.identifier))
                    }
                }
            }
            
            execute {
            
                if (self.leftUserAccount.type(at: EMSwap.SwapCollectionStoragePath) == nil) {
                
                    let newSwapCollection <- EMSwap.createEmptySwapCollection()
                    self.leftUserAccount.save(<-newSwapCollection, to: EMSwap.SwapCollectionStoragePath)
                
                    self.leftUserAccount.link<&AnyResource{EMSwap.SwapCollectionManager}>(EMSwap.SwapCollectionPrivatePath, target: EMSwap.SwapCollectionStoragePath)
                    self.leftUserAccount.link<&AnyResource{EMSwap.SwapCollectionPublic}>(EMSwap.SwapCollectionPublicPath, target: EMSwap.SwapCollectionStoragePath)
                
                } else if (self.leftUserAccount.type(at: EMSwap.SwapCollectionStoragePath) != Type<@EMSwap.SwapCollection>()) {
                
                    panic("Incorrect collection type stored at EMSwap.SwapCollectionStoragePath")
                }
                
                let swapCollectionManagerCapability = self.leftUserAccount.getCapability<&AnyResource{EMSwap.SwapCollectionManager}>(EMSwap.SwapCollectionPrivatePath)
                assert(swapCollectionManagerCapability.check(), message: "Got invalid SwapCollectionManager capability")
                let swapCollectionManager = swapCollectionManagerCapability.borrow()!
                
                swapCollectionManager.createProposal(
                    leftUserOffer: self.leftUserOffer,
                    rightUserOffer: self.rightUserOffer,
                    leftUserCapabilities: EMSwap.UserCapabilities(
                        collectionReceiverCapabilities: self.leftUserReceiverCapabilities,
                        collectionProviderCapabilities: self.leftUserProviderCapabilities,
                        nil
                    ),
                    fees: self.fees,
                    expirationOffsetMinutes: nil
                )
            }
        }
        """

        if userAddress == nil {
            return
        }

        let args: [Cadence.Argument] = [
            Cadence.Argument(.address(Cadence.Address(hexString: otherUserMoment.user))),
            Cadence.Argument(.uint64(UInt64(userMoment.globalId))),
            Cadence.Argument(.uint64(UInt64(otherUserMoment.globalId)))
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
    
    @MainActor
    func deleteProposal(trade: Trade) async throws -> Void {
        let script = """
        import EMSwap from 0xaa3d8fb4584f9b91
        
        transaction(leftUser: Address, id: String) {
            prepare(acct: AuthAccount) {
                let acct = getAccount(leftUser)
                let swapCollectionCapability = acct.getCapability<&AnyResource{EMSwap.SwapCollectionPublic}>(EMSwap.SwapCollectionPublicPath)
                let swapCollection = swapCollectionCapability.borrow() ?? panic("swapCollection is invalid")
                swapCollection.deleteProposal(id: id)
            }
        }
        """
        
        if userAddress == nil {
            return
        }
        
        let args: [Cadence.Argument] = [
            Cadence.Argument(.address(Cadence.Address(hexString: trade.leftMoment.user))),
            Cadence.Argument(.string(trade.id))
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
        try await getPendingTrades()
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
            limit: 5000,
            authorizers: [userAddress!]
        )
    }
}
