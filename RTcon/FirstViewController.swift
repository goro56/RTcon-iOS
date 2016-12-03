//
//  FirstViewController.swift
//  RTcon
//
//  Created by 下地勇人 on 2016/12/04.
//  Copyright © 2016年 下地勇人. All rights reserved.
//

import UIKit
import Foundation

class FirstViewController: UIViewController {
    
    let btConnection = BluetoothConnection.init()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // Scan Bluetooth Devices ボタン押下時
    @IBAction func pushScanButton(_ sender: Any) {
        performSegue(withIdentifier: "showDevicesList", sender: self)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showDevicesList" {
            let vc: DevicesListTableViewController = segue.destination as! DevicesListTableViewController
            vc.btConnection = btConnection
        }
    }
}
