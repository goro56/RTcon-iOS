//
//  PeerListViewController.swift
//  iOS_handson_Swift
//
//  Created by rokihiro on 2016/03/24.
//  Copyright © 2016年 ntt.com. All rights reserved.
//

import Foundation

//
//  ViewController.swift
//  UIKit006
//

import UIKit

class PeerListViewController: UITableViewController{
    
    var items: [AnyObject]?
    weak var callback: UIViewController?
    //    var myTableView:UITableView!
    
    
    //
    //    required init?(coder aDecoder: NSCoder) {
    //        fatalError("init(coder:) has not been implemented")
    //    }
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.tableView.allowsSelection = true
        self.tableView.allowsMultipleSelection = false
        
        let bbiBack:UIBarButtonItem = UIBarButtonItem.init(title: "Cancel", style: UIBarButtonItemStyle.plain, target: self, action: #selector(PeerListViewController.cancel))
        self.navigationItem.leftBarButtonItem = bbiBack
        
        self.tableView.register(UITableViewCell.self,forCellReuseIdentifier: "ITEMS")
        
        self.tableView.delegate = self;
        self.tableView.dataSource = self;
        
    }
    
    
    func cancel(){
        if self.callback != nil{
            self.callback?.dismiss(animated: true, completion: nil)
        }else{
            self.dismiss(animated: true, completion: nil)
        }
    }
    
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let strTo:String = (self.items![indexPath.row] as? String)!
        if self.callback != nil {
            self.callback?.dismiss(animated: true, completion: { () -> Void in
                if (self.callback?.responds(to: #selector(CallViewController.call(_:))))! == true{
                    DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.background).async(execute: { () -> Void in
                        let view = self.callback as! CallViewController
                        view.call(strTo)
                    })
                }
                
                if (self.callback?.responds(to: #selector(CallViewController.connect(_:))))! == true{
                    DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.background).async(execute: { () -> Void in
                        let view = self.callback as! CallViewController
                        view.connect(strTo)
                    })
                    
                }
            })
            
        }
    }
    
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return (items?.count)!
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        // 再利用するCellを取得する.
        let cell = tableView.dequeueReusableCell(withIdentifier: "ITEMS", for: indexPath)
        
        // Cellに値を設定する.
        cell.textLabel!.text = items![indexPath.row] as? String
        
        return cell
    }
    
}

