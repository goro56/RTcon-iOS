//
//  BluetoothConnection.swift
//  RTcon
//
//  Created by 下地勇人 on 2016/12/04.
//  Copyright © 2016年 下地勇人. All rights reserved.
//

import UIKit
import Foundation
import CoreBluetooth

class BluetoothConnection: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    var centralManager: CBCentralManager!
    var peripheral: CBPeripheral!
    
    var foundDevices: Array<CBPeripheral> = []
    var scanCallback: ((Void) -> Void)? = nil
    var connectCallback: ((Void) -> Void)? = nil
    
    var characteristics: [CBCharacteristic] = []
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func scan(callback: @escaping (Void) -> Void) {
        foundDevices = []
        peripheral = nil
        characteristics = []
        
        if centralManager.state == CBManagerState.poweredOn {
            scanCallback = callback
            foundDevices = []
            centralManager.scanForPeripherals(withServices: [CBUUID.init(string: "FFE0")], options: nil)
            print("scanning started")
        }
    }
    
    func send(message: String) {
        let data = message.data(using: .utf8)
        for characteristic in characteristics {
            if characteristic.uuid.isEqual(CBUUID.init(string: "FFE1")) {
                peripheral.writeValue(data!, for: characteristic, type: .withoutResponse)
            }
        }
    }
    
    func connect(peripheral: CBPeripheral, callback: @escaping (Void) -> Void) {
        connectCallback = callback
        centralManager.connect(peripheral, options: nil)
    }
    
    func disconnect() {
        centralManager.cancelPeripheralConnection(peripheral)
        peripheral = nil
    }
    
    // CentralManager の State が変更されると呼ばれる
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("state: \(central.state.hashValue)")
    }
    
    // スキャン結果を受け取る
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        print("device: \(peripheral.name!), RSSI = \(RSSI)")
        foundDevices.append(peripheral)
        scanCallback!()
    }
    
    // Peripheral への接続が成功すると呼ばれる
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("connected to \(peripheral.name!)!")
        
        centralManager.stopScan()
        print("scanning stoped")
        
        self.peripheral = peripheral
        
        connectCallback!()
        
        peripheral.delegate = self
        peripheral.discoverServices([CBUUID.init(string: "FFE0")])
    }
    
    // Peripheral への接続が失敗すると呼ばれる
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("connecting to peripheral failed...")
    }
    
    // Services の探索結果を受け取る
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("error: \(error)")
            return
        }
        
        let services = peripheral.services
        print("Found \((services?.count)!) service")
        
        for service in services! {
            peripheral.discoverCharacteristics([CBUUID.init(string: "FFE1")], for: service)
        }
    }
    
    // Characteristics の探索結果を受け取る
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            print("error: \(error)")
        }
        
        characteristics = service.characteristics!
        print("Found \(characteristics.count) characteristic")
        
        let data = "connected".data(using: .utf8)
        for characteristic in characteristics {
            if characteristic.uuid.isEqual(CBUUID.init(string: "FFE1")) {
                peripheral.writeValue(data!, for: characteristic, type: .withoutResponse)
            }
        }
    }
}
