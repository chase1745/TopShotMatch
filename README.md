# TopShot Match

[TopShot Match logo](bball.png)

## Flow Hackathon 2023

This repo contains the native iOS appplication (`/ios`) and the Cadence smart contracts/scripts/transactions (`/cadence`).

### iOS App

The iOS app is written in SwiftUI. This was writting completely from scratch for this hackathon
and uses the [https://github.com/portto/fcl-swift](fcl-swift) library for user wallet and transactions.

The app can be run locally by opening the `TopShot Match.xcworkspace` file in the latest
version of XCode. You can then run the app in a simulator or install it to your device to run.

Note to run it on your device, you'll need to follow [these instructions](https://www.twilio.com/blog/2018/07/how-to-test-your-ios-application-on-a-real-device.html).

### Smart Contracts

Instead of writing/deploying a backend for this project, I decided to use a smart contract for all data storage.

This includes liked moments, trading blocks, and initial trade proposals. There are some downsides
to this (mostly UX, forcing the user to submit lots of transactions), and longer term I would
probably store most of these things off-chain, utilizing the existing on-chain Swap contract for
Moment swaps.

`TopShotMatch.cdc` is the only contract I wrote for this project. The other contracts in the repo,
`EMSwap`, `TopShot`, and `TopShotLocking` were all just taken from their respective repos and brought
into this project so I could re-deploy them in order to have admin capabilities for this
hackathon demo.

#### Testnet Addresses

`TopShotMatch` - [0xaa3d8fb4584f9b91](https://testnet.flowscan.org/account/0xaa3d8fb4584f9b91)
