import EMSwap from 0x2a9011074c827145

pub fun main(address: Address): {String: EMSwap.ReadableSwapProposal} {
    let acct = getAccount(address)

    let cap = acct.getCapability<&{EMSwap.SwapCollectionManager, EMSwap.SwapCollectionPublic}>(EMSwap.SwapCollectionPublicPath).borrow()!

    return cap.getAllProposals()
}