//
// Created by Michael O'Riley on 5/29/15.
// Copyright (c) 2015 BitGarage. All rights reserved.
//

import Foundation
import CoreBluetooth

protocol BLECentralDelegate {
    func didDiscoverPeripheral(_ peripheral: CBPeripheral!)
}
