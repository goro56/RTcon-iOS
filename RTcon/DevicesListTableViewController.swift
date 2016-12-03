//
//  DevicesListTableViewController.swift
//  RTcon
//
//  Created by 下地勇人 on 2016/12/04.
//  Copyright © 2016年 下地勇人. All rights reserved.
//

import UIKit
import Foundation
import CoreBluetooth

class DevicesListTableViewController: UITableViewController {
    
    var btConnection: BluetoothConnection? = nil
    weak var callback: UIViewController?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.tableView.allowsSelection = true
        self.tableView.allowsMultipleSelection = false
        self.navigationItem.title = "Select Device"
        
        let bbiBack:UIBarButtonItem = UIBarButtonItem.init(title: "Cancel", style: UIBarButtonItemStyle.plain, target: self, action: #selector(PeerListViewController.cancel))
        self.navigationItem.leftBarButtonItem = bbiBack
        
        self.tableView.register(UITableViewCell.self,forCellReuseIdentifier: "cell")
        
        self.tableView.delegate = self;
        self.tableView.dataSource = self;
        
        btConnection?.scan(callback: updateDevicesList)
    }
    
    func updateDevicesList() {
        self.tableView.reloadData()
    }
    
    func cancel(){
        if self.callback != nil{
            self.callback?.dismiss(animated: true, completion: nil)
        }else{
            self.dismiss(animated: true, completion: nil)
        }
    }
    
    func showCallView() {
        performSegue(withIdentifier: "showCallView", sender: self)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        btConnection?.connect(peripheral: (btConnection?.foundDevices[indexPath.row])!, callback: showCallView)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return (btConnection?.foundDevices.count)!
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // 再利用するCellを取得する.
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        
        // Cellに値を設定する.
        cell.textLabel!.text = (btConnection?.foundDevices[indexPath.row].name!)! as String
        print("\(btConnection?.foundDevices[indexPath.row].name)")
        
        return cell
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showCallView" {
            let vc: CallViewController = segue.destination as! CallViewController
            vc.btConnection = btConnection
        }
    }
}
