//
//  ViewController.swift
//  RTcon
//
//  Created by 下地勇人 on 2016/10/26.
//  Copyright © 2016年 下地勇人. All rights reserved.
//

import UIKit
import CoreBluetooth

class ViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    var centralManager: CBCentralManager!
    var peripheral: CBPeripheral!

    override func viewDidLoad() {
        super.viewDidLoad()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func scan() {
        centralManager.scanForPeripherals(withServices: [CBUUID.init(string: "B83BD1D0-1FB0-4A96-A471-E2300982C40A")], options: nil)
        print("scanning started")
    }

    // CentralManager の State が変更されると呼ばれる
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("state: \(central.state)")
        scan()
    }
    
    // スキャン結果を受け取る
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if RSSI.intValue < -50 || -15 < RSSI.intValue {
            print("eject: \(peripheral.name), RSSI = \(RSSI)")
            return;
        }
        print("peripheral: \(peripheral)")
        if self.peripheral != peripheral {
            self.peripheral = peripheral
            centralManager.connect(self.peripheral, options: nil)
        }
    }
    
    // Peripheral への接続が成功すると呼ばれる
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("connected!")
        
        centralManager.stopScan()
        print("scanning stoped")
        
        peripheral.delegate = self
        peripheral.discoverServices([CBUUID.init(string: "B83BD1D0-1FB0-4A96-A471-E2300982C40A")])
    }
    
    // Peripheral への接続が失敗すると呼ばれる
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("failed...")
    }
    
    // Services の探索結果を受け取る
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("error: \(error)")
            return
        }
        
        let services = peripheral.services
        print("Found \(services?.count) services! :\(services)")
        
        for service in services! {
            peripheral.discoverCharacteristics([CBUUID.init(string: "B83BD1D0-1FB0-4A96-A471-E2300982C40B")], for: service)
        }
    }
    
    // Characteristics の探索結果を受け取る
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            print("error: \(error)")
        }
        
        let characteristics = service.characteristics
        print("Found \(characteristics?.count) characteristics! : \(characteristics)")
        
        let data = "hello world!".data(using: .utf8)
        for characteristic in characteristics! {
            if characteristic.uuid.isEqual(CBUUID.init(string: "B83BD1D0-1FB0-4A96-A471-E2300982C40B")) {
                peripheral.writeValue(data!, for: characteristic, type: .withResponse)
            }
        }
    }

}

