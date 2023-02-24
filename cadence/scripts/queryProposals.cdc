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