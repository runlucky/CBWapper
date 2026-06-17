//
//  Untitled.swift
//  CBWrapper
//
//  Created by kakeru on 2026/06/17.
//

import CoreBluetooth

extension CBService {
    internal func getCharacteristic(_ uuid: CBUUID) -> CBCharacteristic? {
        self.characteristics?.first(where: { $0.uuid == uuid })
    }
}
