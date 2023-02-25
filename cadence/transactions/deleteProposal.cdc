import EMSwap from 0xaa3d8fb4584f9b91

transaction(leftUser: Address, id: String) {
    prepare(acct: AuthAccount) {
        let acct = getAccount(leftUser)
        let swapCollectionCapability = acct.getCapability<&AnyResource{EMSwap.SwapCollectionManager}>(EMSwap.SwapCollectionPublicPath)
        let swapCollection = swapCollectionCapability.borrow() ?? panic("swapCollection is invalid")
        swapCollection.deleteProposal(id: id)
    }
}