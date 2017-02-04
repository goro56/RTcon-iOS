//
//  CallViewController.swift
//  RTcon
//
//  Created by 下地勇人 on 2016/12/04.
//  Copyright © 2016年 下地勇人. All rights reserved.
//

import UIKit
import Foundation
import AVFoundation
import ReachabilitySwift

class CallViewController: UIViewController {
    var btConnection: BluetoothConnection? = nil
    weak var callback: UIViewController?
    let reachability = Reachability()!
    
    @IBOutlet weak var idLabel: UILabel!
    @IBOutlet weak var callButton: UIButton!
    
    var peer: SKWPeer?
    var localMedia: SKWMediaStream?
    var remoteMedia: SKWMediaStream?
    var mediaConnection: SKWMediaConnection?
    var id: String? = nil
    var peerIds: Array<String> = []
    var dataConnection: SKWDataConnection?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        self.callButton.isEnabled = false
        
        if nil != self.navigationController {
            self.navigationController?.delegate = self
        }
        
        // サーバへ接続
        // APIキー、ドメインを設定
        let option: SKWPeerOption = SKWPeerOption.init()
        option.key = "1bb5e4fc-4f56-4ee0-89dc-f36ec07aa7e5"
        option.domain = "localhost"
        
        // Peerオブジェクトのインスタンスを生成
        peer = SKWPeer.init(options: option)
        
        // コールバックを登録 (ERROR / 接続失敗時)
        peer?.on(.PEER_EVENT_ERROR, callback: { (obj: NSObject?) in
            let error: SKWPeerError = obj as! SKWPeerError
            
            let alert: UIAlertController = UIAlertController.init(title: "Peer Error (\(error.type.rawValue))", message: "\(error.message)", preferredStyle: .alert)
            alert.addAction(UIAlertAction.init(title: "OK", style: .default, handler: nil))
            
            self.present(alert, animated: true, completion: nil)
        })
        
        // コールバックを登録 (OPEN / 接続成功時)
        peer?.on(.PEER_EVENT_OPEN, callback: { (obj: NSObject?) in
            self.id = obj as? String
            DispatchQueue.main.async {
                self.idLabel.text = "your ID: \(self.id!)"
                self.callButton.isEnabled = true
            }
        })
        
        // メディアを取得
        SKWNavigator.initialize(peer)
        
        let constraints: SKWMediaConstraints = SKWMediaConstraints.init()
        constraints.cameraPosition = .CAMERA_POSITION_FRONT
        localMedia = SKWNavigator.getUserMedia(constraints) as SKWMediaStream
        
        //let localVideoView: SKWVideo = self.view.viewWithTag(ViewTag.tag_LOCAL_VIDEO.hashValue) as! SKWVideo
        //localVideoView.addSrc(localMedia, track: 0)
        
        // コールバックを登録（CALL / 相手から着信時)
        peer?.on(.PEER_EVENT_CALL, callback: { (obj: NSObject?) in
            self.mediaConnection = obj as? SKWMediaConnection
            self.mediaConnection?.answer(self.localMedia)
            self.setMediaCallbacks()
            self.updateUI()
        })
        
        // コールバックを登録（CONNECTION / 相手からデータ通信開始時)
        peer?.on(.PEER_EVENT_CONNECTION, callback: { (obj: NSObject?) in
            self.dataConnection = obj as? SKWDataConnection
            self.setDataCallbacks()
            self.updateUI()
        })
    }
    
    override func viewWillAppear(_ animated: Bool) {
        /*NotificationCenter.default.addObserver(self, selector: #selector(self.reachabilityChanged), name: ReachabilityChangedNotification, object: reachability)
        do{
            try reachability.startNotifier()
        }catch{
            print("Could not start reachability notifier")
        }*/
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    // Backボタン押下時
    @IBAction func onBack(_ sender: UIButton) {
        btConnection?.disconnect()
        
        if self.mediaConnection != nil {
            self.performSelector(inBackground: #selector(CallViewController.hangUp), with: nil)
        }
        
        if self.dataConnection != nil {
            self.performSelector(inBackground: #selector(CallViewController.disconnect), with: nil)
        }
        
        if peer != nil {
            peer?.disconnect()
        }
        
        let _ = self.navigationController?.popToRootViewController(animated: true)
    }
    
    // Call ボタン押下時
    @IBAction func pushCallButton(_ sender: AnyObject) {
        if self.mediaConnection == nil {
            self.getPeerList()
        }else{
            self.performSelector(inBackground: #selector(CallViewController.hangUp), with: nil)
        }
        
        if dataConnection != nil {
            self.performSelector(inBackground: #selector(CallViewController.disconnect), with: nil)
        }
    }
    
    // ネットワーク接続変化時
    func reachabilityChanged(note: NSNotification) {
        let reachability = note.object as! Reachability
        
        if reachability.isReachable {
            if reachability.isReachableViaWiFi {
                print("Reachable via WiFi")
            } else {
                print("Reachable via Cellular")
            }
        } else {
            print("Network not reachable")
        }
        
        if self.peer != nil {
            peer?.reconnect()
        }
    }
    
    func setMediaCallbacks(){
        // コールバックを登録（Stream）
        self.mediaConnection?.on(.MEDIACONNECTION_EVENT_STREAM, callback: { (obj: NSObject?) -> Void in
            self.remoteMedia = obj as? SKWMediaStream
            
            let session: AVAudioSession = AVAudioSession.sharedInstance()
            do {
                try session.overrideOutputAudioPort(.speaker)
            } catch {
                print("override output audio port error")
            }
            
            DispatchQueue.main.async { () -> Void in
                let remoteVideoView: SKWVideo = self.view.viewWithTag(ViewTag.tag_REMOTE_VIDEO.hashValue) as! SKWVideo
                remoteVideoView.isHidden = false
                remoteVideoView.addSrc(self.remoteMedia, track: 0)
            }
        })
        
        // コールバックを登録（Close）
        self.mediaConnection?.on(.MEDIACONNECTION_EVENT_CLOSE, callback: { (obj: NSObject?) -> Void in
            self.remoteMedia = obj as? SKWMediaStream
            
            DispatchQueue.main.async { () -> Void in
                let remoteVideoView:SKWVideo = self.view.viewWithTag(ViewTag.tag_REMOTE_VIDEO.hashValue) as! SKWVideo
                remoteVideoView.removeSrc(self.remoteMedia, track: 0)
                self.remoteMedia = nil
                self.mediaConnection = nil
                remoteVideoView.isHidden = true
            }
            
            self.updateUI()
        })
    }
    
    func setDataCallbacks(){
        // コールバックを登録(チャンネルOPEN)
        self.dataConnection?.on(.DATACONNECTION_EVENT_OPEN, callback: { (obj: NSObject?) -> Void in
            print("[system] DataConnection opened")
        })
        
        // コールバックを登録(DATA受信)
        self.dataConnection?.on(.DATACONNECTION_EVENT_DATA, callback: { (obj: NSObject?) -> Void in
            let strValue:String = obj as! String
            print("[Partner] \(strValue)")
            self.btConnection?.send(message: strValue)
        })
        
        // コールバックを登録(チャンネルCLOSE)
        self.dataConnection?.on(.DATACONNECTION_EVENT_CLOSE, callback: { (obj: NSObject?) -> Void in
            self.dataConnection = nil
            print("[system] DataConnection closed")
            self.updateUI()
        })
        
        self.btConnection?.read(callback: { (message: String) in
            self.send(message)
        })
    }
    
    // ビデオ通話を開始する
    func call(destId: String) {
        let option = SKWCallOption()
        mediaConnection = peer!.call(withId: destId, stream: localMedia, options: option)
        if mediaConnection != nil {
            self.setMediaCallbacks()
        }
        self.updateUI()
    }
    
    // ビデオ通話を終了する
    func hangUp(){
        if mediaConnection != nil{
            if remoteMedia != nil{
                let remoteVideoView:SKWVideo = self.view.viewWithTag(ViewTag.tag_REMOTE_VIDEO.hashValue) as! SKWVideo
                
                remoteVideoView.removeSrc(remoteMedia, track: 0)
                remoteMedia?.close()
                remoteMedia = nil
            }
            mediaConnection?.close()
        }
        self.updateUI()
    }
    
    // データチャンネルを開く
    func connect(destId: String) {
        let options = SKWConnectOption()
        options.reliable = true
        
        self.dataConnection = peer?.connect(withId: destId, options: options)
        setDataCallbacks()
    }
    
    // 接続を終了する
    func disconnect(){
        if dataConnection != nil {
            dataConnection?.close()
        }
    }
    
    // テキストデータを送信する
    func send(_ data:String){
        let bResult: Bool = (dataConnection?.send(data as NSObject!))!
        if bResult {
            print("[send] \(data)")
        }
    }
    
    // Peerリストを取得
    func getPeerList(){
        if (peer == nil) || (id == nil) || (id?.characters.count == 0) {
            return
        }
        
        peer?.listAllPeers({ (peers:[Any]?) -> Void in
            self.peerIds = []
            let peersArray:[String] = peers as! [String]
            for strValue: String in peersArray {
                if strValue != self.id {
                    self.peerIds.append(strValue)
                }
            }
            
            if self.peerIds.count >= 0 {
                self.showPeerDialog()
            }
        })
    }
    
    // Peer の一覧（TableView）を表示
    func showPeerDialog(){
        let vc = PeerListViewController()
        vc.items = peerIds as [AnyObject]?
        vc.callback = self
        
        let nc = UINavigationController.init(rootViewController: vc)
        
        DispatchQueue.main.async(execute: {
            self.present(nc, animated: true, completion: nil)
        })
        
        //performSegue(withIdentifier: "showPeerList", sender: self)
    }
    
    // UIのセットアップ
    func setupUI(){
        let rcScreen: CGRect = self.view.bounds
        
        //ローカルビデオ用のView
        var rcLocal: CGRect = CGRect.zero
        rcLocal.size.width = rcScreen.size.height / 5
        rcLocal.size.height = rcLocal.size.width
        
        rcLocal.origin.x = rcScreen.size.width - rcLocal.size.width - 8.0
        rcLocal.origin.y = rcScreen.size.height - rcLocal.size.height - 8.0
        rcLocal.origin.y -= (self.navigationController?.toolbar.frame.size.height)!
        
        let vwVideo: SKWVideo = SKWVideo.init(frame: rcLocal)
        vwVideo.tag = ViewTag.tag_LOCAL_VIDEO.hashValue
        vwVideo.isHidden = true
        self.view.addSubview(vwVideo)
        
        //リモートビデオ用のView
        var rcRemote: CGRect = CGRect.zero
        rcRemote.size.width = rcScreen.size.width
        rcRemote.size.height = rcRemote.size.width
        
        rcRemote.origin.x = (rcScreen.size.width - rcRemote.size.width) / 2.0
        rcRemote.origin.y = (rcScreen.size.height - rcRemote.size.height) / 2.0
        rcRemote.origin.y -= 8.0
        
        let vwRemote: SKWVideo = SKWVideo.init(frame: rcRemote)
        vwRemote.tag = ViewTag.tag_REMOTE_VIDEO.hashValue
        vwRemote.isHidden = true
        self.view.addSubview(vwRemote)
        
        self.updateUI()
    }
    
    func updateUI(){
        DispatchQueue.main.async { () -> Void in
            //CALLボタンのアップデート
            if self.mediaConnection == nil {
                self.callButton.titleLabel?.text = "Call"
            }else{
                self.callButton.titleLabel?.text = "Hang up"
            }
            
            //IDラベルのアップデート
            if self.id == nil {
                self.idLabel.text = "your Id:"
            }else{
                self.idLabel.text = "your Id:" + self.id! as String
            }
        }
    }
    
    enum ViewTag : UInt {
        case tagid = 1000
        case tag_WEBRTC_ACTION
        case tag_REMOTE_VIDEO
        case tag_LOCAL_VIDEO
    }
    
    /*
    func appendLogWithMessage(_ strMessage:String){
        print("message: \(strMessage)")
    }
    */
    
    /*
    func appendLogWithHead(_ strHeader: String?, value strValue: String) {
        if 0 == strValue.characters.count {
            return
        }
        let mstrValue = NSMutableString()
        if nil != strHeader {
            mstrValue.append("[")
            mstrValue.append(strHeader!)
            mstrValue.append("] ")
        }
        if 32000 < strValue.characters.count {
            //            var rng:NSRange = NSMakeRange(0, 32)
            mstrValue.append(strValue.substring(with: (strValue.characters.index(strValue.startIndex, offsetBy: 0) ..< strValue.characters.index(strValue.startIndex, offsetBy: 32))))
            mstrValue.append("...")
            //            rng = NSMakeRange(strValue.characters.count - 32, 32)
            mstrValue.append(strValue.substring(with: (strValue.characters.index(strValue.startIndex, offsetBy: strValue.characters.count - 32) ..< strValue.characters.index(strValue.startIndex, offsetBy: 32))))
        } else {
            mstrValue.append(strValue)
        }
        mstrValue.append("\n")
        self.performSelector(onMainThread: #selector(CallViewController.appendLogWithMessage(_:)), with: mstrValue, waitUntilDone: true)
    }
    */
    
    /*
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showPeerList" {
            let vc: PeerListViewController = segue.destination as! PeerListViewController
            vc.items = peerIds as [AnyObject]?
            vc.callback = self
        }
    }
    */
}

extension CallViewController: UINavigationControllerDelegate, UIAlertViewDelegate {
}
