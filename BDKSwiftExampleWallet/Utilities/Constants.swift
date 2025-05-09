//
//  Constants.swift
//  BDKSwiftExampleWallet
//
//  Created by Matthew Ramsden on 6/4/23.
//

import BitcoinDevKit
import Foundation
import SwiftUI

struct Constants {
    enum BitcoinNetworkColor {
        case bitcoin
        case regtest
        case signet
        case testnet
        case testnet4

        var color: Color {
            switch self {
            case .regtest:
                return Color.green
            case .signet:
                return Color.yellow
            case .bitcoin:
                // Supposed to be `Color.black`
                // ... but I'm just going to make it `Color.orange`
                // ... since `Color.black` might not work well for both light+dark mode
                // ... and `Color.orange` just makes more sense to me
                return Color.orange
            case .testnet:
                return Color.red
            case .testnet4:
                return Color.cyan
            }
        }
    }
}
