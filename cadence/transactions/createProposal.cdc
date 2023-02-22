import EMSwap from 0x2a9011074c827145
import NonFungibleToken from 0x631e88ae7f1d7c20
import TopShot from 0xaa3d8fb4584f9b91

transaction(leftUserNft: UInt64, rightUserNft: UInt64, rightUserAddress: Address) {

	let leftUserOffer: EMSwap.UserOffer
	let rightUserOffer: EMSwap.UserOffer
	let leftUserReceiverCapabilities: {String: Capability<&{NonFungibleToken.Receiver}>}
	let leftUserProviderCapabilities: {String: Capability<&{NonFungibleToken.Provider}>}
	let leftUserAccount: AuthAccount

	prepare(signer: AuthAccount) {

		let missingProviderMessage: String = "Missing or invalid provider capability for "
		let providerLinkFailedMessage: String = "Unable to create private link to collection provider for "
		let invalidNftFormatMessage: String = "Invalid proposed NFT format"

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
					type: key!
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

					let receiverCapability = signer.getCapability<&{
                        NonFungibleToken.Receiver
                    }>(partnerProposedNft.metadata.collectionData.publicPath)
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
			fees: nil,
			expirationOffsetMinutes: nil
		)
	}
}

// transaction(leftNftID: UInt64, rightNftID: UInt64, rightUserAddress: Address) {
//     let managerRef: &EMSwap.SwapCollection
//     let userCapability: EMSwap.UserCapabilities
//     let type: String
//     let leftUserAddress: Address

//     prepare(acct: AuthAccount) {
//         self.type = "A.aa3d8fb4584f9b91.TopShot.NFT"
//         self.leftUserAddress = acct.address

//         // borrow a reference to the Admin resource in storage
//         self.managerRef = acct.borrow<&EMSwap.SwapCollection>(from: EMSwap.SwapCollectionStoragePath)
//             ?? panic("Could not borrow a reference to the SwapCollectionManager resource")

//         self.userCapability = EMSwap.UserCapabilities(
//             collectionReceiverCapabilities: {
//                 "A.aa3d8fb4584f9b91.TopShot.NFT" : acct.getCapability<&AnyResource{NonFungibleToken.Receiver}>(/public/MomentCollection)
//             },
//             collectionProviderCapabilities: {
//                 "A.aa3d8fb4584f9b91.TopShot.NFT" : acct.getCapability<&AnyResource{NonFungibleToken.Provider}>(/public/MomentCollection)
//             },
//             feeProviderCapabilities: nil
//         )
//     }

//     execute {
//         let leftUserProposal: EMSwap.UserOffer = EMSwap.UserOffer(
//             userAddress: self.leftUserAddress,
//             proposedNfts: [
//                 EMSwap.ProposedTradeAsset(
//                     nftID: 18,
//                     type: self.type
//                 )
//             ]
//         )

//         let rightUserProposal: EMSwap.UserOffer = EMSwap.UserOffer(
//             userAddress: rightUserAddress,
//             proposedNfts: [
//                 EMSwap.ProposedTradeAsset(
//                     nftID: rightNftID,
//                     type: self.type
//                 )
//             ]
//         )

//         // Create a proposal and return the proposal id
//         self.managerRef.createProposal(
//             leftUserOffer: leftUserProposal,
//             rightUserOffer: rightUserProposal,
//             leftUserCapabilities: self.userCapability,
//             fees: nil,
//             expirationOffsetMinutes: nil
//         )
//     }
// }
