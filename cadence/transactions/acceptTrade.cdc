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

		self.leftUserSwapCollection.deleteProposal(id: proposalId)

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