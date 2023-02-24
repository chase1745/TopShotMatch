import FungibleToken from 0x9a0766d93b6608b7
import NonFungibleToken from 0x631e88ae7f1d7c20
import NFTCatalog from 0x324c34e1c517e4db
import MetadataViews from 0x631e88ae7f1d7c20

access(all) contract EMSwap {

    // ProposalCreated
    // Event to notify when a user has created a swap proposal
    access(all) event ProposalCreated(proposal: ReadableSwapProposal)

    // ProposalExecuted
    // Event to notify when a user has executed a previously created swap proposal
    access(all) event ProposalExecuted(proposal: ReadableSwapProposal)

    // AllowSwapProposalCreation
    // Toggle to control creation of new swap proposals
    access(account) var AllowSwapProposalCreation: Bool

    // SwapCollectionStoragePath
    // Storage directory used to store the SwapCollection object
    access(all) let SwapCollectionStoragePath: StoragePath

    // SwapCollectionPrivatePath
    // Private directory used to expose the SwapCollectionManager object
    access(all) let SwapCollectionPrivatePath: PrivatePath

    // SwapCollectionPublicPath
    // Public directory used to store the SwapCollectionPublic object
    access(all) let SwapCollectionPublicPath: PublicPath

    // SwapProposalAdminStoragePath
    // Storage directory used to store SwapProposalAdmin object
    access(account) let SwapProposalAdminStoragePath: StoragePath

    // SwapProposalAdminPrivatePath
    // Storage directory used to store SwapProposalAdmin object
    access(account) let SwapProposalAdminPrivatePath: PrivatePath

    // SwapProposalMinExpirationMinutes
    // Minimum number of minutes that a swap proposal can be set to expire in
    access(all) let SwapProposalMinExpirationMinutes: UFix64

    // SwapProposalMaxExpirationMinutes
    // Maximum number of minutes that a swap proposal can be set to expire in
    access(all) let SwapProposalMaxExpirationMinutes: UFix64

    // SwapProposalDefaultExpirationMinutes
    // Default nubmer of minutes for swap proposal exiration
    access(all) let SwapProposalDefaultExpirationMinutes: UFix64

    // NftTradeAsset
    // The field to identify a valid NFT within a trade
    // The nftID allows for verification of a valid NFT being transferred
    access(all) struct interface NftTradeAsset {
        access(all) let nftID: UInt64
    }

    access(all) struct interface Readable {
        access(all) fun getReadable(): {String: AnyStruct}
    }

    // ProposedTradeAsset
    // An NFT asset proposed as part of a swap.
    // The init function searches for a corresponding NFTCatalog entry and stores the metadata on the ProposedTradeAsset.
    access(all) struct ProposedTradeAsset: NftTradeAsset, Readable {
        access(all) let nftID: UInt64
        access(all) let type: Type
        access(all) let metadata: NFTCatalog.NFTCatalogMetadata

        access(all) fun getReadable(): {String: String} {
            return {
                "nftID": self.nftID.toString(),
                "type": self.type.identifier
            }
        }

        init(
            nftID: UInt64,
            type: String,
            ownerAddress: Address?
        ) {

            let multipleCatalogEntriesMessage: String = "found multiple NFTCatalog entries but no ownerAddress for "
            let zeroCatalogEntriesMessage: String = "could not find NFTCatalog entry for "
            let nftCatalogTypeMismatch: String = "input type does not match NFTCatalog entry type for "

            let inputType = CompositeType(type) ?? panic("unable to cast type; must be a valid NFT type reference")

            // attempt to get NFTCatalog entry from type
            var catalogEntry: NFTCatalog.NFTCatalogMetadata? = nil
            let nftCatalogCollections: {String: Bool}? = NFTCatalog.getCollectionsForType(nftTypeIdentifier: inputType.identifier)

            if (nftCatalogCollections == nil || nftCatalogCollections!.keys.length < 1) {
                panic(zeroCatalogEntriesMessage.concat(inputType.identifier))
            } else if (nftCatalogCollections!.keys.length > 1) {

                if (ownerAddress == nil) {
                    panic(multipleCatalogEntriesMessage.concat(inputType.identifier))
                }
                let ownerPublicAccount = getAccount(ownerAddress!)

                // attempt to match NFTCatalog entry with NFT from ownerAddress
                for collectionKey in nftCatalogCollections!.keys {
                    let tempCatalogEntry = NFTCatalog.getCatalogEntry(collectionIdentifier: collectionKey)
                    if (tempCatalogEntry == nil) {
                        continue
                    }
                    let collectionCap = ownerPublicAccount.getCapability<&AnyResource{MetadataViews.ResolverCollection}>(tempCatalogEntry!.collectionData.publicPath)
                    if (collectionCap.check()) {
                        let collectionRef = collectionCap.borrow()!
                        if (!collectionRef.getIDs().contains(nftID)) {
                            continue
                        }
                        let viewResolver = collectionRef.borrowViewResolver(id: nftID)
                        let nftView = MetadataViews.getNFTView(id: nftID, viewResolver: viewResolver)
                        if (nftView.display!.name == tempCatalogEntry!.collectionDisplay.name) {
                            catalogEntry = tempCatalogEntry
                        }
                    }
                }

            } else {
                catalogEntry = NFTCatalog.getCatalogEntry(collectionIdentifier: nftCatalogCollections!.keys[0])
            }

            if (catalogEntry == nil) {
                panic(zeroCatalogEntriesMessage.concat(inputType.identifier))
            }

            assert(inputType == catalogEntry!.nftType, message: nftCatalogTypeMismatch.concat(inputType.identifier))

            self.nftID = nftID
            self.type = inputType
            self.metadata = catalogEntry!
        }
    }

    // Fee
    // This struct represents a fee to be paid upon execution of the swap proposal.
    access(all) struct Fee: Readable {
        access(all) let receiver: Capability<&AnyResource{FungibleToken.Receiver}>
        access(all) let amount: UFix64
        access(all) let tokenType: Type

        init(receiver: Capability<&AnyResource{FungibleToken.Receiver}>, amount: UFix64) {

            assert(receiver.check(), message: "invalid fee receiver")
            let tokenType = receiver.borrow()!.getType()
            assert(amount > 0.0, message: "fee amount must be greater than zero")

            self.receiver = receiver
            self.amount = amount
            self.tokenType = tokenType
        }

        access(all) fun getReadable(): {String: String} {
            return {
                "receiverAddress": self.receiver.address.toString(),
                "amount": self.amount.toString(),
                "tokenType": self.tokenType.identifier
            }
        }
    }

    // UserOffer
    access(all) struct UserOffer: Readable {
        access(all) let userAddress: Address
        access(all) let proposedNfts: [ProposedTradeAsset]

        access(all) fun getReadable(): {String: [{String: String}]} {

            let readableProposedNfts: [{String: String}] = []
            for proposedNft in self.proposedNfts {
                readableProposedNfts.append(proposedNft.getReadable())
            }

            return {
                "proposedNfts": readableProposedNfts
            }
        }

        init(
            userAddress: Address,
            proposedNfts: [ProposedTradeAsset],
        ) {
            self.userAddress = userAddress
            self.proposedNfts = proposedNfts
        }
    }

    // UserCapabilities
    // This struct contains the providers needed to send the user's offered tokens and any required fees, as well as the
    // receivers needed to accept the trading partner's tokens.
    // Each token's type identifier is used as the key for each entry in each dict.
    access(all) struct UserCapabilities {
        access(all) let collectionReceiverCapabilities: {String: Capability<&{NonFungibleToken.Receiver}>}
        access(all) let collectionProviderCapabilities: {String: Capability<&{NonFungibleToken.Provider}>}
        access(all) let feeProviderCapabilities: {String: Capability<&{FungibleToken.Provider, FungibleToken.Balance}>}?

        init(
            collectionReceiverCapabilities: {String: Capability<&{NonFungibleToken.Receiver}>},
            collectionProviderCapabilities: {String: Capability<&{NonFungibleToken.Provider}>},
            feeProviderCapabilities: {String: Capability<&{FungibleToken.Provider, FungibleToken.Balance}>}?
        ) {
            self.collectionReceiverCapabilities = collectionReceiverCapabilities
            self.collectionProviderCapabilities = collectionProviderCapabilities
            self.feeProviderCapabilities = feeProviderCapabilities
        }
    }

    // ReadableSwapProposal
    // Struct for return type to SwapProposal.getReadable()
    access(all) struct ReadableSwapProposal {
        access(all) let id: String
        access(all) let fees: [{String: String}]
        access(all) let minutesRemainingBeforeExpiration: String
        access(all) let leftUserAddress: String
        access(all) let leftUserOffer: {String: [{String: String}]}
        access(all) let rightUserAddress: String
        access(all) let rightUserOffer: {String: [{String: String}]}

        init(
            id: String,
            fees: [Fee],
            expirationEpochMilliseconds: UFix64,
            leftUserOffer: UserOffer,
            rightUserOffer: UserOffer
        ) {

            let readableFees: [{String: String}] = []
            for fee in fees {
                readableFees.append(fee.getReadable())
            }

            let currentTimestamp: UFix64 = getCurrentBlock().timestamp
            var minutesRemaining: UFix64 = 0.0
            if (expirationEpochMilliseconds > currentTimestamp) {
                minutesRemaining = (expirationEpochMilliseconds - currentTimestamp) / 60000.0
            }

            self.id = id
            self.fees = readableFees
            self.minutesRemainingBeforeExpiration = minutesRemaining.toString()
            self.leftUserAddress = leftUserOffer.userAddress.toString()
            self.leftUserOffer = leftUserOffer.getReadable()
            self.rightUserAddress = rightUserOffer.userAddress.toString()
            self.rightUserOffer = rightUserOffer.getReadable()
        }
    }

    // SwapProposal
    access(all) struct SwapProposal {

        // Semi-unique identifier (unique within the left user's account) to identify swap proposals
        access(all) let id: String

        // Array of all fees to be paid out on execution of swap proposal (can be empty array in case of zero fees)
        access(all) let fees: [Fee]

        // When this swap proposal should no longer be eligible to be accepted (in epoch milliseconds)
        access(all) let expirationEpochMilliseconds: UFix64

        // The offer of the initializing user
        access(all) let leftUserOffer: UserOffer

        // The offer of the secondary proposer
        access(all) let rightUserOffer: UserOffer

        // The trading capabilities of the initializing user
        access(self) let leftUserCapabilities: UserCapabilities

        init(
            id: String,
            leftUserOffer: UserOffer,
            rightUserOffer: UserOffer,
            leftUserCapabilities: UserCapabilities,
            fees: [Fee],
            expirationOffsetMinutes: UFix64
        ) {

            assert(expirationOffsetMinutes >= EMSwap.SwapProposalMinExpirationMinutes,
                message: "expirationOffsetMinutes must be greater than or equal to EMSwap.SwapProposalMinExpirationMinutes")
            assert(expirationOffsetMinutes <= EMSwap.SwapProposalMaxExpirationMinutes,
                message: "expirationOffsetMinutes must be less than or equal to EMSwap.SwapProposalMaxExpirationMinutes")
            assert(EMSwap.AllowSwapProposalCreation, message: "swap proposal creation is paused")

            // convert offset minutes to epoch milliseconds
            let expirationEpochMilliseconds = getCurrentBlock().timestamp + (expirationOffsetMinutes * 1000.0 * 60.0)

            // verify that both users own their proposed assets and that leftUser has supplied proper capabilities
            EMSwap.verifyUserOffer(
                userOffer: leftUserOffer,
                userCapabilities: leftUserCapabilities,
                partnerOffer: rightUserOffer,
                fees: fees
            )
            EMSwap.verifyUserOffer(
                userOffer: rightUserOffer,
                userCapabilities: nil,
                partnerOffer: nil,
                fees: nil
            )

            self.id = id
            self.fees = fees
            self.leftUserOffer = leftUserOffer
            self.rightUserOffer = rightUserOffer
            self.leftUserCapabilities = leftUserCapabilities
            self.expirationEpochMilliseconds = expirationEpochMilliseconds

            emit ProposalCreated(proposal: self.getReadableSwapProposal())
        }

        // Get a human-readable version of the swap proposal data
        access(contract) fun getReadableSwapProposal(): ReadableSwapProposal {
            return ReadableSwapProposal(
                id: self.id,
                fees: self.fees,
                expirationEpochMilliseconds: self.expirationEpochMilliseconds,
                leftUserOffer: self.leftUserOffer,
                rightUserOffer: self.rightUserOffer
            )
        }

        // Function to execute the proposed swap
        access(contract) fun execute(rightUserCapabilities: UserCapabilities) {

            assert(getCurrentBlock().timestamp <= self.expirationEpochMilliseconds, message: "swap proposal is expired")

            // verify capabilities and ownership of tokens
            EMSwap.verifyUserOffer(
                userOffer: self.leftUserOffer,
                userCapabilities: self.leftUserCapabilities,
                partnerOffer: self.rightUserOffer,
                fees: self.fees
            )
            EMSwap.verifyUserOffer(
                userOffer: self.rightUserOffer,
                userCapabilities: rightUserCapabilities,
                partnerOffer: self.leftUserOffer,
                fees: self.fees
            )

            // execute offers
            EMSwap.executeUserOffer(
                userOffer: self.leftUserOffer,
                userCapabilities: self.leftUserCapabilities,
                partnerCapabilities: rightUserCapabilities,
                fees: self.fees
            )
            EMSwap.executeUserOffer(
                userOffer: self.rightUserOffer,
                userCapabilities: rightUserCapabilities,
                partnerCapabilities: self.leftUserCapabilities,
                fees: self.fees
            )

            emit ProposalExecuted(proposal: self.getReadableSwapProposal())
        }
    }

    // This interface allows private linking of management methods for the SwapCollection owner
    access(all) resource interface SwapCollectionManager {
        access(all) fun createProposal(
            leftUserOffer: UserOffer,
            rightUserOffer: UserOffer,
            leftUserCapabilities: UserCapabilities,
            fees: [Fee]?,
            expirationOffsetMinutes: UFix64?
        ): String
        access(all) fun getAllProposals(): {String: ReadableSwapProposal}
        access(all) fun deleteProposal(id: String)
    }

    // This interface allows public linking of the get and execute methods for trading partners
    access(all) resource interface SwapCollectionPublic {
        access(all) fun getProposal(id: String): ReadableSwapProposal
        access(all) fun getUserOffer(proposalId: String, leftOrRight: String): UserOffer
        access(all) fun executeProposal(id: String, rightUserCapabilities: UserCapabilities)
    }

    access(all) resource SwapCollection: SwapCollectionManager, SwapCollectionPublic {

        // Dict to store by swap id all trade offers created by the end user
        access(self) let swapProposals: {String: SwapProposal}

        // Function to create and store a swap proposal
        access(all) fun createProposal(
            leftUserOffer: UserOffer,
            rightUserOffer: UserOffer,
            leftUserCapabilities: UserCapabilities,
            fees: [Fee]?,
            expirationOffsetMinutes: UFix64?
        ): String {

            // generate semi-random number for the SwapProposal id
            var semiRandomId: String = unsafeRandom().toString()
            while (self.swapProposals[semiRandomId] != nil) {
                semiRandomId = unsafeRandom().toString()
            }

            // create swap proposal and add to swapProposals
            let newSwapProposal = SwapProposal(
                id: semiRandomId,
                leftUserOffer: leftUserOffer,
                rightUserOffer: rightUserOffer,
                leftUserCapabilities: leftUserCapabilities,
                fees: fees ?? [],
                expirationOffsetMinutes: expirationOffsetMinutes ?? EMSwap.SwapProposalDefaultExpirationMinutes
            )
            self.swapProposals.insert(key: semiRandomId, newSwapProposal)

            return semiRandomId
        }

        // Function to get a readable version of a single swap proposal
        access(all) fun getProposal(id: String): ReadableSwapProposal {

            let noSwapProposalMessage: String = "found no swap proposal with id "
            let swapProposal: SwapProposal = self.swapProposals[id] ?? panic(noSwapProposalMessage.concat(id))

            return swapProposal.getReadableSwapProposal()
        }

        // Function to get a readable version of all swap proposals
        access(all) fun getAllProposals(): {String: ReadableSwapProposal} {

            let proposalReadErrorMessage: String = "unable to get readable swap proposal for id "
            let readableSwapProposals: {String: ReadableSwapProposal} = {}

            for swapProposalId in self.swapProposals.keys {
                let swapProposal = self.swapProposals[swapProposalId] ?? panic(proposalReadErrorMessage.concat(swapProposalId))
                readableSwapProposals.insert(key: swapProposalId, swapProposal!.getReadableSwapProposal())
            }

            return readableSwapProposals
        }

        // Function to provide the specified user offer details
        access(all) fun getUserOffer(proposalId: String, leftOrRight: String): UserOffer {

            let noSwapProposalMessage: String = "found no swap proposal with id "
            let swapProposal: SwapProposal = self.swapProposals[proposalId] ?? panic(noSwapProposalMessage.concat(proposalId))

            var userOffer: UserOffer? = nil

            switch leftOrRight.toLower() {
                case "left":
                    userOffer = swapProposal.leftUserOffer
                case "right":
                    userOffer = swapProposal.rightUserOffer
                default:
                    panic("argument leftOrRight must be either 'left' or 'right'")
            }

            return userOffer!
        }

        // Function to delete a swap proposal
        access(all) fun deleteProposal(id: String) {
            self.swapProposals.remove(key: id)
        }

        // Function to execute a previously created swap proposal
        access(all) fun executeProposal(id: String, rightUserCapabilities: UserCapabilities) {

            let noSwapProposalMessage: String = "found no swap proposal with id "
            let swapProposal: SwapProposal = self.swapProposals[id] ?? panic(noSwapProposalMessage.concat(id))

            swapProposal.execute(rightUserCapabilities: rightUserCapabilities)
        }

        init() {
            self.swapProposals = {}
        }
    }

    // SwapProposalManager
    // This interface allows private linking of swap proposal management functionality
    access(all) resource interface SwapProposalManager {
        access(all) fun stopProposalCreation()
        access(all) fun startProposalCreation()
        access(all) fun getProposalCreationStatus(): Bool
    }

    // SwapProposalAdmin
    // This object provides admin controls for swap proposals
    access(all) resource SwapProposalAdmin: SwapProposalManager {

        // Pause all new swap proposal creation (for maintenance)
        access(all) fun stopProposalCreation() {
            EMSwap.AllowSwapProposalCreation = false
        }

        // Resume new swap proposal creation
        access(all) fun startProposalCreation() {
            EMSwap.AllowSwapProposalCreation = true
        }

        // Get current value of AllowSwapProposalCreation
        access(all) fun getProposalCreationStatus(): Bool {
            return EMSwap.AllowSwapProposalCreation
        }
    }

    // createEmptySwapCollection
    // This function allows user to create a swap collection resource for future swap proposal creation.
    access(all) fun createEmptySwapCollection(): @SwapCollection {
        return <-create SwapCollection()
    }

    // verifyUserOffer
    // This function verifies that all assets in user offer are owned by the user.
    // If userCapabilities is provided, the function checks that the provider capabilities are valid and that the
    // address of each capability matches the address of the userOffer.
    // If partnerOffer is provided in addition to userCapabilities, the function checks that the receiver
    // capabilities are valid and that one exists for each of the collections in the partnerOffer.
    access(contract) fun verifyUserOffer(
        userOffer: UserOffer,
        userCapabilities: UserCapabilities?,
        partnerOffer: UserOffer?,
        fees: [Fee]?
    ) {

        let nftCatalogMessage: String = "NFTCatalog entry not found for "
        let collectionPublicMessage: String = "could not borrow collectionPublic for "
        let feeProviderRefMessage: String = "could not borrow fee provider reference for "
        let feeTypeMismatchMessage: String = "feeProvider token type and fee.tokenType do not match for "
        let feeBalanceMessage: String = "insufficient balance to pay fees for token "
        let nftTypeMismatchMessage: String = "proposedNft.type and stored asset type do not match for "
        let ownershipMessage: String = "could not verify ownership for "
        let capabilityNilMessage: String = "capability not found for "
        let addressMismatchMessage: String = "capability address does not match userOffer address for "
        let capabilityCheckMessage: String = "capability is invalid for "

        let userPublicAccount: PublicAccount = getAccount(userOffer.userAddress)

        for proposedNft in userOffer.proposedNfts {

            // attempt to load CollectionPublic capability and verify ownership
            let publicCapability = userPublicAccount.getCapability<&AnyResource{NonFungibleToken.CollectionPublic}>(proposedNft.metadata.collectionData.publicPath)

            let collectionPublicRef = publicCapability.borrow()
                ?? panic(collectionPublicMessage.concat(proposedNft.type.identifier))

            let ownedNftIds: [UInt64] = collectionPublicRef.getIDs()
            assert(ownedNftIds.contains(proposedNft.nftID), message: ownershipMessage.concat(proposedNft.type.identifier))

            let nftRef = collectionPublicRef.borrowNFT(id: proposedNft.nftID)
            assert(nftRef.getType() == proposedNft.type, message: nftTypeMismatchMessage.concat(proposedNft.type.identifier))

            if (userCapabilities != nil) {

                // check NFT provider capabilities
                let providerCapability = userCapabilities!.collectionProviderCapabilities[proposedNft.type.identifier]
                assert(providerCapability != nil, message: capabilityNilMessage.concat(proposedNft.type.identifier))
                assert(providerCapability!.address == userOffer.userAddress, message: addressMismatchMessage.concat(proposedNft.type.identifier))
                assert(providerCapability!.check(), message: capabilityCheckMessage.concat(proposedNft.type.identifier))
            }
        }

        if (userCapabilities != nil && partnerOffer != nil) {

            for partnerProposedNft in partnerOffer!.proposedNfts {

                // check NFT receiver capabilities
                let receiverCapability = userCapabilities!.collectionReceiverCapabilities[partnerProposedNft.type.identifier]
                assert(receiverCapability != nil, message: capabilityNilMessage.concat(partnerProposedNft.type.identifier))
                assert(receiverCapability!.address == userOffer.userAddress, message: addressMismatchMessage.concat(partnerProposedNft.type.identifier))
                assert(receiverCapability!.check(), message: capabilityCheckMessage.concat(partnerProposedNft.type.identifier))
            }
        }

        if (fees != nil && fees!.length > 0 && userCapabilities != nil) {

            assert(userCapabilities!.feeProviderCapabilities != nil && userCapabilities!.feeProviderCapabilities!.keys.length > 0,
                message: "feeProviderCapabilities dictionary cannot be empty if fees are required")

            let feeTotals: {String: UFix64} = {}

            for fee in fees! {

                // check that user has proper capabilities for fee
                let feeProviderCapability = userCapabilities!.feeProviderCapabilities![fee.tokenType.identifier]
                assert(feeProviderCapability != nil, message: capabilityNilMessage.concat(fee.tokenType.identifier))
                let vaultRef = feeProviderCapability!.borrow() ?? panic(feeProviderRefMessage.concat(fee.tokenType.identifier))
                assert(vaultRef.isInstance(fee.tokenType), message: feeTypeMismatchMessage.concat(fee.tokenType.identifier))

                // tally running fee totals and check that user has available balance of specified token
                let previousFeeTotal = feeTotals[fee.tokenType.identifier] ?? 0.0
                let newFeeTotal = previousFeeTotal + fee.amount
                feeTotals.insert(key: fee.tokenType.identifier, newFeeTotal)
                assert(vaultRef.balance >= newFeeTotal, message: feeBalanceMessage.concat(fee.tokenType.identifier))
            }
        }
    }

    // executeUserOffer
    // This function verifies for each token in the user offer that both users have the required capabilites for the
    // trade and that the token type matches that of the offer, and then it moves the token to the receiving collection.
    access(contract) fun executeUserOffer(
        userOffer: UserOffer,
        userCapabilities: UserCapabilities,
        partnerCapabilities: UserCapabilities,
        fees: [Fee]
    ) {

        let feeReceiverRefMessage: String = "could not borrow fee receiver reference for "
        let feeProviderRefMessage: String = "could not borrow fee provider reference for "
        let feeTypeMismatchMessage: String = "token type mismatch for fee token "
        let typeMismatchMessage: String = "token type mismatch for "
        let receiverRefMessage: String = "could not borrow receiver reference for "
        let providerRefMessage: String = "could not borrow provider reference for "

        for fee in fees {

            // get fee receiver and fee provider
            let feeReceiverRef = fee.receiver.borrow() ?? panic(feeReceiverRefMessage.concat(fee.tokenType.identifier))
            let vaultRef = userCapabilities.feeProviderCapabilities![fee.tokenType.identifier]!.borrow()
                ?? panic(feeProviderRefMessage.concat(fee.tokenType.identifier))

            // verify token type
            let feePayment <- vaultRef.withdraw(amount: fee.amount)
            assert(feePayment.isInstance(fee.tokenType), message: feeTypeMismatchMessage.concat(fee.tokenType.identifier))

            // transfer fee
            feeReceiverRef.deposit(from: <-feePayment)
        }

        for proposedNft in userOffer.proposedNfts {

            // get receiver and provider
            let receiverReference = partnerCapabilities.collectionReceiverCapabilities[proposedNft.type.identifier]!.borrow()
                ?? panic(receiverRefMessage.concat(proposedNft.type.identifier))
            let providerReference = userCapabilities.collectionProviderCapabilities[proposedNft.type.identifier]!.borrow()
                ?? panic(providerRefMessage.concat(proposedNft.type.identifier))

            // verify token type
            let nft <- providerReference.withdraw(withdrawID: proposedNft.nftID)
            assert(nft.isInstance(proposedNft.type), message: typeMismatchMessage.concat(proposedNft.type.identifier))

            // transfer token
            receiverReference.deposit(token: <-nft)
        }
    }

    init() {

        // initialize contract constants
        self.AllowSwapProposalCreation = true
        self.SwapCollectionStoragePath = /storage/emSwapCollection
        self.SwapCollectionPrivatePath = /private/emSwapCollectionManager
        self.SwapCollectionPublicPath = /public/emSwapCollectionPublic
        self.SwapProposalAdminStoragePath = /storage/emSwapProposalAdmin
        self.SwapProposalAdminPrivatePath = /private/emSwapProposalAdmin
        self.SwapProposalMinExpirationMinutes = 2.0
        self.SwapProposalMaxExpirationMinutes = 20.0
        self.SwapProposalDefaultExpirationMinutes = 5.0

        // save swap proposal admin object
        self.account.save(<- create SwapProposalAdmin(), to: self.SwapProposalAdminStoragePath)
        self.account.link<&{SwapProposalManager}>(self.SwapProposalAdminPrivatePath, target: self.SwapProposalAdminStoragePath)
    }
}
