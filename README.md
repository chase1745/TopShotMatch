# TopShotMatch

## Flow Hackathon 2023

This repo contains the native iOS appplication (`/ios`) and the Cadence smart contracts/scripts/transactions (`/cadence`).

### iOS App

The iOS app is written in SwiftUI. This was writting completely from scratch for this hackathon
and uses the [https://github.com/portto/fcl-swift](fcl-swift) library for user wallet and transactions.

The app can be run locally by opening the `TopShot Match.xcworkspace` file in the latest
version of XCode. You can then run the app in a simulator ro install it to your device to run.

### Smart Contracts

Instead of writing backend for this project, I decided to use smart contracts for all data storage.
This includes liked moments, trading blocks, and initial trade proposals. There are some downsides
to this (mostly UX, forcing the user to submit lots of transactions) and longer term I would
probably store most of these things off-chain, utilizing the existing on-chain Swap contract for
Moment swaps.

#### Testnet Addresses

`TopShotMatch` - `0xaa3d8fb4584f9b91`
